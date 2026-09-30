# Шаг 1 — голый Linux: процесс + systemd, без контейнеров

🐳 Tier 1 (VM внутри Tier 2 — см. [../../02_local_vms/linux_kvm](../../02_local_vms/linux_kvm/))

Цель шага — прогнать полный цикл "код → работающий сервис" руками, без Docker
и k8s, чтобы на следующих шагах было видно, что именно эти инструменты
на самом деле экономят. Теория — [1_linux_and_shell](../../../1_linux_and_shell/)
(process model, systemd).

## Поднять VM

```bash
cd ../02_local_vms/linux_kvm/02_examples/
terraform apply -var="vm_count=1"
IP=$(terraform output -json vm_ips | jq -r '.[0]')
```

## Установить зависимости и Redis прямо на VM (без контейнеров)

```bash
ssh -i ~/.ssh/lab_key lab@$IP <<'EOF'
sudo apt update
sudo apt install -y python3-venv redis-server
sudo systemctl enable --now redis-server
EOF
```

## Задеплоить приложение

```bash
scp -i ~/.ssh/lab_key -r ../../05_capstone_project/app lab@$IP:/tmp/app
ssh -i ~/.ssh/lab_key lab@$IP <<'EOF'
sudo mkdir -p /opt/shortener
sudo cp /tmp/app/main.py /tmp/app/requirements.txt /opt/shortener/
sudo python3 -m venv /opt/shortener/.venv
sudo /opt/shortener/.venv/bin/pip install -r /opt/shortener/requirements.txt
sudo chown -R lab:lab /opt/shortener
EOF
scp -i ~/.ssh/lab_key shortener.service lab@$IP:/tmp/
ssh -i ~/.ssh/lab_key lab@$IP <<'EOF'
sudo mv /tmp/shortener.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now shortener
EOF
```

## Проверить

```bash
curl -s http://$IP:8000/health
curl -s -X POST http://$IP:8000/shorten -d '{"url":"https://example.com"}'
```

## Что почувствовать на этом шаге

- `systemctl status shortener` / `journalctl -u shortener -f` — единственный
  способ узнать что происходит с процессом (сравни с `docker logs` на шаге 2).
- Redis и приложение — два независимых systemd-юнита на одной машине: без
  контейнерной изоляции они делят файловую систему, порты, сеть напрямую.
- Обновление кода = вручную scp + `systemctl restart` — на шаге 5 (CI/CD)
  это станет одной командой в пайплайне.
