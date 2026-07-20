import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  originalAuthRequest,
  profileTableForRole,
} from '../_shared/originalauth.ts';

/// Confirma el código de verificación de correo contra Original Auth y
/// marca email_verified en el perfil de HeartCoin correspondiente.
Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const { code } = await req.json().catch(() => ({}));
  if (!code || typeof code !== 'string') {
    return new Response(JSON.stringify({ error: 'Falta el código.' }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    });
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
  const role = user.user_metadata?.role as string | undefined;
  const table = profileTableForRole(role);

  const result = await originalAuthRequest(
    'POST',
    '/api/v1/integrations/registration/verify-email',
    { token: code },
  );

  if (result.status !== 200) {
    const error = result.body?.error as Record<string, unknown> | undefined;
    return new Response(
      JSON.stringify({
        error: (error?.message as string | undefined) ?? 'Código inválido o vencido.',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  await adminClient
    .from(table)
    .update({ email_verified: true })
    .eq('id', user.id);

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
