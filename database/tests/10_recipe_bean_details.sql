-- Bean purchase details and the single use of each uploaded image.
BEGIN;
SELECT pg_temp.create_fixture_users();

UPDATE coffee_beans
SET purchase_date = '2026-09-01', opened_date = '2026-09-05', price = 68000, currency = 'COP',
    lot = 'Lot 12', is_favorite = true
WHERE id = '00000000-0000-0000-0000-0000000000b1';

SELECT pg_temp.expect_error($$
    UPDATE coffee_beans SET opened_date = '2026-08-01'
    WHERE id = '00000000-0000-0000-0000-0000000000b1'$$, '23514');
SELECT pg_temp.expect_error($$
    UPDATE coffee_beans SET currency = NULL WHERE id = '00000000-0000-0000-0000-0000000000b1'$$, '23514');
SELECT pg_temp.expect_error($$
    UPDATE coffee_beans SET currency = 'cop' WHERE id = '00000000-0000-0000-0000-0000000000b1'$$, '23514');

-- Each image has one use.
INSERT INTO media (id, owner_id, content_type, data, width, height)
VALUES ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000000a', 'image/jpeg', '\xffd8ffd9', 10, 10);
SELECT pg_temp.expect_equal(media_in_use('00000000-0000-0000-0000-0000000000d1'), false, 'unused upload');
UPDATE coffee_beans SET photo_media_id = '00000000-0000-0000-0000-0000000000d1'
WHERE id = '00000000-0000-0000-0000-0000000000b1';
SELECT pg_temp.expect_equal(media_in_use('00000000-0000-0000-0000-0000000000d1'), true, 'bean photo in use');
SELECT pg_temp.expect_error($$
    INSERT INTO coffee_beans (owner_id, name, photo_media_id)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'Copy', '00000000-0000-0000-0000-0000000000d1')$$, '23505');

-- Deleting the image clears the photo.
DELETE FROM media WHERE id = '00000000-0000-0000-0000-0000000000d1';
SELECT pg_temp.expect_equal((SELECT photo_media_id FROM coffee_beans WHERE id = '00000000-0000-0000-0000-0000000000b1'),
                            NULL::uuid, 'photo cleared');

ROLLBACK;
