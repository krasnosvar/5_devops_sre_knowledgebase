# Раздел 10. DevSecOps

Безопасность как часть DevOps-процесса: не аудит раз в год, а автоматические
проверки в каждом pipeline и правильные паттерны с нуля.

> **Разделение уровней:** основы security на каждом слое стека (права доступа
> в Linux, изоляция контейнеров, RBAC/NetworkPolicy в k8s) разобраны рядом с
> самим слоем — этот раздел не повторяет их, а даёт инструменты, готовые
> скрипты аудита и практики, которые применяются поверх этих основ:
> [`../1_linux_and_shell/09_linux_security/`](../1_linux_and_shell/09_linux_security/),
> [`../3_containers/05_security/`](../3_containers/05_security/),
> [`../4_kubernetes/06_security/`](../4_kubernetes/06_security/).

## Подразделы

1. [01_k8s_rbac](./01_k8s_rbac/) — Kubernetes RBAC: ServiceAccount, Role/ClusterRole,
   RoleBinding; принцип наименьших привилегий; типичные антипаттерны (cluster-admin
   для всего, wildcards в rules); аудит RBAC с kubectl-who-can, rakkess.

2. [02_secrets_management](./02_secrets_management/) — почему k8s Secret небезопасен
   по умолчанию (base64 ≠ шифрование); Vault (HashiCorp / OpenBao): secret engines,
   dynamic secrets, PKI; External Secrets Operator — мост между Vault и k8s;
   Sealed Secrets для GitOps.

3. [03_network_policy](./03_network_policy/) — NetworkPolicy как L3/L4 firewall
   в k8s: default-deny паттерн, egress/ingress правила; ограничения (не L7, нет
   логирования); Cilium NetworkPolicy как расширение (L7, FQDN).

4. [04_image_security](./04_image_security/) — безопасность образов: Trivy и Grype
   для сканирования CVE; минимальные образы (distroless, scratch); подписание
   образов (Cosign/Sigstore), verification при деплое; OPA/Kyverno policy
   для запрета образов без сигнатуры.

5. [05_pod_security](./05_pod_security/) — Pod Security Standards (restricted/
   baseline/privileged); securityContext: runAsNonRoot, readOnlyRootFilesystem,
   capabilities, allowPrivilegeEscalation; OPA Gatekeeper и Kyverno как
   admission controllers.

6. [06_supply_chain](./06_supply_chain/) — supply chain security: SBOM (Software
   Bill of Materials) через Syft; SLSA framework уровни; Sigstore (Cosign,
   Rekor, Fulcio) для подписания артефактов; атаки на supply chain и защита.

7. [07_sast_in_ci](./07_sast_in_ci/) — статический анализ в CI: Semgrep для
   кода, Checkov и tfsec для Terraform, kubesec для манифестов, hadolint для
   Dockerfile; как интегрировать без превращения CI в узкое место.

8. [08_runtime_security](./08_runtime_security/) — защита в runtime: Falco
   (eBPF-based, обнаружение аномального поведения в k8s), audit log для
   kubernetes API server; реакция на инциденты в контейнерной среде.

## Как проходить

01 → 02 → 03 → 04 — базовый security-стек для k8s. 05 → 06 → 07 → 08 —
углублённые темы по мере роста зрелости.

## Упражнения — тиры

🐳 Tier 1: Trivy, Semgrep, Checkov локально; Vault в Docker Compose
🖥 Tier 2: External Secrets Operator + Vault в kind кластере, Falco
