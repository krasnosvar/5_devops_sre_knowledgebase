# Раздел 6. Compute Platforms

Где реально запускается инфраструктура: облака, bare metal серверы, on-prem
виртуализация. Теория, особенности каждого типа и критерии выбора.

## Подразделы

### 6.1 Облако

1. [01_cloud_fundamentals](./01_cloud_fundamentals/) — shared responsibility model,
   регионы и зоны доступности, модели сервисов (IaaS/PaaS/SaaS); почему AZ
   критичны для отказоустойчивости; billing модели (on-demand, reserved, spot).

2. [02_aws](./02_aws/) — AWS core: VPC (subnets, routing, SG, NACLs), IAM
   (roles, policies, trust, IRSA для k8s), EC2, S3, EKS, RDS, ECR, Route53;
   cost optimization (Savings Plans, Spot, rightsizing).

3. [03_gcp_azure_overview](./03_gcp_azure_overview/) — GCP и Azure: отличия от AWS
   в терминологии и подходах, Autopilot vs Standard GKE, AKS, сравнение IAM-моделей;
   когда смотреть в сторону GCP (BigQuery, Vertex AI) или Azure (Microsoft-стек).

4. [04_multi_cloud_and_hybrid](./04_multi_cloud_and_hybrid/) — гибридные паттерны:
   cloud bursting, federated identity, единая observability; multi-cloud без vendor
   lock-in через Terraform + Kubernetes; когда multi-cloud оправдан, а когда это
   преждевременная сложность.

### 6.2 Bare Metal

5. [05_baremetal_fundamentals](./05_baremetal_fundamentals/) — что отличает bare metal
   от VM/cloud: latency, NUMA, SR-IOV, PCI passthrough; когда bare metal оправдан
   (HPC, GPU inference, финансовый trading, compliance без гипервизора).

6. [06_out_of_band_management](./06_out_of_band_management/) — управление серверами
   без ОС: IPMI, BMC, Redfish API; iDRAC (Dell), iLO (HP), iRMC (Fujitsu);
   `ipmitool` команды: power on/off/status, sensor, SOL (serial over LAN),
   PXE boot через IPMI.

7. [07_os_provisioning](./07_os_provisioning/) — автоматическая установка ОС:
   PXE boot цепочка (DHCP → TFTP → iPXE/GRUB → installer); kickstart (RHEL/Fedora),
   preseed/cloud-init (Debian/Ubuntu); MAAS (Metal as a Service) как полноценный
   bare metal provisioner; Tinkerbell (CNCF, cloud-native подход).

8. [08_hardware_inventory](./08_hardware_inventory/) — инвентаризация: `dmidecode`,
   `lshw`, `lspci`, `lsblk`, `smartctl`; firmware обновления через `fwupd` и
   vendor-утилиты; RAID (mdadm software RAID vs аппаратный HBA); мониторинг
   железа (IPMI Exporter для Prometheus).

9. [09_network_provisioning](./09_network_provisioning/) — сеть для bare metal:
   bonding/teaming, VLAN через 802.1q, jumbo frames (MTU 9000); network booting;
   ToR (Top of Rack) свитчи и uplinks; SDN для on-prem (Open vSwitch).

### 6.3 On-prem виртуализация

10. [10_proxmox](./10_proxmox/) — Proxmox VE: KVM + LXC под одной крышей, кластер,
    shared storage (Ceph, NFS, iSCSI), HA, миграция VM; API для автоматизации;
    Terraform provider для Proxmox.

11. [11_vmware_vsphere](./11_vmware_vsphere/) — VMware vSphere: vCenter, ESXi,
    vSAN, NSX-T в общих чертах; Terraform vSphere provider; миграция workloads
    с vSphere на k8s (virt-v2v, Konveyor).

12. [12_platform_comparison](./12_platform_comparison/) — матрица выбора платформы:
    cloud vs bare metal vs on-prem virt по осям latency, cost, control, compliance,
    операционной сложности; типичные архитектурные решения по индустриям.

## Как проходить

01 → 02 (AWS) — обязательная база для большинства реальных проектов.
05 → 06 → 07 — если работаешь с bare metal или планируешь homelab.
10 или 11 — по используемой платформе.
03, 04, 08, 09, 12 — по необходимости.

## Упражнения — тиры

🐳 Tier 1: AWS CLI / Terraform в dry-run режиме, IPMI simulator
🖥 Tier 2: Proxmox или KVM-хост как bare metal + Terraform libvirt/proxmox
☁️ Tier 3: AWS free tier (EC2, S3, IAM), Hetzner VPS (bare metal dedicated)

## Связь с другими разделами

- Terraform примеры для AWS/libvirt/vSphere → [`../1_sysadm_sre_devops_tools/.../terraform/examples/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/1_infra_terraform_clouds/terraform/examples/)
- cloud-init конфиги → [`../1_sysadm_sre_devops_tools/.../cloud-init/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/1_infra_terraform_clouds/cloud-init/)
- KVM команды → [`../1_sysadm_sre_devops_tools/.../kvm/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/1_infra_terraform_clouds/kvm/)
