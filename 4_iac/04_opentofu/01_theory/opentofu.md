# OpenTofu — открытый форк Terraform

## Почему OpenTofu

В августе 2023 HashiCorp изменила лицензию Terraform с MPL-2.0 (open source) на BSL 1.1
(Business Source License — не open source). BSL запрещает использование для создания
конкурирующих продуктов.

Сообщество (Gruntwork, Spacelift, env0, Harness и др.) создало форк под именем **OpenTofu**
под лицензией MPL-2.0. Проект принят в Linux Foundation (OpenTF Foundation).

**Вывод:** OpenTofu — это Terraform, но с открытой лицензией и активным сообществом.

## Совместимость с Terraform

OpenTofu 1.6.x совместим с Terraform 1.5.x — провайдеры, модули, state файлы работают без изменений.

```bash
# установка (Fedora/RHEL)
dnf install opentofu

# macOS
brew install opentofu

# или бинарник
curl -Lo tofu.zip "https://github.com/opentofu/opentofu/releases/latest/download/tofu_linux_amd64.zip"
unzip tofu.zip && sudo mv tofu /usr/local/bin/

# использование — все команды идентичны terraform
tofu init
tofu plan
tofu apply
tofu state list

# alias для совместимости с существующими скриптами
alias terraform=tofu
```

## Отличия от Terraform

### 1. State encryption (OpenTofu 1.7+)

```hcl
# Шифрование state файла at-rest — в Terraform этого нет
terraform {
  encryption {
    key_provider "pbkdf2" "my_key" {
      passphrase = var.encryption_passphrase
    }
    method "aes_gcm" "my_method" {
      keys = key_provider.pbkdf2.my_key
    }
    state {
      method = method.aes_gcm.my_method
    }
    plan {
      method = method.aes_gcm.my_method
    }
  }
}
```

### 2. Provider functions (OpenTofu 1.7+)

```hcl
# Провайдеры могут экспортировать функции (в TF это недоступно)
locals {
  decoded = provider::aws::arn_parse("arn:aws:s3:::my-bucket")
  # decoded.service = "s3"
  # decoded.account_id = ""
}
```

### 3. Улучшенный for_each с set объектов

```hcl
# В Terraform требовался костыль через toset() и keys()
# OpenTofu поддерживает for_each напрямую для сложных типов
resource "aws_iam_user" "users" {
  for_each = toset(["alice", "bob", "charlie"])
  name     = each.value
}
```

### 4. Открытая разработка

- Публичные RFC для новых фич
- Community voting на приоритеты
- Нет vendor lock-in

## Миграция с Terraform на OpenTofu

```bash
# 1. Установить OpenTofu
brew install opentofu

# 2. Создать alias
alias terraform=tofu

# 3. Запустить init (переиспользует существующие провайдеры)
tofu init

# 4. Проверить plan (должен быть идентичен)
tofu plan

# State файл совместим — менять ничего не нужно
```

Если используете Terraform Cloud/Enterprise — OpenTofu имеет аналог: **Scalr**, **env0**, **Spacelift**.

## Когда переходить, когда нет

**Переходить:**
- Если BSL лицензия проблема для вашей компании
- Если нужны фичи которые есть в OpenTofu но нет в Terraform
- Если хотите поддержать open-source

**Не переходить (пока):**
- Если используете Terraform Cloud — миграция сложнее
- Если команда уже хорошо знает TF и нет мотивации
- OpenTofu молодой проект, Terraform — проверенный

**Практика:** у большинства компаний переход прозрачен за 30 минут.
