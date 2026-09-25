-- can_view_content(viewer, owner, visibility): visibility, followers and blocks.
BEGIN;
SELECT pg_temp.create_fixture_users();

-- leo follows ana; eve is a stranger.
INSERT INTO follows (follower_id, followed_id) VALUES
    ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a');

CREATE TEMP TABLE cases (viewer uuid, vis text, expected boolean, label text);
INSERT INTO cases VALUES
    ('00000000-0000-0000-0000-00000000000a', 'private',   true,  'owner sees private'),
    ('00000000-0000-0000-0000-00000000000b', 'public',    true,  'follower sees public'),
    ('00000000-0000-0000-0000-00000000000b', 'followers', true,  'follower sees followers-only'),
    ('00000000-0000-0000-0000-00000000000b', 'private',   false, 'follower does not see private'),
    ('00000000-0000-0000-0000-00000000000e', 'public',    true,  'stranger sees public'),
    ('00000000-0000-0000-0000-00000000000e', 'followers', false, 'stranger does not see followers-only'),
    (NULL,                                   'public',    true,  'anonymous sees public'),
    (NULL,                                   'followers', false, 'anonymous does not see followers-only');

DO $$
DECLARE c record;
BEGIN
    FOR c IN SELECT * FROM cases LOOP
        PERFORM pg_temp.expect_equal(
            can_view_content(c.viewer, '00000000-0000-0000-0000-00000000000a', c.vis::visibility),
            c.expected, c.label);
    END LOOP;
END $$;

-- Blocks hide content in both directions, even public content.
INSERT INTO user_blocks (blocker_id, blocked_id) VALUES
    ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000e');
SELECT pg_temp.expect_equal(
    can_view_content('00000000-0000-0000-0000-00000000000e', '00000000-0000-0000-0000-00000000000a', 'public'),
    false, 'blocked user does not see public content');
SELECT pg_temp.expect_equal(
    can_view_content('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000e', 'public'),
    false, 'blocker does not see the blocked user either');

ROLLBACK;
