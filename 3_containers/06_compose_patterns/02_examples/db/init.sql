-- Выполняется postgres-образом один раз, при первой инициализации пустого
-- volume pgdata (каталог /docker-entrypoint-initdb.d)
CREATE TABLE IF NOT EXISTS healthcheck_demo (
    id         serial PRIMARY KEY,
    created_at timestamptz NOT NULL DEFAULT now()
);
