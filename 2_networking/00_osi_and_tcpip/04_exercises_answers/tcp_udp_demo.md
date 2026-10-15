# Ответы — упражнения OSI и TCP/IP

Стенд из [03_exercises/README.md](../03_exercises/README.md) уже поднят
(сеть `netlab`, контейнеры `server` и `client`).

## Упражнение 01 — Захватить TCP handshake

```bash
docker exec server tcpdump -i any -n 'tcp port 8080' -c 6 &
docker exec server nc -l -p 8080 &
sleep 1
docker exec client nc -zv server 8080
wait   # дождаться, пока tcpdump поймает 6 пакетов и завершится
```

Ожидаемый вывод (примерно так, адреса и seq будут другими):

```text
Connection to server (172.19.0.2) 8080 port [tcp/http-alt] succeeded!
eth0  In  IP 172.19.0.3.33564 > 172.19.0.2.8080: Flags [S], seq 2399694877, ...
eth0  Out IP 172.19.0.2.8080 > 172.19.0.3.33564: Flags [S.], seq 490548714, ack 2399694878, ...
eth0  In  IP 172.19.0.3.33564 > 172.19.0.2.8080: Flags [.], ack 1, ...
eth0  In  IP 172.19.0.3.33564 > 172.19.0.2.8080: Flags [F.], seq 1, ack 1, ...
eth0  Out IP 172.19.0.2.8080 > 172.19.0.3.33564: Flags [F.], seq 1, ack 2, ...
eth0  In  IP 172.19.0.3.33564 > 172.19.0.2.8080: Flags [.], ack 2, ...
```

Почему так: `[S]` — SYN от клиента, `[S.]` — SYN-ACK сервера (ack = seq
клиента + 1), `[.]` — финальный ACK, handshake завершён. Следующие три
пакета — закрытие (`[F.]` = FIN+ACK): `nc -z` сразу закрывает соединение.
tcpdump по умолчанию показывает относительные seq/ack после первого пакета.

## Упражнение 02 — TCP vs UDP: разница в поведении при потере пакета

```bash
docker exec -d server nc -k -l -p 8080
docker exec -d server sh -c 'nc -k -u -l -p 9090 > /tmp/udp.txt'
docker exec client tc qdisc add dev eth0 root netem loss 30%

docker exec client sh -c "time nc -zv server 8080"

for i in $(seq 1 10); do docker exec client sh -c "echo msg-$i | nc -u -w1 server 9090"; done
docker exec server cat /tmp/udp.txt

docker exec client tc qdisc del dev eth0 root
```

Ожидаемый вывод (примерно так, число и номера дошедших msg-N случайны):

```text
Connection to server (172.19.0.2) 8080 port [tcp/http-alt] succeeded!
real    0m 1.01s
msg-1
msg-3
msg-4
msg-6
msg-7
msg-9
```

Почему так: TCP-соединение в итоге устанавливается всегда — если SYN или
ACK потерялся, ядро клиента повторит его по таймеру ретрансмиссии (первый
RTO для SYN — 1 с), поэтому `time` то почти 0, то ~1 с и больше. UDP не
подтверждает доставку: при 30% потерь до сервера доходит в среднем ~7 из 10
сообщений (на 10 попытках разброс большой), а отправитель об этом не узнаёт.

## Упражнение 03 — Port exhaustion

```bash
docker run -d --name client-narrow --network netlab \
  --sysctl net.ipv4.ip_local_port_range="32768 32770" \
  nicolaka/netshoot sleep infinity
docker exec client-narrow sysctl net.ipv4.ip_local_port_range
for i in $(seq 1 10); do docker exec client-narrow nc -zv -w2 server 8080; done
docker exec client-narrow ss -tanu
```

Ожидаемый вывод (примерно так; сколько соединений пройдёт до первой ошибки —
1-3, зависит от того, какие порты уже заняты):

```text
net.ipv4.ip_local_port_range = 32768	32770
Connection to server (172.19.0.2) 8080 port [tcp/http-alt] succeeded!
nc: connect to server (172.19.0.2) port 8080 (tcp) failed: Address not available
nc: connect to server (172.19.0.2) port 8080 (tcp) failed: Address not available
...
Netid State     Recv-Q Send-Q Local Address:Port  Peer Address:Port
udp   UNCONN    0      0         127.0.0.11:32768      0.0.0.0:*
tcp   LISTEN    0      4096      127.0.0.11:32769      0.0.0.0:*
tcp   TIME-WAIT 0      0         172.19.0.5:32768   172.19.0.2:8080
```

Почему так: `nc -z` закрывает соединение первым, поэтому порт клиента
остаётся в `TIME-WAIT` (~60 с) и не может быть сразу переиспользован для того
же адресата. Часть крошечного диапазона уже заняли сокеты встроенного
DNS-прокси Docker (`127.0.0.11`). Как только свободных портов нет, `connect()`
возвращает `EADDRNOTAVAIL` — musl пишет его как "Address not available",
glibc — как "Cannot assign requested address". Через ~60 с порты освободятся.

Уборка — см. раздел «Уборка» в
[03_exercises/README.md](../03_exercises/README.md#уборка).
