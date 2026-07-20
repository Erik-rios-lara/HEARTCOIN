// Edge Function: proxy de subida a MediaAAS.
//
// La app Flutter llama a esta función ya autenticada con su sesión de
// Supabase (el JWT del usuario se valida abajo). Esta función firma el
// request a MediaAAS con HMAC-SHA256 usando MEDIAAS_SECRET_KEY, que solo
// existe como variable de entorno del servidor y nunca llega al cliente.
//
// Request esperado (multipart/form-data):
//   file       -> binario de la imagen
//   file_name  -> nombre original del archivo
//
// Respuesta: { image_url, file_id }

import { createClient } from 'jsr:@supabase/supabase-js@2';

const MEDIAAS_API_HOST = Deno.env.get('MEDIAAS_API_HOST')!;
const MEDIAAS_API_KEY = Deno.env.get('MEDIAAS_API_KEY')!;
const MEDIAAS_SECRET_KEY = Deno.env.get('MEDIAAS_SECRET_KEY')!;

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

// SHA256 de string vacío, requerido por MediaAAS para requests multipart.
const EMPTY_BODY_HASH = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  // Valida que quien llama sea un usuario autenticado de Supabase.
  const authHeader = req.headers.get('Authorization') ?? '';
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return new Response(JSON.stringify({ error: 'No autenticado.' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const incomingForm = await req.formData();
  const file = incomingForm.get('file');
  const fileName = incomingForm.get('file_name');
  if (!(file instanceof File) || typeof fileName !== 'string' || fileName.length === 0) {
    return new Response(JSON.stringify({ error: 'Faltan file o file_name.' }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const timestamp = Math.floor(Date.now() / 1000);
  const path = '/client/upload';
  const canonical = `POST\n${path}\n${timestamp}\n${EMPTY_BODY_HASH}`;
  const signature = await hmacSha256Hex(MEDIAAS_SECRET_KEY, canonical);

  const outgoingForm = new FormData();
  outgoingForm.append('file', file, fileName);
  outgoingForm.append('file_name', fileName);
  outgoingForm.append('is_public', 'true');

  const mediaResponse = await fetch(`${MEDIAAS_API_HOST}${path}`, {
    method: 'POST',
    headers: {
      'X-Api-Key': MEDIAAS_API_KEY,
      'X-Timestamp': String(timestamp),
      'X-Signature': `sha256=${signature}`,
    },
    body: outgoingForm,
  });

  if (!mediaResponse.ok) {
    const errorBody = await mediaResponse.text();
    return new Response(
      JSON.stringify({ error: 'MediaAAS rechazó la subida.', detail: errorBody }),
      { status: 502, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const mediaData = await mediaResponse.json();
  return new Response(
    JSON.stringify({
      image_url: mediaData.public_url,
      file_id: mediaData.file_id,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
