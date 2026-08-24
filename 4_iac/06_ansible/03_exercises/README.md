# Упражнения — Ansible

Стенд: 🖥 Tier 2 — 2+ VM через KVM/Terraform или Multipass

```bash
# Поднять 2 VM через Terraform (из 0_lab_setup/02_local_vms/linux_kvm/02_examples/)
cd ../../0_lab_setup/02_local_vms/linux_kvm/02_examples/
terraform apply -var="vm_count=2"
terraform output ssh_commands   # получить IP адреса

# Обновить inventory.yaml — подставить реальные IP
```

## 01 — Ping и gather facts

```bash
# Проверить что Ansible достучался до всех хостов
ansible webservers -i inventory.yaml -m ping

# Посмотреть факты о хостах
ansible web1 -i inventory.yaml -m setup
ansible web1 -i inventory.yaml -m setup -a "filter=ansible_distribution*"
```

## 02 — Запустить site.yaml из 02_examples/

```bash
cd ../4_iac/06_ansible/02_examples/

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
# Использование роли в playbook
- hosts: webservers
  roles:
    - nginx
    - { role: nginx, nginx_port: 8080 }   # с кастомным портом
```

## 04 — ansible-vault для секретов

```bash
# Зашифровать файл с паролями
ansible-vault encrypt vars/secrets.yaml

# Запустить playbook с vault
ansible-playbook -i inventory.yaml site.yaml --ask-vault-pass

# Или через файл с паролем (для CI)
echo "my_vault_password" > .vault_pass
ansible-playbook -i inventory.yaml site.yaml --vault-password-file .vault_pass
```

## 05 — Идемпотентность

**Задача:** Убедиться что playbook идемпотентен:
```bash
ansible-playbook -i inventory.yaml site.yaml  # первый запуск: changed
ansible-playbook -i inventory.yaml site.yaml  # второй запуск: ok (без changed)
```
Если есть `changed` во втором запуске — найти и исправить.
