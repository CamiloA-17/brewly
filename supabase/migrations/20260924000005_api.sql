-- =============================================================================
-- Brewly · API (funciones RPC y campos calculados expuestos por PostgREST)
-- -----------------------------------------------------------------------------
-- Las funciones son SECURITY INVOKER salvo que se indique lo contrario, de
-- modo que las políticas RLS siguen aplicando a quien llama.
-- =============================================================================

revoke execute on function public.assert_owned(regclass, uuid, uuid) from public, anon, authenticated;
revoke execute on function public.assert_method_usable(uuid, uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Campos calculados (se piden en el select: `select=*,liked_by_me,saved_by_me`)
-- -----------------------------------------------------------------------------

create or replace function public.liked_by_me(p public.posts)
returns boolean
language sql
stable
as $$
  select exists (select 1 from public.likes where post_id = p.id and user_id = auth.uid());
$$;

create or replace function public.saved_by_me(p public.posts)
returns boolean
language sql
stable
as $$
  select exists (select 1 from public.saved_posts where post_id = p.id and user_id = auth.uid());
$$;

-- Estado de la relación del usuario actual con un perfil: none | pending | accepted | self
create or replace function public.viewer_follow_status(p public.profiles)
returns text
language sql
stable
as $$
  select case
    when p.id = auth.uid() then 'self'
    else coalesce(
      (select status::text from public.follows
        where follower_id = auth.uid() and following_id = p.id),
      'none')
  end;
$$;

-- -----------------------------------------------------------------------------
-- Publicar contenido
-- -----------------------------------------------------------------------------
-- Crea un post a partir de una receta, preparación o grano del usuario. Si el
-- contenido es más restrictivo que el post, se amplía su visibilidad para que
-- los lectores del post puedan abrirlo. Todo ocurre en una sola transacción.
create or replace function public.publish_post(
  p_kind public.post_kind,
  p_content_id uuid default null,
  p_caption text default null,
  p_visibility public.visibility default 'public',
  p_comments_enabled boolean default true
)
returns public.posts
language plpgsql
as $$
declare
  v_uid uuid := auth.uid();
  v_post public.posts;
begin
  if v_uid is null then
    raise exception 'Se requiere autenticación' using errcode = '42501';
  end if;
  if p_visibility = 'private' then
    raise exception 'Un post no puede ser privado' using errcode = '22023';
  end if;

  -- Orden de visibilidad: private < followers < public (orden del enum).
  case p_kind
    when 'recipe' then
      update public.recipes set visibility = greatest(visibility, p_visibility)
       where id = p_content_id and owner_id = v_uid;
    when 'brew' then
      update public.brews set visibility = greatest(visibility, p_visibility)
       where id = p_content_id and owner_id = v_uid;
    when 'bean' then
      update public.coffee_beans set visibility = greatest(visibility, p_visibility)
       where id = p_content_id and owner_id = v_uid;
    else
      null;
  end case;

  if p_kind <> 'note' and not found then
    raise exception 'Contenido no encontrado' using errcode = 'P0002';
  end if;

  insert into public.posts (author_id, kind, recipe_id, brew_id, bean_id, caption,
                            visibility, comments_enabled)
  values (
    v_uid, p_kind,
    case when p_kind = 'recipe' then p_content_id end,
    case when p_kind = 'brew'   then p_content_id end,
    case when p_kind = 'bean'   then p_content_id end,
    p_caption, p_visibility, p_comments_enabled
  )
  returning * into v_post;

  return v_post;
end;
$$;

-- -----------------------------------------------------------------------------
-- Reemplazar los pasos de una receta de forma atómica (el editor de la app
-- envía la lista completa y ordenada).
--   p_steps: [{"kind":"bloom","instruction":"...","water_g":45,"start_at_s":0,"duration_s":45}, ...]
-- -----------------------------------------------------------------------------
create or replace function public.replace_recipe_steps(p_recipe_id uuid, p_steps jsonb)
returns setof public.recipe_steps
language plpgsql
as $$
begin
  if not exists (select 1 from public.recipes where id = p_recipe_id and owner_id = auth.uid()) then
    raise exception 'Receta no encontrada' using errcode = 'P0002';
  end if;

  delete from public.recipe_steps where recipe_id = p_recipe_id;

  return query
  insert into public.recipe_steps (recipe_id, position, kind, instruction, water_g, start_at_s, duration_s)
  select p_recipe_id, (e.ord - 1)::smallint,
         coalesce((e.step ->> 'kind')::public.step_kind, 'other'),
         e.step ->> 'instruction',
         (e.step ->> 'water_g')::numeric,
         (e.step ->> 'start_at_s')::integer,
         (e.step ->> 'duration_s')::integer
    from jsonb_array_elements(coalesce(p_steps, '[]'::jsonb)) with ordinality as e(step, ord)
  returning *;
end;
$$;

-- -----------------------------------------------------------------------------
-- Guardar ("forkear") la receta de otra persona como copia privada propia
-- -----------------------------------------------------------------------------
create or replace function public.fork_recipe(p_recipe_id uuid)
returns uuid
language plpgsql
as $$
declare
  v_uid uuid := auth.uid();
  v_src public.recipes;
  v_new_id uuid;
begin
  if v_uid is null then
    raise exception 'Se requiere autenticación' using errcode = '42501';
  end if;

  -- RLS garantiza que solo se lea si es visible para quien llama.
  select * into v_src from public.recipes where id = p_recipe_id;
  if not found then
    raise exception 'Receta no encontrada' using errcode = 'P0002';
  end if;

  insert into public.recipes (
    owner_id, title, description, brew_method_id, dose_g, water_g, yield_g,
    water_temp_c, grind_size, grind_setting, total_time_s, forked_from_id, visibility
  )
  select v_uid, v_src.title, v_src.description,
         -- Si el método es personalizado de otra persona, se usa el del sistema de la misma categoría.
         coalesce(
           (select id from public.brew_methods where id = v_src.brew_method_id and owner_id is null),
           (select m.id from public.brew_methods m
              join public.brew_methods src on src.id = v_src.brew_method_id
             where m.owner_id is null and m.category = src.category
             order by m.slug limit 1),
           (select id from public.brew_methods where owner_id is null and slug = 'other')
         ),
         v_src.dose_g, v_src.water_g, v_src.yield_g, v_src.water_temp_c,
         v_src.grind_size, v_src.grind_setting, v_src.total_time_s, v_src.id, 'private'
  returning id into v_new_id;

  insert into public.recipe_steps (recipe_id, position, kind, instruction, water_g, start_at_s, duration_s)
  select v_new_id, position, kind, instruction, water_g, start_at_s, duration_s
    from public.recipe_steps where recipe_id = p_recipe_id;

  return v_new_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- Feeds (paginación por cursor: created_at + id del último elemento recibido)
-- Se pueden embeber relaciones desde el cliente:
--   rpc/home_feed?select=*,author:profiles(*),post_media(*),recipe:recipes(*),liked_by_me
-- -----------------------------------------------------------------------------

create or replace function public.home_feed(
  p_limit integer default 20,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null
)
returns setof public.posts
language sql
stable
as $$
  select p.*
    from public.posts p
   where (p.author_id = auth.uid()
          or p.author_id in (select following_id from public.follows
                              where follower_id = auth.uid() and status = 'accepted'))
     and (p_before_created_at is null
          or (p.created_at, p.id) < (p_before_created_at, coalesce(p_before_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
   order by p.created_at desc, p.id desc
   limit least(greatest(p_limit, 1), 50);
$$;

-- Descubrir: posts públicos recientes ordenados por interacción con decaimiento temporal.
create or replace function public.explore_feed(
  p_limit integer default 20,
  p_offset integer default 0,
  p_kind public.post_kind default null
)
returns setof public.posts
language sql
stable
as $$
  select p.*
    from public.posts p
   where p.visibility = 'public'
     and p.created_at > now() - interval '14 days'
     and (p_kind is null or p.kind = p_kind)
     and (auth.uid() is null or p.author_id <> auth.uid())
   order by (p.like_count + 2 * p.comment_count + 1)
            / power(extract(epoch from (now() - p.created_at)) / 3600 + 2, 1.5) desc,
            p.created_at desc
   limit least(greatest(p_limit, 1), 50)
  offset greatest(p_offset, 0);
$$;

-- -----------------------------------------------------------------------------
-- Estadísticas personales del barista
-- -----------------------------------------------------------------------------
create or replace function public.my_brew_stats(p_days integer default 30)
returns table (
  total_brews bigint,
  total_coffee_g numeric,
  avg_rating numeric,
  favorite_method_id uuid,
  favorite_bean_id uuid
)
language sql
stable
as $$
  with b as (
    select * from public.brews
     where owner_id = auth.uid()
       and brewed_at > now() - make_interval(days => p_days)
  )
  select count(*),
         coalesce(sum(dose_g), 0),
         round(avg(rating), 2),
         (select brew_method_id from b group by 1 order by count(*) desc limit 1),
         (select bean_id from b where bean_id is not null group by 1 order by count(*) desc limit 1)
    from b;
$$;

-- -----------------------------------------------------------------------------
-- Registro de tokens de push (un token pasa al último usuario que inició sesión
-- en ese dispositivo).
-- -----------------------------------------------------------------------------
create or replace function public.register_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Se requiere autenticación' using errcode = '42501';
  end if;
  insert into public.push_tokens (token, user_id)
  values (p_token, auth.uid())
  on conflict (token) do update set user_id = excluded.user_id, updated_at = now();
end;
$$;

revoke execute on function public.register_push_token(text) from public, anon;
revoke execute on function public.publish_post(public.post_kind, uuid, text, public.visibility, boolean) from public, anon;
revoke execute on function public.fork_recipe(uuid) from public, anon;
revoke execute on function public.replace_recipe_steps(uuid, jsonb) from public, anon;
revoke execute on function public.my_brew_stats(integer) from public, anon;
grant execute on function public.register_push_token(text) to authenticated;
grant execute on function public.publish_post(public.post_kind, uuid, text, public.visibility, boolean) to authenticated;
grant execute on function public.fork_recipe(uuid) to authenticated;
grant execute on function public.replace_recipe_steps(uuid, jsonb) to authenticated;
grant execute on function public.my_brew_stats(integer) to authenticated;
