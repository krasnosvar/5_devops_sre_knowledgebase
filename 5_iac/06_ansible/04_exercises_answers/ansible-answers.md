# Ответы — Ansible

Стенд: 2 VM Ubuntu из `0_lab_setup/02_local_vms/linux_kvm/02_examples/`
(`base_lab.tf`, пользователь `lab`, ключ `~/.ssh/lab_key`), IP вписаны
в [../02_examples/inventory.yaml](../02_examples/inventory.yaml).

Файлы ответов:
- упражнение 03 — роль [roles/nginx/](./roles/nginx/) и playbook
  [site-role.yaml](./site-role.yaml);
- упражнение 04 — [vault-demo.yaml](./vault-demo.yaml);
- упражнение 05 — [site-idempotent.yaml](./site-idempotent.yaml).

## Упражнение 01 — Ping и gather facts

```bash
cd 5_iac/06_ansible/02_examples/
ansible webservers -i inventory.yaml -m ping
ansible web1 -i inventory.yaml -m setup -a "filter=ansible_distribution*"
```

Ожидаемый вывод (примерно так):

```text
web1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
web2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
web1 | SUCCESS => {
    "ansible_facts": {
        "ansible_distribution": "Ubuntu",
        "ansible_distribution_major_version": "24",
        "ansible_distribution_release": "noble",
        "ansible_distribution_version": "24.04",
        ...
```

Почему так: модуль `ping` — не ICMP, а проверка всей цепочки: SSH
подключение, вход по ключу и запуск Python на хосте. `UNREACHABLE`
означает проблему SSH/IP, `FAILED` с `python` — нет интерпретатора.

## Упражнение 02 — Запустить site.yaml из 02_examples/

```bash
cd 5_iac/06_ansible/02_examples/
ansible-playbook -i inventory.yaml site.yaml --check --diff
ansible-playbook -i inventory.yaml site.yaml
curl http://192.168.200.10
curl http://192.168.200.10/health
```

Ожидаемый вывод (примерно так):

```text
(--check на чистой VM)
TASK [Deploy nginx config] ****
fatal: [web1]: FAILED! => ... "Destination directory
/etc/nginx/sites-available does not exist"
...
(без --check)
PLAY RECAP ****
web1 : ok=12 changed=8 unreachable=0 failed=0 skipped=1 ...
web2 : ok=12 changed=8 unreachable=0 failed=0 skipped=1 ...

<h1>Server: web1</h1>
<p>App version: 1.0.0</p>
<p>Managed by Ansible</p>
ok
```

Почему так: `--check` ничего не меняет, поэтому на чистой VM задачи,
зависящие от предыдущих (пакет ещё «не установлен»), могут падать или
давать неточный diff — это ограничение dry-run, а не ошибка playbook:
каталог `/etc/nginx` появится только после реальной установки пакета.
Повторный `--check --diff` на уже настроенной VM проходит чисто.
`skipped=1` — задача для `RedHat`, отфильтрованная `when`.

## Упражнение 03 — Написать роль

Структура — в [roles/nginx/](./roles/nginx/): `tasks/main.yaml`
(установка, конфиг, запуск), `handlers/main.yaml`, шаблон
`templates/nginx.conf.j2`, `defaults/main.yaml` (`nginx_port: 80`),
`meta/main.yaml`.

```bash
cd 5_iac/06_ansible/04_exercises_answers/
ansible-playbook -i ../02_examples/inventory.yaml site-role.yaml --syntax-check
ansible-playbook -i ../02_examples/inventory.yaml site-role.yaml
ansible-playbook -i ../02_examples/inventory.yaml site-role.yaml \
  -e nginx_port=8080
curl http://192.168.200.10:8080/health
```

Ожидаемый вывод (примерно так):

```text
playbook: site-role.yaml

TASK [nginx : Deploy site config] ****
ok: [web1]
...
(с -e nginx_port=8080)
TASK [nginx : Deploy site config] ****
changed: [web1]
RUNNING HANDLER [nginx : Reload nginx] ****
changed: [web1]
...
ok
```

Почему так: роль ищет `src: nginx.conf.j2` в своей `templates/`, а
handlers — в своей `handlers/`. `defaults` имеют самый низкий
приоритет: inventory (`nginx_port: 80` в группе) и `-e` их
перекрывают. Подключить роль дважды с разными портами в одном play
(`- nginx` и `- { role: nginx, nginx_port: 8080 }`) бессмысленно: оба
вызова пишут один и тот же файл сайта, выиграет последний.

## Упражнение 04 — ansible-vault для секретов

```bash
cd 5_iac/06_ansible/04_exercises_answers/
mkdir -p vars
printf 'db_password: "change-me"\n' > vars/secrets.yaml
ansible-vault encrypt vars/secrets.yaml      # спросит vault-пароль
head -1 vars/secrets.yaml
ansible-vault view vars/secrets.yaml

ansible-playbook -i ../02_examples/inventory.yaml vault-demo.yaml \
  --ask-vault-pass

# Для CI: пароль в файле с правами 600, файл — в .gitignore
printf '%s\n' 'my_vault_password' > ~/.vault_pass && chmod 600 ~/.vault_pass
ansible-playbook -i ../02_examples/inventory.yaml vault-demo.yaml \
  --vault-password-file ~/.vault_pass
```

Ожидаемый вывод (примерно так):

```text
Encryption successful
$ANSIBLE_VAULT;1.1;AES256
db_password: "change-me"

TASK [Write app secret to a root-only file] ****
changed: [web1]
changed: [web2]
```

Почему так: в Git попадает только шифротекст (`$ANSIBLE_VAULT;1.1;
AES256`), расшифровка происходит в памяти при запуске. `no_log: true`
нужен, иначе при `-v` или ошибке значение попадёт в вывод и логи CI.
Сам пароль vault в репозиторий не кладут — в CI его передают через
секрет пайплайна. Перед коммитом проверьте, что `vars/secrets.yaml`
зашифрован (`head -1`).

## Упражнение 05 — Идемпотентность

```bash
cd 5_iac/06_ansible/02_examples/
ansible-playbook -i inventory.yaml site.yaml
ansible-playbook -i inventory.yaml site.yaml
```

Ожидаемый вывод (примерно так):

```text
(первый запуск на чистой VM)
web1 : ok=12 changed=8 unreachable=0 failed=0 skipped=1 ...
(второй запуск: handlers не вызываются)
web1 : ok=10 changed=0 unreachable=0 failed=0 skipped=1 ...
```

`site.yaml` уже идемпотентен: все изменения идут через модули с
проверкой состояния (`package`, `file`, `copy`, `service`), handlers
срабатывают только при `changed`. Нюанс: `apt: update_cache: true`
с `cache_valid_time: 3600` покажет `changed`, если второй запуск
случился больше чем через час — это обновление кеша, а не дрейф.

Типичный источник `changed` на каждом запуске — `shell`/`command`:

```yaml
- name: Create dir (НЕ идемпотентно: всегда changed)
  ansible.builtin.command: mkdir -p /opt/app
```

Исправления: заменить на модуль (`ansible.builtin.file` со
`state: directory`), либо, если модуля нет, добавить `creates:` /
`removes:` или `changed_when:` по реальному результату команды.
Вариант playbook с этими приёмами — [site-idempotent.yaml](./site-idempotent.yaml):

```bash
cd 5_iac/06_ansible/04_exercises_answers/
ansible-playbook -i ../02_examples/inventory.yaml site-idempotent.yaml
ansible-playbook -i ../02_examples/inventory.yaml site-idempotent.yaml
```

```text
web1 : ok=9 changed=0 unreachable=0 failed=0 ...
```

Почему так: идемпотентность — свойство каждой задачи, а не playbook
целиком. Проверка `nginx -t` в handler помечена `changed_when: false`:
она ничего не меняет и не должна портить статистику второго запуска.
