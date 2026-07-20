import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  originalAuthRequest,
  profileTableForRole,
} from '../_shared/originalauth.ts';

/// Dispara la verificación de correo en Original Auth justo después de
/// que la cuenta ya se creó en Supabase. Ver ORIGINAL_AUTH_INTEGRATION.md.
Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const { password } = await req.json().catch(() => ({}));
  if (!password || typeof password !== 'string') {
    return new Response(
      JSON.stringify({ error: 'Falta la contraseña.' }),
      { status: 422, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const anonClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userError } = await anonClient.auth.getUser();
  if (userError || !userData.user) {
    return new Response(JSON.stringify({ error: 'No autenticado.' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const user = userData.user;
  const email = user.email;
  if (!email) {
    return new Response(
      JSON.stringify({ error: 'La cuenta no tiene correo.' }),
      { status: 422, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const role = user.user_metadata?.role as string | undefined;
  const table = profileTableForRole(role);

  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const nameColumn = table === 'personal_profiles' ? 'full_name' : 'representative_name';
  const { data: profile } = await adminClient
    .from(table)
    .select(nameColumn)
    .eq('id', user.id)
    .maybeSingle();

  const fullName = (profile?.[nameColumn] as string | undefined)?.trim() ?? '';
  const [firstName, ...rest] = fullName.split(' ').filter(Boolean);
  const lastName = rest.join(' ');

  // No mandamos `country`: en HeartCoin es texto libre (ej. "México"),
  // y Original Auth espera un código corto (ISO 3166-1 alpha-2, máx 5
  // caracteres) — mandar el texto libre causa un 400. El campo es
  // opcional para este flujo, así que simplemente se omite.
  const result = await originalAuthRequest(
    'POST',
    '/api/v1/integrations/registration',
    {
      email,
      password,
      first_name: firstName || 'Usuario',
      last_name: lastName || 'HeartCoin',
      language: 'es',
    },
  );

  // 409: el correo ya está registrado en Original Auth (ej. un intento
  // previo que no se verificó). No es un error fatal para este flujo —
  // seguimos para que el usuario pueda reenviar/ingresar su código.
  if (result.status !== 200 && result.status !== 201 && result.status !== 409) {
    return new Response(
      JSON.stringify({
        error: 'No se pudo iniciar la verificación de correo.',
        detail: result.body,
      }),
      { status: 502, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const data = result.body?.data as Record<string, unknown> | undefined;
  const externalId = (data?.user as Record<string, unknown> | undefined)?.id as
    | string
    | undefined;

  if (externalId) {
    await adminClient
      .from(table)
      .update({ original_auth_id: externalId })
      .eq('id', user.id);
  }

  // Solo en el ambiente `test` de Original Auth: no se envía correo real
  // (a propósito, para no gastar cuota del proveedor de email), y la
  // respuesta trae el token de verificación directo en
  // `data.verification.token`. En `prod` este campo no viene — el
  // usuario sí recibe el correo real y lo escribe a mano.
  const verification = data?.verification as Record<string, unknown> | undefined;
  const testToken = verification?.token as string | undefined;

  return new Response(JSON.stringify({ ok: true, testToken }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
