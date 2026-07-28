// Pruebas del verificador de firma HMAC entrante de Original Pay.
//
// El módulo bajo prueba lee `Deno.env.get('ORIGINALPAY_API_KEY')!` a
// nivel de archivo (no dentro de una función), así que la variable de
// entorno debe existir ANTES de que el proceso de Deno arranque —no
// alcanza con Deno.env.set(...) dentro de este archivo, porque los
// imports estáticos se resuelven antes de ejecutar cualquier código
// de nivel superior que los siga en el archivo.
//
// Ejecutar con:
//   ORIGINALPAY_API_KEY=clave-de-prueba-original-pay deno test --allow-env \
//     supabase/functions/_shared/originalpay_auth.test.ts
//
// La clave usada en las aserciones de este archivo (API_KEY, abajo)
// debe coincidir exactamente con el valor exportado en el shell.

import { assertEquals } from 'jsr:@std/assert@1';
import {
  canonicalPathWithQuery,
  verifyOriginalPaySignature,
} from './originalpay_auth.ts';

const API_KEY = 'clave-de-prueba-original-pay';

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

/** Construye un request firmado válido, igual que lo haría Original Pay. */
async function buildSignedRequest(options: {
  method?: string;
  path: string;
  body?: string;
  apiKey?: string;
  timestamp?: number;
  signatureOverride?: string;
}): Promise<Request> {
  const method = options.method ?? 'POST';
  const body = options.body ?? '';
  const timestamp = options.timestamp ?? Math.floor(Date.now() / 1000);
  const apiKey = options.apiKey ?? API_KEY;

  const bodyHash = await sha256Hex(body);
  const canonical = [method.toUpperCase(), options.path, String(timestamp), bodyHash]
    .join('\n');
  const signature =
    options.signatureOverride ?? `sha256=${await hmacSha256Hex(API_KEY, canonical)}`;

  return new Request('https://example.com' + options.path, {
    method,
    headers: {
      'X-Api-Key': apiKey,
      'X-Timestamp': String(timestamp),
      'X-Signature': signature,
    },
    ...(body ? { body } : {}),
  });
}

Deno.test('canonicalPathWithQuery: sin query params devuelve solo el path', () => {
  const result = canonicalPathWithQuery('/api/redeem', new URLSearchParams());
  assertEquals(result, '/api/redeem');
});

Deno.test('canonicalPathWithQuery: ordena los parámetros alfabéticamente', () => {
  const params = new URLSearchParams('z=1&a=2&m=3');
  const result = canonicalPathWithQuery('/api/redeem', params);
  assertEquals(result, '/api/redeem?a=2&m=3&z=1');
});

Deno.test(
  'canonicalPathWithQuery: mismo resultado sin importar el orden original de los params',
  () => {
    const a = canonicalPathWithQuery('/x', new URLSearchParams('b=2&a=1'));
    const b = canonicalPathWithQuery('/x', new URLSearchParams('a=1&b=2'));
    assertEquals(a, b);
  },
);

Deno.test(
  'canonicalPathWithQuery: conserva valores repetidos de un mismo parámetro',
  () => {
    const result = canonicalPathWithQuery(
      '/x',
      new URLSearchParams('tag=b&tag=a'),
    );
    assertEquals(result, '/x?tag=b&tag=a');
  },
);

Deno.test(
  'verifyOriginalPaySignature: acepta una firma válida construida con la misma clave',
  async () => {
    const body = JSON.stringify({ amount: 100 });
    const req = await buildSignedRequest({ path: '/api/redeem', body });
    const result = await verifyOriginalPaySignature(req, '/api/redeem', body);
    assertEquals(result.ok, true);
  },
);

Deno.test(
  'verifyOriginalPaySignature: rechaza una API key incorrecta',
  async () => {
    const body = '';
    const req = await buildSignedRequest({
      path: '/api/redeem',
      body,
      apiKey: 'clave-equivocada',
    });
    const result = await verifyOriginalPaySignature(req, '/api/redeem', body);
    assertEquals(result.ok, false);
    if (!result.ok) assertEquals(result.status, 401);
  },
);

Deno.test(
  'verifyOriginalPaySignature: rechaza si falta el header de timestamp',
  async () => {
    const req = new Request('https://example.com/api/redeem', {
      method: 'POST',
      headers: { 'X-Api-Key': API_KEY, 'X-Signature': 'sha256=loquesea' },
    });
    const result = await verifyOriginalPaySignature(req, '/api/redeem', '');
    assertEquals(result.ok, false);
  },
);

Deno.test(
  'verifyOriginalPaySignature: rechaza un timestamp fuera de la ventana ' +
    'anti-replay de ±5 minutos',
  async () => {
    const body = '';
    const staleTimestamp = Math.floor(Date.now() / 1000) - 600; // 10 min atrás
    const req = await buildSignedRequest({
      path: '/api/redeem',
      body,
      timestamp: staleTimestamp,
    });
    const result = await verifyOriginalPaySignature(req, '/api/redeem', body);
    assertEquals(result.ok, false);
  },
);

Deno.test(
  'verifyOriginalPaySignature: rechaza si la firma no corresponde al body ' +
    'exacto (detecta manipulación del contenido)',
  async () => {
    const signedBody = JSON.stringify({ amount: 100 });
    const req = await buildSignedRequest({ path: '/api/redeem', body: signedBody });

    // Se verifica con un body distinto al que se firmó originalmente.
    const tamperedBody = JSON.stringify({ amount: 999999 });
    const result = await verifyOriginalPaySignature(
      req,
      '/api/redeem',
      tamperedBody,
    );
    assertEquals(result.ok, false);
  },
);

Deno.test(
  'verifyOriginalPaySignature: rechaza si la ruta verificada no coincide ' +
    'con la firmada (detecta path confusion)',
  async () => {
    const body = '';
    const req = await buildSignedRequest({ path: '/api/redeem', body });
    const result = await verifyOriginalPaySignature(req, '/api/balance', body);
    assertEquals(result.ok, false);
  },
);

Deno.test(
  'verifyOriginalPaySignature: rechaza una firma con formato inválido',
  async () => {
    const body = '';
    const req = await buildSignedRequest({
      path: '/api/redeem',
      body,
      signatureOverride: 'no-es-una-firma-hmac-valida',
    });
    const result = await verifyOriginalPaySignature(req, '/api/redeem', body);
    assertEquals(result.ok, false);
  },
);
