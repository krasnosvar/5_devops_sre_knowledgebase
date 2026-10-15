# 06. Сеть в Linux: инструменты

## Зачем
Прежде чем разбирать протоколы, нужно уметь посмотреть, что
происходит с сетью на конкретном хосте: интерфейсы и адреса, маршруты,
сокеты, откуда берётся DNS-резолвинг, и как собрать изолированную сеть из
network namespace и veth — так устроена сеть каждого контейнера.

## Пререквизиты
- [02_cgroups_and_namespaces](../02_cgroups_and_namespaces/) — что такое
  network namespace.
- [03_file_descriptors_and_io](../03_file_descriptors_and_io/) — сокет как
  файловый дескриптор.
- Стенд: Linux VM с sudo (🖥 Tier 2) для `ip netns` и `tcpdump`.

## Файлы
- [01_theory/linux_networking.md](./01_theory/linux_networking.md) —
  iproute2 (`ip`), маршруты, `ss` и TIME_WAIT, `/etc/hosts`/nsswitch/
  `resolv.conf`, netns и veth, базовый tcpdump; протоколы — ссылками в
  [2_networking](../../2_networking/).
- [02_examples/network_debug.sh](./02_examples/network_debug.sh) — обход
  сетевого состояния хоста: интерфейсы, маршруты, порты, conntrack,
  правила, DNS.
- Без отдельных упражнений: лаба с netns и veth приведена в теории (§5).

## Как проходить
1. Прочитать теорию, повторить лабу с `ip netns` из §5.
2. Запустить `sudo bash 02_examples/network_debug.sh` на своём хосте.
3. Ответить на Interview Q&A без подсказки.

## Когда двигаться дальше
- можете через `ip route get` сказать, куда и с какого адреса уйдёт пакет;
- можете собрать два namespace, связанных veth, и пропинговать между ними;
- можете объяснить, почему `dig` работает, а приложение не резолвит имя.

Дальше: [07_bash_for_devops](../07_bash_for_devops/); протоколы —
в [2_networking](../../2_networking/).
