# Шаг 4 — IaC: настоящие VM вместо kind

🖥 Tier 2. Теория — [4_iac](../../4_iac/) (Ansible — роли, идемпотентность).

То, что на шаге 3 сделал `kind` за 30 секунд, здесь делаем сами на реальных
VM: поднимаем кластер через Terraform, кладём k8s через kubeadm+Ansible.
Показывает, что реально стоит за managed/local k8s дистрибутивами.

## 1. Поднять VM под кластер

```bash
cd ../../02_local_vms/linux_kvm/02_examples/cluster/
terraform init
terraform apply -var="master_count=1" -var="worker_count=2"
terraform output ssh_commands
```

Впиши полученные IP в [ansible/inventory.ini](ansible/inventory.ini) вместо
`REPLACE_ME`.

## 2. Развернуть k8s через kubeadm

```bash
cd ../../../05_capstone_project/04_iac/ansible/
ansible-playbook -i inventory.ini site.yaml
```

Плейбук идемпотентен (`creates:` на ключевых шагах) — можно гонять повторно,
не пересоздаст то, что уже есть (см. [4_iac/06_ansible](../../../4_iac/06_ansible/)
про идемпотентность).

## 3. Накатить приложение (те же манифесты, что на шаге 3)

```bash
scp -i ~/.ssh/lab_key -r ../03_kubernetes/manifests lab@<master-ip>:/tmp/
ssh -i ~/.ssh/lab_key lab@<master-ip> "kubectl apply -f /tmp/manifests/"
```

Образ `shortener:local` тут взять неоткуда (в отличие от kind, который
грузит образ локально) — либо собери и запушь его в registry на шаге 5
(CI/CD), либо `docker save`/`ctr images import` на каждый worker вручную.

## Что почувствовать на этом шаге

- `ansible-playbook -i inventory.ini site.yaml` второй раз подряд — сравни
  вывод `changed=` с первым запуском. Идемпотентность — это не "ничего не
  делает", а "делает ровно недостающее".
- Версия k8s не зашита числом — репозиторий `pkgs.k8s.io/core:/stable:/v1.34`
  всегда отдаёт актуальный патч этой ветки. Если бы версия была вкопана в
  `curl .../v1.24/...`, через год-два это был бы тот самый "устаревший код",
  который мы разбирали в самой базе знаний.

```bash
cd ../../02_local_vms/linux_kvm/02_examples/cluster/
terraform destroy
```
