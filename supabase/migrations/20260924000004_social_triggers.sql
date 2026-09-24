-- =============================================================================
-- Brewly · Lógica social automática
-- -----------------------------------------------------------------------------
-- Solicitudes de seguimiento, contadores desnormalizados y notificaciones.
-- Todo se ejecuta en triggers para que el cliente no pueda saltárselo.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Seguimiento: cuentas privadas requieren aprobación
-- -----------------------------------------------------------------------------

create or replace function public.follows_before_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.status := case
      when (select is_private from public.profiles where id = new.following_id)
        then 'pending'::public.follow_status
      else 'accepted'::public.follow_status
    end;
    new.accepted_at := case when new.status = 'accepted' then now() end;
  elsif tg_op = 'UPDATE' then
    if old.status = 'accepted' and new.status = 'pending' then
      raise exception 'No se puede revertir un seguimiento aceptado' using errcode = '22023';
    end if;
    if old.status = 'pending' and new.status = 'accepted' then
      new.accepted_at := now();
    end if;
  end if;
  return new;
end;
$$;

create trigger follows_before_write
  before insert or update on public.follows
  for each row execute function public.follows_before_write();

-- Al pasar una cuenta de privada a pública se aceptan las solicitudes pendientes.
create or replace function public.profiles_accept_pending_on_public()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.is_private and not new.is_private then
    update public.follows
       set status = 'accepted'
     where following_id = new.id and status = 'pending';
  end if;
  return new;
end;
$$;

create trigger profiles_accept_pending_on_public
  after update of is_private on public.profiles
  for each row execute function public.profiles_accept_pending_on_public();

-- Bloquear elimina la relación de seguimiento en ambos sentidos.
create or replace function public.blocks_cleanup_follows()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.follows
   where (follower_id = new.blocker_id and following_id = new.blocked_id)
      or (follower_id = new.blocked_id and following_id = new.blocker_id);
  return new;
end;
$$;

create trigger blocks_cleanup_follows
  after insert on public.blocks
  for each row execute function public.blocks_cleanup_follows();

-- -----------------------------------------------------------------------------
-- Contadores
-- -----------------------------------------------------------------------------

create or replace function public.follows_update_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_accepted boolean := tg_op in ('UPDATE', 'DELETE') and old.status = 'accepted';
  v_new_accepted boolean := tg_op in ('INSERT', 'UPDATE') and new.status = 'accepted';
  v_follower  uuid := coalesce(new.follower_id, old.follower_id);
  v_following uuid := coalesce(new.following_id, old.following_id);
  v_delta integer := v_new_accepted::int - v_old_accepted::int;
begin
  if v_delta <> 0 then
    update public.profiles set following_count = greatest(0, following_count + v_delta)
     where id = v_follower;
    update public.profiles set followers_count = greatest(0, followers_count + v_delta)
     where id = v_following;
  end if;
  return null;
end;
$$;

create trigger follows_update_counts
  after insert or update of status or delete on public.follows
  for each row execute function public.follows_update_counts();

create or replace function public.posts_update_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.profiles set posts_count = posts_count + 1 where id = new.author_id;
  else
    update public.profiles set posts_count = greatest(0, posts_count - 1) where id = old.author_id;
  end if;
  return null;
end;
$$;

create trigger posts_update_counts
  after insert or delete on public.posts
  for each row execute function public.posts_update_counts();

create or replace function public.likes_update_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set like_count = like_count + 1 where id = new.post_id;
  else
    update public.posts set like_count = greatest(0, like_count - 1) where id = old.post_id;
  end if;
  return null;
end;
$$;

create trigger likes_update_counts
  after insert or delete on public.likes
  for each row execute function public.likes_update_counts();

create or replace function public.comments_update_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set comment_count = comment_count + 1 where id = new.post_id;
  else
    update public.posts set comment_count = greatest(0, comment_count - 1) where id = old.post_id;
  end if;
  return null;
end;
$$;

create trigger comments_update_counts
  after insert or delete on public.comments
  for each row execute function public.comments_update_counts();

-- Respuestas de un solo nivel y en el mismo post; marca la edición.
create or replace function public.comments_before_write()
returns trigger
language plpgsql
as $$
declare
  v_parent public.comments;
begin
  if tg_op = 'INSERT' and new.parent_id is not null then
    select * into v_parent from public.comments where id = new.parent_id;
    if v_parent.post_id is distinct from new.post_id then
      raise exception 'La respuesta debe pertenecer al mismo post' using errcode = '22023';
    end if;
    -- Aplana: responder a una respuesta cuelga del comentario raíz.
    new.parent_id := coalesce(v_parent.parent_id, v_parent.id);
  elsif tg_op = 'UPDATE' and new.body is distinct from old.body then
    new.edited_at := now();
  end if;
  return new;
end;
$$;

create trigger comments_before_write
  before insert or update on public.comments
  for each row execute function public.comments_before_write();

-- -----------------------------------------------------------------------------
-- Notificaciones
-- -----------------------------------------------------------------------------

create or replace function public.notify(
  p_recipient uuid,
  p_actor uuid,
  p_type public.notification_type,
  p_post uuid default null,
  p_comment uuid default null,
  p_recipe uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_recipient is null or p_recipient = p_actor then
    return;
  end if;
  insert into public.notifications (recipient_id, actor_id, type, post_id, comment_id, recipe_id)
  values (p_recipient, p_actor, p_type, p_post, p_comment, p_recipe);
end;
$$;

revoke execute on function public.notify(uuid, uuid, public.notification_type, uuid, uuid, uuid)
  from public, anon, authenticated;

create or replace function public.follows_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.notify(
      new.following_id, new.follower_id,
      case when new.status = 'pending' then 'follow_request' else 'follow' end::public.notification_type
    );
  elsif old.status = 'pending' and new.status = 'accepted' then
    perform public.notify(new.follower_id, new.following_id, 'follow_accepted');
    delete from public.notifications
     where type = 'follow_request'
       and recipient_id = new.following_id and actor_id = new.follower_id;
  end if;
  return null;
end;
$$;

create trigger follows_notify
  after insert or update of status on public.follows
  for each row execute function public.follows_notify();

create or replace function public.likes_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify(
    (select author_id from public.posts where id = new.post_id),
    new.user_id, 'like', new.post_id
  );
  return null;
end;
$$;

create trigger likes_notify
  after insert on public.likes
  for each row execute function public.likes_notify();

create or replace function public.comments_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_author   uuid := (select author_id from public.posts where id = new.post_id);
  v_parent_author uuid;
begin
  perform public.notify(v_post_author, new.author_id, 'comment', new.post_id, new.id);

  if new.parent_id is not null then
    v_parent_author := (select author_id from public.comments where id = new.parent_id);
    if v_parent_author is distinct from v_post_author then
      perform public.notify(v_parent_author, new.author_id, 'reply', new.post_id, new.id);
    end if;
  end if;
  return null;
end;
$$;

create trigger comments_notify
  after insert on public.comments
  for each row execute function public.comments_notify();

create or replace function public.recipes_notify_fork()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.forked_from_id is not null then
    perform public.notify(
      (select owner_id from public.recipes where id = new.forked_from_id),
      new.owner_id, 'fork', null, null, new.forked_from_id
    );
  end if;
  return null;
end;
$$;

create trigger recipes_notify_fork
  after insert on public.recipes
  for each row execute function public.recipes_notify_fork();
