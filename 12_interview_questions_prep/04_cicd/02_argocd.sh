# 1. Что такое ArgoCD и какую модель GitOps он реализует?
ArgoCD — агент непрерывной доставки для Kubernetes, работающий по
Pull-модели (GitOps, см. `00_fundamentals.sh`, вопрос 4): он сам
внутри кластера постоянно сравнивает состояние Git-репозитория
(желаемое состояние) с реальным состоянием ресурсов в кластере и
автоматически приводит кластер к тому, что описано в Git — в
отличие от классического CI-пайплайна, который САМ пушит `kubectl
apply` наружу в кластер (Push-модель).

# 2. Что такое Application в терминах ArgoCD и из чего он состоит?
Application — основной custom resource ArgoCD, описывающий один
деплоймент.
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
spec:
  source:
    repoURL: https://git.example.com/infra/my-app.git
    path: manifests/prod
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
- `source` — где лежат манифесты (Git-репо, путь, ветка/тег).
- `destination` — в какой кластер/namespace деплоить.
- `syncPolicy.automated` — включает автоматическую синхронизацию
  без ручного нажатия кнопки Sync.

# 3. Что означают флаги `prune` и `selfHeal` в `syncPolicy`?
- **prune** — если ресурс был удалён из Git (манифест убрали из
  репозитория), ArgoCD удалит соответствующий ресурс и из кластера.
  Без этого флага удалённые из Git ресурсы останутся висеть в
  кластере молча.
- **selfHeal** — если кто-то руками поменял ресурс в кластере
  напрямую через `kubectl edit` (в обход Git), ArgoCD откатит это
  изменение обратно к состоянию из Git при следующей сверке —
  обеспечивает, что Git остаётся единственным источником истины.

# 4. Что такое ApplicationSet и зачем он нужен?
Custom resource, который автоматически генерирует МНОЖЕСТВО
Application-ресурсов (вопрос 2) из одного шаблона и генератора
(List, Git-директорий, кластеров) — используется, когда нужно
деплоить один и тот же набор манифестов в десятки окружений/
кластеров/namespace, не создавая Application-манифест для каждого
вручную.

# 5. Что такое App of Apps паттерн?
Подход, при котором один "корневой" ArgoCD Application сам
указывает на Git-репозиторий, содержащий манифесты ДРУГИХ
Application-ресурсов — таким образом весь набор приложений кластера
разворачивается и управляется через единственную точку входа
(применил один корневой Application — ArgoCD сам создал и
просинхронизировал все дочерние).

# 6. Какие статусы Sync Status и Health Status показывает ArgoCD, и
чем они отличаются?
- **Sync Status** (Synced/OutOfSync) — отвечает на вопрос "совпадают
  ли манифесты в кластере с тем, что лежит в Git прямо сейчас".
- **Health Status** (Healthy/Progressing/Degraded) — отвечает на
  вопрос "работает ли сам ресурс фактически" (например, Deployment
  может быть Synced, но Degraded, если под не может подняться
  из-за CrashLoopBackOff).
Оба статуса независимы: ресурс может быть синхронизирован с Git, но
при этом быть нездоровым в runtime.

# 7. Как ArgoCD работает с Helm-чартами и Kustomize напрямую, без
отдельного шага `helm template`/`kustomize build` в CI?
ArgoCD сам умеет распознавать тип манифестов в указанном `path` —
если там `Chart.yaml`, он сам выполнит рендеринг Helm-чарта
(с возможностью передать `values` прямо в `spec.source.helm.values`
Application-а); если там `kustomization.yaml` — выполнит `kustomize
build`. Поэтому CI-пайплайну (см. `00_fundamentals.sh`) больше не
нужно самому рендерить манифесты и пушить готовый YAML — достаточно
обновить версию образа/тег в Git, а рендеринг и применение берёт на
себя ArgoCD.
