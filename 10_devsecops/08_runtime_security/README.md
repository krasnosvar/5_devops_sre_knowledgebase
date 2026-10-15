# 08. Runtime Security

## Зачем
Статические проверки не видят того, что происходит после запуска:
shell в контейнере, чтение `/etc/shadow`, неожиданные соединения.
Тема: Falco для обнаружения аномалий, audit log API server и порядок
действий при инциденте в контейнерной среде.

## Пререквизиты
- [1_linux_and_shell/08_performance_and_ebpf](../../1_linux_and_shell/08_performance_and_ebpf/)
  — syscalls и eBPF, на которых работает Falco.
- [05_pod_security](../05_pod_security/) — что должно было не допустить
  атаку до runtime.
- Helm: подробно в
  [4_kubernetes/07_manifests_management](../../4_kubernetes/07_manifests_management/);
  здесь достаточно `helm repo add` и `helm install`.

## Файлы
- [01_theory/runtime_security.md](./01_theory/runtime_security.md) —
  Falco, Kubernetes audit log, incident response, NetworkPolicy для
  изоляции.
- [02_examples/falco-rules.yaml](./02_examples/falco-rules.yaml) —
  пользовательские правила Falco.
- Упражнений нет: Falco требует доступа к ядру ноды, проверка — по
  примеру в 🖥 Tier 2 (kind на Linux VM).

## Как проходить
1. Прочитать теорию.
2. Установить Falco в kind кластер, подключить `falco-rules.yaml`.
3. Сделать `kubectl exec ... -- sh` и найти событие в логах Falco.

## Когда двигаться дальше
- Можете объяснить, чем `modern_ebpf` драйвер отличается от kernel
  module.
- Можете перечислить шаги реакции на скомпрометированный Pod и почему
  его нельзя сразу удалять.

Далее: раздел [11_mlops](../../11_mlops/).
