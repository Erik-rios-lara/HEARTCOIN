import { createClient } from 'jsr:@supabase/supabase-js@2';
import { originalAuthRequest } from '../_shared/originalauth.ts';

/// Reenvía el código de verificación de correo vía Original Auth.
Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const anonClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userError } = await anonClient.auth.getUser();
  if (userError || !userData.user || !userData.user.email) {
    return new Response(JSON.stringify({ error: 'No autenticado.' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const result = await originalAuthRequest(
    'POST',
    '/api/v1/integrations/registration/resend-verification',
    { email: userData.user.email },
  );

  if (result.status !== 200) {
    return new Response(
      JSON.stringify({ error: 'No se pudo reenviar el código.' }),
      { status: 502, headers: { 'Content-Type': 'application/json' } },
    );
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
