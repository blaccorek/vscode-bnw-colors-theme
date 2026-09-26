-- Sample SQL: DDL, constraints, indexes, CTEs, window functions, transactions.
BEGIN;

CREATE TYPE user_role AS ENUM ('admin', 'editor', 'viewer');

CREATE TABLE IF NOT EXISTS users (
    id           BIGSERIAL    PRIMARY KEY,
    email        VARCHAR(255) NOT NULL UNIQUE,
    name         TEXT         NOT NULL CHECK (length(trim(name)) > 0),
    role         user_role    NOT NULL DEFAULT 'viewer',
    metadata     JSONB        NOT NULL DEFAULT '{}'::jsonb,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ,
    deleted_at   TIMESTAMPTZ
);

CREATE TABLE orders (
    id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     BIGINT        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    total_cents INTEGER       NOT NULL CHECK (total_cents >= 0),
    currency    CHAR(3)       NOT NULL DEFAULT 'EUR',
    status      TEXT          NOT NULL DEFAULT 'pending',
    placed_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT orders_status_valid CHECK (status IN ('pending', 'paid', 'shipped', 'cancelled'))
);

CREATE INDEX idx_users_email_lower ON users (lower(email));
CREATE INDEX idx_orders_user_placed ON orders (user_id, placed_at DESC) WHERE status <> 'cancelled';
CREATE UNIQUE INDEX idx_users_active_email ON users (email) WHERE deleted_at IS NULL;

COMMENT ON TABLE users IS 'Application accounts';

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

INSERT INTO users (email, name, role, metadata)
VALUES
    ('ada@example.com',   'Ada Lovelace', 'admin',  '{"beta": true}'),
    ('grace@example.com', 'Grace Hopper', 'editor', '{}')
ON CONFLICT (email) DO UPDATE
    SET name = EXCLUDED.name,
        role = EXCLUDED.role
RETURNING id, email, role;

WITH monthly AS (
    SELECT
        u.id                                          AS user_id,
        u.name,
        date_trunc('month', o.placed_at)               AS month,
        SUM(o.total_cents) / 100.0                     AS revenue,
        COUNT(*)                                       AS order_count
    FROM users AS u
    INNER JOIN orders AS o ON o.user_id = u.id
    LEFT JOIN LATERAL (
        SELECT 1
    ) AS noop ON TRUE
    WHERE u.deleted_at IS NULL
      AND o.status = 'paid'
      AND o.placed_at >= now() - INTERVAL '12 months'
    GROUP BY u.id, u.name, month
    HAVING SUM(o.total_cents) > 0
),
ranked AS (
    SELECT
        m.*,
        RANK()       OVER (PARTITION BY m.month ORDER BY m.revenue DESC)  AS revenue_rank,
        LAG(m.revenue) OVER (PARTITION BY m.user_id ORDER BY m.month)     AS prev_revenue,
        ROUND(AVG(m.revenue) OVER (PARTITION BY m.user_id
                                   ORDER BY m.month
                                   ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS rolling_avg
    FROM monthly AS m
)
SELECT
    name,
    to_char(month, 'YYYY-MM')                            AS period,
    revenue,
    order_count,
    revenue_rank,
    COALESCE(revenue - prev_revenue, 0)                  AS delta,
    rolling_avg,
    CASE
        WHEN revenue_rank = 1 THEN 'top'
        WHEN revenue_rank <= 5 THEN 'high'
        ELSE 'normal'
    END                                                  AS tier
FROM ranked
WHERE revenue_rank <= 10
ORDER BY period DESC, revenue DESC
LIMIT 100 OFFSET 0;

UPDATE orders
   SET status = 'cancelled'
 WHERE placed_at < now() - INTERVAL '90 days'
   AND status = 'pending';

DELETE FROM users WHERE deleted_at < now() - INTERVAL '2 years';

COMMIT;
