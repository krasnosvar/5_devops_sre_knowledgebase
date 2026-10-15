# Упражнения — OSI и TCP/IP

Стенд: 🐳 Tier 1 — два контейнера в одной Docker-сети

```bash
docker network create netlab
docker run -d --name server --network netlab --cap-add=NET_ADMIN nicolaka/netshoot sleep infinity
docker run -d --name client --network netlab --cap-add=NET_ADMIN nicolaka/netshoot sleep infinity
```

## 01 — Захватить TCP handshake

**Задача:** Запустить `nc -l` на сервере, подключиться с клиента, захватить
SYN/SYN-ACK/ACK через tcpdump.

```bash
docker exec server tcpdump -i any -n 'tcp port 8080' -c 6 &
docker exec server nc -l -p 8080 &
sleep 1   # дать tcpdump и nc успеть стартовать
docker exec client nc -zv server 8080
# TODO: разбери вывод tcpdump — найди SYN, SYN-ACK, ACK по флагам [S], [S.], [.]
```

## 02 — TCP vs UDP: разница в поведении при потере пакета

**Задача:** Сравнить поведение TCP и UDP при искусственной потере пакетов
(`tc netem`).

```bash
# Слушатели на сервере. -k: не завершаться после первого соединения/датаграммы
# (без -k UDP-слушатель nc "прилипает" к первому отправителю и остальные
# датаграммы с других портов игнорирует)
docker exec -d server nc -k -l -p 8080
docker exec -d server sh -c 'nc -k -u -l -p 9090 > /tmp/udp.txt'

# Внести 30% потерь на клиенте (исходящий трафик eth0)
docker exec client tc qdisc add dev eth0 root netem loss 30%

# TCP: должен пройти (с ретрансмитами), просто медленнее
docker exec client sh -c "time nc -zv server 8080"

# UDP: часть "сообщений" просто не долетит
for i in $(seq 1 10); do docker exec client sh -c "echo msg-$i | nc -u -w1 server 9090"; done
docker exec server cat /tmp/udp.txt
# TODO: сравни сколько msg-N реально дошло на сервер

# Убрать потери после эксперимента
docker exec client tc qdisc del dev eth0 root
```

## 03 — Port exhaustion

**Задача:** Смоделировать исчерпание эфемерных портов и увидеть реальную
ошибку.

`/proc/sys` внутри обычного контейнера смонтирован read-only, поэтому
`sysctl -w` через `docker exec` не сработает. Сетевые sysctl задаются при
создании контейнера флагом `--sysctl` — заведём отдельный клиент с диапазоном
всего из 3 портов:

```bash
docker run -d --name client-narrow --network netlab \
  --sysctl net.ipv4.ip_local_port_range="32768 32770" \
  nicolaka/netshoot sleep infinity
docker exec client-narrow sysctl net.ipv4.ip_local_port_range

# Слушатель из упражнения 02 (nc -k на 8080) должен быть запущен.
# Попробуй открыть 10 соединений к серверу подряд
for i in $(seq 1 10); do docker exec client-narrow nc -zv -w2 server 8080; done
docker exec client-narrow ss -tan
# TODO: с какого соединения начнутся ошибки "Address not available"
# (в glibc-утилитах тот же errno EADDRNOTAVAIL пишется как
# "Cannot assign requested address")? В каком состоянии занятые порты?
```

## Уборка

```bash
docker rm -f server client client-narrow
docker network rm netlab
```
