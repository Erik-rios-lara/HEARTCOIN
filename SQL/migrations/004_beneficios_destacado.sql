-- Permite a la empresa marcar un beneficio como "destacado" al crearlo,
-- para la sección "Destacados" del rediseño de la billetera.
--
-- Correr manualmente en el SQL Editor del proyecto de Supabase, o vía
-- `supabase db query --linked -f SQL/migrations/004_beneficios_destacado.sql`.

alter table public.beneficios
  add column if not exists destacado boolean not null default false;
