-- migrate:up

CREATE TABLE notifications (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id  uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    actor_id      uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    kind          text        NOT NULL,
    post_id       uuid        REFERENCES posts (id) ON DELETE CASCADE,
    comment_id    uuid        REFERENCES comments (id) ON DELETE CASCADE,
    recipe_id     uuid        REFERENCES recipes (id) ON DELETE CASCADE,
    read_at       timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT notifications_not_self CHECK (recipient_id <> actor_id),
    CONSTRAINT notifications_kind_check CHECK (kind IN
        ('follow', 'post_like', 'comment', 'comment_reply', 'recipe_save', 'recipe_fork')),
    CONSTRAINT notifications_kind_target CHECK (
        CASE kind
            WHEN 'follow'        THEN num_nonnulls(post_id, comment_id, recipe_id) = 0
            WHEN 'post_like'     THEN post_id IS NOT NULL AND comment_id IS NULL AND recipe_id IS NULL
            WHEN 'comment'       THEN post_id IS NOT NULL AND comment_id IS NOT NULL AND recipe_id IS NULL
            WHEN 'comment_reply' THEN post_id IS NOT NULL AND comment_id IS NOT NULL AND recipe_id IS NULL
            WHEN 'recipe_save'   THEN recipe_id IS NOT NULL AND post_id IS NULL AND comment_id IS NULL
            WHEN 'recipe_fork'   THEN recipe_id IS NOT NULL AND post_id IS NULL AND comment_id IS NULL
        END)
);
CREATE INDEX notifications_recipient_created_idx ON notifications (recipient_id, created_at DESC);
CREATE INDEX notifications_unread_idx ON notifications (recipient_id) WHERE read_at IS NULL;
CREATE INDEX notifications_actor_idx ON notifications (actor_id);
CREATE INDEX notifications_post_idx ON notifications (post_id);
CREATE INDEX notifications_comment_idx ON notifications (comment_id);
CREATE INDEX notifications_recipe_idx ON notifications (recipe_id);

-- User reports of objectionable content (App Store Review Guideline 1.2).
CREATE TABLE reports (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id       uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    reported_user_id  uuid        REFERENCES users (id) ON DELETE CASCADE,
    post_id           uuid        REFERENCES posts (id) ON DELETE CASCADE,
    comment_id        uuid        REFERENCES comments (id) ON DELETE CASCADE,
    recipe_id         uuid        REFERENCES recipes (id) ON DELETE CASCADE,
    reason            text        NOT NULL,
    details           text,
    status            text        NOT NULL DEFAULT 'open',
    created_at        timestamptz NOT NULL DEFAULT now(),
    resolved_at       timestamptz,
    CONSTRAINT reports_single_target CHECK (num_nonnulls(reported_user_id, post_id, comment_id, recipe_id) = 1),
    CONSTRAINT reports_reason_check CHECK (reason IN
        ('spam', 'harassment', 'hate', 'sexual_content', 'violence', 'misinformation', 'other')),
    CONSTRAINT reports_status_check CHECK (status IN ('open', 'reviewing', 'resolved', 'dismissed')),
    CONSTRAINT reports_details_length CHECK (details IS NULL OR char_length(details) <= 1000)
);
CREATE INDEX reports_status_created_idx ON reports (status, created_at);
CREATE INDEX reports_reporter_idx ON reports (reporter_id);
CREATE INDEX reports_reported_user_idx ON reports (reported_user_id);
CREATE INDEX reports_post_idx ON reports (post_id);
CREATE INDEX reports_comment_idx ON reports (comment_id);
CREATE INDEX reports_recipe_idx ON reports (recipe_id);

-- migrate:down

DROP TABLE reports;
DROP TABLE notifications;
