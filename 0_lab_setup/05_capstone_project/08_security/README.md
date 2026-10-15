# Шаг 8 — Security: образ, поды, сеть и права CI

🐳 Tier 1 (kind/k3d из шага 3). Теория — [10_devsecops](../../../10_devsecops/):
[04_image_security](../../../10_devsecops/04_image_security/),
[05_pod_security](../../../10_devsecops/05_pod_security/),
[03_network_policy](../../../10_devsecops/03_network_policy/),
[01_k8s_rbac](../../../10_devsecops/01_k8s_rbac/).

На шаге 3 манифесты были намеренно минимальными: поды без
`securityContext`, любой под может ходить в Redis, а пайплайн шага 5
деплоит с kubeconfig, у которого, скорее всего, права cluster-admin.
Здесь это закрываем.

## Задание

1. **Образ.** Просканировать `shortener:local` сканером уязвимостей
   (Trivy) и разобрать отчёт: какие находки в базовом образе, какие — в
   Python-зависимостях; что из этого исправляется обновлением.
2. **Pod Security.** Включить для namespace `shortener` Pod Security
   Admission уровня `restricted` и довести манифесты
   [03_kubernetes/manifests](../03_kubernetes/manifests/) до того, чтобы они
   проходили этот профиль: non-root, без повышения привилегий, без
   capabilities, seccomp `RuntimeDefault`, read-only root filesystem.
3. **NetworkPolicy.** Default deny на ingress в namespace; в Redis
   пускать только поды shortener; shortener доступен на 8000.
   Проверить, что под из другого namespace не достучится до Redis.
4. **RBAC для CI.** Создать ServiceAccount для job `deploy` из шага 5 с
   минимальными правами: обновить образ Deployment в namespace
   `shortener` и дождаться rollout — и ничего больше. Проверить через
   `kubectl auth can-i`.

Решение — [ANSWERS.md](ANSWERS.md) и манифесты в [answers/](answers/).
