# Ansible — шпаргалка

Подробности и объяснения — в [ansible.md](./01_theory/ansible.md). ⚠️ —
опасная команда или частая ловушка.

## ansible-playbook

| Задача | Команда |
| :--- | :--- |
| Запуск | `ansible-playbook -i inventory.ini site.yml` |
| Синтаксис без подключения | `ansible-playbook -i inventory.ini site.yml --syntax-check` |
| Сухой прогон + diff файлов | `ansible-playbook ... --check --diff` |
| Какие хосты / задачи / теги затронет | `--list-hosts` / `--list-tasks` / `--list-tags` |
| Ограничить хосты | `-l web1` / `-l 'webservers:!web3'` |
| Только / кроме тегов | `--tags config` / `--skip-tags slow` |
| Начать с задачи / по шагам | `--start-at-task 'Конфиг из шаблона'` / `--step` |
| Переопределить переменную (высший приоритет) | `-e app_port=9090` / `-e @vars.yml` |
| sudo на хосте | `-b` (`--become`), пароль: `-K` (`--ask-become-pass`) |
| Параллельно хостов (по умолчанию 5) | `-f 20` (`--forks`) |
| Пароль Vault | `--ask-vault-pass` / `--vault-password-file ~/.vault_pass` |
| Хендлеры даже при падении | `--force-handlers` (или `force_handlers: true` в play) |
| Подробнее | `-v` … `-vvvv` (SSH-отладка) |
| Сбросить кэш фактов | `--flush-cache` |

## Ad-hoc и инвентарь

| Задача | Команда |
| :--- | :--- |
| Проверить доступ (SSH + Python) | `ansible -i inventory.ini all -m ansible.builtin.ping` |
| Факт с хостов | `ansible all -m ansible.builtin.setup -a 'filter=ansible_os_family'` |
| Команда на группе ⚠️ (не идемпотентно) | `ansible webservers -m ansible.builtin.command -a 'uptime'` |
| Сервис | `ansible web1 -b -m ansible.builtin.systemd -a 'name=nginx state=restarted'` |
| Дерево групп | `ansible-inventory -i inventory.ini --graph` |
| Переменные хоста после слияния | `ansible-inventory -i inventory.ini --host web1` |
| Динамический инвентарь AWS | файл `aws_ec2.yml` с `plugin: amazon.aws.aws_ec2` → `-i aws_ec2.yml` |

## Galaxy, Vault, документация

| Задача | Команда |
| :--- | :--- |
| Роли из `requirements.yml` | `ansible-galaxy role install -r requirements.yml` |
| Коллекции | `ansible-galaxy collection install -r requirements.yml` |
| Скелет роли | `ansible-galaxy role init roles/web` |
| Зашифровать файл / открыть / править | `ansible-vault encrypt vars.yml` / `view` / `edit` |
| Сменить пароль Vault | `ansible-vault rekey vars.yml` |
| Зашифровать одно значение | `ansible-vault encrypt_string 's3cr3t' --name db_password` |
| Справка по модулю | `ansible-doc ansible.builtin.file` / кратко `-s` |
| Что изменено в конфиге | `ansible-config dump --only-changed` |
| Линтер | `ansible-lint site.yml` |

## Роль

```text
roles/web/
├── defaults/main.yml   # дефолты — самый низкий приоритет
├── vars/main.yml       # переменные роли — высокий приоритет
├── tasks/main.yml
├── handlers/main.yml
└── templates/app.conf.j2
```

```yaml
- name: Создать каталог
  ansible.builtin.file:
    path: "{{ app_dir }}"
    state: directory
    mode: "0755"

- name: Конфиг из шаблона
  ansible.builtin.template:
    src: app.conf.j2
    dest: "{{ app_dir }}/app.conf"
    mode: "0644"
  notify: Reload app            # хендлер — один раз в конце play

- name: Разовая инициализация
  ansible.builtin.command: /opt/app/init.sh
  args:
    creates: /opt/app/.initialized   # иначе changed на каждом прогоне
```

## Приоритет переменных (упрощённо, снизу вверх)

| Уровень | Источник |
| :--- | :--- |
| низший | `roles/*/defaults` |
| | inventory: `group_vars/all` → `group_vars/<group>` → `host_vars/<host>` |
| | факты хоста |
| | `vars` в play, `vars_files` |
| | `roles/*/vars`, `set_fact`, `register` |
| высший | `-e` (extra vars) |

## Когда что

| Задача | Использовать | Не использовать |
| :--- | :--- | :--- |
| Каталог, файл, права | `file`, `copy`, `template` | `shell: mkdir -p` |
| Пакеты, сервисы | `apt`/`dnf`/`package`, `systemd` | `command: apt install` |
| Неизбежная команда | `command` + `creates`/`removes` или `changed_when` | голый `shell` |
| Конфиг с переменными | `template` (Jinja2) | `copy` |
| Статическое подключение роли | `import_role` (парсинг заранее, ошибки до запуска) | |
| Роль в цикле / по условию runtime | `include_role` | |
| Действие на другом хосте (LB) | `delegate_to: lb1` | отдельный play |
| Перезапуск сразу, а не в конце | `meta: flush_handlers` | |
| Ускорить старт на 1000 хостов | `gather_facts: false`, fact cache, `forks` | |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Задача всегда `changed` | `shell`/`command` без `creates`/`changed_when` — заменить модулем |
| Конфиг поменялся, сервис не перезапущен | play упал до хендлеров — `--force-handlers` |
| `UNREACHABLE` | SSH: `-vvvv`, ключ, `ansible_user`, `ansible_host` |
| `MODULE FAILURE` / нет Python | `ansible_python_interpreter`, модуль `raw` для bootstrap |
| Переменная «не та» | приоритет: `ansible-inventory --host`, `debug: var=...` |
| `--check` падает на зависимых задачах | ресурс не создан в check mode — `check_mode: false` / `when: not ansible_check_mode` |

> Проверка: ansible-core 2.21.4 — роль из сниппета (с путями scratch)
> прогнана на `localhost` (`ansible_connection=local`): `--syntax-check`,
> `--list-tasks`, `--check --diff`, повторный прогон `changed=0`, хендлер,
> `-e`, `ansible-inventory --graph`, ad-hoc `ping`/`setup`; флаги — по
> `--help`; YAML — `yamllint -d relaxed`; не проверено: `ansible-lint` (не
> установлен), `aws_ec2`-инвентарь (нет AWS).
