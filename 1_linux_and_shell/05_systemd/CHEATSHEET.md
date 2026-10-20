# Systemd и journald — шпаргалка

Подробности и объяснения — в [systemd.md](./01_theory/systemd.md).
⚠️ — опасная команда или частая ловушка.

## systemctl: каждый день

| Задача | Команда |
| :--- | :--- |
| Статус + последние строки лога | `systemctl status nginx` |
| Старт / стоп / рестарт | `sudo systemctl start\|stop\|restart nginx` |
| Перечитать конфиг без рестарта | `sudo systemctl reload nginx` (если есть `ExecReload=`) |
| Включить в автозагрузку и сразу запустить | `sudo systemctl enable --now nginx` |
| Выключить из автозагрузки | `sudo systemctl disable --now nginx` |
| Запретить запуск совсем | `sudo systemctl mask nginx` (вернуть: `unmask`) |
| Упавшие юниты | `systemctl --failed` |
| Сбросить счётчик падений | `sudo systemctl reset-failed nginx` |
| Включён / активен (для скриптов) | `systemctl is-enabled nginx`, `systemctl is-active --quiet nginx` |
| Все сервисы | `systemctl list-units --type=service --state=running` |
| Установленные unit-файлы | `systemctl list-unit-files --type=service` |
| Итоговый unit со всеми drop-in | `systemctl cat nginx` |
| Значения свойств | `systemctl show nginx -p MainPID,Restart,MemoryMax,NRestarts` |
| Зависимости | `systemctl list-dependencies nginx` (`--reverse` — кто зависит) |
| Таймеры и следующий запуск | `systemctl list-timers --all` |

## Правка юнитов

| Задача | Команда |
| :--- | :--- |
| Override через drop-in | `sudo systemctl edit nginx` → `/etc/systemd/system/nginx.service.d/override.conf` |
| Полная копия юнита в `/etc` | `sudo systemctl edit --full nginx` |
| Откатить к версии из пакета | `sudo systemctl revert nginx` |
| После ручной правки файла | `sudo systemctl daemon-reload` ⚠️ иначе systemd не увидит изменения |
| Проверить unit-файл | `systemd-analyze verify ./myapp.service` |
| Оценка sandbox-защиты | `systemd-analyze security nginx` |
| Проверить `OnCalendar` | `systemd-analyze calendar 'Mon..Fri 09:00'` |

| Каталог | Чей | Приоритет |
| :--- | :--- | :--- |
| `/etc/systemd/system/` | админ, overrides | высший |
| `/run/systemd/system/` | runtime | средний |
| `/usr/lib/systemd/system/` (`/lib/...`) | пакеты | низший, перезаписывается при обновлении |

⚠️ В drop-in, чтобы заменить `ExecStart=`, сначала обнулите его пустой
строкой `ExecStart=`, затем задайте новое значение.

## Сервис: шаблон

```ini
[Unit]
Description=My app
Wants=network-online.target
After=network-online.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=app
ExecStart=/usr/local/bin/myapp
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535
MemoryMax=512M
CPUQuota=50%
EnvironmentFile=-/etc/myapp/env

[Install]
WantedBy=multi-user.target
```

| Директива | Значение |
| :--- | :--- |
| `Type=simple` (дефолт) | процесс из `ExecStart` и есть сервис |
| `Type=exec` | как `simple`, но «запущен» только после успешного `exec()` |
| `Type=forking` | легаси-демон уходит в фон; `PIDFile=` |
| `Type=oneshot` | выполнить и выйти (миграции, бэкап); `RemainAfterExit=yes` |
| `Type=notify` | сервис сам сообщает готовность (`sd_notify`) |
| `Restart=on-failure` / `always` | рестарт при ненулевом коде/сигнале / всегда |
| `MemoryMax=` | cgroup v2 `memory.max` ⚠️ `MemoryLimit=` — устаревший, v1 |
| `CPUQuota=50%` | cgroup v2 `cpu.max` |
| `TasksMax=` | `pids.max` |

## Зависимости

| Директива | Смысл |
| :--- | :--- |
| `Wants=` | мягкая: запустить вместе, падение B не мешает A |
| `Requires=` | жёсткая: B не стартовал → A не стартует; B явно остановлен → A тоже |
| `BindsTo=` | как `Requires=`, плюс A останавливается, если B упал |
| `After=` / `Before=` | только **порядок**, не зависимость |
| `WantedBy=multi-user.target` | куда «подвесить» при `enable` |

⚠️ `Requires=` без `After=` стартует оба параллельно.

| Target | Аналог runlevel |
| :--- | :--- |
| `multi-user.target` | 3 — серверы без GUI |
| `graphical.target` | 5 |
| `rescue.target` | 1 |
| `network-online.target` | сеть реально поднята (`network.target` — нет) |

| Задача | Команда |
| :--- | :--- |
| Target по умолчанию | `systemctl get-default` / `sudo systemctl set-default multi-user.target` |

## Timer вместо cron

```ini
# backup.timer (рядом backup.service с Type=oneshot)
[Timer]
OnCalendar=*-*-* 03:00:00
RandomizedDelaySec=10m
Persistent=true

[Install]
WantedBy=timers.target
```

| Задача | Команда |
| :--- | :--- |
| Включить таймер | `sudo systemctl enable --now backup.timer` |
| Запустить задачу сейчас | `sudo systemctl start backup.service` |
| Разовый запуск через 5 минут | `sudo systemd-run --on-active=5m /usr/local/bin/job.sh` |

| Опция | Смысл |
| :--- | :--- |
| `OnCalendar=` | по расписанию (`daily`, `hourly`, `Mon..Fri 09:00`) |
| `OnBootSec=` / `OnUnitActiveSec=` | через N после загрузки / после прошлого запуска |
| `Persistent=true` | догнать пропущенный запуск (сервер был выключен) |

## journalctl

| Задача | Команда |
| :--- | :--- |
| Логи сервиса | `journalctl -u nginx` |
| Хвост в реальном времени | `journalctl -u nginx -f` |
| Последние N строк, без пейджера | `journalctl -u nginx -n 100 --no-pager` |
| За период | `journalctl --since "1 hour ago"` / `--since "2026-10-15 10:00" --until "10:30"` |
| Только ошибки и хуже | `journalctl -p err -b` |
| Ядро (как dmesg) | `journalctl -k` |
| Прошлая загрузка | `journalctl -b -1` (список: `--list-boots`) |
| Поиск по тексту | `journalctl -u nginx -g 'timeout\|refused'` |
| По PID / бинарнику | `journalctl _PID=1234`, `journalctl /usr/sbin/sshd` |
| JSON для парсинга | `journalctl -u nginx -o json-pretty -n 1` |
| С пояснениями, перейти в конец | `journalctl -xeu nginx` |
| Сколько места | `journalctl --disk-usage` |
| Очистить ⚠️ | `sudo journalctl --vacuum-time=7d` / `--vacuum-size=500M` |

⚠️ Постоянное хранение: `Storage=persistent` в `journald.conf` или
существующий `/var/log/journal/`; иначе журнал в `/run` и пропадает при
перезагрузке. Лимит: `SystemMaxUse=`.

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Сервис в `failed` | `systemctl status`, `journalctl -xeu <svc>` |
| `start-limit-hit` | `StartLimitBurst`/`StartLimitIntervalSec`; `reset-failed` |
| Правка юнита «не применилась» | `daemon-reload`, `systemctl cat` — какой drop-in победил |
| `Too many open files` у демона | `LimitNOFILE=` в юните, не `limits.conf` |
| Сервис стартует раньше БД | нет `After=` |
| Таймер не срабатывает | `systemctl list-timers`, `systemd-analyze calendar` |

> Проверка: шаблоны `myapp.service`, `backup.service`/`backup.timer`
> прошли `systemd-analyze verify` (кроме ожидаемого «postgresql.service
> not found»), `systemd-analyze calendar` и флаги `systemctl`/`journalctl`
> сверены с `--help` (systemd 259); не проверено: команды, меняющие
> состояние (`enable`, `edit`, `vacuum`, `systemd-run --on-active`).
