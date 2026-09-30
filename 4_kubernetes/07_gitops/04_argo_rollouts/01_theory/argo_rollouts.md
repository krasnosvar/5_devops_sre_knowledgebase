# Argo Rollouts: Canary и Blue/Green деплой

## Содержание
1. [Зачем Rollout, если есть Deployment](#1-зачем-rollout-если-есть-deployment)
2. [Canary: steps, setWeight, pause](#2-canary-steps-setweight-pause)
3. [AnalysisTemplate: автоматический rollback по метрикам](#3-analysistemplate-автоматический-rollback-по-метрикам)
4. [Blue/Green: preview vs active Service](#4-bluegreen-preview-vs-active-service)
5. [Типовые вопросы на собеседовании (Interview Q&A)](#5-типовые-вопросы-на-собеседовании-interview-qa)

> Работает поверх GitOps (см. [`../../01_theory/`](../../01_theory/), [`../../02_argocd/`](../../02_argocd/)), но это отдельный CRD/контроллер — ставится и используется независимо от ArgoCD.

---

## 1. Зачем Rollout, если есть Deployment

Обычный Kubernetes `Deployment` умеет только `RollingUpdate` (см. [`../../../02_workloads/`](../../../02_workloads/) §2): он ничего не знает о метриках приложения и не умеет управлять пропорцией трафика между старой и новой версией — только количеством подов. Если новая версия технически `Ready` (прошла Readiness Probe), но у неё, например, растёт HTTP 500 — Deployment продолжит raскатку, он этого просто не видит.

**`Rollout`** — Custom Resource (замена Deployment, тот же `spec.template`, но другая стратегия обновления), которым управляет отдельный контроллер `argo-rollouts`. Он умеет:
- постепенно подавать трафик на новую версию, а не просто менять количество подов (**Canary**);
- запрашивать метрики (Prometheus, Datadog) на каждом шаге и автоматически откатываться, если что-то пошло не так (**AnalysisTemplate**);
- держать две полные копии приложения одновременно и переключать трафик одним движением (**Blue/Green**).

## 2. Canary: steps, setWeight, pause

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 10
  strategy:
    canary:
      steps:
        - setWeight: 5        # 5% трафика на новую версию, 95% на старую
        - pause: {duration: 5m}
        - setWeight: 25
        - pause: {duration: 5m}
        - setWeight: 50
        - pause: {}            # пауза БЕЗ duration — ждёт ручной `promote`
  selector:
    matchLabels: {app: myapp}
  template:
    metadata:
      labels: {app: myapp}
    spec:
      containers:
        - name: myapp
          image: myapp:v2
```

Для реального управления трафиком (не просто пропорцией количества подов) Rollout интегрируется с Ingress-контроллером или Service Mesh (см. [`../../../03_networking/`](../../../03_networking/) §4) — NGINX, Istio, ALB — которые физически умеют направлять X% запросов на один набор подов, а не просто масштабировать их количество.

## 3. AnalysisTemplate: автоматический rollback по метрикам

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
    - name: error-rate
      interval: 1m
      successCondition: result[0] < 0.05      # меньше 5% ошибок — ОК
      failureLimit: 2                          # 2 провала подряд — стоп
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{status=~"5.."}[1m]))
            /
            sum(rate(http_requests_total[1m]))
```

Rollout привязывает `AnalysisTemplate` к шагам Canary (`analysis: {templates: [{templateName: success-rate}]}`). На каждом шаге контроллер сам запрашивает Prometheus. Если условие `successCondition` не выполняется `failureLimit` раз подряд — Rollout автоматически откатывает трафик на старую версию (`setWeight: 0`) без участия человека. Это принципиальное отличие от обычного RollingUpdate: там "здоровье" версии проверяется только по Readiness Probe одного пода, здесь — по агрегированным бизнес-метрикам всего трафика.

## 4. Blue/Green: preview vs active Service

```yaml
spec:
  strategy:
    blueGreen:
      activeService: myapp-active     # получает продакшен-трафик
      previewService: myapp-preview   # новая версия, доступна только для проверки
      autoPromotionEnabled: false     # ждать ручного promote
```

В отличие от Canary (постепенно, по проценту), Blue/Green держит **обе версии полностью запущенными одновременно**: старая (`active`) продолжает обслуживать весь прод-трафик, новая (`preview`) доступна только через отдельный Service для внутреннего тестирования (QA, smoke-тесты). Переключение — не постепенное, а мгновенное: `previewService` становится `activeService` одной командой (`kubectl argo rollouts promote`). Откат так же мгновенен — старая версия никуда не делась, трафик просто возвращается на неё.

---

## 5. Типовые вопросы на собеседовании (Interview Q&A)

**1. Зачем нужен `Argo Rollouts` и чем он отличается от обычного `Deployment` в контексте прогрессивной доставки?**
*Ответ:* Обычный Deployment умеет делать только базовый `RollingUpdate` — замену подов, ничего не зная о метриках приложения. `Argo Rollouts` — Custom Resource, заменяющий Deployment, который умеет делать управляемый Canary и Blue/Green деплой: постепенно подаёт трафик на новую версию (например, 5%), запрашивает метрики из Prometheus, и если ошибок нет — автоматически увеличивает трафик дальше. Если метрики плохие — делает автоматический rollback.

**2. В Canary-стратегии шаг `pause: {}` не имеет `duration`. Что произойдёт с деплоем на этом шаге и как его продолжить?**
*Ответ:* `pause: {}` без `duration` — это бесконечная пауза: Rollout остановит прогресс ровно на этом шаге и будет ждать неограниченно долго, пока кто-то не вмешается вручную. Это осознанный gate для ручного подтверждения (например, "покажи QA, пусть проверят staging-трафик перед тем как катить на 100%"). Продолжить можно командой `kubectl argo rollouts promote myapp`, которая передвигает Rollout к следующему шагу.

**3. Чем `AnalysisTemplate` в Argo Rollouts принципиально отличается от обычного `readinessProbe` пода?**
*Ответ:* `readinessProbe` проверяет здоровье **одного конкретного пода** (обычно локальным HTTP/TCP-запросом) и решает, включать ли его в Service. `AnalysisTemplate` оценивает **агрегированные метрики всего трафика** новой версии сразу (запросы к Prometheus/Datadog за интервал времени) — например, реальный процент HTTP 500 у пользователей, а не факт того, что процесс отвечает на `/healthz`. Под может быть технически `Ready`, но при этом отдавать 20% ошибок бизнес-логики — это `AnalysisTemplate` поймает, а `readinessProbe` нет.

**4. В чём принципиальная разница между Canary и Blue/Green стратегиями с точки зрения используемых ресурсов кластера?**
*Ответ:* Canary постепенно наращивает количество подов новой версии, одновременно уменьшая старую — в моменте работает где-то между 100% старой и 100% новой версии, суммарное количество подов растёт лишь не намного больше базового. Blue/Green держит **обе версии полностью запущенными одновременно** (весь `replicas` и старой, и новой версии) до момента переключения — это требует вдвое больше ресурсов на время проверки, но даёт мгновенный и полностью предсказуемый откат: старая версия просто продолжает крутиться нетронутой.

**5. Разработчик хочет протестировать новую версию приложения реальными QA-инженерами до того, как на неё пойдёт хоть один процент боевого трафика. Какая стратегия Argo Rollouts для этого предназначена и как это работает?**
*Ответ:* Blue/Green с `previewService`. Новая версия разворачивается полностью (весь `replicas`), но получает трафик только через отдельный `previewService`, не связанный с продакшен-балансировщиком. QA заходит именно на `previewService` и тестирует новую версию в изоляции, пока `activeService` продолжает обслуживать 100% реальных пользователей старой версией. Только после ручного `promote` `previewService` становится новым `activeService`, и весь боевой трафик мгновенно переключается.
