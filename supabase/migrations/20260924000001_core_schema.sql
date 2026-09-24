-- =============================================================================
-- Brewly · Esquema principal
-- -----------------------------------------------------------------------------
-- Dominio personal: perfiles, equipo, granos, inventario, métodos, recetas y
-- preparaciones (brews). Todo lo personal nace PRIVADO por defecto.
-- =============================================================================

create extension if not exists citext;
create extension if not exists pg_trgm;

-- -----------------------------------------------------------------------------
-- Tipos enumerados
-- -----------------------------------------------------------------------------

-- Quién puede ver un contenido.
--   private   → solo el dueño
--   followers → el dueño y sus seguidores aceptados
--   public    → cualquiera (salvo que la cuenta del dueño sea privada, en cuyo
--               caso se comporta como "followers")
create type public.visibility as enum ('private', 'followers', 'public');

create type public.user_role as enum ('barista', 'home_brewer', 'roaster', 'enthusiast');

create type public.roast_level as enum (
  'light', 'medium_light', 'medium', 'medium_dark', 'dark'
);

create type public.coffee_process as enum (
  'washed', 'natural', 'honey', 'anaerobic', 'carbonic_maceration',
  'wet_hulled', 'experimental', 'other'
);

create type public.brew_category as enum (
  'espresso', 'pour_over', 'immersion', 'pressure', 'cold_brew', 'siphon', 'other'
);

create type public.equipment_type as enum (
  'grinder', 'brewer', 'espresso_machine', 'kettle', 'scale', 'filter', 'other'
);

create type public.step_kind as enum (
  'bloom', 'pour', 'stir', 'swirl', 'wait', 'press', 'invert', 'extract', 'other'
);

-- -----------------------------------------------------------------------------
-- Utilidades
-- -----------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Perfiles (1:1 con auth.users)
-- -----------------------------------------------------------------------------

create table public.profiles (
  id                uuid primary key references auth.users (id) on delete cascade,
  username          citext not null unique
                    check (username ~ '^[a-z0-9_.]{3,30}$'),
  display_name      text check (char_length(display_name) <= 60),
  bio               text check (char_length(bio) <= 300),
  avatar_path       text,
  role              public.user_role not null default 'enthusiast',
  location          text check (char_length(location) <= 80),
  website           text check (char_length(website) <= 200),
  is_private        boolean not null default false,   -- cuenta privada estilo Instagram
  -- Contadores desnormalizados (mantenidos por triggers, solo lectura para clientes)
  followers_count   integer not null default 0,
  following_count   integer not null default 0,
  posts_count       integer not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index profiles_username_trgm_idx on public.profiles using gin (username gin_trgm_ops);
create index profiles_display_name_trgm_idx on public.profiles using gin (display_name gin_trgm_ops);

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- Crea el perfil automáticamente al registrarse. El cliente puede enviar
-- `username` en los metadatos del sign-up; si no, se genera uno provisional.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text := lower(coalesce(
    new.raw_user_meta_data ->> 'username',
    'user_' || substr(replace(new.id::text, '-', ''), 1, 10)
  ));
begin
  insert into public.profiles (id, username, display_name)
  values (new.id, v_username, new.raw_user_meta_data ->> 'display_name');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Equipo (molinos, cafeteras, máquinas…)
-- -----------------------------------------------------------------------------

create table public.equipment (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null references public.profiles (id) on delete cascade,
  type         public.equipment_type not null,
  brand        text not null check (char_length(brand) between 1 and 80),
  model        text check (char_length(model) <= 80),
  notes        text check (char_length(notes) <= 1000),
  visibility   public.visibility not null default 'private',
  archived_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index equipment_owner_idx on public.equipment (owner_id, type);

create trigger equipment_updated_at before update on public.equipment
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Granos de café (la "ficha" del café) e inventario (bolsas físicas)
-- -----------------------------------------------------------------------------

create table public.coffee_beans (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null references public.profiles (id) on delete cascade,
  name            text not null check (char_length(name) between 1 and 120),
  roaster         text check (char_length(roaster) <= 120),
  origin_country  text check (char_length(origin_country) <= 80),
  region          text check (char_length(region) <= 120),
  farm            text check (char_length(farm) <= 120),
  producer        text check (char_length(producer) <= 120),
  varieties       text[] not null default '{}',
  process         public.coffee_process,
  altitude_min_m  integer check (altitude_min_m between 0 and 4000),
  altitude_max_m  integer check (altitude_max_m between 0 and 4000),
  roast_level     public.roast_level,
  tasting_notes   text[] not null default '{}',
  sca_score       numeric(4, 2) check (sca_score between 0 and 100),
  photo_path      text,
  notes           text check (char_length(notes) <= 2000),
  visibility      public.visibility not null default 'private',
  archived_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (altitude_min_m is null or altitude_max_m is null or altitude_min_m <= altitude_max_m)
);

create index coffee_beans_owner_idx on public.coffee_beans (owner_id, created_at desc);
create index coffee_beans_name_trgm_idx on public.coffee_beans using gin (name gin_trgm_ops);

create trigger coffee_beans_updated_at before update on public.coffee_beans
  for each row execute function public.set_updated_at();

-- Cada bolsa comprada de un café. El inventario SIEMPRE es privado.
create table public.bean_bags (
  id               uuid primary key default gen_random_uuid(),
  bean_id          uuid not null references public.coffee_beans (id) on delete cascade,
  owner_id         uuid not null references public.profiles (id) on delete cascade,
  roast_date       date,
  purchase_date    date,
  opened_at        date,
  weight_g         numeric(7, 1) not null check (weight_g > 0),
  remaining_g      numeric(7, 1) not null check (remaining_g >= 0),
  price            numeric(10, 2) check (price >= 0),
  currency         char(3),
  is_frozen        boolean not null default false,
  finished_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (remaining_g <= weight_g)
);

create index bean_bags_owner_active_idx on public.bean_bags (owner_id) where finished_at is null;
create index bean_bags_bean_idx on public.bean_bags (bean_id);

create trigger bean_bags_updated_at before update on public.bean_bags
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Métodos de preparación
--   owner_id NULL  → método del sistema (catálogo global, solo lectura)
--   owner_id != NULL → método personalizado del usuario
-- -----------------------------------------------------------------------------

create table public.brew_methods (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid references public.profiles (id) on delete cascade,
  slug            text not null check (slug ~ '^[a-z0-9_-]{2,40}$'),
  name            text not null check (char_length(name) between 1 and 60),
  category        public.brew_category not null,
  description     text check (char_length(description) <= 1000),
  icon            text,             -- nombre de SF Symbol o asset
  -- Parámetros sugeridos: {"dose_g":15,"water_g":250,"temp_c":94,"time_s":180}
  default_params  jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);

create unique index brew_methods_system_slug_uidx
  on public.brew_methods (slug) where owner_id is null;
create unique index brew_methods_user_slug_uidx
  on public.brew_methods (owner_id, slug) where owner_id is not null;

-- -----------------------------------------------------------------------------
-- Recetas
-- -----------------------------------------------------------------------------

create table public.recipes (
  id               uuid primary key default gen_random_uuid(),
  owner_id         uuid not null references public.profiles (id) on delete cascade,
  title            text not null check (char_length(title) between 1 and 120),
  description      text check (char_length(description) <= 2000),
  brew_method_id   uuid not null references public.brew_methods (id) on delete restrict,
  bean_id          uuid references public.coffee_beans (id) on delete set null,
  grinder_id       uuid references public.equipment (id) on delete set null,
  brewer_id        uuid references public.equipment (id) on delete set null,
  dose_g           numeric(5, 1) not null check (dose_g > 0 and dose_g <= 1000),
  water_g          numeric(6, 1) check (water_g > 0 and water_g <= 10000),
  yield_g          numeric(6, 1) check (yield_g > 0),     -- bebida en taza / espresso
  ratio            numeric(5, 2) generated always as (
                     case when water_g is not null then round(water_g / dose_g, 2) end
                   ) stored,
  water_temp_c     numeric(4, 1) check (water_temp_c between 0 and 100),
  grind_size       text check (char_length(grind_size) <= 40),   -- "medio-fino"
  grind_setting    text check (char_length(grind_setting) <= 40),-- "Comandante 22 clicks"
  total_time_s     integer check (total_time_s > 0),
  forked_from_id   uuid references public.recipes (id) on delete set null,
  visibility       public.visibility not null default 'private',
  archived_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index recipes_owner_idx on public.recipes (owner_id, created_at desc);
create index recipes_method_idx on public.recipes (brew_method_id);
create index recipes_title_trgm_idx on public.recipes using gin (title gin_trgm_ops);

create trigger recipes_updated_at before update on public.recipes
  for each row execute function public.set_updated_at();

create table public.recipe_steps (
  id              uuid primary key default gen_random_uuid(),
  recipe_id       uuid not null references public.recipes (id) on delete cascade,
  position        smallint not null check (position >= 0),
  kind            public.step_kind not null default 'other',
  instruction     text not null check (char_length(instruction) between 1 and 500),
  water_g         numeric(6, 1) check (water_g >= 0),      -- agua a verter en este paso
  start_at_s      integer check (start_at_s >= 0),          -- segundo del temporizador
  duration_s      integer check (duration_s >= 0),
  unique (recipe_id, position) deferrable initially deferred
);

-- -----------------------------------------------------------------------------
-- Preparaciones (bitácora de cada café preparado)
-- -----------------------------------------------------------------------------

create table public.brews (
  id               uuid primary key default gen_random_uuid(),
  owner_id         uuid not null references public.profiles (id) on delete cascade,
  recipe_id        uuid references public.recipes (id) on delete set null,
  bean_id          uuid references public.coffee_beans (id) on delete set null,
  bag_id           uuid references public.bean_bags (id) on delete set null,
  brew_method_id   uuid not null references public.brew_methods (id) on delete restrict,
  grinder_id       uuid references public.equipment (id) on delete set null,
  dose_g           numeric(5, 1) not null check (dose_g > 0),
  water_g          numeric(6, 1) check (water_g > 0),
  yield_g          numeric(6, 1) check (yield_g > 0),
  water_temp_c     numeric(4, 1) check (water_temp_c between 0 and 100),
  grind_setting    text check (char_length(grind_setting) <= 40),
  total_time_s     integer check (total_time_s > 0),
  tds              numeric(4, 2) check (tds between 0 and 30),
  extraction_pct   numeric(4, 1) check (extraction_pct between 0 and 40),
  -- Evaluación sensorial (1-10) y valoración global (1-5)
  rating           smallint check (rating between 1 and 5),
  acidity          smallint check (acidity between 1 and 10),
  sweetness        smallint check (sweetness between 1 and 10),
  body             smallint check (body between 1 and 10),
  bitterness       smallint check (bitterness between 1 and 10),
  aftertaste       smallint check (aftertaste between 1 and 10),
  tasting_notes    text[] not null default '{}',
  notes            text check (char_length(notes) <= 2000),
  visibility       public.visibility not null default 'private',
  brewed_at        timestamptz not null default now(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index brews_owner_idx on public.brews (owner_id, brewed_at desc);
create index brews_recipe_idx on public.brews (recipe_id);
create index brews_bean_idx on public.brews (bean_id);

create trigger brews_updated_at before update on public.brews
  for each row execute function public.set_updated_at();

-- Descuenta automáticamente del inventario los gramos usados en una preparación.
create or replace function public.consume_bag_on_brew()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') and old.bag_id is not null then
    update public.bean_bags
       set remaining_g = least(weight_g, remaining_g + old.dose_g)
     where id = old.bag_id and owner_id = old.owner_id;
  end if;

  if tg_op in ('INSERT', 'UPDATE') and new.bag_id is not null then
    update public.bean_bags
       set remaining_g = greatest(0, remaining_g - new.dose_g),
           finished_at = case when remaining_g - new.dose_g <= 0
                              then coalesce(finished_at, now())
                              else finished_at end
     where id = new.bag_id and owner_id = new.owner_id;
  end if;

  return coalesce(new, old);
end;
$$;

create trigger brews_consume_bag
  after insert or delete or update of bag_id, dose_g on public.brews
  for each row execute function public.consume_bag_on_brew();
