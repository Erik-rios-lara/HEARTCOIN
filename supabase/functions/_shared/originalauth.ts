// Cliente firmado para la API server-to-server de Original Auth
// (integraciones por API key + HMAC-SHA256). Ver ORIGINAL_AUTH_INTEGRATION.md.

const AUTH_BASE_URL = Deno.env.get('ORIGINAL_AUTH_BASE_URL')!;
const AUTH_API_KEY = Deno.env.get('ORIGINAL_AUTH_API_KEY')!;

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

export interface OriginalAuthResult {
  status: number;
  body: Record<string, unknown>;
}

/** POST/DELETE firmado a `/api/v1/integrations/<path>` de Original Auth. */
export async function originalAuthRequest(
  method: string,
  path: string,
  payload?: Record<string, unknown>,
): Promise<OriginalAuthResult> {
  const body = payload === undefined ? '' : JSON.stringify(payload);
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const nonce = crypto.randomUUID();
  const bodyHash = await sha256Hex(body);
  const canonical = [method.toUpperCase(), path, timestamp, nonce, bodyHash].join(
    '\n',
  );
  const signature = await hmacSha256Hex(AUTH_API_KEY, canonical);

  const response = await fetch(`${AUTH_BASE_URL}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': AUTH_API_KEY,
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': `sha256=${signature}`,
    },
    ...(body ? { body } : {}),
  });

  const result = await response.json().catch(() => ({}));
  return { status: response.status, body: result };
}

/** Tabla de perfil correspondiente al rol guardado en user_metadata.role. */
export function profileTableForRole(role: string | undefined): string {
  switch (role) {
    case 'organizacion':
      return 'organization_profiles';
    case 'empresa':
      return 'company_profiles';
    case 'personal':
    default:
      return 'personal_profiles';
  }
}
