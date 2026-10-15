# Ответы — упражнение 07 (три сломанных VM)

Не подглядывайте, пока сами не попробовали `journalctl`/`top`/`curl`.
Упражнения 01–06 — в [answers.md](./answers.md). Условие —
[03_exercises/README.md](../03_exercises/README.md).

## Упражнение 7 — Troubleshooting: три сломанных VM

Стенд поднимается из `02_examples/broken/`, на каждую VM заходим по SSH из
`terraform output ssh_commands`. Ниже — три кейса по очереди.

### broken-logs

```bash
systemctl status myapp --no-pager
journalctl -u myapp -n 5 --no-pager
ls -l /var/log/myapp.log
grep -E '^(User|ExecStart)=' /etc/systemd/system/myapp.service
sudo chown myapp:myapp /var/log/myapp.log
sleep 6
sudo tail -n 2 /var/log/myapp.log
```

Ожидаемый вывод (примерно так):

```text
● myapp.service - Demo app that logs a heartbeat every 5s
     Active: active (running) since ...
... myapp.sh[812]: /usr/local/bin/myapp.sh: line 3: /var/log/myapp.log: Permission denied
-rw------- 1 root root 0 ... /var/log/myapp.log
User=myapp
ExecStart=/usr/local/bin/myapp.sh
2026-10-14T10:00:05+00:00 heartbeat ok
2026-10-14T10:00:10+00:00 heartbeat ok
```

Почему так: сервис не падает — неудачный `>>` в bash не завершает цикл,
он просто пишет `Permission denied` в journal каждые 5 секунд. Файл
принадлежит `root` с правами `0600`, а юнит работает от `User=myapp`.
Чиним владельца файла, скрипт не трогаем; рестарт не нужен — скрипт
открывает файл заново на каждой итерации.

### broken-cpu

```bash
ps aux --sort=-%cpu | head -n 3
systemctl status worker --no-pager
cat /usr/local/bin/worker.py
sudo sed -i -e '1a import time' -e '/total += 1/a\    time.sleep(1)' \
  /usr/local/bin/worker.py
cat /usr/local/bin/worker.py
sudo systemctl restart worker
ps aux --sort=-%cpu | head -n 3
```

Ожидаемый вывод (примерно так):

```text
USER  PID %CPU %MEM ... COMMAND
root  701 99.8  0.4 ... /usr/bin/python3 /usr/local/bin/worker.py
...
#!/usr/bin/env python3
import time
# Воркер должен раз в секунду агрегировать метрики и спать.
...
while True:
    total += 1
    time.sleep(1)
USER  PID %CPU %MEM ... COMMAND
root 1032  0.0  0.4 ... /usr/bin/python3 /usr/local/bin/worker.py
```

Почему так: busy loop без `sleep` занимает ядро на 100%. В исходном
скрипте нет `import time` — если добавить только `time.sleep(1)`, воркер
упадёт с `NameError` и уйдёт в цикл рестартов (`Restart=always`), поэтому
импорт добавляем той же командой.

### broken-504

```bash
curl -si http://localhost/ping | head -n 1
sudo tail -n 1 /var/log/nginx/error.log
curl -s -m 3 http://127.0.0.1:8080/ping; echo "exit=$?"
grep -n 'sleep' /usr/local/bin/backend.py
sudo sed -i '/time.sleep(60)/d' /usr/local/bin/backend.py
sudo systemctl restart backend
curl -si http://localhost/ping | head -n 1
```

Ожидаемый вывод (примерно так):

```text
HTTP/1.1 504 Gateway Time-out
... upstream timed out (110: Connection timed out) while reading response
header from upstream, ... upstream: "http://127.0.0.1:8080/ping"
exit=28
9:        time.sleep(60)
HTTP/1.1 200 OK
```

Почему так: nginx ждёт ответа бэкенда `proxy_read_timeout 5s`, а бэкенд
спит 60 секунд — отсюда 504. Прямой `curl` на `:8080` тоже висит (exit 28 —
таймаут curl), значит проблема в бэкенде, а не в nginx. Правильный фикс —
убрать debug-задержку; поднимать `proxy_read_timeout` значит спрятать
проблему. Бэкенд однопоточный (`HTTPServer`), поэтому после фикса первые
запросы могут ещё постоять в очереди за старыми — рестарт это сбрасывает.

После всех трёх кейсов — выйти с VM и удалить стенд из `02_examples/broken/`:

```bash
terraform destroy
```
