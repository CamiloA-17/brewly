-- Notification rules.
BEGIN;
SELECT pg_temp.create_fixture_users();

INSERT INTO posts (id, author_id, kind, body) VALUES
    ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000000a', 'text', 'Hello');

-- Nobody is notified about their own actions.
SELECT pg_temp.expect_error($$
    INSERT INTO notifications (recipient_id, actor_id, kind)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a', 'follow')$$, '23514');

-- A like, unlike and like again notify once.
INSERT INTO notifications (recipient_id, actor_id, kind, post_id) VALUES
    ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 'post_like',
     '00000000-0000-0000-0000-0000000000e1');
INSERT INTO notifications (recipient_id, actor_id, kind, post_id) VALUES
    ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 'post_like',
     '00000000-0000-0000-0000-0000000000e1')
ON CONFLICT DO NOTHING;
SELECT pg_temp.expect_equal(
    (SELECT count(*) FROM notifications WHERE post_id = '00000000-0000-0000-0000-0000000000e1'),
    1::bigint, 'likes notify once');

-- Comments notify every time.
INSERT INTO comments (id, post_id, author_id, body) VALUES
    ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000e1',
     '00000000-0000-0000-0000-00000000000b', 'First'),
    ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000e1',
     '00000000-0000-0000-0000-00000000000b', 'Second');
INSERT INTO notifications (recipient_id, actor_id, kind, post_id, comment_id) VALUES
    ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 'comment',
     '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000f1'),
    ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 'comment',
     '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000f2');

-- Deleting a comment removes its notification.
DELETE FROM comments WHERE id = '00000000-0000-0000-0000-0000000000f1';
SELECT pg_temp.expect_equal(
    (SELECT count(*) FROM notifications WHERE kind = 'comment' AND post_id = '00000000-0000-0000-0000-0000000000e1'),
    1::bigint, 'notifications of deleted comments are removed');
ROLLBACK;
