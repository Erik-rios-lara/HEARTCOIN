-- Vincula una publicación con la iniciativa real de la que habla
-- (reemplaza el selector de relleno que solo guardaba un nombre suelto
-- en `initiative_name`, sin relación real con `iniciativas`).
--
-- Correr manualmente en el SQL Editor del proyecto de Supabase, o vía
-- `supabase db query --linked -f SQL/migrations/003_publicaciones_iniciativa.sql`.

alter table public.publicaciones
  add column if not exists iniciativa_id uuid references public.iniciativas(id) on delete set null;
