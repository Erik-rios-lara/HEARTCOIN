-- Participantes reales, invitaciones y solicitudes de unión para
-- iniciativas de categoría "Ahorro". Ver ORIGINAL_AUTH_INTEGRATION.md
-- no aplica aquí; este cambio es independiente de esa integración.
--
-- Este repo no usa migraciones versionadas por Supabase CLI todavía:
-- corre este archivo manualmente en el SQL Editor del proyecto de
-- Supabase correspondiente.

alter table public.iniciativas
  add column if not exists current_amount numeric not null default 0;

create table public.iniciativa_participants (
  id uuid primary key default gen_random_uuid(),
  iniciativa_id uuid not null references public.iniciativas(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'participante' check (role in ('participante')),
  created_at timestamptz not null default now(),
  unique (iniciativa_id, user_id)
);

create table public.iniciativa_join_requests (
  id uuid primary key default gen_random_uuid(),
  iniciativa_id uuid not null references public.iniciativas(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  unique (iniciativa_id, user_id)
);

alter table public.iniciativa_participants enable row level security;
alter table public.iniciativa_join_requests enable row level security;

-- Participantes visibles para el dueño y para los propios participantes.
create policy "select participants" on public.iniciativa_participants
  for select using (
    auth.uid() = user_id
    or auth.uid() in (select author_id from public.iniciativas where id = iniciativa_id)
  );

-- Solo el dueño de la iniciativa invita (insert directo).
create policy "owner invites participant" on public.iniciativa_participants
  for insert with check (
    auth.uid() in (select author_id from public.iniciativas where id = iniciativa_id)
  );

-- Un usuario ve su propia solicitud; el dueño ve todas las de su iniciativa.
create policy "select own or owner requests" on public.iniciativa_join_requests
  for select using (
    auth.uid() = user_id
    or auth.uid() in (select author_id from public.iniciativas where id = iniciativa_id)
  );

-- Cualquier usuario autenticado puede solicitar unirse (para sí mismo).
create policy "request to join" on public.iniciativa_join_requests
  for insert with check (auth.uid() = user_id);

-- El dueño puede rechazar (update status) sus solicitudes recibidas.
create policy "owner updates request status" on public.iniciativa_join_requests
  for update using (
    auth.uid() in (select author_id from public.iniciativas where id = iniciativa_id)
  );

-- Aceptar una solicitud: crea el participante y marca 'accepted' de forma atómica.
create or replace function public.accept_iniciativa_join_request(request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_iniciativa_id uuid;
  v_user_id uuid;
  v_author_id uuid;
begin
  select iniciativa_id, user_id into v_iniciativa_id, v_user_id
  from iniciativa_join_requests where id = request_id and status = 'pending';

  if v_iniciativa_id is null then
    raise exception 'Solicitud no encontrada o ya procesada';
  end if;

  select author_id into v_author_id from iniciativas where id = v_iniciativa_id;
  if auth.uid() != v_author_id then
    raise exception 'No autorizado';
  end if;

  insert into iniciativa_participants (iniciativa_id, user_id)
  values (v_iniciativa_id, v_user_id)
  on conflict (iniciativa_id, user_id) do nothing;

  update iniciativa_join_requests set status = 'accepted' where id = request_id;
end;
$$;
