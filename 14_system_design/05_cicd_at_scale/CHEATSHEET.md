# CI/CD на масштабе — шпаргалка

Подробности и объяснения — в [cicd_at_scale.md](./01_theory/cicd_at_scale.md).
⚠️ — опасная команда или частая ловушка.

## Что ломается на масштабе

| Узкое место | Симптом | Ответ |
| :--- | :--- | :--- |
| Пересборка всего на каждый пуш | CI — главное бутылочное горлышко | сборка только изменённого, кэш, параллельный пул раннеров |
| Последовательная раскатка `O(N)` | деплой на 2000 хостов идёт час | волны/батчи, параллелизм внутри волны |
| Центральная точка (раннер, control-нода) | SPOF и очередь | флот раннеров, pull-модель |
| Откат «всего флота» | дорого и долго | progressive delivery, малый blast radius |

## Build once, deploy many

| Правило | Как |
| :--- | :--- |
| Один артефакт на коммит | собрать один раз, продвигать тот же образ |
| Неизменяемая ссылка | digest `app@sha256:...`, не `latest` |
| Промоушн | смена тега/digest в манифесте окружения, не `docker build` |
| Узнать digest после push | `docker buildx imagetools inspect registry/app:tag` |
| Связка с GitOps | CI пишет digest в Ops-репо, раскатывает CD |

## Флот раннеров

| Задача | Чем |
| :--- | :--- |
| GitLab в Kubernetes | GitLab Runner, Kubernetes executor (под на джобу) |
| GitHub в Kubernetes | Actions Runner Controller (ARC), ephemeral runners |
| Масштабирование по очереди джоб | автоскейлинг пула раннеров (как KEDA для воркеров) |
| Кэш слоёв Docker | BuildKit `--mount=type=cache`, `--cache-to/--cache-from type=registry` |
| Кэш зависимостей | distributed cache (S3/GCS) для всех раннеров |
| Изоляция | ⚠️ под/VM на джобу, не общий shared-хост с секретами |

## Push vs Pull для конфигурации флота

| | Push (Ansible по SSH) | Pull (Puppet/Chef/Salt, `ansible-pull`, k8s) |
| :--- | :--- | :--- |
| Кто инициирует | control-нода | каждый хост сам |
| Масштаб | fork + SSH handshake на хост, линейно | горизонтально |
| «Применить сейчас на один хост» | легко | сложнее |
| Нужен агент | нет | да |
| Ускорение | `serial:`, `forks`, Mitogen, SSH pipelining | — |

| Задача Ansible на флоте | Как |
| :--- | :--- |
| Волнами | `serial: ["1", "10%", "25%"]` в play |
| Параллелизм control-ноды | `ansible-playbook -f 50 site.yml` (`forks`, по умолчанию 5) |
| Остановить при доле ошибок | `max_fail_percentage: 10` |
| Pull-режим | `ansible-pull -U https://git.example.com/ops.git site.yml` по cron/timer |

## Progressive delivery на флоте

| Стратегия | Плюсы | Минусы |
| :--- | :--- | :--- |
| Canary 1–5% + автоанализ | минимальный blast radius | нужен автоматический анализ метрик |
| Blue-green на весь флот | мгновенный откат | ⚠️ x2 ёмкости всего флота |
| Волны по AZ/региону | компромисс скорость/риск | дольше полного rolling |

| Инструмент | Для чего |
| :--- | :--- |
| Argo Rollouts `AnalysisTemplate` | автопромоушн/откат canary по метрикам Prometheus |
| Argo CD ApplicationSet | N приложений из шаблона + генератор (clusters, git, list) |
| Argo CD sync waves / ApplicationSet progressive sync | порядок раскатки по целям |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Сборки каждый раз с нуля в автоскейл-пуле | нет distributed/registry cache |
| «В stage работает, в prod — нет» | пересборка на каждом окружении → build once |
| Ansible на 2000 хостов идёт часами | `forks`, `serial`, Mitogen, pull-модель |
| Регрессия разошлась по всему флоту | ручное сравнение canary → автоанализ, волны |
| Компрометация CI = доступ ко всему проду | push-деплой → GitOps (CI пишет только в Git) |

> Проверка: `docker buildx imagetools inspect`, `ansible-playbook -f`,
> `ansible-pull -U` — по `--help`; не проверено: ApplicationSet
> progressive sync (alpha-фича Argo CD, зависит от версии).
