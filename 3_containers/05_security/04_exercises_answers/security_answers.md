# Ответы — упражнения Container Security

Упражнения: [03_exercises/README.md](../03_exercises/README.md).

## Упражнение 01 — Drop capabilities и non-root

Сначала — сколько capabilities контейнер получает по умолчанию:

```bash
docker run --rm alpine sh -c "cat /proc/1/status | grep Cap"
```

Ожидаемый вывод (примерно так):

```text
CapInh:	0000000000000000
CapPrm:	00000000a80425fb
CapEff:	00000000a80425fb
CapBnd:	00000000a80425fb
CapAmb:	0000000000000000
```

Расшифровать маску: `capsh --decode=00000000a80425fb` (пакет `libcap`).
Дальше — `--cap-drop ALL` и добавлять по одному, глядя в `docker logs`:

```bash
docker run -d --name nginx-caps --cap-drop ALL -p 8080:80 nginx:alpine
docker logs nginx-caps
docker rm -f nginx-caps

docker run -d --name nginx-caps \
  --cap-drop ALL \
  --cap-add CHOWN --cap-add SETUID --cap-add SETGID \
  --security-opt no-new-privileges \
  -p 8080:80 \
  nginx:alpine
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080
docker rm -f nginx-caps
```

Ожидаемый вывод (примерно так):

```text
nginx: [emerg] chown("/var/cache/nginx/client_temp", 101) failed (1: Operation not permitted)
200
```

Почему так: master-процесс nginx стартует от root, делает `chown` временных
каталогов на пользователя `nginx` (UID 101) — нужен `CHOWN`, затем worker'ы
переходят на UID 101 через `setgid`/`setuid` — нужны `SETGID`/`SETUID` (без
них master жив, но в логах `setuid(101) failed`). `NET_BIND_SERVICE` не
нужен: Docker выставляет в контейнере `net.ipv4.ip_unprivileged_port_start=0`.

Вариант без root и вообще без capabilities — образ, который сразу работает от
UID 101 и слушает 8080. Он пишет pid и временные файлы в `/tmp`:

```bash
docker run -d --name nginx-unpriv \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --read-only \
  --tmpfs /tmp:size=10m \
  -p 8081:8080 \
  nginxinc/nginx-unprivileged:alpine
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8081
docker rm -f nginx-unpriv
```

Ожидаемый вывод (примерно так):

```text
200
```

Почему так: процессу без root capabilities не нужны вовсе — порт > 1024, смена
UID не требуется. Это и есть лучшая практика: non-root образ + `--cap-drop
ALL`.

## Упражнение 02 — Read-only filesystem

```bash
docker run --rm --read-only nginx:alpine
docker run --rm nginx:alpine sh -c "nginx -V 2>&1 | tr ' ' '\n' | grep -i path"

docker run -d --name nginx-ro --read-only \
  --tmpfs /var/cache/nginx \
  --tmpfs /var/run \
  -p 8080:80 \
  nginx:alpine
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080
docker rm -f nginx-ro
```

Ожидаемый вывод (примерно так):

```text
nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (30: Read-only file system)
--pid-path=/run/nginx.pid
--http-client-body-temp-path=/var/cache/nginx/client_temp
--http-proxy-temp-path=/var/cache/nginx/proxy_temp
...
200
```

Почему так: nginx пишет только временные файлы (`/var/cache/nginx/*_temp`) и
pid-файл (`/run`, в Alpine `/var/run` — симлинк на него). Логи в официальном
образе — симлинки на stdout/stderr, их писать в rootfs не нужно. Скрипты
entrypoint, которые правят `default.conf`, при read-only rootfs просто
пропускают правку.

## Упражнение 03 — Trivy сканирование

```bash
trivy image --severity HIGH,CRITICAL nginx:latest
trivy image --severity HIGH,CRITICAL ubuntu:20.04
trivy image --severity HIGH,CRITICAL alpine:3.18
```

Ожидаемый вывод (примерно так, конкретные числа меняются каждый день вместе
с базой уязвимостей):

```text
nginx:latest (debian 12.x)
Total: NN (HIGH: NN, CRITICAL: N)
...
ubuntu:20.04 (ubuntu 20.04)
Total: NN (HIGH: NN, CRITICAL: N)
...
alpine:3.18 (alpine 3.18.x)
Total: N (HIGH: N, CRITICAL: N)
```

Почему так: число CVE пропорционально числу пакетов и возрасту образа.
Минимальный образ (alpine, distroless, scratch) почти всегда чище, а
устаревший релиз дистрибутива (ubuntu 20.04, alpine 3.18 после окончания
поддержки) копит неисправленные CVE. Для базового образа выбирайте
минимальный и поддерживаемый, с закреплённым тегом/digest, и регулярно
пересобирайте.

## Упражнение 04 — Dockerfile hardening

Исправленный Dockerfile —
[Dockerfile.fixed](./Dockerfile.fixed). Проверка:

```bash
docker run --rm -i hadolint/hadolint < bad.Dockerfile
cp Dockerfile.fixed good.Dockerfile
docker run --rm -i hadolint/hadolint < good.Dockerfile
trivy config good.Dockerfile
```

Ожидаемый вывод (примерно так, для `bad.Dockerfile`):

```text
-:1 DL3007 warning: Using latest is prone to errors if the image will ever update.
-:2 DL3015 info: Avoid additional packages by specifying `--no-install-recommends`
-:2 DL3009 info: Delete the apt lists (/var/lib/apt/lists) after installing something
-:3 DL3064 warning: Potentially sensitive data should not be used in the `ARG` or `ENV` commands
-:6 DL3042 warning: Avoid use of cache directory with pip.
-:6 DL3003 warning: Use WORKDIR to switch to a directory
```

Для `good.Dockerfile` остаются только мелкие замечания (например, DL3008 —
не закреплены версии apt-пакетов).

Почему так: основные проблемы исходника — плавающий тег `latest`, секрет в
`ARG`/`ENV` (виден в `docker history`/`docker inspect`), лишние порты (SSH,
PostgreSQL), запуск от root, нет `--no-install-recommends` и очистки кэшей,
`COPY . .` до установки зависимостей (ломает кэш слоёв). Секреты передаются
при запуске (`-e`, secrets оркестратора) или через `RUN --mount=type=secret`.
