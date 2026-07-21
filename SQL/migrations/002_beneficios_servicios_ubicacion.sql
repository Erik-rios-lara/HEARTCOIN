-- Ubicación (texto + coordenadas) para beneficios y servicios, para
-- poder mostrarlos en un mapa y ordenar por cercanía. Mismo shape que
-- ya usa `iniciativas` (location/latitude/longitude).
--
-- Correr manualmente en el SQL Editor del proyecto de Supabase, o vía
-- `supabase db query --linked -f SQL/migrations/002_beneficios_servicios_ubicacion.sql`.

alter table public.beneficios
  add column if not exists location text,
  add column if not exists latitude numeric,
  add column if not exists longitude numeric;

alter table public.servicios
  add column if not exists location text,
  add column if not exists latitude numeric,
  add column if not exists longitude numeric;
