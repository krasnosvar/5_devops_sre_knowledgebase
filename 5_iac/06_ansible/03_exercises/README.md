# Упражнения — Ansible

Стенд: 🖥 Tier 2 — 2+ VM через KVM/Terraform или Multipass

Все команды ниже — от корня репозитория.

```bash
# Поднять 2 VM через Terraform (стенд из 0_lab_setup)
cd 0_lab_setup/02_local_vms/linux_kvm/02_examples/
terraform init
terraform plan -var="vm_count=2" -out=tfplan
terraform apply tfplan
terraform output ssh_commands   # получить IP адреса
cd -

# Обновить 5_iac/06_ansible/02_examples/inventory.yaml — подставить
# реальные IP в web1/web2 (db1 в этих упражнениях не нужен)
```

Описание стенда:
[0_lab_setup/02_local_vms/linux_kvm](../../../0_lab_setup/02_local_vms/linux_kvm/).

## 01 — Ping и gather facts

```bash
cd 5_iac/06_ansible/02_examples/

# Проверить что Ansible достучался до всех хостов
ansible webservers -i inventory.yaml -m ping

# Посмотреть факты о хостах
ansible web1 -i inventory.yaml -m setup
ansible web1 -i inventory.yaml -m setup -a "filter=ansible_distribution*"
```

## 02 — Запустить site.yaml из 02_examples/

```bash
cd 5_iac/06_ansible/02_examples/

# dry-run (без изменений)
ansible-playbook -i inventory.yaml site.yaml --check --diff

# применить
ansible-playbook -i inventory.yaml site.yaml

# проверить
curl http://192.168.200.10
curl http://192.168.200.11
```

## 03 — Написать роль

**Задача:** Вынести установку nginx в роль `roles/nginx/`.

```
roles/nginx/
├── tasks/main.yaml      ← install + configure + start
├── handlers/main.yaml   ← restart/reload
├── templates/nginx.conf.j2
├── defaults/main.yaml   ← nginx_port: 80
└── meta/main.yaml       ← galaxy info
```

```yaml
# Использование роли в playbook — один из двух вариантов
- hosts: webservers
  roles:
    - nginx                                # порт из defaults (80)
    # - { role: nginx, nginx_port: 8080 }  # или с кастомным портом
```

## 04 — ansible-vault для секретов

**Задача:** Положить пароль БД в `vars/secrets.yaml`, зашифровать его
и использовать переменную в playbook (`vars_files`), не печатая
секрет в вывод.

```bash
# Зашифровать файл с паролями
ansible-vault encrypt vars/secrets.yaml

# Запустить playbook, который подключает vars/secrets.yaml
ansible-playbook -i inventory.yaml playbook.yaml --ask-vault-pass

# Или через файл с паролем (для CI): права 600 и файл в .gitignore
ansible-playbook -i inventory.yaml playbook.yaml \
  --vault-password-file .vault_pass
```

## 05 — Идемпотентность

**Задача:** Убедиться что playbook идемпотентен:
```bash
ansible-playbook -i inventory.yaml site.yaml  # первый запуск: changed
ansible-playbook -i inventory.yaml site.yaml  # второй запуск: ok (без changed)
```
Если есть `changed` во втором запуске — найти и исправить.
