import { createClient } from 'jsr:@supabase/supabase-js@2';
import { verifyOriginalPaySignature } from '../_shared/originalpay_auth.ts';

/// Registra un cobro con HC iniciado desde Original Pay. Descuenta del
/// ledger de HC de HeartCoin (hc_transactions) — nunca escribe
/// hc_balance directo, se actualiza solo vía el trigger existente. Ver
/// ORIGINAL_PAY_INTEGRATION.md.
Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const rawBody = await req.text();
  const verification = await verifyOriginalPaySignature(
    req,
    '/originalpay-redeem',
    rawBody,
  );
  if (!verification.ok) {
    return new Response(JSON.stringify({ error: verification.error }), {
      status: verification.status,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const payload = JSON.parse(rawBody || '{}');
  const email = payload.email as string | undefined;
  const amountHc = payload.amount_hc as number | undefined;
  const orderReference = payload.order_reference as string | undefined;

  if (
    !email ||
    typeof amountHc !== 'number' ||
    !Number.isFinite(amountHc) ||
    amountHc <= 0 ||
    !orderReference
  ) {
    return new Response(JSON.stringify({ error: 'faltan_campos' }), {
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
    .select('id, hc_balance')
    .eq('email', email)
    .maybeSingle();

  if (!profile) {
    return new Response(JSON.stringify({ error: 'usuario_no_encontrado' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  if ((profile.hc_balance ?? 0) < amountHc) {
    return new Response(JSON.stringify({ error: 'hc_insuficiente' }), {
      status: 409,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const { data: inserted, error: insertError } = await adminClient
    .from('hc_transactions')
    .insert({
      user_id: profile.id,
      amount: -amountHc,
      type: 'redemption_spend',
      reference_type: 'originalpay',
      external_reference: orderReference,
    })
    .select('id')
    .single();

  if (insertError || !inserted) {
    return new Response(JSON.stringify({ error: 'no_se_pudo_registrar' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const { data: updatedProfile } = await adminClient
    .from('personal_profiles')
    .select('hc_balance')
    .eq('id', profile.id)
    .maybeSingle();

  return new Response(
    JSON.stringify({
      transaction_id: inserted.id,
      new_balance: updatedProfile?.hc_balance ?? profile.hc_balance - amountHc,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
