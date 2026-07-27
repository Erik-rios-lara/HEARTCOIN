-- Permite a la empresa marcar un servicio como "destacado" al crearlo,
-- para la sección "Destacados" de la pestaña Servicios en la billetera
-- (mismo patrón que 004_beneficios_destacado.sql).
--
-- Correr manualmente en el SQL Editor del proyecto de Supabase, o vía
-- `supabase db query --linked -f SQL/migrations/006_servicios_destacado.sql`.

alter table public.servicios
  add column if not exists destacado boolean not null default false;
