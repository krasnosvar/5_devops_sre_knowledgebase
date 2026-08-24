# Сетевой стек Linux

Понимание Linux networking критично для k8s: Services, CNI, kube-proxy —
всё строится поверх этих примитивов.

## netfilter и iptables/nftables

**netfilter** — фреймворк ядра для обработки пакетов. Хуки на разных
этапах прохождения пакета через стек.

**iptables** — userspace утилита для управления netfilter правилами.
**nftables** — современная замена iptables (Linux 3.13+).

kube-proxy в режиме iptables создаёт тысячи правил iptables для реализации
k8s Services. kube-proxy в режиме IPVS использует специализированную таблицу
для L4 балансировки (быстрее при большом количестве сервисов).

```bash
# посмотреть все правила
iptables -L -n -v --line-numbers
iptables -t nat -L -n -v            # таблица NAT

# правила kube-proxy
iptables -t nat -L KUBE-SERVICES -n
iptables -t nat -L KUBE-SVC-<hash> -n

# nftables
nft list ruleset
```

## veth pair — виртуальный кабель

veth (virtual ethernet) — пара сетевых интерфейсов, связанных между собой.
Пакет, вошедший в один конец, выходит из другого.

Именно так контейнер соединяется с хостом:

```
контейнер                    хост
─────────                    ────
eth0 ◄──── veth pair ────► vethXXXX ──► docker0 (bridge)
```

```bash
# посмотреть veth пары
ip link show type veth

# посмотреть в каком namespace veth находится
ip link show vethXXXX
# peer_ifindex даёт номер интерфейса на другом конце

# зайти в namespace контейнера и посмотреть его интерфейсы
PID=$(docker inspect --format '{{.State.Pid}}' mycontainer)
nsenter --net -t $PID ip addr
```

## bridge — виртуальный коммутатор

Linux bridge (docker0, cni0) — L2 коммутатор в ядре.
Все veth хост-концы подключены к bridge. Bridge соединён с физическим
интерфейсом или имеет iptables MASQUERADE правило для NAT.

```bash
ip link show type bridge
bridge link show          # какие интерфейсы в каком bridge
brctl show                # устаревший, но иногда есть
```

## Маршрутизация

```bash
ip route show             # таблица маршрутизации
ip route get 8.8.8.8      # по какому маршруту пойдёт пакет

# k8s: Pod IP маршруты добавляются CNI плагином
# пример вывода после создания pod:
# 10.244.1.5 via 10.244.1.1 dev cni0 src 10.244.0.1
```

## Полезные команды для отладки сети

```bash
# посмотреть все сетевые namespace на хосте
ls /var/run/netns/
ip netns list

# трассировка маршрута
traceroute 8.8.8.8
mtr 8.8.8.8              # real-time traceroute

# перехватить трафик
tcpdump -i any -n port 80
tcpdump -i docker0 -n     # трафик на docker bridge

# проверить открытые порты
ss -tlnp                  # современный аналог netstat
ss -tlnp | grep :80

# проверить доступность
curl -v http://10.96.0.1  # ClusterIP k8s API server
nc -zv 10.96.0.1 443      # проверить TCP порт
```

## conntrack — таблица соединений

NAT в Linux stateful: conntrack отслеживает все соединения и выполняет
DNAT/SNAT автоматически для ответных пакетов.

```bash
conntrack -L              # все отслеживаемые соединения
conntrack -L | grep ESTABLISHED | wc -l

# проблема: conntrack table full = потеря пакетов
sysctl net.netfilter.nf_conntrack_count
sysctl net.netfilter.nf_conntrack_max
```

В нагруженных k8s кластерах conntrack table overflow — частая причина
случайных сетевых проблем. Cilium (eBPF) решает это, обходя conntrack.
