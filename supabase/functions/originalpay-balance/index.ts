import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  canonicalPathWithQuery,
  verifyOriginalPaySignature,
} from '../_shared/originalpay_auth.ts';

/// Consulta el saldo de HC de un usuario para Original Pay. Server-to-
/// server, firmado con HMAC — nunca usa la sesión del usuario final. Ver
/// ORIGINAL_PAY_INTEGRATION.md.
Deno.serve(async (req) => {
  if (req.method !== 'GET') {
    return new Response('Method not allowed', { status: 405 });
  }

  const url = new URL(req.url);
  const path = canonicalPathWithQuery('/originalpay-balance', url.searchParams);

  const verification = await verifyOriginalPaySignature(req, path, '');
  if (!verification.ok) {
    return new Response(JSON.stringify({ error: verification.error }), {
      status: verification.status,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const email = url.searchParams.get('email');
  if (!email) {
    return new Response(JSON.stringify({ error: 'falta_email' }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: profile } = await adminClient
    .from('personal_profiles')
    .select('hc_balance')
    .eq('email', email)
    .maybeSingle();

  if (!profile) {
    return new Response(JSON.stringify({ error: 'usuario_no_encontrado' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  return new Response(
    JSON.stringify({ email, hc_balance: profile.hc_balance }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
