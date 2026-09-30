# Раздел 3. Kubernetes

Kubernetes от архитектуры до GitOps. Упор — на понимание механики планировщика,
сети и хранилища, а не на заучивание kubectl-команд.

> Команды kubectl/helm/argocd → [`../1_sysadm_sre_devops_tools/.../kubernetes/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/3_containers_and_orchestration/kubernetes/)

## Подразделы

**Фундамент**

1. [01_architecture](./01_architecture/) — control plane (kube-apiserver, etcd,
   scheduler, controller-manager) и data plane (kubelet, kube-proxy, container runtime);
   как создание Pod проходит через всю цепочку компонентов; способы поднять
   кластер (kubeadm, Managed, Kops, Kubespray).

2. [02_workloads](./02_workloads/) — Pod lifecycle, Deployment/StatefulSet/DaemonSet/Job;
   liveness/readiness/startup probes.

3. [03_networking](./03_networking/) — Service (ClusterIP/NodePort/LoadBalancer),
   kube-proxy (iptables vs IPVS), CNI-плагины, DNS (CoreDNS), Ingress и Gateway API,
   Service Mesh (Istio); автоматизация вокруг Ingress (ExternalDNS, cert-manager, MetalLB).

4. [04_storage](./04_storage/) — PersistentVolume/PVC/StorageClass; CSI-драйверы;
   динамический провижининг; ReadWriteMany vs ReadWriteOnce; StatefulSet и storage.

5. [05_scheduling](./05_scheduling/) — как работает kube-scheduler: filtering,
   scoring, affinity/anti-affinity, taints и tolerations, PodDisruptionBudget;
   QoS классы (Guaranteed/Burstable/BestEffort) и их влияние на eviction;
   ResourceQuota и LimitRange (multi-tenancy на уровне namespace).

6. [06_security](./06_security/) — безопасность кластера, двумя подтемами:
   - [01_core](./06_security/01_core/) — RBAC (Role/ClusterRole/RoleBinding),
     ServiceAccount и OIDC-аутентификация; SecurityContext и Pod Security Admission;
     NetworkPolicy (Zero Trust); секреты (ESO, SOPS); runtime security (Falco); аудит.
     Основы — за инструментами и готовыми скриптами аудита → [`../10_devsecops/`](../10_devsecops/).
   - [02_policy_engines](./06_security/02_policy_engines/) — OPA Gatekeeper
     (Rego, ConstraintTemplate) vs Kyverno (нативный YAML, Validate/Mutate); failurePolicy.

**Манифесты и деплой**

7. [07_gitops](./07_gitops/) — GitOps: общая теория (Push vs Pull, Drift, Image
   Updater, секреты) и три конкретных инструмента:
   - [02_argocd](./07_gitops/02_argocd/) — Application, ApplicationSet/App-of-Apps, SyncWaves.
   - [03_fluxcd](./07_gitops/03_fluxcd/) — Source Controller, Kustomize/Helm Controller,
     Image Automation; Flux vs ArgoCD.
   - [04_argo_rollouts](./07_gitops/04_argo_rollouts/) — прогрессивная доставка:
     Canary (steps, AnalysisTemplate с автоматическим rollback по метрикам), Blue/Green.

8. [08_cluster_operations](./08_cluster_operations/) — эксплуатация кластера,
   двумя подтемами:
   - [01_core](./08_cluster_operations/01_core/) — cordon/drain, обновление
     кластера, etcd backup/Velero, ротация сертификатов; troubleshooting
     (CrashLoopBackOff, OOMKilled, Pending, ImagePullBackOff — что реально смотреть).
   - [02_node_autoscaling](./08_cluster_operations/02_node_autoscaling/) — Cluster
     Autoscaler vs Karpenter (JIT provisioning), Consolidation/bin-packing.

9. [09_manifests_management](./09_manifests_management/) — работа с манифестами:
   общая теория (labels, Client-Side vs Server-Side Apply, dry-run/diff) и два
   инструмента:
   - [02_helm](./09_manifests_management/02_helm/) — chart структура, values,
     templating, зависимости, helm diff, helmfile.
   - [03_kustomize](./09_manifests_management/03_kustomize/) — bases/overlays,
     ConfigMapGenerator и авто-Rolling-Update, Strategic Merge vs JSON Patch,
     `$patch: delete`.

**Автоскейлинг подов и расширение кластера**

10. [10_pod_autoscaling](./10_pod_autoscaling/) — HPA (формула, метрики,
    stabilization window), VPA (и почему не уживается с HPA), KEDA (event-driven,
    scale-to-zero).

11. [11_operators_and_crds](./11_operators_and_crds/) — CRD как схема данных,
    Operator как reconcile loop, идемпотентность; где в этой базе уже
    встречались Operators (cert-manager, ESO, Karpenter).

12. [12_k8s_ecosystem](./12_k8s_ecosystem/) — справочная карта: альтернативные
    дистрибутивы (OpenShift, Rancher, k3s), инструменты (k9s, kubectx, stern),
    куда смотреть дальше. Без упражнений — это не тема для лабы.

## Как проходить

01 → 02 → 03 строго по порядку (фундамент). 04–06 параллельно.
07 → 09 (GitOps и манифесты — общая теория каждого раздела, потом конкретные
инструменты внутри) — практический стек деплоя. 10–11 — по мере необходимости.
08, 12 — справочные/операционные, открывать по задаче.

## Упражнения — тиры

🐳 Tier 1: большинство упражнений на kind (Kubernetes in Docker)
🖥 Tier 2: kubeadm-кластер из 3 VM для разделов 05, 06, 08
☁️ Без лабы: 08_cluster_operations/02_node_autoscaling — Cluster Autoscaler/Karpenter
требуют реальное облако
