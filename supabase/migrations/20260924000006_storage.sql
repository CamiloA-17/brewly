-- =============================================================================
-- Brewly · Almacenamiento de archivos (Supabase Storage)
-- -----------------------------------------------------------------------------
-- Convención de rutas: <bucket>/<user_id>/<...>.  La primera carpeta siempre es
-- el dueño, lo que permite escribir políticas simples.
--
--   avatars     → público (fotos de perfil)
--   post-media  → privado; lectura con URL firmada si el post es visible
--                 ruta: <author_id>/<post_id>/<archivo>
--   bean-photos → privado; lectura si el grano es visible
--                 ruta: <owner_id>/<bean_id>/<archivo>
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars',     'avatars',     true,  2097152,  array['image/jpeg', 'image/png', 'image/heic', 'image/webp']),
  ('post-media',  'post-media',  false, 20971520, array['image/jpeg', 'image/png', 'image/heic', 'image/webp', 'video/mp4', 'video/quicktime']),
  ('bean-photos', 'bean-photos', false, 5242880,  array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do nothing;

-- Escritura: cada usuario solo escribe dentro de su propia carpeta.
create policy storage_owner_insert on storage.objects for insert to authenticated
  with check (
    bucket_id in ('avatars', 'post-media', 'bean-photos')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy storage_owner_update on storage.objects for update to authenticated
  using ((storage.foldername(name))[1] = auth.uid()::text)
  with check ((storage.foldername(name))[1] = auth.uid()::text);

create policy storage_owner_delete on storage.objects for delete to authenticated
  using ((storage.foldername(name))[1] = auth.uid()::text);

-- Lectura
create policy storage_avatars_read on storage.objects for select
  using (bucket_id = 'avatars');

create policy storage_post_media_read on storage.objects for select
  using (
    bucket_id = 'post-media'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.posts p
         where p.id::text = (storage.foldername(name))[2]
      )
    )
  );

create policy storage_bean_photos_read on storage.objects for select
  using (
    bucket_id = 'bean-photos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.coffee_beans c
         where c.id::text = (storage.foldername(name))[2]
      )
    )
  );
