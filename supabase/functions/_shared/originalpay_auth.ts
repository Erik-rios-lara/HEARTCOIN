// Verificación de firma HMAC entrante para las peticiones de Original Pay
// hacia HeartCoin (dirección inversa a `_shared/originalauth.ts`, que
// firma peticiones salientes hacia Original Auth). Ver
// ORIGINAL_PAY_INTEGRATION.md.

const API_KEY = Deno.env.get('ORIGINALPAY_API_KEY')!;
const MAX_SKEW_SECONDS = 300; // ±5 minutos, frena replay de requests viejos

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(hash)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

async function hmacSha256Hex(key: string, message: string): Promise<string> {
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(key),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'HMAC',
    cryptoKey,
    new TextEncoder().encode(message),
  );
  return [...new Uint8Array(signature)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Ruta canónica: query params ordenados alfabéticamente, mismo criterio
 * que usa Original Auth para firmar hacia nosotros (ver
 * `_shared/originalauth.ts` / guía de integración mobile). */
export function canonicalPathWithQuery(
  pathname: string,
  searchParams: URLSearchParams,
): string {
  const keys = [...new Set(searchParams.keys())].sort();
  const params = new URLSearchParams();
  for (const key of keys) {
    for (const value of searchParams.getAll(key)) params.append(key, value);
  }
  const query = params.toString();
  return query ? `${pathname}?${query}` : pathname;
}

export type VerifyResult = { ok: true } | { ok: false; status: number; error: string };

/** Verifica `X-Api-Key` + `X-Timestamp` + `X-Signature` de un request de
 * Original Pay. `path` debe ser la ruta canónica (con query si aplica) y
 * `rawBody` el body exacto tal como llegó (sin volver a serializar). */
export async function verifyOriginalPaySignature(
  req: Request,
  path: string,
  rawBody: string,
): Promise<VerifyResult> {
  const apiKey = req.headers.get('X-Api-Key');
  const timestamp = req.headers.get('X-Timestamp');
  const signatureHeader = req.headers.get('X-Signature');

  if (!apiKey || !timingSafeEqual(apiKey, API_KEY)) {
    return { ok: false, status: 401, error: 'no_autenticado' };
  }
  if (!timestamp || !signatureHeader) {
    return { ok: false, status: 401, error: 'no_autenticado' };
  }

  const ts = Number(timestamp);
  const now = Math.floor(Date.now() / 1000);
  if (!Number.isFinite(ts) || Math.abs(now - ts) > MAX_SKEW_SECONDS) {
    return { ok: false, status: 401, error: 'no_autenticado' };
  }

  const bodyHash = await sha256Hex(rawBody);
  const canonical = [req.method.toUpperCase(), path, timestamp, bodyHash].join(
    '\n',
  );
  const expected = await hmacSha256Hex(API_KEY, canonical);
  const provided = signatureHeader.replace(/^sha256=/, '');

  if (!timingSafeEqual(provided, expected)) {
    return { ok: false, status: 401, error: 'no_autenticado' };
  }
  return { ok: true };
}
