#!/usr/bin/env bash
# Ответы: упражнение 07 — troubleshooting трёх сломанных VM
# Не подглядывай, пока сам не попробовал journalctl/top/curl.

# ── broken-logs ──────────────────────────────────────────────────────────────
# Симптом: myapp.service постоянно рестартует, лог пустой.
#
#   systemctl status myapp
#   journalctl -u myapp -n 20 --no-pager
#
# В логе: "Permission denied" при попытке дописать /var/log/myapp.log —
# файл создан от root с правами 0600, а сервис работает от User=myapp
# (см. /etc/systemd/system/myapp.service). Правим владельца, не скрипт:
#
#   sudo chown myapp:myapp /var/log/myapp.log
#   sudo systemctl restart myapp
#   sudo tail -f /var/log/myapp.log   # heartbeat пошёл

# ── broken-cpu ───────────────────────────────────────────────────────────────
# Симптом: один процесс жрёт 100% одного ядра.
#
#   top -o %CPU            # или: ps aux --sort=-%cpu | head
#   systemctl status worker
#   cat /usr/local/bin/worker.py
#
# В коде — бесконечный while-цикл без time.sleep(), должен был раз в секунду
# агрегировать метрики и засыпать. Правим скрипт и перезапускаем сервис:
#
#   sudo sed -i '/total += 1/a\    time.sleep(1)' /usr/local/bin/worker.py
#   sudo systemctl restart worker
#   top -o %CPU            # CPU worker.py упал до ~0%

# ── broken-504 ───────────────────────────────────────────────────────────────
# Симптом: curl http://localhost/ping виснет на 5с и возвращает 504.
#
#   curl -i http://localhost/ping                 # 504 после ~5с
#   sudo tail -n 20 /var/log/nginx/error.log       # "upstream timed out"
#   curl -m 3 http://127.0.0.1:8080/ping           # тоже висит — бэкенд, не nginx
#   cat /usr/local/bin/backend.py                  # видим time.sleep(60)
#
# Корень проблемы — в backend.py оставили debug-задержку под "медленную"
# внешнюю зависимость. Правильный фикс — убрать/сократить sleep в самом
# бэкенде (не поднимать proxy_read_timeout — это просто спрячет проблему):
#
#   sudo sed -i 's/time.sleep(60)/time.sleep(0)/' /usr/local/bin/backend.py
#   sudo systemctl restart backend
#   curl -i http://localhost/ping                  # 200 pong

# ── бонус: упражнение 05 (масштабирование кластера без replace) ─────────────
# count у workers индексируется с 0..N-1: увеличение worker_count только
# ДОБАВЛЯЕТ новые индексы в конец списка, terraform plan не трогает
# уже существующие k8s-worker-1/2 — replace не будет:
#
#   terraform apply -var="master_count=1" -var="worker_count=3"
