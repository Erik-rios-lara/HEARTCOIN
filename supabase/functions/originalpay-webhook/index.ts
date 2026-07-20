import { createClient } from 'jsr:@supabase/supabase-js@2';

/// Webhook de notificaciones de Original Pay (pago aprobado/rechazado).
/// A diferencia de originalpay-balance/originalpay-redeem, Original Pay
/// NO firma este request con HMAC en headers — autentica mandando
/// `token_app`/`secret_key` dentro del body JSON. Hay que compararlos
/// contra las credenciales que ellos mismos generaron para esta app.
/// Ver ORIGINAL_PAY_INTEGRATION.md.

const TOKEN_APP = Deno.env.get('ORIGINALPAY_WEBHOOK_TOKEN_APP')!;
const SECRET_KEY = Deno.env.get('ORIGINALPAY_WEBHOOK_SECRET_KEY')!;

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const payload = await req.json().catch(() => null);
  if (!payload) {
    return new Response(JSON.stringify({ error: 'json_invalido' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const tokenApp = payload.token_app as string | undefined;
  const secretKey = payload.secret_key as string | undefined;
  if (
    !tokenApp ||
    !secretKey ||
    !timingSafeEqual(tokenApp, TOKEN_APP) ||
    !timingSafeEqual(secretKey, SECRET_KEY)
  ) {
    return new Response(JSON.stringify({ error: 'no_autenticado' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const orderNumber = payload.order_number as string | undefined;
  const paymentStatus = payload.payment_status as string | undefined;
  if (!orderNumber || !paymentStatus) {
    return new Response(JSON.stringify({ error: 'faltan_campos' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // "approved" no requiere ninguna acción de nuestro lado: el HC ya se
  // descontó cuando Original Pay llamó a /originalpay-redeem. Solo se
  // reconoce la notificación.
  if (paymentStatus !== 'rejected') {
    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // "rejected": el pago no se completó, así que hay que devolverle al
  // usuario el HC que ya se le había descontado en el redeem original.
  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: original } = await adminClient
    .from('hc_transactions')
    .select('id, user_id, amount')
    .eq('reference_type', 'originalpay')
    .eq('external_reference', orderNumber)
    .maybeSingle();

  if (!original) {
    // No encontramos el cobro original — no hay nada que reembolsar
    // (puede ser un pago que nunca pasó por /originalpay-redeem).
    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const { data: alreadyRefunded } = await adminClient
    .from('hc_transactions')
    .select('id')
    .eq('reference_type', 'originalpay_refund')
    .eq('external_reference', orderNumber)
    .maybeSingle();

  if (alreadyRefunded) {
    // Ya se procesó este reembolso antes (reintento del webhook) —
    // no duplicar el crédito.
    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const refundAmount = Math.abs(original.amount as number);
  await adminClient.from('hc_transactions').insert({
    user_id: original.user_id,
    amount: refundAmount,
    type: 'ajuste',
    reference_type: 'originalpay_refund',
    external_reference: orderNumber,
  });

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
