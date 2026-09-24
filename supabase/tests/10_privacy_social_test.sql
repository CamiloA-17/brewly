-- Pruebas de privacidad y lógica social. Cada bloque cambia de "usuario"
-- simulando el JWT de Supabase (rol authenticated + claim sub).
\set ON_ERROR_STOP 1

create or replace function pg_temp.as_user(p uuid) returns void language plpgsql as $$
begin
  if p is null then
    perform set_config('role', 'anon', false);
    perform set_config('request.jwt.claim.sub', '', false);
  else
    perform set_config('role', 'authenticated', false);
    perform set_config('request.jwt.claim.sub', p::text, false);
  end if;
end $$;
grant execute on function pg_temp.as_user(uuid) to anon, authenticated;

create or replace function pg_temp.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'FALLÓ: %', msg; end if;
  raise notice 'ok  %', msg;
end $$;
grant execute on function pg_temp.check(boolean, text) to anon, authenticated;

-- Usuarios: ana (pública), beto (cuenta privada), carla (pública)
insert into auth.users (id, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', '{"username":"ana"}'),
  ('00000000-0000-0000-0000-00000000000b', '{"username":"beto"}'),
  ('00000000-0000-0000-0000-00000000000c', '{"username":"carla"}');

-- ---------------------------------------------------------------- ana
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select pg_temp.check((select count(*) = 3 from profiles), 'perfiles creados por trigger');

insert into coffee_beans (id, owner_id, name, roaster, process, roast_level)
values ('10000000-0000-0000-0000-000000000001', auth.uid(), 'Huila Geisha', 'Tostador X', 'washed', 'light');
insert into bean_bags (id, bean_id, owner_id, weight_g, remaining_g)
values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', auth.uid(), 250, 250);
insert into recipes (id, owner_id, title, brew_method_id, bean_id, dose_g, water_g, water_temp_c)
values ('30000000-0000-0000-0000-000000000001', auth.uid(), 'V60 dulce',
        (select id from brew_methods where slug = 'v60'), '10000000-0000-0000-0000-000000000001', 15, 250, 94);
insert into recipe_steps (recipe_id, position, kind, instruction, water_g, start_at_s) values
  ('30000000-0000-0000-0000-000000000001', 0, 'bloom', 'Bloom con 45 g', 45, 0),
  ('30000000-0000-0000-0000-000000000001', 1, 'pour',  'Verter hasta 250 g', 205, 45);
select pg_temp.check((select ratio = 16.67 from recipes where id = '30000000-0000-0000-0000-000000000001'), 'ratio calculado');

insert into brews (owner_id, recipe_id, bean_id, bag_id, brew_method_id, dose_g, water_g, rating)
values (auth.uid(), '30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001', (select id from brew_methods where slug = 'v60'), 15, 250, 5);
select pg_temp.check((select remaining_g = 235 from bean_bags), 'la preparación descuenta del inventario');

-- ---------------------------------------------------------------- carla no ve lo privado
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select pg_temp.check((select count(*) = 0 from recipes), 'receta privada invisible para otros');
select pg_temp.check((select count(*) = 0 from bean_bags), 'inventario ajeno invisible');
select pg_temp.check((select count(*) = 0 from recipe_steps), 'pasos de receta privada invisibles');

do $$ begin
  insert into recipes (owner_id, title, brew_method_id, bean_id, dose_g)
  values (auth.uid(), 'robo', (select id from brew_methods where slug = 'v60'),
          '10000000-0000-0000-0000-000000000001', 15);
  raise exception 'FALLÓ: se permitió usar un grano ajeno';
exception when insufficient_privilege then raise notice 'ok  no se puede enlazar un grano ajeno';
end $$;

-- ---------------------------------------------------------------- ana publica
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select id as ana_post from publish_post('recipe', '30000000-0000-0000-0000-000000000001', 'Mi receta favorita') \gset
select pg_temp.check((select visibility = 'public' from recipes where id = '30000000-0000-0000-0000-000000000001'),
                     'publicar amplía la visibilidad de la receta');
select pg_temp.check((select visibility = 'private' from coffee_beans), 'el grano sigue privado');
select pg_temp.check((select posts_count = 1 from profiles where id = auth.uid()), 'posts_count');

select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select pg_temp.check((select count(*) = 1 from posts), 'carla ve el post público');
select pg_temp.check((select count(*) = 2 from recipe_steps), 'carla ve los pasos de la receta publicada');
select pg_temp.check((select count(*) = 0 from coffee_beans), 'carla no ve el grano privado de ana');

insert into likes (user_id, post_id) values (auth.uid(), :'ana_post');
insert into comments (id, post_id, author_id, body)
values ('40000000-0000-0000-0000-000000000001', :'ana_post', auth.uid(), '¡Qué buena receta!');
select pg_temp.check((select like_count = 1 and comment_count = 1 from posts where id = :'ana_post'), 'contadores de likes y comentarios');
select pg_temp.check((select liked_by_me(p) from posts p where id = :'ana_post'), 'campo calculado liked_by_me');

do $$ begin
  update posts set like_count = 999;
  raise exception 'FALLÓ: se pudo alterar un contador';
exception when insufficient_privilege then raise notice 'ok  contadores protegidos';
end $$;

select fork_recipe('30000000-0000-0000-0000-000000000001') as forked \gset
select pg_temp.check((select bean_id is null and visibility = 'private' and forked_from_id is not null
                        from recipes where id = :'forked'), 'fork crea copia privada sin grano ajeno');
select pg_temp.check((select count(*) = 2 from recipe_steps where recipe_id = :'forked'), 'fork copia los pasos');

-- ---------------------------------------------------------------- respuestas y notificaciones
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
insert into comments (post_id, author_id, parent_id, body)
values (:'ana_post', auth.uid(), '40000000-0000-0000-0000-000000000001', '¡Gracias!');
select pg_temp.check((select array_agg(type::text order by type::text) = '{comment,fork,like}' from notifications),
                     'ana recibe notificaciones de like, comentario y fork');

select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select pg_temp.check((select count(*) = 1 from notifications where type = 'reply'), 'carla recibe notificación de respuesta');

-- ---------------------------------------------------------------- cuenta privada (beto)
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
update profiles set is_private = true where id = auth.uid();
insert into recipes (id, owner_id, title, brew_method_id, dose_g, yield_g)
values ('30000000-0000-0000-0000-000000000002', auth.uid(), 'Espresso de la casa',
        (select id from brew_methods where slug = 'espresso'), 18, 36);
select id as beto_post from publish_post('recipe', '30000000-0000-0000-0000-000000000002', 'Shot del día') \gset

select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select pg_temp.check((select count(*) = 0 from posts where author_id = '00000000-0000-0000-0000-00000000000b'),
                     'post "público" de cuenta privada invisible para no seguidores');
insert into follows (follower_id, following_id) values (auth.uid(), '00000000-0000-0000-0000-00000000000b');
select pg_temp.check((select status = 'pending' from follows where following_id = '00000000-0000-0000-0000-00000000000b'),
                     'seguir cuenta privada crea solicitud pendiente');
select pg_temp.check((select count(*) = 0 from posts where author_id = '00000000-0000-0000-0000-00000000000b'),
                     'solicitud pendiente no da acceso');

do $$ begin
  update follows set status = 'accepted' where following_id = '00000000-0000-0000-0000-00000000000b';
  if found then raise exception 'FALLÓ: el seguidor se auto-aceptó'; end if;
  raise notice 'ok  el seguidor no puede aceptar su propia solicitud';
end $$;

select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
update follows set status = 'accepted' where follower_id = '00000000-0000-0000-0000-00000000000c';
select pg_temp.check((select followers_count = 1 from profiles where id = auth.uid()), 'followers_count tras aceptar');

select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select pg_temp.check((select count(*) = 1 from posts where author_id = '00000000-0000-0000-0000-00000000000b'),
                     'seguidor aceptado ve los posts de la cuenta privada');
select pg_temp.check((select count(*) = 1 from home_feed() where author_id = '00000000-0000-0000-0000-00000000000b'),
                     'home_feed incluye a los seguidos');
select pg_temp.check((select viewer_follow_status(pr) = 'accepted' from profiles pr where username = 'beto'),
                     'campo calculado viewer_follow_status');

-- ---------------------------------------------------------------- ocultar contenido publicado
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
update recipes set visibility = 'private' where id = '30000000-0000-0000-0000-000000000001';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select pg_temp.check((select count(*) = 0 from posts where id = :'ana_post'),
                     'volver privada la receta oculta su post');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
update recipes set visibility = 'public' where id = '30000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------- anónimo
select pg_temp.as_user(null);
select pg_temp.check((select count(*) = 1 from posts), 'anónimo solo ve posts públicos de cuentas públicas');
select pg_temp.check((select count(*) = 1 from explore_feed()), 'explore_feed para anónimo');

-- ---------------------------------------------------------------- bloqueo
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
insert into blocks (blocker_id, blocked_id) values (auth.uid(), '00000000-0000-0000-0000-00000000000c');
select pg_temp.check((select followers_count = 0 from profiles where id = auth.uid()), 'bloquear elimina el seguimiento');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select pg_temp.check((select count(*) = 0 from profiles where username = 'beto'), 'el bloqueado no ve el perfil');
select pg_temp.check((select count(*) = 0 from posts where author_id = '00000000-0000-0000-0000-00000000000b'),
                     'el bloqueado no ve los posts');

-- ---------------------------------------------------------------- editor de pasos
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select count(*) from replace_recipe_steps('30000000-0000-0000-0000-000000000001',
  '[{"kind":"bloom","instruction":"Bloom","water_g":50,"start_at_s":0},
    {"kind":"pour","instruction":"Primer vertido","water_g":100,"start_at_s":45},
    {"instruction":"Drenar"}]');
select pg_temp.check((select array_agg(kind::text order by position) = '{bloom,pour,other}'
                        from recipe_steps where recipe_id = '30000000-0000-0000-0000-000000000001'),
                     'replace_recipe_steps reemplaza y ordena los pasos');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
do $$ begin
  perform replace_recipe_steps('30000000-0000-0000-0000-000000000001', '[]');
  raise exception 'FALLÓ: se editaron pasos de una receta ajena';
exception when no_data_found then raise notice 'ok  no se pueden editar pasos ajenos';
end $$;

-- ---------------------------------------------------------------- estadísticas
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select pg_temp.check((select total_brews = 1 and total_coffee_g = 15 and avg_rating = 5 from my_brew_stats()),
                     'estadísticas personales');

reset role;
