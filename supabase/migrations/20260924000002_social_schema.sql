-- =============================================================================
-- Brewly · Capa social
-- -----------------------------------------------------------------------------
-- Seguidores, bloqueos, publicaciones, multimedia, likes, comentarios,
-- guardados, notificaciones y tokens de push.
--
-- Idea clave: un "post" es un envoltorio social que APUNTA a contenido del
-- dominio personal (receta, preparación o grano). Publicar no duplica datos;
-- el contenido sigue siendo del usuario y su visibilidad se controla aparte.
-- =============================================================================

create type public.follow_status as enum ('pending', 'accepted');

create type public.post_kind as enum ('recipe', 'brew', 'bean', 'note');

create type public.media_type as enum ('image', 'video');

create type public.notification_type as enum (
  'follow', 'follow_request', 'follow_accepted', 'like', 'comment', 'reply', 'fork'
);

-- -----------------------------------------------------------------------------
-- Seguidores y bloqueos
-- -----------------------------------------------------------------------------

create table public.follows (
  follower_id   uuid not null references public.profiles (id) on delete cascade,
  following_id  uuid not null references public.profiles (id) on delete cascade,
  status        public.follow_status not null default 'accepted',
  created_at    timestamptz not null default now(),
  accepted_at   timestamptz,
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create index follows_following_idx on public.follows (following_id, status);

create table public.blocks (
  blocker_id  uuid not null references public.profiles (id) on delete cascade,
  blocked_id  uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index blocks_blocked_idx on public.blocks (blocked_id);

-- -----------------------------------------------------------------------------
-- Publicaciones
-- -----------------------------------------------------------------------------

create table public.posts (
  id              uuid primary key default gen_random_uuid(),
  author_id       uuid not null references public.profiles (id) on delete cascade,
  kind            public.post_kind not null,
  recipe_id       uuid references public.recipes (id) on delete cascade,
  brew_id         uuid references public.brews (id) on delete cascade,
  bean_id         uuid references public.coffee_beans (id) on delete cascade,
  caption         text check (char_length(caption) <= 2200),
  visibility      public.visibility not null default 'public'
                  check (visibility <> 'private'),
  comments_enabled boolean not null default true,
  like_count      integer not null default 0,
  comment_count   integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- Cada tipo de post referencia exactamente el contenido que le corresponde.
  check (
    (kind = 'recipe' and recipe_id is not null and brew_id is null and bean_id is null) or
    (kind = 'brew'   and brew_id   is not null and recipe_id is null and bean_id is null) or
    (kind = 'bean'   and bean_id   is not null and recipe_id is null and brew_id is null) or
    (kind = 'note'   and recipe_id is null and brew_id is null and bean_id is null
                     and caption is not null)
  )
);

create index posts_author_idx on public.posts (author_id, created_at desc, id desc);
create index posts_created_idx on public.posts (created_at desc, id desc);
create index posts_recipe_idx on public.posts (recipe_id) where recipe_id is not null;
create index posts_brew_idx on public.posts (brew_id) where brew_id is not null;
create index posts_bean_idx on public.posts (bean_id) where bean_id is not null;

create trigger posts_updated_at before update on public.posts
  for each row execute function public.set_updated_at();

create table public.post_media (
  id            uuid primary key default gen_random_uuid(),
  post_id       uuid not null references public.posts (id) on delete cascade,
  storage_path  text not null,          -- <author_id>/<post_id>/<uuid>.jpg
  media_type    public.media_type not null default 'image',
  position      smallint not null default 0 check (position between 0 and 9),
  width         integer,
  height        integer,
  blurhash      text,
  created_at    timestamptz not null default now(),
  unique (post_id, position)
);

-- -----------------------------------------------------------------------------
-- Interacciones
-- -----------------------------------------------------------------------------

create table public.likes (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  post_id     uuid not null references public.posts (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, post_id)
);

create index likes_post_idx on public.likes (post_id);

create table public.comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.posts (id) on delete cascade,
  author_id   uuid not null references public.profiles (id) on delete cascade,
  parent_id   uuid references public.comments (id) on delete cascade,  -- respuestas (1 nivel)
  body        text not null check (char_length(body) between 1 and 1000),
  created_at  timestamptz not null default now(),
  edited_at   timestamptz
);

create index comments_post_idx on public.comments (post_id, created_at);
create index comments_parent_idx on public.comments (parent_id) where parent_id is not null;

create table public.saved_posts (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  post_id     uuid not null references public.posts (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, post_id)
);

-- -----------------------------------------------------------------------------
-- Notificaciones y push
-- -----------------------------------------------------------------------------

create table public.notifications (
  id            uuid primary key default gen_random_uuid(),
  recipient_id  uuid not null references public.profiles (id) on delete cascade,
  actor_id      uuid not null references public.profiles (id) on delete cascade,
  type          public.notification_type not null,
  post_id       uuid references public.posts (id) on delete cascade,
  comment_id    uuid references public.comments (id) on delete cascade,
  recipe_id     uuid references public.recipes (id) on delete cascade,
  read_at       timestamptz,
  created_at    timestamptz not null default now()
);

create index notifications_recipient_idx
  on public.notifications (recipient_id, created_at desc);

create table public.push_tokens (
  token       text primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  platform    text not null default 'ios' check (platform in ('ios')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index push_tokens_user_idx on public.push_tokens (user_id);
