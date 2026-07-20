// Edge Function: elimina la cuenta del usuario autenticado.
//
// El cliente Flutter llama a esta función ya autenticado con su sesión de
// Supabase. La función valida al usuario con su propio JWT y, ya
// identificado, usa la Service Role Key (que solo existe como variable de
// entorno del servidor, nunca en el cliente) para borrar su fila en
// auth.users. Todas las tablas de la app tienen sus foreign keys hacia
// auth.users con ON DELETE CASCADE, así que perfil, publicaciones, votos,
// check-ins, transacciones de HC, etc. se eliminan automáticamente.

import { createClient } from 'jsr:@supabase/supabase-js@2';

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
  if (userError || !userData.user) {
    return new Response(JSON.stringify({ error: 'No autenticado.' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(
    userData.user.id,
  );

  if (deleteError) {
    return new Response(
      JSON.stringify({ error: 'No se pudo eliminar la cuenta.', detail: deleteError.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
