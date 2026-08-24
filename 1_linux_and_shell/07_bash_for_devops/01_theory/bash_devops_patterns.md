# Bash-паттерны для DevOps

Не синтаксис, а идиомы: паттерны которые встречаются в реальных скриптах
автоматизации, CI/CD пайплайнах и Dockerfile CMD/ENTRYPOINT.

## Строгий режим — всегда включать

```bash
#!/usr/bin/env bash
set -euo pipefail

# -e  : выход при ошибке любой команды
# -u  : ошибка при обращении к неустановленной переменной
# -o pipefail : ошибка если любая команда в pipe завершилась с ошибкой

# Без pipefail это успех:
cat /nonexistent | grep something   # cat вернул 1, но grep вернул 0
```

## Idempotency — скрипт можно запустить несколько раз

```bash
# Плохо: создаёт директорию, падает если уже есть
mkdir /opt/myapp

# Хорошо: идемпотентно
mkdir -p /opt/myapp

# Плохо: добавляет строку каждый раз
echo "export PATH=$PATH:/opt/myapp/bin" >> ~/.bashrc

# Хорошо: добавляет только если строки нет
grep -qxF 'export PATH=$PATH:/opt/myapp/bin' ~/.bashrc \
  || echo 'export PATH=$PATH:/opt/myapp/bin' >> ~/.bashrc

# Идемпотентная установка пакета (не падает если уже установлен)
dpkg -l nginx &>/dev/null || apt-get install -y nginx
command -v nginx &>/dev/null || apt-get install -y nginx
```

## Retry с backoff

```bash
# простой retry с экспоненциальной задержкой
retry() {
  local max_attempts=${1}
  local delay=${2:-1}
  local attempt=1
  shift 2

  while true; do
    "$@" && return 0

    if (( attempt >= max_attempts )); then
      echo "Failed after ${attempt} attempts: $*" >&2
      return 1
    fi

    echo "Attempt ${attempt}/${max_attempts} failed, retrying in ${delay}s..." >&2
    sleep "${delay}"
    (( attempt++ ))
    (( delay = delay * 2 ))   # экспоненциальный backoff
  done
}

# использование
retry 5 2 curl -f http://myservice/health
retry 3 1 kubectl wait --for=condition=ready pod -l app=myapp --timeout=60s
```

## Lockfile — предотвратить параллельный запуск

```bash
LOCK_FILE="/var/run/myscript.lock"

# через flock (рекомендуется)
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "Script already running, exiting" >&2
  exit 1
fi
# flock снимается автоматически при завершении скрипта

# через mkdir (атомарная операция)
if ! mkdir /tmp/myscript.lock 2>/dev/null; then
  echo "Script already running" >&2
  exit 1
fi
trap 'rm -rf /tmp/myscript.lock' EXIT
```

## trap — cleanup при завершении

```bash
TEMP_DIR=$(mktemp -d)
TEMP_FILE=$(mktemp)

# cleanup выполнится при любом завершении (успех, ошибка, сигнал)
cleanup() {
  rm -rf "${TEMP_DIR}" "${TEMP_FILE}"
  echo "Cleanup done"
}
trap cleanup EXIT

# Graceful shutdown (для long-running процессов)
RUNNING=true
trap 'RUNNING=false' SIGTERM SIGINT

while $RUNNING; do
  do_work
  sleep 5
done

echo "Shutting down gracefully..."
```

## Работа с JSON через jq

```bash
# получить значение
kubectl get pod mypod -o json | jq '.status.phase'

# список всех image в поде
kubectl get pod mypod -o json | jq '[.spec.containers[].image]'

# фильтровать pods в статусе Running
kubectl get pods -o json | jq '.items[] | select(.status.phase == "Running") | .metadata.name'

# обработать массив
aws ec2 describe-instances --output json \
  | jq '.Reservations[].Instances[] | {id: .InstanceId, state: .State.Name, ip: .PublicIpAddress}'

# --raw-output (-r): убрать кавычки из строк
kubectl get secret mysecret -o json | jq -r '.data.password' | base64 -d

# итерация в скрипте
while IFS= read -r line; do
  echo "Processing: $line"
done < <(kubectl get pods -o json | jq -r '.items[].metadata.name')
```

## Проверки и условия

```bash
# Проверка наличия команды
command -v kubectl &>/dev/null || { echo "kubectl not found"; exit 1; }

# Проверка переменной окружения
: "${AWS_REGION:?AWS_REGION is required}"   # выход с ошибкой если не задана
: "${DEBUG:=false}"                          # default value если не задана

# Проверка root
(( EUID == 0 )) || { echo "Run as root"; exit 1; }

# Проверка ОС
if [[ -f /etc/debian_version ]]; then
  PACKAGE_MANAGER="apt"
elif [[ -f /etc/fedora-release ]]; then
  PACKAGE_MANAGER="dnf"
fi

# Проверка версии (сравнение)
KUBECTL_VERSION=$(kubectl version --client -o json | jq -r '.clientVersion.minor')
(( KUBECTL_VERSION >= 28 )) || { echo "kubectl 1.28+ required"; exit 1; }
```

## Heredoc — многострочные строки и файлы

```bash
# создать файл
cat > /etc/myapp/config.yaml <<EOF
database:
  host: ${DB_HOST}
  port: ${DB_PORT}
  name: ${DB_NAME}
EOF

# передать stdin команде
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  key: value
EOF

# одинарные кавычки — отключить подстановку переменных
cat > /etc/script.sh <<'EOF'
echo "This $variable is not expanded"
EOF
```

## Параллельное выполнение

```bash
# запустить N задач параллельно
for server in server1 server2 server3; do
  ssh "$server" "apt-get update && apt-get upgrade -y" &
done
wait   # дождаться всех фоновых задач

# с контролем параллельности (xargs -P)
cat servers.txt | xargs -P 5 -I{} ssh {} "systemctl restart nginx"

# GNU parallel
parallel --jobs 4 ssh {} "systemctl status myapp" ::: server1 server2 server3 server4
```

## Логирование

```bash
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] ${*:2}" >&2
}

log INFO "Starting deployment"
log ERROR "Failed to connect to database"
log WARN "Disk usage above 80%"

# писать и в файл и в stderr
exec 2> >(tee -a /var/log/myscript.log >&2)
```
