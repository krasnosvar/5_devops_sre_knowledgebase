# Упражнения — OSI и TCP/IP

Стенд: 🐳 Tier 1 — два контейнера в одной Docker-сети

```bash
docker network create netlab
docker run -d --name server --network netlab --cap-add=NET_ADMIN nicolaka/netshoot sleep infinity
docker run -d --name client --network netlab --cap-add=NET_ADMIN nicolaka/netshoot sleep infinity
```

## 01 — Захватить TCP handshake

**Задача:** Запустить `nc -l` на сервере, подключиться с клиента, захватить SYN/SYN-ACK/ACK через tcpdump.

```bash
docker exec server nc -l -p 8080 &
docker exec server tcpdump -i any -n 'tcp port 8080' -c 6 &
docker exec client nc -zv server 8080
# TODO: разбери вывод tcpdump — найди SYN, SYN-ACK, ACK по флагам [S], [S.], [.]
```

## 02 — TCP vs UDP: разница в поведении при потере пакета

**Задача:** Сравнить поведение TCP и UDP при искусственной потере пакетов (`tc netem`).

```bash
# Внести 30% потерь на клиенте
docker exec client tc qdisc add dev eth0 root netem loss 30%

# TCP: должен пройти (с ретрансмитами), просто медленнее
docker exec client sh -c "time nc -zv server 8080"

# UDP: часть "сообщений" просто не долетит
docker exec server nc -u -l -p 9090 &
for i in $(seq 1 10); do docker exec client sh -c "echo msg-$i | nc -u -w1 server 9090"; done
# TODO: сравни сколько msg-N реально дошло на сервер
```

## 03 — Port exhaustion

**Задача:** Смоделировать исчерпание эфемерных портов и увидеть реальную ошибку.

```bash
docker exec client sysctl net.ipv4.ip_local_port_range
# TODO: временно сузь диапазон (net.ipv4.ip_local_port_range = 32768 32770 — всего 3 порта)
docker exec client sysctl -w net.ipv4.ip_local_port_range="32768 32770"

# Попробуй открыть 10 параллельных соединений к серверу
for i in $(seq 1 10); do docker exec client nc -zv server 8080 & done; wait
# TODO: с какого соединения начнутся ошибки "Cannot assign requested address"?
```
