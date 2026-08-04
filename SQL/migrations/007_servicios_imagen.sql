-- Imagen para servicios, mismo shape que ya usa `beneficios.image_url`.
--
-- Correr manualmente en el SQL Editor del proyecto de Supabase, o vía
-- `supabase db query --linked -f SQL/migrations/007_servicios_imagen.sql`.

alter table public.servicios
  add column if not exists image_url text;
