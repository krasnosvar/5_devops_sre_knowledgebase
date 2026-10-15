# 05. Финальный проект (capstone): URL-shortener от VM до SRE

## Зачем

Темы базы по отдельности не показывают, как инструменты стыкуются друг с
другом. Здесь одно маленькое приложение (FastAPI + Redis, папка
[app/](app/)) проходит весь путь: процесс на голом Linux → контейнер →
Kubernetes → IaC → CI/CD → мониторинг → SRE-практики → безопасность.
На каждом этапе видно, какую проблему решает следующий инструмент.

**Проект делается в конце курса**, а не на шаге 0: папка лежит в
`0_lab_setup/` только потому, что использует стенды этого раздела. Каждый
этап опирается на пройденный раздел базы.

## Пререквизиты

| Этап | Нужен раздел | Что именно оттуда |
|------|--------------|-------------------|
| [01_bare_linux](01_bare_linux/) | [1_linux_and_shell](../../1_linux_and_shell/) | процессы, systemd, journalctl |
| [02_containerize](02_containerize/) | [3_containers](../../3_containers/) | слои образа, multi-stage, non-root, compose |
| [03_kubernetes](03_kubernetes/) | [4_kubernetes](../../4_kubernetes/) | Deployment, Service, probes |
| [04_iac](04_iac/) | [5_iac](../../5_iac/) | Terraform, Ansible, идемпотентность; kubeadm — [4_kubernetes/08_cluster_operations](../../4_kubernetes/08_cluster_operations/) |
| [05_cicd](05_cicd/) | [6_cicd](../../6_cicd/) | GitLab CI, тесты в пайплайне, registry; git |
| [06_observability](06_observability/) | [8_observability](../../8_observability/) | Prometheus, PromQL, Grafana, алерты |
| [07_sre_incident](07_sre_incident/) | [9_sre](../../9_sre/) | SLI/SLO, error budget, постмортем |
| [08_security](08_security/) | [10_devsecops](../../10_devsecops/) | скан образов, PSA, NetworkPolicy, RBAC |

Стенды — из этого же раздела: VM из
[02_local_vms/linux_kvm](../02_local_vms/linux_kvm/), кластер из
[03_local_k8s](../03_local_k8s/).

## Файлы

- [app/](app/) — приложение: `main.py` (API + метрики Prometheus),
  `test_app.py`, `requirements.txt`, `Dockerfile` (multi-stage, non-root).
- `01_bare_linux/` … `05_cicd/` — пошаговые инструкции с готовыми
  конфигами (systemd unit, compose, манифесты, Ansible, `.gitlab-ci.yml`).
- `06_observability/`, `07_sre_incident/`, `08_security/` — задания в
  `README.md`, решения в `ANSWERS.md` и `answers/`.

## Как проходить

1. Этапы идут строго по порядку: каждый использует результат предыдущего.
2. Перед этапом проверить, что соответствующий раздел из таблицы пройден.
3. Для этапов 6–8 сначала сделать задание самостоятельно, затем сверить с
   `ANSWERS.md`.
4. В конце каждого этапа удалить стенд (`terraform destroy`,
   `docker compose down -v`, `kind delete cluster`).

## Когда двигаться дальше

- Можете объяснить, что именно каждый этап добавил по сравнению с
  предыдущим (изоляция, самовосстановление, воспроизводимость,
  автоматизация, наблюдаемость, надёжность, безопасность).
- Можете без подсказки поднять приложение в kind с hardened-манифестами
  и алертами Prometheus.
- Дальше — [11_mlops](../../11_mlops/) или
  [12_interview_questions_prep](../../12_interview_questions_prep/).
