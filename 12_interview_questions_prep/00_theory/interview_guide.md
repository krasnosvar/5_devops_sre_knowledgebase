# DevOps / SRE Interview Guide

## Структура интервью

Типичное DevOps/SRE интервью состоит из:
1. **Coding** — bash/Python/Go скрипты, алгоритмы (иногда)
2. **Linux / System Fundamentals** — процессы, сеть, диски
3. **Kubernetes / Containers** — debugging, networking, security
4. **CI/CD / IaC** — пайплайны, Terraform
5. **Observability** — мониторинг, логи, трейсинг
6. **System Design** — спроектируй X
7. **Behavioral** — STAR метод про прошлый опыт

---

## Linux — типичные вопросы

**Q: Как найти процесс занимающий наибольше памяти?**
```bash
ps aux --sort=-%mem | head -10
# или
top → нажать M (sort by memory)
# или
cat /proc/PID/status | grep VmRSS
```

**Q: В чём разница между zombie и orphan процессом?**
- Zombie: завершился, но родитель не вызвал wait(). Запись в таблице есть, ресурсов нет.
- Orphan: родитель умер, процесс переусыновлён PID 1.

**Q: Как работает fork()?**
Создаёт точную копию процесса (copy-on-write). Возвращает 0 в дочернем, PID дочернего в родительском.

**Q: Что такое inode?**
Метаданные файла: тип, права, UID, размер, timestamps, указатели на блоки. Имя хранится в директории.

**Q: Как мониторить открытые файловые дескрипторы?**
```bash
lsof -p PID | wc -l
ls /proc/PID/fd | wc -l
cat /proc/sys/fs/file-nr   # системный лимит
```

---

## Kubernetes — типичные вопросы

**Q: Pod застрял в Pending. Что делать?**
```bash
kubectl describe pod mypod   # смотреть Events
# Причины: нет подходящей ноды (ресурсы, taint, affinity), нет PVC
kubectl describe nodes | grep -A5 "Allocated resources"
kubectl get events --field-selector reason=FailedScheduling
```

**Q: Что такое CrashLoopBackOff?**
Контейнер запускается, падает, k8s перезапускает с экспоненциальной задержкой.
```bash
kubectl logs mypod --previous   # логи предыдущего запуска
kubectl describe pod mypod | grep -A5 "Last State"
```

**Q: В чём разница между livenessProbe и readinessProbe?**
- liveness: жив ли контейнер? Failure → restart
- readiness: готов ли принимать трафик? Failure → убрать из Service Endpoints (трафик не идёт, restart нет)

**Q: Как работает Service ClusterIP?**
Виртуальный IP который не привязан ни к какому интерфейсу. kube-proxy создаёт правила iptables/IPVS: трафик на ClusterIP:Port → DNAT → Pod IP:Port.

**Q: В чём разница Deployment и StatefulSet?**
- Deployment: Pod'ы взаимозаменяемы, случайные имена, нет стабильного storage
- StatefulSet: стабильные имена (pod-0, pod-1), стабильный DNS, свой PVC для каждого Pod

**Q: Как работает RBAC в k8s?**
Subject (User/ServiceAccount) + RoleBinding/ClusterRoleBinding → Role/ClusterRole → rules (apiGroups + resources + verbs).

---

## CI/CD — типичные вопросы

**Q: В чём разница push-based и pull-based CD?**
- Push: pipeline → kubectl apply → кластер. CI нужны credentials кластера.
- Pull: ArgoCD внутри кластера смотрит в Git и сам применяет. Credentials не покидают кластер. Drift detection.

**Q: Как безопасно хранить секреты в CI?**
- GitLab: Protected variables + masked
- GitHub: Repository/Environment secrets
- Лучше: OIDC → временные credentials (без статических ключей)

---

## System Design — DevOps задачи

### Спроектируй CI/CD платформу для 500 разработчиков

```
Требования:
- 500 devs, 200 репозиториев, 1000 pipelines/день
- SLA 99.9%, P50 pipeline time < 10 мин
- Секреты, артефакты, мониторинг

Решение:
1. GitLab CE / GitHub Enterprise — source of truth
2. GitLab Runners / GitHub Actions self-hosted на spot VM
   - Kubernetes executor для изоляции (каждый job в Pod)
   - Auto-scaling (KEDA / GitLab runner autoscale)
3. Container Registry — Harbor или GHCR
4. Артефакты — S3 + CDN для быстрой раздачи
5. Secrets — Vault + OIDC (GitLab JWT)
6. Monitoring — Prometheus + Grafana (pipeline duration, queue depth, failure rate)
7. Кэш — distributed cache (Redis или S3 caching) для зависимостей
```

### Спроектируй observability стек для 100 микросервисов

```
Метрики: Prometheus → VictoriaMetrics (долгосрочное хранение) → Grafana
Логи: Alloy → Loki → Grafana
Трейсинг: OTel Collector → Tempo → Grafana
Алертинг: Alertmanager → PagerDuty/Slack

Correlation:
- trace_id в логах → клик → Tempo
- span metrics (из трейсов) → Prometheus
- Grafana Unified Alerting — один источник

Масштаб:
- VictoriaMetrics: горизонтально масштабируется, меньше ресурсов чем Prometheus
- Loki: S3 как хранилище (дёшево), compactors для дедупликации
- Tempo: S3 хранение (только trace data, не индекс)
```

---

## Behavioral — STAR метод

**S**ituation — контекст  
**T**ask — твоя задача  
**A**ction — что сделал  
**R**esult — результат (измеримый)

Пример ответа на "Расскажи о сложном инциденте":

> Situation: Production БД упала в пятницу вечером, сайт недоступен 40 минут.
> Task: Восстановить сервис и предотвратить повтор.
> Action: Немедленно откатил последний деплой (не помогло), проверил метрики —
> увидел резкий рост connections до max_connections. Нашёл N+1 запрос в новом коде.
> Временно поднял max_connections, дал сервису ожить, потом задеплоил фикс.
> Result: Downtime 40 мин, написал postmortem, добавил алерт на connections/sec,
> добавил query count метрику в code review checklist. Повторов не было.

---

## Что читать для подготовки

- [Google SRE Book](https://sre.google/sre-book/) — главы про SLO, toil, incident management
- [Kubernetes docs — Concepts](https://kubernetes.io/docs/concepts/) — перечитать фундаментальные разделы
- [Designing Data-Intensive Applications](https://dataintensive.net/) — для senior уровня
- Killercoda CKA scenarios — практика kubectl под давлением
