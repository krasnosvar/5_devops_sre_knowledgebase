#!/usr/bin/env bash
# Ответ: упражнения 01-03 — TCP handshake, TCP vs UDP под потерями, port exhaustion

echo "=== Ответ 01: захват handshake ==="
echo "Флаги в tcpdump: [S] = SYN, [S.] = SYN-ACK, [.] = ACK (просто флаг ACK без данных)."
echo "Порядок в выводе: client->server [S], server->client [S.], client->server [.]"

echo -e "\n=== Ответ 02: TCP vs UDP под потерями ==="
echo "TCP: 'time nc -zv' покажет увеличенное время (retransmit timers), но подключение"
echo "     в итоге состоится — ядро само повторяет непринятые сегменты."
echo "UDP: из 10 отправленных msg-N на сервере окажется примерно 7 (при 30% потерь)"
echo "     — недостающие просто исчезли, никто не заметил и не переспросил."

echo -e "\n=== Ответ 03: port exhaustion ==="
echo "С диапазоном 'net.ipv4.ip_local_port_range = 32768 32770' доступно всего"
echo "3 эфемерных порта. Первые 2-3 параллельных соединения откроются успешно,"
echo "остальные упадут с 'nc: Cannot assign requested address' — ядру физически"
echo "нечем присвоить исходящий порт новому соединению, все заняты."
echo
echo "Восстановить дефолт:"
echo "  sysctl -w net.ipv4.ip_local_port_range=\"32768 60999\""
