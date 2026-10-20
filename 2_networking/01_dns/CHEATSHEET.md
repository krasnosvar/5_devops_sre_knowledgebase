# DNS — шпаргалка

Подробности и объяснения — в [dns.md](./01_theory/dns.md). ⚠️ — опасная
команда или частая ловушка.

## dig

| Задача | Команда |
| :--- | :--- |
| Спросить резолвер из `/etc/resolv.conf` | `dig www.example.com` |
| Только ответ | `dig +short www.example.com` |
| Ответ с TTL, без шума | `dig example.com +noall +answer` |
| Конкретный тип записи | `dig example.com MX` / `AAAA` / `TXT` / `NS` / `SOA` / `SRV` |
| Через конкретный резолвер | `dig @1.1.1.1 example.com` |
| Authoritative напрямую, мимо кэша | `dig @a.iana-servers.net example.com` |
| Кто authoritative для зоны | `dig +short NS example.com` |
| Вся цепочка от root | `dig +trace www.example.com` |
| Без рекурсии (что знает сам сервер) | `dig @<ns> example.com +norecurse` |
| По TCP | `dig +tcp example.com` |
| С DNSSEC-записями (RRSIG) | `dig +dnssec example.com` |
| Обратная зона (PTR) | `dig -x 8.8.8.8` |
| Проверка DNSSEC-цепочки | `delv example.com` |
| Что резолвит systemd-resolved | `resolvectl query example.com`, `resolvectl status` |
| Как резолвит libc (с `/etc/hosts`) | `getent hosts example.com` |

## Типы записей

| Тип | Что | Ловушка |
| :--- | :--- | :--- |
| `A` / `AAAA` | имя → IPv4 / IPv6 | — |
| `CNAME` | имя → другое имя | ⚠️ не сосуществует с другими записями; нельзя на apex зоны |
| `MX` | почта домена, с приоритетом | меньше число — выше приоритет |
| `TXT` | SPF/DKIM, верификация, ACME DNS-01 | — |
| `NS` | делегирование зоны | — |
| `SOA` | параметры зоны, negative TTL | — |
| `SRV` | имя+протокол → хост+порт | `_service._proto.name` |
| `PTR` | IP → имя | живёт в `in-addr.arpa` |
| `ALIAS` / `ANAME` | «CNAME на apex» | нестандарт, фича провайдера |

## Роли

| Роль | Пример | Что делает |
| :--- | :--- | :--- |
| Recursive resolver | 8.8.8.8, 1.1.1.1, systemd-resolved, CoreDNS | обходит дерево за клиента, кэширует |
| Authoritative | NS зоны (`ns1.example.com`) | отвечает только за свою зону, без рекурсии |
| Порядок обхода | `.` → `com.` → `example.com.` → `www` | каждый уровень знает только детей |

## TTL и миграция

| Шаг | Действие |
| :--- | :--- |
| 1 | Понизить TTL записи (например, 86400 → 60) |
| 2 | ⚠️ Ждать **старый** TTL — у резолверов в кэше запись со старым TTL |
| 3 | Сменить IP |
| 4 | Держать старый сервер, пока не истечёт новый TTL, затем вернуть TTL |

## Контейнеры и Kubernetes

| Задача | Команда / факт |
| :--- | :--- |
| Резолвер контейнера | `cat /etc/resolv.conf` (nameserver, `search`, `options ndots`) |
| Имя сервиса в k8s | `<svc>.<ns>.svc.cluster.local` → ClusterIP (CoreDNS) |
| Внешние имена из пода | CoreDNS проксирует во внешний резолвер (`forward`) |

## UDP и TCP

| Ситуация | Транспорт |
| :--- | :--- |
| Обычный запрос | UDP/53 |
| Ответ не влез (флаг `TC`) | повтор по TCP/53 |
| Передача зоны (AXFR) | TCP |
| Размер UDP-ответа | 512 байт классически, больше с EDNS0 |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| После смены IP часть клиентов на старом | TTL старой записи, кэш резолверов |
| `@8.8.8.8` не видит внутренний домен | зона не делегирована публично — спросить внутренний NS |
| `SERVFAIL` на подписанной зоне | DNSSEC-цепочка: `delv`, `dig +dnssec`, DS у родителя |
| `NXDOMAIN` | опечатка, нет записи, неверный `search` |
| Внутри пода резолвится, снаружи нет (или наоборот) | `resolv.conf` пода, CoreDNS `forward` |
| Большие ответы теряются | UDP + фрагментация, TCP/53 закрыт файрволом |

- ⚠️ DNSSEC даёт подлинность и целостность, но **не** шифрует ответ.

> Проверка: опции `dig` сверены с `dig -h` (BIND 9), `delv`, `resolvectl`
> есть локально; не проверено: —.
