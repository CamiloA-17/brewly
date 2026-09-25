-- Assertion helpers shared by every test file (session-scoped, never persisted).

CREATE FUNCTION pg_temp.expect_error(stmt text, expected_sqlstate text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE stmt;
    EXCEPTION WHEN others THEN
        IF SQLSTATE = expected_sqlstate THEN
            RETURN;
        END IF;
        RAISE EXCEPTION 'expected SQLSTATE % but got % (%) for: %', expected_sqlstate, SQLSTATE, SQLERRM, stmt;
    END;
    RAISE EXCEPTION 'expected SQLSTATE % but the statement succeeded: %', expected_sqlstate, stmt;
END;
$$;

CREATE FUNCTION pg_temp.expect_equal(actual anyelement, expected anyelement, label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    IF actual IS DISTINCT FROM expected THEN
        RAISE EXCEPTION '%: expected %, got %', label, expected, actual;
    END IF;
END;
$$;

-- Fixture users: ana (author), leo (follower of ana), eve (stranger).
CREATE FUNCTION pg_temp.create_fixture_users() RETURNS void
LANGUAGE sql AS $$
    INSERT INTO users (id, username, display_name, email) VALUES
        ('00000000-0000-0000-0000-00000000000a', 'ana.test', 'Ana', 'ana@test.dev'),
        ('00000000-0000-0000-0000-00000000000b', 'leo.test', 'Leo', 'leo@test.dev'),
        ('00000000-0000-0000-0000-00000000000e', 'eve.test', 'Eve', 'eve@test.dev');
    INSERT INTO coffee_beans (id, owner_id, name, country_code, farm, altitude_min_m, altitude_max_m, processing_method_slug)
    VALUES
        ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000000a',
         'Geisha Washed', 'CO', 'Finca Test', 1700, 1900, 'washed'),
        ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-00000000000b',
         'Pink Bourbon Natural', 'CO', 'Finca Leo', 1800, 1950, 'natural');
$$;
