// Pruebas del cliente firmado hacia la API de Original Auth.
//
// El módulo bajo prueba lee `ORIGINAL_AUTH_BASE_URL` y
// `ORIGINAL_AUTH_API_KEY` a nivel de archivo (no dentro de una
// función), así que ambas variables de entorno deben existir ANTES de
// que el proceso de Deno arranque. `ORIGINAL_AUTH_BASE_URL` apunta a
// un servidor HTTP local levantado dentro de este mismo archivo, para
// no depender de red real ni de credenciales del servicio externo.
//
// Ejecutar con:
//   ORIGINAL_AUTH_BASE_URL=http://127.0.0.1:8971 \
//   ORIGINAL_AUTH_API_KEY=clave-de-prueba-original-auth \
//   deno test --allow-env --allow-net \
//     supabase/functions/_shared/originalauth.test.ts

import { assertEquals, assertNotEquals } from 'jsr:@std/assert@1';
import { originalAuthRequest, profileTableForRole } from './originalauth.ts';

const API_KEY = 'clave-de-prueba-original-auth';
const PORT = 8971;

Deno.test('profileTableForRole: personal', () => {
  assertEquals(profileTableForRole('personal'), 'personal_profiles');
});

Deno.test('profileTableForRole: organizacion', () => {
  assertEquals(profileTableForRole('organizacion'), 'organization_profiles');
});

Deno.test('profileTableForRole: empresa', () => {
  assertEquals(profileTableForRole('empresa'), 'company_profiles');
});

Deno.test(
  'profileTableForRole: un rol no reconocido cae al perfil personal (valor por defecto)',
  () => {
    assertEquals(profileTableForRole('rol-que-no-existe'), 'personal_profiles');
  },
);

Deno.test(
  'profileTableForRole: rol indefinido cae al perfil personal (valor por defecto)',
  () => {
    assertEquals(profileTableForRole(undefined), 'personal_profiles');
  },
);

Deno.test({
  name:
    'originalAuthRequest: firma cada petición con headers distintos ' +
    '(nonce único) incluso para el mismo payload',
  permissions: { net: true, env: true },
  fn: async () => {
    const receivedHeaders: Headers[] = [];

    const server = Deno.serve(
      { port: PORT, onListen: () => {} },
      async (req) => {
        receivedHeaders.push(req.headers);
        await req.text();
        return new Response(JSON.stringify({ data: { ok: true } }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      },
    );

    try {
      await originalAuthRequest('POST', '/api/v1/integrations/registration', {
        email: 'test@example.com',
      });
      await originalAuthRequest('POST', '/api/v1/integrations/registration', {
        email: 'test@example.com',
      });

      assertEquals(receivedHeaders.length, 2);
      const nonceA = receivedHeaders[0].get('X-Nonce');
      const nonceB = receivedHeaders[1].get('X-Nonce');
      assertNotEquals(nonceA, nonceB);

      // Ambas peticiones deben ir firmadas con la misma API key y
      // traer los headers de firma esperados por el servidor.
      for (const headers of receivedHeaders) {
        assertEquals(headers.get('X-API-Key'), API_KEY);
        assertEquals(typeof headers.get('X-Signature'), 'string');
        assertEquals(typeof headers.get('X-Timestamp'), 'string');
      }
    } finally {
      await server.shutdown();
    }
  },
});

Deno.test({
  name:
    'originalAuthRequest: dos payloads distintos producen firmas distintas',
  permissions: { net: true, env: true },
  fn: async () => {
    const receivedSignatures: string[] = [];

    const server = Deno.serve(
      { port: PORT, onListen: () => {} },
      async (req) => {
        receivedSignatures.push(req.headers.get('X-Signature') ?? '');
        await req.text();
        return new Response(JSON.stringify({ data: {} }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      },
    );

    try {
      await originalAuthRequest('POST', '/api/v1/integrations/registration', {
        email: 'uno@example.com',
      });
      await originalAuthRequest('POST', '/api/v1/integrations/registration', {
        email: 'dos@example.com',
      });

      assertEquals(receivedSignatures.length, 2);
      assertNotEquals(receivedSignatures[0], receivedSignatures[1]);
    } finally {
      await server.shutdown();
    }
  },
});

Deno.test({
  name:
    'originalAuthRequest: propaga el status HTTP y el cuerpo de la ' +
    'respuesta del servidor tal como los devuelve Original Auth',
  permissions: { net: true, env: true },
  fn: async () => {
    const server = Deno.serve(
      { port: PORT, onListen: () => {} },
      async (req) => {
        await req.text();
        return new Response(
          JSON.stringify({ error: { message: 'correo ya registrado' } }),
          { status: 409, headers: { 'Content-Type': 'application/json' } },
        );
      },
    );

    try {
      const result = await originalAuthRequest(
        'POST',
        '/api/v1/integrations/registration',
        { email: 'duplicado@example.com' },
      );
      assertEquals(result.status, 409);
      assertEquals(
        (result.body.error as { message: string }).message,
        'correo ya registrado',
      );
    } finally {
      await server.shutdown();
    }
  },
});
