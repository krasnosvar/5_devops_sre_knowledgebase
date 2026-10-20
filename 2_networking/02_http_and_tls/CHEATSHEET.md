# HTTP и TLS — шпаргалка

Подробности и объяснения — в
[http_and_tls.md](./01_theory/http_and_tls.md). ⚠️ — опасная команда или
частая ловушка.

## curl

| Задача | Команда |
| :--- | :--- |
| Только заголовки | `curl -I https://example.com` |
| Подробно: TLS, заголовки запроса/ответа | `curl -v https://example.com -o /dev/null` |
| Следовать редиректам | `curl -L https://example.com` |
| Проверить HTTP/2 | `curl -I --http2 https://example.com` |
| Проверить HTTP/3 (если curl собран с QUIC) | `curl -I --http3 https://example.com` |
| Отправить заголовок | `curl -H 'Host: app.local' http://10.0.0.5/` |
| Подставить IP без DNS (SNI сохраняется) | `curl --resolve example.com:443:10.0.0.5 https://example.com` |
| Своя CA для проверки | `curl --cacert ca.pem https://internal.local` |
| Не проверять сертификат ⚠️ (только отладка) | `curl -k https://...` |
| Таймаут целиком | `curl -m 5 https://...` |
| Тайминги по фазам | `curl -so /dev/null -w 'dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total}\n' https://example.com` |
| Код ответа и версия HTTP | `curl -so /dev/null -w '%{http_code} %{http_version}\n' https://...` |
| Проверить ревалидацию | `curl -I -H 'If-None-Match: "<etag>"' https://...` → `304` |

## openssl

| Задача | Команда |
| :--- | :--- |
| Хендшейк и цепочка | `openssl s_client -connect example.com:443 -servername example.com </dev/null` |
| Кратко: протокол, шифр | `openssl s_client -connect example.com:443 -brief </dev/null` |
| Только TLS 1.3 | `openssl s_client -connect example.com:443 -tls1_3 </dev/null` |
| Все сертификаты цепочки | `openssl s_client -connect example.com:443 -showcerts </dev/null` |
| Согласованный ALPN (h2?) | `openssl s_client -connect example.com:443 -alpn h2 </dev/null 2>/dev/null \| grep ALPN` |
| Срок, subject, issuer с сервера | `openssl s_client -connect example.com:443 </dev/null 2>/dev/null \| openssl x509 -noout -dates -subject -issuer` |
| SAN сертификата | `openssl x509 -in cert.pem -noout -ext subjectAltName` |
| Истекает в ближайшие 30 дней? | `openssl x509 -in cert.pem -noout -checkend 2592000` (код 1 — да) |
| Проверить цепочку локально | `openssl verify -CAfile ca.pem -untrusted intermediate.pem cert.pem` |
| Self-signed для лабы | `openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 365 -subj '/CN=app.local' -addext 'subjectAltName=DNS:app.local'` |

## Версии HTTP

| | HTTP/1.1 | HTTP/2 | HTTP/3 |
| :--- | :--- | :--- | :--- |
| Транспорт | TCP | TCP | QUIC поверх UDP |
| Параллелизм | keep-alive, запросы по очереди; браузер — 6–8 соединений | мультиплексирование потоков в одном соединении | потоки независимы |
| HoL blocking | на уровне HTTP | на уровне TCP (потеря сегмента стопорит все потоки) | только в потерявшем пакет потоке |
| TLS | отдельный слой | отдельный слой | встроен в QUIC |

## TLS 1.3 и сертификаты

| Факт | Значение |
| :--- | :--- |
| Хендшейк TLS 1.3 | 1 RTT: ClientHello (keyshare) → ServerHello + cert → Finished |
| Асимметрия | только для обмена ключом (ECDHE); трафик — симметричный (AES-GCM / ChaCha20) |
| Цепочка | leaf ← intermediate ← root (root в trust store ОС/браузера) |
| DV / OV / EV | проверка домена / организации / строгая юрпроверка; шифрование одинаковое |
| SNI | имя хоста в ClientHello — по нему сервер выбирает сертификат |

## Кэширование

| Заголовок | Эффект |
| :--- | :--- |
| `Cache-Control: max-age=3600` | час без запроса к серверу |
| `ETag` + `If-None-Match` | `304 Not Modified` без тела: экономит трафик, не RTT |
| `Cache-Control: no-cache` | кэшировать можно, но ревалидировать каждый раз |
| `Cache-Control: no-store` | не сохранять вообще (чувствительные данные) |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `certificate not trusted` у внутреннего сайта | корневой CA компании не в trust store клиента |
| `unable to get local issuer certificate` | сервер не отдаёт intermediate: `-showcerts` |
| Не тот сертификат | нет SNI: добавить `-servername`, проверить vhost |
| `certificate has expired` | `openssl x509 -noout -dates`, автообновление (ACME) |
| Медленно, но сервер быстрый | `curl -w` — какая фаза: DNS, TCP, TLS или TTFB |

- ⚠️ `curl -k` в скриптах прячет реальную ошибку цепочки — только для отладки.
- ⚠️ `304` — запрос всё равно дошёл до сервера.

> Проверка: флаги `curl --help all` и `openssl s_client`/`x509 -help`
> (OpenSSL 3.5), запуск `req`/`x509`/`-alpn`, `curl -w` и `--http3` (curl с
> ngtcp2); не проверено: —.
