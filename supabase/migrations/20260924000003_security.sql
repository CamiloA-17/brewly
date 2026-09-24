-- =============================================================================
-- Brewly · Seguridad: privacidad (RLS), privilegios por columna e integridad
-- -----------------------------------------------------------------------------
-- La app iOS habla directamente con PostgREST usando el JWT del usuario, por
-- lo que TODA regla de privacidad vive aquí, en la base de datos.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Funciones auxiliares de visibilidad (security definer para evitar recursión
-- entre políticas y para poder consultar follows/blocks sin exponerlos).
-- -----------------------------------------------------------------------------

create or replace function public.is_blocked_between(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.blocks
     where (blocker_id = a and blocked_id = b)
        or (blocker_id = b and blocked_id = a)
  );
$$;

create or replace function public.is_follower(p_follower uuid, p_following uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.follows
     where follower_id = p_follower
       and following_id = p_following
       and status = 'accepted'
  );
$$;

-- ¿Puede el usuario actual ver un contenido de `p_owner` con visibilidad `p_visibility`?
create or replace function public.can_view(p_owner uuid, p_visibility public.visibility)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when auth.uid() is not null and p_owner = auth.uid() then true
    when p_visibility = 'private' then false
    when auth.uid() is not null and public.is_blocked_between(p_owner, auth.uid()) then false
    when p_visibility = 'public'
         and not coalesce((select is_private from public.profiles where id = p_owner), true)
      then true
    when auth.uid() is null then false
    else public.is_follower(auth.uid(), p_owner)
  end;
$$;

-- -----------------------------------------------------------------------------
-- Integridad de referencias: nadie puede enlazar granos, bolsas o equipo ajeno
-- en su receta/preparación, ni usar métodos personalizados de otro usuario.
-- -----------------------------------------------------------------------------

create or replace function public.assert_owned(p_table regclass, p_id uuid, p_owner uuid)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_ok boolean;
begin
  if p_id is null then
    return;
  end if;
  execute format('select exists (select 1 from %s where id = $1 and owner_id = $2)', p_table)
     into v_ok using p_id, p_owner;
  if not v_ok then
    raise exception 'El recurso % no pertenece al usuario', p_table
      using errcode = '42501';
  end if;
end;
$$;

create or replace function public.assert_method_usable(p_method uuid, p_owner uuid)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.brew_methods
     where id = p_method and (owner_id is null or owner_id = p_owner)
  ) then
    raise exception 'Método de preparación no disponible' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.validate_recipe_refs()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_method_usable(new.brew_method_id, new.owner_id);
  perform public.assert_owned('public.coffee_beans', new.bean_id, new.owner_id);
  perform public.assert_owned('public.equipment', new.grinder_id, new.owner_id);
  perform public.assert_owned('public.equipment', new.brewer_id, new.owner_id);
  return new;
end;
$$;

create trigger recipes_validate_refs
  before insert or update of owner_id, brew_method_id, bean_id, grinder_id, brewer_id
  on public.recipes
  for each row execute function public.validate_recipe_refs();

create or replace function public.validate_brew_refs()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_method_usable(new.brew_method_id, new.owner_id);
  perform public.assert_owned('public.coffee_beans', new.bean_id, new.owner_id);
  perform public.assert_owned('public.bean_bags', new.bag_id, new.owner_id);
  perform public.assert_owned('public.equipment', new.grinder_id, new.owner_id);
  -- Se permite preparar la receta de otra persona siempre que se pueda ver.
  if new.recipe_id is not null and not exists (
    select 1 from public.recipes r
     where r.id = new.recipe_id
       and (r.owner_id = new.owner_id or public.can_view(r.owner_id, r.visibility))
  ) then
    raise exception 'Receta no disponible' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger brews_validate_refs
  before insert or update of owner_id, brew_method_id, bean_id, bag_id, grinder_id, recipe_id
  on public.brews
  for each row execute function public.validate_brew_refs();

create or replace function public.validate_bag_refs()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_owned('public.coffee_beans', new.bean_id, new.owner_id);
  return new;
end;
$$;

create trigger bean_bags_validate_refs
  before insert or update of owner_id, bean_id on public.bean_bags
  for each row execute function public.validate_bag_refs();

create or replace function public.validate_post_refs()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_owned('public.recipes', new.recipe_id, new.author_id);
  perform public.assert_owned('public.brews', new.brew_id, new.author_id);
  perform public.assert_owned('public.coffee_beans', new.bean_id, new.author_id);
  return new;
end;
$$;

create trigger posts_validate_refs
  before insert or update of author_id, recipe_id, brew_id, bean_id on public.posts
  for each row execute function public.validate_post_refs();

-- -----------------------------------------------------------------------------
-- Privilegios por columna: los contadores y campos de sistema no los toca el
-- cliente. (Supabase concede ALL a anon/authenticated por defecto.)
-- -----------------------------------------------------------------------------

revoke update on public.profiles from anon, authenticated;
grant update (username, display_name, bio, avatar_path, role, location, website, is_private)
  on public.profiles to authenticated;

revoke update on public.posts from anon, authenticated;
grant update (caption, visibility, comments_enabled) on public.posts to authenticated;

revoke update on public.follows from anon, authenticated;
grant update (status) on public.follows to authenticated;

revoke update on public.comments from anon, authenticated;
grant update (body) on public.comments to authenticated;

revoke update on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;

revoke insert, update, delete on public.brew_methods, public.likes, public.comments,
  public.saved_posts, public.follows, public.blocks, public.posts, public.post_media,
  public.notifications, public.push_tokens, public.coffee_beans, public.bean_bags,
  public.equipment, public.recipes, public.recipe_steps, public.brews
  from anon;

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------

alter table public.profiles      enable row level security;
alter table public.equipment     enable row level security;
alter table public.coffee_beans  enable row level security;
alter table public.bean_bags     enable row level security;
alter table public.brew_methods  enable row level security;
alter table public.recipes       enable row level security;
alter table public.recipe_steps  enable row level security;
alter table public.brews         enable row level security;
alter table public.follows       enable row level security;
alter table public.blocks        enable row level security;
alter table public.posts         enable row level security;
alter table public.post_media    enable row level security;
alter table public.likes         enable row level security;
alter table public.comments      enable row level security;
alter table public.saved_posts   enable row level security;
alter table public.notifications enable row level security;
alter table public.push_tokens   enable row level security;

-- Perfiles: visibles para todos (como Instagram, aunque la cuenta sea privada),
-- excepto entre usuarios bloqueados. Solo el dueño los edita.
create policy profiles_select on public.profiles for select
  using (auth.uid() is null or not public.is_blocked_between(id, auth.uid()));
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Contenido personal con visibilidad configurable: equipo, granos, recetas, brews.
create policy equipment_select on public.equipment for select
  using (public.can_view(owner_id, visibility));
create policy equipment_write on public.equipment for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy coffee_beans_select on public.coffee_beans for select
  using (public.can_view(owner_id, visibility));
create policy coffee_beans_write on public.coffee_beans for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy recipes_select on public.recipes for select
  using (public.can_view(owner_id, visibility));
create policy recipes_write on public.recipes for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy brews_select on public.brews for select
  using (public.can_view(owner_id, visibility));
create policy brews_write on public.brews for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Pasos de receta: heredan la visibilidad de la receta.
create policy recipe_steps_select on public.recipe_steps for select
  using (exists (select 1 from public.recipes r where r.id = recipe_id));
create policy recipe_steps_write on public.recipe_steps for all to authenticated
  using (exists (select 1 from public.recipes r where r.id = recipe_id and r.owner_id = auth.uid()))
  with check (exists (select 1 from public.recipes r where r.id = recipe_id and r.owner_id = auth.uid()));

-- Inventario: estrictamente privado.
create policy bean_bags_owner on public.bean_bags for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Métodos: los del sistema son visibles para todos; los personales solo para su dueño.
create policy brew_methods_select on public.brew_methods for select
  using (owner_id is null or owner_id = auth.uid());
create policy brew_methods_write on public.brew_methods for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Seguidores
create policy follows_select on public.follows for select
  using (
    follower_id = auth.uid() or following_id = auth.uid()
    or (status = 'accepted' and public.can_view(following_id, 'public'))
  );
create policy follows_insert on public.follows for insert to authenticated
  with check (
    follower_id = auth.uid()
    and not public.is_blocked_between(follower_id, following_id)
  );
-- Solo quien recibe la solicitud puede aceptarla.
create policy follows_update on public.follows for update to authenticated
  using (following_id = auth.uid()) with check (following_id = auth.uid());
-- Dejar de seguir, cancelar solicitud o eliminar a un seguidor.
create policy follows_delete on public.follows for delete to authenticated
  using (follower_id = auth.uid() or following_id = auth.uid());

create policy blocks_owner on public.blocks for all to authenticated
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- Publicaciones: visibles si el autor lo permite Y el contenido enlazado es visible
-- (si el usuario vuelve privada una receta, sus posts dejan de verse).
create policy posts_select on public.posts for select
  using (
    public.can_view(author_id, visibility)
    and (
      kind = 'note'
      or (kind = 'recipe' and exists (select 1 from public.recipes r where r.id = recipe_id))
      or (kind = 'brew'   and exists (select 1 from public.brews b where b.id = brew_id))
      or (kind = 'bean'   and exists (select 1 from public.coffee_beans c where c.id = bean_id))
    )
  );
create policy posts_insert on public.posts for insert to authenticated
  with check (author_id = auth.uid());
create policy posts_update on public.posts for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy posts_delete on public.posts for delete to authenticated
  using (author_id = auth.uid());

create policy post_media_select on public.post_media for select
  using (exists (select 1 from public.posts p where p.id = post_id));
create policy post_media_write on public.post_media for all to authenticated
  using (exists (select 1 from public.posts p where p.id = post_id and p.author_id = auth.uid()))
  with check (exists (select 1 from public.posts p where p.id = post_id and p.author_id = auth.uid()));

-- Likes / guardados / comentarios: solo sobre posts que el usuario puede ver.
create policy likes_select on public.likes for select
  using (exists (select 1 from public.posts p where p.id = post_id));
create policy likes_insert on public.likes for insert to authenticated
  with check (user_id = auth.uid() and exists (select 1 from public.posts p where p.id = post_id));
create policy likes_delete on public.likes for delete to authenticated
  using (user_id = auth.uid());

create policy saved_posts_owner on public.saved_posts for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and exists (select 1 from public.posts p where p.id = post_id));

create policy comments_select on public.comments for select
  using (
    exists (select 1 from public.posts p where p.id = post_id)
    and (auth.uid() is null or not public.is_blocked_between(author_id, auth.uid()))
  );
create policy comments_insert on public.comments for insert to authenticated
  with check (
    author_id = auth.uid()
    and exists (select 1 from public.posts p where p.id = post_id and p.comments_enabled)
  );
create policy comments_update on public.comments for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());
-- El autor del comentario o el dueño del post pueden borrarlo (moderación).
create policy comments_delete on public.comments for delete to authenticated
  using (
    author_id = auth.uid()
    or exists (select 1 from public.posts p where p.id = post_id and p.author_id = auth.uid())
  );

-- Notificaciones: solo lectura y marcado como leídas por su destinatario.
create policy notifications_select on public.notifications for select to authenticated
  using (recipient_id = auth.uid());
create policy notifications_update on public.notifications for update to authenticated
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());
create policy notifications_delete on public.notifications for delete to authenticated
  using (recipient_id = auth.uid());

create policy push_tokens_owner on public.push_tokens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
