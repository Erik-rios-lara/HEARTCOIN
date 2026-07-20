# Integración HeartCoin ↔ Original Pay

Este documento describe cómo Original Pay consulta el saldo de HeartCoin (HC) de un usuario y registra un cobro con HC, sin pasar por la app de HeartCoin.

**Estado: implementado y probado.** Los 3 endpoints (consulta de saldo, cobro, webhook de notificaciones) están desplegados y verificados de punta a punta, incluyendo el flujo completo de reembolso automático ante un pago rechazado.

---

## 1. Dónde vive esto

Son **Supabase Edge Functions**, el mismo mecanismo que ya usa HeartCoin para otras integraciones server-to-server (MediaAAS, Original Auth). Se hospedan y escalan automáticamente dentro del proyecto de Supabase de HeartCoin.

**Base URL:** `https://bamrvwzpcqwoyuwbvomw.supabase.co/functions/v1/`

Estas dos funciones se desplegaron con `--no-verify-jwt`: por defecto, toda Edge Function de Supabase exige un JWT propio de Supabase antes de dejar pasar el request (a nivel de plataforma, antes de que corra nuestro código). Como Original Pay no tiene sesión de usuario de Supabase, esa capa se desactivó para estas dos rutas — la seguridad real la da nuestra propia verificación HMAC (sección 3), no la plataforma.

---

## 2. Identificación del usuario

**Resuelto: se identifica por correo electrónico**, no por un ID interno de ningún sistema. Confirmado directamente con Lucero (equipo de Original Pay): así es como ya identifican usuarios al integrar un nuevo método de pago.

Nota: HeartCoin también guarda `original_auth_id` en cada perfil (desde la integración de verificación de correo con Original Auth), pero no se usa aquí — el correo es más simple y ya es el criterio que usa Original Pay.

---

## 3. Autenticación entre Original Pay y HeartCoin

Firma HMAC-SHA256 por request, mismo patrón que ya usa HeartCoin con MediaAAS y con Original Auth (ver `supabase/functions/_shared/originalpay_auth.ts`):

1. HeartCoin genera una **API key** que sirve también como secreto de firma (un solo valor, mismo patrón que ya usa Original Auth con nosotros — no hay un "API key" y un "secreto" separados).
2. Por cada request, Original Pay arma la cadena canónica:
   ```
   <MÉTODO>\n<ruta-con-query-canónica>\n<timestamp-unix>\n<sha256-hex-del-body-exacto>
   ```
   - La ruta incluye el query string si lo hay, con las claves **ordenadas alfabéticamente** (mismo criterio que usa Original Auth para firmar hacia nosotros).
   - El body debe ser el string exacto que se envía — no se puede serializar una vez para firmar y otra vez para transmitir.
   - Para `GET /originalpay-balance` (sin body), el hash SHA-256 es el de la cadena vacía (`""`).
3. Firma esa cadena con HMAC-SHA256 usando la API key como secreto, y envía:

   | Header | Valor |
   |---|---|
   | `X-Api-Key` | La API key |
   | `X-Timestamp` | Timestamp Unix (segundos) del request |
   | `X-Signature` | `sha256=<firma hex>` |

4. HeartCoin recalcula la firma; si no coincide, si falta algún header, o si `X-Timestamp` está fuera de una ventana de ±5 minutos (anti-replay), responde `401 — { "error": "no_autenticado" }`. La comparación de la firma es de tiempo constante (no vulnerable a timing attacks).

**Nota sobre duplicidad:** Original Pay ya maneja su propia prevención de cobros duplicados, así que HeartCoin no implementa idempotencia adicional sobre `order_reference` — se guarda solo como referencia para trazabilidad/conciliación, no como clave única.

---

## 4. Endpoints

### 4.1 Consultar saldo

**`GET /functions/v1/originalpay-balance?email=<correo>`**

| Respuesta | Código | Body |
|---|---|---|
| Éxito | `200` | `{ "email": "...", "hc_balance": 1250 }` |
| Falta el parámetro `email` | `422` | `{ "error": "falta_email" }` |
| Usuario no encontrado | `404` | `{ "error": "usuario_no_encontrado" }` |
| Firma inválida / vencida | `401` | `{ "error": "no_autenticado" }` |

### 4.2 Registrar un cobro con HC

**`POST /functions/v1/originalpay-redeem`**

Body:
```json
{
  "email": "usuario@example.com",
  "amount_hc": 300,
  "order_reference": "id de la orden en Original Pay",
  "description": "opcional, no se persiste todavía — ver pendientes"
}
```

Comportamiento:
- Busca al usuario en `personal_profiles` por `email`.
- Valida que `hc_balance >= amount_hc`.
- Inserta una fila en `hc_transactions` (`type: 'redemption_spend'`, `reference_type: 'originalpay'`, `external_reference: order_reference`) — el balance se actualiza solo, vía el mismo trigger que ya usan los canjes de beneficios/servicios dentro de la app. La función **nunca** escribe `hc_balance` directo.
- Responde con el nuevo saldo ya actualizado.

| Respuesta | Código | Body |
|---|---|---|
| Éxito | `200` | `{ "transaction_id": "...", "new_balance": 950 }` |
| Saldo insuficiente | `409` | `{ "error": "hc_insuficiente" }` |
| Usuario no encontrado | `404` | `{ "error": "usuario_no_encontrado" }` |
| Faltan campos / `amount_hc` inválido | `422` | `{ "error": "faltan_campos" }` |
| Firma inválida / vencida | `401` | `{ "error": "no_autenticado" }` |
| Error interno al registrar | `500` | `{ "error": "no_se_pudo_registrar" }` |

---

## 5. Dónde vive la API key

Configurada como secret de las Edge Functions (`ORIGINALPAY_API_KEY`), nunca en el código:

```bash
supabase secrets set ORIGINALPAY_API_KEY=heartcoin_live_...
supabase functions deploy originalpay-balance --no-verify-jwt
supabase functions deploy originalpay-redeem --no-verify-jwt
```

Esa misma key es la que Original Pay necesita para firmar sus requests — se le comparte a Lucero por un canal seguro (no por chat/correo en texto plano), y ella la guarda del lado de Original Pay con el mismo cuidado que cualquier credencial de servidor.

---

## 6. Webhook de notificaciones (Original Pay → HeartCoin)

**`POST /functions/v1/originalpay-webhook`** — Original Pay nos notifica el resultado final de un pago. A diferencia de los dos endpoints anteriores, **este lo llama Original Pay, no lo llamamos nosotros**, y **no usa firma HMAC**: autentican incluyendo `token_app` y `secret_key` (las credenciales que su panel generó para la aplicación de HeartCoin) directo en el body JSON. Se verifican con comparación de tiempo constante contra los secrets `ORIGINALPAY_WEBHOOK_TOKEN_APP`/`ORIGINALPAY_WEBHOOK_SECRET_KEY`.

Body que envían (dos variantes, según `payment_status`):

```json
{
  "token_app": "...",
  "secret_key": "...",
  "order_number": "ORD-00042",
  "app_order_id": 42,
  "payment_status": "approved",
  "payment_method": "heartcoin",
  "amount": 300.0,
  "currency": "MXN",
  "payer_email": "usuario@correo.com",
  "raw_data": { "transaction_id": 42, "payment_date": 1719859200, "amount_received": 300.0 }
}
```

`payment_status` también puede ser `"rejected"` (con `raw_data.error_message` en vez de `amount_received`).

**Comportamiento:**
- `"approved"`: no requiere ninguna acción — el HC ya se descontó cuando Original Pay llamó a `/originalpay-redeem`. Solo se responde `200`.
- `"rejected"`: el pago no se completó, así que **se reembolsa automáticamente** el HC que ya se había descontado. Busca en `hc_transactions` la transacción original por `reference_type = 'originalpay'` + `external_reference = order_number` (no se usa el campo `amount`/`currency` del webhook para calcular el reembolso — viene en MXN, no en HC; se reembolsa exactamente lo que nuestro propio ledger registró que se descontó). Inserta una transacción compensatoria (`type: 'ajuste'`, `reference_type: 'originalpay_refund'`, mismo `external_reference`).
- **Idempotente**: si el mismo `order_number` ya tiene un reembolso registrado (`reference_type = 'originalpay_refund'`), no se duplica — importante porque los webhooks pueden reintentarse.
- Si no se encuentra la transacción original (ej. un pago que nunca pasó por `/originalpay-redeem`), simplemente se responde `200` sin hacer nada — no es un error.

Siempre responde `200 { "received": true }` salvo error de autenticación (`401`) o payload inválido (`400`). No se filtran detalles internos.

```bash
supabase secrets set ORIGINALPAY_WEBHOOK_TOKEN_APP=app_... ORIGINALPAY_WEBHOOK_SECRET_KEY=sk_...
supabase functions deploy originalpay-webhook --no-verify-jwt
```

Probado de punta a punta: cobro real → webhook `rejected` → HC devuelto correctamente → reintento del mismo webhook confirmado que no duplica el reembolso.

**URL para dar de alta en el dashboard de Original Pay:** `https://bamrvwzpcqwoyuwbvomw.supabase.co/functions/v1/originalpay-webhook`

Las URLs de Retorno / Éxito / Error / Front no aplican a esta integración (confirmado con Lucero) — son para flujos de checkout con redirección web, y esta integración es 100% server-to-server. Se dejan vacías en su dashboard.

## 7. Pendiente de definir

- **`description` no se persiste todavía**: el endpoint `redeem` la acepta en el body pero hoy no se guarda en ningún lado (no hay columna para eso en `hc_transactions`). Si Original Pay la necesita para conciliación, hay que agregar una columna.
- **Condición de carrera en `redeem`**: la validación de saldo y el registro de la transacción no son atómicos entre sí (se lee el saldo, luego se inserta) — dos cobros simultáneos al mismo usuario podrían, en teoría, sobregirar el saldo por una fracción de segundo. Es el mismo comportamiento que ya tienen `redeem_beneficio`/`redeem_servicio` internos de la app (no es una regresión nueva), pero como este endpoint lo dispara un tercero externo, vale la pena endurecerlo más adelante (ej. una función de Postgres con bloqueo de fila) si el volumen de transacciones lo justifica.
- **Límites de monto por transacción**, si los hay, del lado de negocio.
- **El webhook no tiene firma criptográfica**, solo un secreto compartido en el body — más débil que HMAC (sin protección anti-replay real, aunque HTTPS protege el tránsito). Es el diseño que ya tiene Original Pay del otro lado, no algo que podamos cambiar nosotros.
