# systemd

## Что такое systemd

systemd — система инициализации (PID 1) и менеджер сервисов.
Заменяет SysVinit и Upstart. Стандарт для RHEL, Fedora, Debian, Ubuntu, Arch.

```bash
systemctl list-units --type=service --state=running   # запущенные сервисы
systemctl list-units --type=service --state=failed    # упавшие

systemctl status nginx
systemctl start|stop|restart|reload nginx
systemctl enable nginx    # автозапуск при загрузке
systemctl disable nginx
systemctl is-enabled nginx
systemctl is-active nginx
```

## Unit файлы

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application
Documentation=https://github.com/org/myapp
After=network.target postgresql.service    # запуск после
Requires=postgresql.service               # жёсткая зависимость (упадёт вместе)
Wants=redis.service                        # мягкая зависимость

[Service]
Type=simple                  # exec | forking | oneshot | notify | idle
User=myapp
Group=myapp
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/myapp --config /etc/myapp/config.yaml
ExecStop=/bin/kill -TERM $MAINPID
ExecReload=/bin/kill -HUP $MAINPID

# Автоперезапуск
Restart=on-failure
RestartSec=5s
StartLimitInterval=60s
StartLimitBurst=3           # максимум 3 рестарта за 60 сек

# Environment
Environment=ENV=production
EnvironmentFile=-/etc/myapp/.env    # "-" = игнорировать если файла нет

# Безопасность (sandboxing)
NoNewPrivileges=yes
PrivateTmp=yes              # изолированный /tmp
ProtectSystem=strict        # /usr, /boot, /etc read-only
ReadWritePaths=/var/lib/myapp /var/log/myapp
CapabilityBoundingSet=      # убрать все capabilities
AmbientCapabilities=        # если нужно добавить конкретные

# Ресурсные лимиты
LimitNOFILE=65536           # максимум открытых fd
MemoryMax=512M              # cgroup memory limit
CPUQuota=50%                # cgroup cpu limit

[Install]
WantedBy=multi-user.target
```

```bash
# после создания/изменения unit файла
systemctl daemon-reload
systemctl enable --now myapp
```

## Типы сервисов (Type=)

**simple** (default) — ExecStart запускает основной процесс. systemd считает
сервис запущенным сразу. Не знает когда приложение готово.

**notify** — приложение уведомляет systemd о готовности через `sd_notify(READY=1)`.
Зависимые сервисы ждут этого уведомления.

**forking** — ExecStart запускает процесс который делает fork и завершается.
Основной процесс — потомок. Требует `PIDFile=`.

**oneshot** — ExecStart запускает задачу и завершается. Хорошо для скриптов.

## journald — логирование

```bash
# все логи
journalctl

# логи конкретного сервиса
journalctl -u nginx
journalctl -u nginx -f          # follow (как tail -f)
journalctl -u nginx --since "1 hour ago"
journalctl -u nginx --since "2024-01-15 10:00:00"

# по приоритету
journalctl -u myapp -p err      # только ошибки
journalctl -u myapp -p warning  # warning и выше

# JSON формат (для парсинга)
journalctl -u myapp -o json | jq .

# размер журнала
journalctl --disk-usage
journalctl --vacuum-size=500M   # ограничить размер
journalctl --vacuum-time=30d    # удалить старше 30 дней

# логи текущей загрузки
journalctl -b
journalctl -b -1                # предыдущая загрузка

# логи ядра
journalctl -k
dmesg                           # альтернатива
```

## Targets — аналог runlevels

```
poweroff.target     ← runlevel 0
rescue.target       ← runlevel 1 (single user)
multi-user.target   ← runlevel 3 (без GUI)
graphical.target    ← runlevel 5 (с GUI)
reboot.target       ← runlevel 6
```

```bash
systemctl get-default           # текущий default target
systemctl set-default multi-user.target
systemctl isolate rescue.target # немедленно перейти (без перезагрузки)
```

## cgroup дерево через systemd

systemd организует все сервисы в cgroup иерархию:

```
/sys/fs/cgroup/
├── system.slice/           ← системные сервисы
│   ├── nginx.service/
│   ├── postgresql.service/
│   └── docker.service/
├── user.slice/             ← пользовательские сессии
│   └── user-1000.slice/
└── machine.slice/          ← виртуальные машины (libvirt)
```

```bash
# посмотреть дерево
systemd-cgls

# ресурсы по slice
systemd-cgtop

# лимиты конкретного сервиса
systemctl show nginx | grep -E 'Memory|CPU|Limit'
cat /sys/fs/cgroup/system.slice/nginx.service/memory.max
```

## Связь с k8s

В k8s кластере kubelet запускается как systemd сервис.
Контейнеры попадают в cgroup иерархию управляемую systemd:

```
/sys/fs/cgroup/system.slice/containerd.service/
└── kubepods/
    ├── besteffort/
    ├── burstable/
    └── guaranteed/
        └── pod-uuid/
            └── container-id/
```

systemd `LimitNOFILE` kubelet влияет на лимит fd всех контейнеров на ноде.
Типичная проблема: слишком низкий `LimitNOFILE` у kubelet → pods падают с "too many open files".
