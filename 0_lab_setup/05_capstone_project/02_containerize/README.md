# Шаг 2 — контейнеризация

🐳 Tier 1. Теория — [3_containers](../../../3_containers/) (image layers, multi-stage,
non-root, compose patterns — всё это уже применено в
[../app/Dockerfile](../app/Dockerfile)).

## Собрать и поднять

```bash
docker compose up --build
```

## Проверить

```bash
curl -s http://localhost:8000/health
curl -s -X POST http://localhost:8000/shorten -d '{"url":"https://example.com"}'
docker compose logs -f shortener   # сравни с journalctl на шаге 1
```

## Что почувствовать на этом шаге

- `docker images shortener` — посмотри размер образа и слои
  (`docker history shortener-shortener`), сверься с
  [3_containers/02_image_layers](../../../3_containers/02_image_layers/).
- `docker compose exec shortener whoami` — не root, см. `USER appuser`
  в Dockerfile ([3_containers/05_security](../../../3_containers/05_security/)).
- Redis и приложение изолированы (свой network namespace), но подняты
  одной командой на одной машине — это всё ещё не кластер: убьёшь docker
  compose — упадёт всё сразу. Дальше (шаг 3) — реальная оркестрация.

```bash
docker compose down
```
