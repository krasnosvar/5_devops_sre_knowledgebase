# VMware vSphere

## Архитектура vSphere

```
vCenter Server — центральное управление
    ├── Datacenter
    │   ├── Cluster
    │   │   ├── ESXi Host 1
    │   │   │   ├── VM1
    │   │   │   ├── VM2
    │   │   │   └── vSAN (shared storage)
    │   │   ├── ESXi Host 2
    │   │   └── ESXi Host 3
    │   └── Datastore (NFS/iSCSI/vSAN)
    └── Network (vSwitches, Port Groups, NSX-T)
```

**ESXi** — гипервизор (bare-metal). Работает прямо на железе.
**vCenter** — централизованное управление кластером ESXi хостов.
**vSAN** — distributed storage из локальных дисков ESXi хостов.
**NSX-T** — software-defined networking (SDN) поверх vSphere.

## Управление через CLI

```bash
# govc — CLI для vSphere (Go)
# https://github.com/vmware/govmomi/tree/main/govc
export GOVC_URL="https://vcenter.example.com"
export GOVC_USERNAME="administrator@vsphere.local"
export GOVC_PASSWORD="password"
export GOVC_INSECURE=1   # skip TLS verification

# Список VM
govc ls /dc/vm/
govc find / -type m     # все VMs

# Информация о VM
govc vm.info my-vm
govc vm.info -json my-vm | jq '.VirtualMachines[0].Config.Hardware'

# Создать VM из шаблона
govc vm.clone -vm template-ubuntu-24 -on=false my-new-vm
govc vm.power -on my-new-vm

# Snapshot
govc snapshot.create -vm my-vm pre-upgrade
govc snapshot.ls -vm my-vm
govc snapshot.revert -vm my-vm pre-upgrade
govc snapshot.remove -vm my-vm pre-upgrade

# Управление питанием
govc vm.power -on my-vm
govc vm.power -off my-vm
govc vm.power -reset my-vm

# Получить IP VM
govc vm.ip my-vm

# Upload файл в datastore
govc datastore.upload --ds=datastore1 myimage.iso ISO/myimage.iso
```

## Terraform vSphere Provider

```hcl
# main.tf
terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.7"
    }
  }
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

# Data sources — найти существующие объекты
data "vsphere_datacenter" "dc" {
  name = "MyDatacenter"
}

data "vsphere_datastore" "ds" {
  name          = "datastore1"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = "MyCluster"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = "VM Network"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = "ubuntu-24.04-template"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Клонировать VM из шаблона
resource "vsphere_virtual_machine" "vm" {
  count            = 3
  name             = "lab-node-${count.index + 1}"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.ds.id

  num_cpus = 2
  memory   = 4096

  guest_id = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks[0].size
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = "lab-node-${count.index + 1}"
        domain    = "lab.local"
      }
      network_interface {
        ipv4_address = "192.168.1.${10 + count.index}"
        ipv4_netmask = 24
      }
      ipv4_gateway = "192.168.1.1"
    }
  }
}

output "vm_ips" {
  value = vsphere_virtual_machine.vm[*].default_ip_address
}
```

## Миграция с vSphere на k8s

```bash
# virt-v2v — конвертировать VMware VM в KVM/OpenShift
virt-v2v -ic vpx://vcenter.example.com/dc/cluster/host?no_verify=1 \
  -it vddk \
  --vddk-libdir /opt/vmware-vix-disklib-distrib \
  -o local -os /var/tmp/output \
  my-vm-name

# Konveyor (CNCF) — migration assessment и выполнение
# https://konveyor.io/
# Анализирует VM, предлагает k8s манифесты

# После конвертации: создать Docker образ из qcow2
# или использовать KubeVirt (запускать VM внутри k8s)
```

## KubeVirt — VM в Kubernetes

```yaml
# Запустить Windows VM внутри k8s кластера
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: windows-vm
spec:
  running: true
  template:
    spec:
      domain:
        cpu:
          cores: 4
        memory:
          guest: 8Gi
        devices:
          disks:
            - name: containerdisk
              disk:
                bus: virtio
      volumes:
        - name: containerdisk
          containerDisk:
            image: kubevirt/windows:latest
```
