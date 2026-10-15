# 06. Ansible

## Зачем

Terraform создаёт VM, но не настраивает то, что внутри: пакеты,
конфиги, сервисы. Ansible делает это по SSH без агентов и идемпотентно
— повторный запуск ничего не меняет, если сервер уже в нужном
состоянии. Здесь — inventory, playbook, роли, handlers, vault.

## Пререквизиты

- [1_linux_and_shell](../../1_linux_and_shell/) — SSH, пакеты, systemd,
  права файлов.
- [0_lab_setup/02_local_vms](../../0_lab_setup/02_local_vms/) — стенд из
  2 VM (KVM через Terraform, `base_lab.tf`; или Multipass/OrbStack).
- [01_terraform_core](../01_terraform_core/) — для подъёма стенда
  (`terraform plan`/`apply`/`output`).

## Файлы

- [01_theory/ansible.md](./01_theory/ansible.md) — push-модель,
  идемпотентность, модули vs shell, роли, handlers.
- [02_examples/inventory.yaml](./02_examples/inventory.yaml) — группы
  webservers/databases для KVM-стенда.
- [02_examples/site.yaml](./02_examples/site.yaml) — playbook: nginx,
  сайт, `/health`, handlers.
- [03_exercises/README.md](./03_exercises/README.md) — 5 упражнений,
  🖥 Tier 2.
- [04_exercises_answers/ansible-answers.md](./04_exercises_answers/ansible-answers.md) —
  ответы; роль [roles/nginx/](./04_exercises_answers/roles/nginx/),
  playbook'и [site-role.yaml](./04_exercises_answers/site-role.yaml),
  [vault-demo.yaml](./04_exercises_answers/vault-demo.yaml),
  [site-idempotent.yaml](./04_exercises_answers/site-idempotent.yaml).

## Как проходить

1. Прочитать теорию.
2. Поднять 2 VM и вписать их IP в `inventory.yaml`.
3. Сделать упражнения 01-05; перед каждым реальным запуском —
   `--syntax-check` и `--check --diff`.
4. Сверить с ответами; в конце `terraform destroy` стенда.

## Когда двигаться дальше

- Можете без подсказки написать роль с шаблоном, defaults и handlers.
- Можете доказать идемпотентность playbook (второй запуск —
  `changed=0`) и найти задачу, которая её ломает.
- Можете объяснить, где Ansible, а где Terraform (конфигурация vs
  провижининг).

Следующая тема: [07_iac_patterns](../07_iac_patterns/).
