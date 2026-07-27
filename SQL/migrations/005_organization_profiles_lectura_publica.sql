-- Permite que cualquier usuario autenticado pueda ver el perfil público
-- de una organización (nombre, logo, descripción, etc.), necesario para
-- el tab "Organizaciones" del buscador. Antes solo el propio dueño podía
-- leer su fila.
create policy "Usuarios autenticados pueden leer perfiles de organización"
  on public.organization_profiles
  for select
  to authenticated
  using (true);
