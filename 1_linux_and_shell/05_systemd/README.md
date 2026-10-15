# 05. Systemd

## Зачем
На любой Linux-ноде сервисы (kubelet, containerd, sshd, ваше
приложение) запускает и перезапускает systemd, а логи собирает journald.
Тема нужна, чтобы писать unit-файлы, понимать зависимости и порядок
запуска, заменить cron таймерами и быстро находить причину падения
сервиса.

## Пререквизиты
- [01_process_model](../01_process_model/) — сигналы, жизненный цикл
  процесса.
- [02_cgroups_and_namespaces](../02_cgroups_and_namespaces/) — systemd
  раскладывает сервисы по cgroup (slices/scopes).
- Стенд: Linux VM с systemd как PID 1 (🖥 Tier 2; в обычном Docker-
  контейнере systemd нет).

## Файлы
- [01_theory/systemd.md](./01_theory/systemd.md) — юниты и их типы,
  зависимости и targets, timers, journald.
- [02_examples/myapp.service](./02_examples/myapp.service) — unit-файл с
  рестартами, лимитами и sandboxing; инструкция установки — в комментарии.
- Без отдельных упражнений: закрепляйте, устанавливая и ломая пример.

## Как проходить
1. Прочитать теорию.
2. Установить `myapp.service` по инструкции из файла, посмотреть
   `systemctl status`, `journalctl -u myapp`, `systemd-cgls`.
3. Ответить на Interview Q&A без подсказки.

## Когда двигаться дальше
- можете написать unit-файл с `Restart=on-failure` и объяснить
  `After=` vs `Requires=`/`Wants=`;
- можете заменить cron-задачу systemd timer'ом;
- можете найти логи упавшего сервиса за последнюю загрузку через journalctl.

Дальше: [06_networking_basics](../06_networking_basics/).
