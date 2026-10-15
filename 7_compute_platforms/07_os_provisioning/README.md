# 07. Автоматическая установка ОС

## Зачем
Устанавливать ОС на десятки серверов руками с флешки — медленно и
невоспроизводимо. Сетевая загрузка (PXE/iPXE) плюс файл ответов
(kickstart, autoinstall, cloud-init) превращают установку в
автоматический процесс, а MAAS и Tinkerbell добавляют поверх этого
управление жизненным циклом серверов.

## Пререквизиты
- [1_linux_and_shell/00_architecture_and_boot](../../1_linux_and_shell/00_architecture_and_boot/)
  — процесс загрузки: firmware, загрузчик, ядро, initramfs.
- [06_out_of_band_management](../06_out_of_band_management/) — выбор
  загрузки по PXE через BMC.
- [2_networking/00_osi_and_tcpip](../../2_networking/00_osi_and_tcpip/) —
  IP-адресация и UDP (DHCP и TFTP работают поверх UDP).

## Файлы
- [01_theory/os_provisioning.md](./01_theory/os_provisioning.md) — цепочка
  PXE, dnsmasq как DHCP+TFTP, kickstart для RHEL/Fedora, cloud-init, MAAS,
  Tinkerbell.
- [02_examples/ubuntu-autoinstall.yaml](./02_examples/ubuntu-autoinstall.yaml)
  — пример Ubuntu autoinstall: сеть, LVM-разметка, пользователь, SSH,
  пакеты, late-commands. Хэш пароля в файле — заглушка, сгенерируйте свой
  через `mkpasswd --method=SHA-512`.

Без упражнений с ответами. Тему можно отработать самостоятельно на
🖥 Tier 2: изолированная сеть libvirt без DHCP, VM с dnsmasq в роли
PXE-сервера и пустая VM, загружающаяся по сети (стенд из
[0_lab_setup/02_local_vms](../../0_lab_setup/02_local_vms/)).

## Как проходить
1. Прочитать теорию, нарисовать цепочку DHCP → TFTP → загрузчик →
   installer → файл ответов.
2. Разобрать `ubuntu-autoinstall.yaml` построчно: что делает каждый ключ.
3. По желанию собрать PXE-стенд на двух VM (см. выше) и установить
   Ubuntu с этим файлом без единого ручного ввода.

## Когда двигаться дальше
- Можете перечислить шаги PXE-загрузки и сказать, какой сервис отвечает
  за каждый.
- Можете объяснить, чем kickstart отличается от cloud-init и когда
  применяется каждый.
- Можете объяснить, какую задачу MAAS решает поверх «голого» PXE.

Дальше — [08_hardware_inventory](../08_hardware_inventory/): учёт того, что
установлено в серверах.
