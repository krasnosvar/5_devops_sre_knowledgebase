# Ansible

## Концепции

**Inventory** — список хостов и их группировка.
**Playbook** — набор task'ов для выполнения на хостах.
**Role** — переиспользуемый блок (tasks, handlers, vars, templates, files).
**Module** — единица работы (`ansible.builtin.apt`, `ansible.builtin.copy`, `template`).
**Handler** — task, выполняемый при изменении (notify → handler).

## Inventory

```ini
# inventory/hosts.ini (INI формат)
[webservers]
web1 ansible_host=10.0.0.1
web2 ansible_host=10.0.0.2

[databases]
db1 ansible_host=10.0.0.10 ansible_user=ubuntu ansible_port=22022

[production:children]   # группа из групп
webservers
databases

[production:vars]
ansible_ssh_private_key_file=~/.ssh/lab_key
ansible_python_interpreter=/usr/bin/python3
```

```yaml
# inventory/hosts.yaml (YAML формат, предпочтительнее)
all:
  children:
    webservers:
      hosts:
        web1:
          ansible_host: 10.0.0.1
        web2:
          ansible_host: 10.0.0.2
    databases:
      hosts:
        db1:
          ansible_host: 10.0.0.10
      vars:
        pg_version: "16"
```

## Playbook

```yaml
# playbooks/deploy.yaml
---
- name: Deploy web application
  hosts: webservers
  become: true              # sudo
  gather_facts: true        # собирать факты о хосте (OS, IP, etc.)

  vars:
    app_version: "1.2.3"
    app_port: 8080

  vars_files:
    - ../vars/secrets.yaml  # зашифрованные переменные (ansible-vault)

  pre_tasks:
    - name: Update apt cache
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600

  tasks:
    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
      notify: Restart nginx   # вызвать handler если изменился

    - name: Deploy nginx config
      ansible.builtin.template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        mode: '0644'
        validate: nginx -t -c %s    # проверить конфиг перед заменой
      notify: Restart nginx

    - name: Ensure nginx is running
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true

    - name: Copy application binary
      ansible.builtin.copy:
        src: "{{ playbook_dir }}/../dist/myapp-{{ app_version }}"
        dest: /opt/myapp/myapp
        mode: '0755'
        owner: myapp
        group: myapp
      notify: Restart myapp

    - name: Run DB migrations
      ansible.builtin.command:
        cmd: /opt/myapp/myapp migrate
      run_once: true            # только на одном хосте из группы
      delegate_to: "{{ groups['webservers'][0] }}"

  handlers:
    - name: Restart nginx
      ansible.builtin.service:
        name: nginx
        state: restarted

    - name: Restart myapp
      ansible.builtin.service:
        name: myapp
        state: restarted
```

## Идемпотентность в Ansible

Каждый модуль проверяет текущее состояние и действует только если нужно.

```yaml
# Идемпотентно: apt проверяет установлен ли пакет
- ansible.builtin.apt:
    name: nginx
    state: present   # installed or nothing to do

# НЕ идемпотентно: command/shell всегда выполняются
- ansible.builtin.shell:
    cmd: echo "hello" >> /tmp/log.txt

# Сделать идемпотентным через creates:
- ansible.builtin.command:
    cmd: /opt/setup.sh
    creates: /opt/.setup_done   # не выполнять если файл существует

# или через changed_when / failed_when:
- ansible.builtin.command:
    cmd: myapp check-migration
  register: migration_result
  changed_when: "'already applied' not in migration_result.stdout"
```

## Роли

```
roles/
└── nginx/
    ├── tasks/
    │   └── main.yaml         # основные задачи
    ├── handlers/
    │   └── main.yaml         # handlers
    ├── templates/
    │   └── nginx.conf.j2     # Jinja2 шаблоны
    ├── files/
    │   └── default.html      # статические файлы
    ├── vars/
    │   └── main.yaml         # переменные роли (высокий приоритет)
    ├── defaults/
    │   └── main.yaml         # default значения (низкий приоритет)
    └── meta/
        └── main.yaml         # зависимости роли
```

```yaml
# Использование роли в playbook
- hosts: webservers
  roles:
    - common
    - nginx
    - { role: myapp, app_version: "1.2.3" }

# или tasks формат (более гибкий):
  tasks:
    - ansible.builtin.import_role:
        name: nginx
    - ansible.builtin.include_role:
        name: myapp           # include_role загружается динамически
      vars:
        app_version: "1.2.3"
```

## ansible-vault — шифрование секретов

```bash
# зашифровать файл
ansible-vault encrypt vars/secrets.yaml

# создать зашифрованный файл
ansible-vault create vars/secrets.yaml

# редактировать
ansible-vault edit vars/secrets.yaml

# зашифровать отдельную строку (вставить в vars файл)
ansible-vault encrypt_string 'mysecretpassword' --name 'db_password'
# вставить вывод в vars файл как обычную переменную

# запуск с vault паролем
ansible-playbook playbook.yaml --ask-vault-pass
ansible-playbook playbook.yaml --vault-password-file ~/.vault_pass
```

## Useful CLI

```bash
# проверить связь
ansible all -i inventory/hosts.ini -m ping

# выполнить команду на всех хостах
ansible webservers -i inventory/ -m shell -a "systemctl status nginx"

# собрать факты
ansible web1 -i inventory/ -m setup
ansible web1 -i inventory/ -m setup -a "filter=ansible_distribution*"

# dry-run (check mode)
ansible-playbook -i inventory/ playbooks/deploy.yaml --check --diff

# ограничить по хостам
ansible-playbook -i inventory/ playbooks/deploy.yaml --limit web1
ansible-playbook -i inventory/ playbooks/deploy.yaml --limit "webservers:!web2"

# теги
ansible-playbook -i inventory/ playbooks/deploy.yaml --tags nginx
ansible-playbook -i inventory/ playbooks/deploy.yaml --skip-tags migrations

# verbose
ansible-playbook -i inventory/ playbooks/deploy.yaml -v     # переменные
ansible-playbook -i inventory/ playbooks/deploy.yaml -vvv   # всё
```

## Ansible vs Terraform

| | Terraform | Ansible |
|---|---|---|
| Что делает | Провижининг инфраструктуры | Конфигурация ОС и приложений |
| Идиома | Декларативный (state) | Процедурный (идемпотентный) |
| State | Есть | Нет (читает текущее состояние) |
| Лучше для | Создание VM, сетей, БД | Установка пакетов, конфиги, деплой |
| Совместно | Terraform создаёт VM → Ansible конфигурирует | |
