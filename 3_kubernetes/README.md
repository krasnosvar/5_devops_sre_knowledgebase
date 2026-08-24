# Раздел 3. Kubernetes

Kubernetes от архитектуры до GitOps. Упор — на понимание механики планировщика,
сети и хранилища, а не на заучивание kubectl-команд.

> Команды kubectl/helm/argocd → [`../1_sysadm_sre_devops_tools/.../kubernetes/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/3_containers_and_orchestration/kubernetes/)

## Подразделы

1. [01_architecture](./01_architecture/) — control plane (kube-apiserver, etcd,
   scheduler, controller-manager) и data plane (kubelet, kube-proxy, container runtime);
   как создание Pod проходит через всю цепочку компонентов.

2. [02_workloads](./02_workloads/) — Pod lifecycle, Deployment/StatefulSet/DaemonSet/Job;
   QoS классы (Guaranteed/Burstable/BestEffort) и их влияние на eviction;
   liveness/readiness/startup probes.

3. [03_networking](./03_networking/) — Service (ClusterIP/NodePort/LoadBalancer),
   kube-proxy (iptables vs IPVS), CNI-плагины (Cilium, Calico, Flannel);
   DNS (CoreDNS); Ingress и Gateway API.

4. [04_storage](./04_storage/) — PersistentVolume/PVC/StorageClass; CSI-драйверы;
   динамический провижининг; ReadWriteMany vs ReadWriteOnce; StatefulSet и storage.

5. [05_scheduling](./05_scheduling/) — как работает kube-scheduler: filtering,
   scoring, affinity/anti-affinity, taints и tolerations, PodDisruptionBudget,
   resource requests vs limits.

6. [06_rbac_and_security](./06_rbac_and_security/) — ServiceAccount, Role/ClusterRole,
   RoleBinding; admission controllers; Pod Security Standards (restricted/baseline);
   NetworkPolicy как L3/L4 firewall.

7. [07_helm](./07_helm/) — chart структура, values, templating, зависимости,
   helm diff, helmfile для multi-env; типичные ошибки при написании чартов.

8. [08_gitops](./08_gitops/) — GitOps паттерн: push-based vs pull-based; ArgoCD
   (ApplicationSet, Sync Waves, resource hooks); Kustomize overlays + ArgoCD;
   стратегии деплоя (blue/green, canary) через Argo Rollouts.

9. [09_cluster_operations](./09_cluster_operations/) — обновление кластера,
   node drain/cordon, etcd backup/restore, troubleshooting (crashloop, OOMKill,
   pending pods, imagePullBackOff).

## Как проходить

01 → 02 → 03 строго по порядку (фундамент). 04–06 параллельно.
07–08 после освоения базы — практический GitOps-стек. 09 — по мере необходимости.

## Упражнения — тиры

🐳 Tier 1: большинство упражнений на kind (Kubernetes in Docker)
🖥 Tier 2: kubeadm-кластер из 3 VM для разделов 05, 06, 09
