# Автоматическая установка ОС

## PXE Boot — цепочка сетевой загрузки

```
Сервер включается → BIOS/UEFI → PXE ROM сетевой карты
    │
    ▼ DHCP запрос (broadcast)
DHCP сервер → IP + next-server (TFTP) + filename (bootloader)
    │
    ▼ TFTP запрос
TFTP сервер → bootloader (iPXE/GRUB/pxelinux)
    │
    ▼ bootloader запрашивает конфигурацию
HTTP/TFTP → kernel + initrd + конфиг установщика
    │
    ▼
Установщик (Anaconda/d-i/cloud-init) устанавливает ОС
```

## dnsmasq — DHCP + TFTP в одном (для лабы)

```bash
# установка
dnf install dnsmasq syslinux-tftpboot

# /etc/dnsmasq.conf
interface=eth0
dhcp-range=192.168.100.100,192.168.100.200,1h
dhcp-boot=pxelinux.0,tftp-server,192.168.100.1
enable-tftp
tftp-root=/var/lib/tftpboot
log-dhcp

# скопировать bootloader
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cp /usr/share/syslinux/menu.c32 /var/lib/tftpboot/

systemctl enable --now dnsmasq
```

## Kickstart (RHEL/Fedora/CentOS)

Kickstart — файл ответов для автоматической установки RHEL-based ОС.

```bash
# /var/www/html/ks/fedora-server.ks
#version=F40
install
url --url="https://mirrors.fedoraproject.org/pub/fedora/linux/releases/40/Server/x86_64/os/"

lang en_US.UTF-8
keyboard us
timezone UTC --utc

# сетевые настройки
network --bootproto=dhcp --device=eth0 --onboot=yes

# разметка диска (автоматически)
ignoredisk --only-use=sda
autopart --type=lvm
clearpart --all --initlabel

# пользователи
rootpw --iscrypted $6$rounds=100000$salt$hashedpassword
user --name=admin --groups=wheel --password=... --iscrypted

# SSH ключ
sshkey --username=admin "ssh-ed25519 AAAA... user@host"

# пакеты
%packages
@core
@server-product-environment
vim
git
curl
%end

# команды после установки
%post
systemctl enable sshd
dnf clean all
%end

# перезагрузка после установки
reboot
```

```
# pxelinux.cfg/default — меню для PXE
LABEL fedora-auto
  KERNEL images/fedora/vmlinuz
  APPEND initrd=images/fedora/initrd.img \
    inst.ks=http://192.168.100.1/ks/fedora-server.ks \
    quiet
```

## Cloud-init (Ubuntu/Debian + любые cloud-ready образы)

```yaml
# user-data (cloud-init)
#cloud-config
hostname: myserver
fqdn: myserver.example.com

users:
  - name: admin
    groups: [sudo, docker]
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - "ssh-ed25519 AAAA... admin@laptop"

# автоматическое обновление пакетов
package_update: true
package_upgrade: true
packages:
  - docker-ce
  - docker-compose-plugin
  - curl
  - jq
  - git
  - htop

runcmd:
  - systemctl enable --now docker
  - usermod -aG docker admin

write_files:
  - path: /etc/sysctl.d/99-k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables = 1
      net.ipv4.ip_forward = 1
    permissions: '0644'

power_state:
  mode: reboot
  message: "Rebooting after initial setup"
  timeout: 30
```

## MAAS — Metal as a Service (Ubuntu Canonical)

MAAS — полноценный bare metal provisioner. Управляет серверами через IPMI,
делает PXE boot, устанавливает ОС, выдаёт IP.

```bash
# установка MAAS (Ubuntu)
sudo snap install maas
sudo maas init region+rack --maas-url http://192.168.1.1:5240/MAAS \
  --database-uri "postgres://maas:password@localhost/maasdb"

# MAAS CLI
maas login admin http://192.168.1.1:5240/MAAS apikey

# список машин
maas admin machines read | jq '.[].hostname'

# commission (обнаружить железо через IPMI)
maas admin machine commission system_id=abc123

# deploy (установить ОС)
maas admin machine deploy system_id=abc123 \
  osystem=ubuntu distro_series=noble \
  user_data=$(base64 -w0 user-data.yaml)

# release (вернуть в пул)
maas admin machine release system_id=abc123
```

## Tinkerbell (CNCF) — cloud-native подход

Tinkerbell — современная альтернатива MAAS из CNCF sandbox.
Использует Kubernetes для хранения состояния, workflow-based provisioning.

```yaml
# Template — что делать с сервером
apiVersion: tinkerbell.org/v1alpha1
kind: Template
metadata:
  name: ubuntu-install
spec:
  data: |
    version: "0.1"
    name: ubuntu-install
    tasks:
      - name: "os-install"
        worker: "{{.device_1}}"
        actions:
          - name: "stream-ubuntu-image"
            image: quay.io/tinkerbell-actions/image2disk:v1.0.0
            environment:
              IMG_URL: http://fileserver/ubuntu-24.04.img.gz
              DEST_DISK: /dev/sda
          - name: "configure-cloud-init"
            image: quay.io/tinkerbell-actions/writefile:v1.0.0
            environment:
              DEST_DISK: /dev/sda1
              DEST_PATH: /etc/cloud/cloud.cfg.d/custom.cfg
              CONTENTS: |
                #cloud-config
                hostname: myserver
```
