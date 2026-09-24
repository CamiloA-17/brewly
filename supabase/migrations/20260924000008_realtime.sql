-- =============================================================================
-- Brewly · Realtime
-- -----------------------------------------------------------------------------
-- Publica los cambios de estas tablas por el canal de Supabase Realtime. Los
-- suscriptores solo reciben filas que su política RLS de SELECT les permite ver.
-- =============================================================================

alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.comments;
