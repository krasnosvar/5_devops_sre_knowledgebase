# 01. Архитектура систем, Clean/DDD и стили API

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — таблицы выбора,
> паттерны и команды диагностики одним экраном.

## Зачем

Прежде чем масштабировать кластеры и настраивать балансировщики, нужно
понимать, как устроена сама система: когда микросервисы оправданы, а когда
превращаются в дорогой «распределённый монолит»; как проводить границы
доменов (DDD) и слоёв внутри сервиса (Clean / Hexagonal), чтобы база данных
не диктовала архитектуру; и какой протокол (REST, gRPC, GraphQL) выбрать
для внешнего периметра (API Gateway / BFF) и внутреннего трафика (Service
Discovery / Service Mesh).

## Пререквизиты

- [2_networking/01_dns](../../2_networking/01_dns/) и
  [2_networking/02_http_and_tls](../../2_networking/02_http_and_tls/) —
  DNS, HTTP/1.1 vs HTTP/2, TLS.
- [4_kubernetes/03_networking](../../4_kubernetes/03_networking/) —
  Service (`ClusterIP`, Headless), Ingress, Gateway API, CNI.

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: монолит vs микросервисы,
  блоки DDD, REST/gRPC/GraphQL, ловушки балансировки.
-
[01_theory/01_system_architecture_monolith_microservices.md](./01_theory/01_system_architecture_monolith_microservices.md)
  — классический и модульный монолит, микросервисы и их инфраструктурная
  цена, антипаттерн распределённого монолита, закон Конвея, 12-Factor App,
  миграция через Strangler Fig и CDC.
-
[01_theory/02_service_architecture_clean_ddd.md](./01_theory/02_service_architecture_clean_ddd.md)
  — Transaction Script vs Domain Model, слоистая (N-tier), Гексагональная
  (Ports & Adapters) и Чистая архитектура, стратегический и тактический
  DDD (Bounded Context, ACL, Entity, Value Object, Aggregate, Repository,
  Unit of Work), CQRS и Event Sourcing.
-
[01_theory/03_api_styles_gateway_and_discovery.md](./01_theory/03_api_styles_gateway_and_discovery.md)
  — идемпотентность и пагинация в REST, устройство gRPC/Protobuf и ловушка
  L4-балансировки HTTP/2, особенности GraphQL, API Gateway и BFF,
  Service Discovery и Service Mesh.

Без лабы: тема закладывает фундаментальный архитектурный аппарат; примеры
реализации в коде на Python и Go приведены в профильных репозиториях:
- [Python: 01_architecture_styles](../../../4_python_my_knowledgebase/4_system_design/01_architecture_styles/)
- [Go: 01_architecture_styles](../../../3_go_my_knowledgebase/3_system_design/01_architecture_styles/)

## Как проходить

1. Прочитать три файла теории строго по порядку: от макроархитектуры
   системы (`01`) к внутренней структуре сервиса и границ доменов (`02`),
   и затем к сетевым контрактам между ними (`03`).
2. Сопоставить признаки распределённого монолита и правило «1 транзакция
   = 1 агрегат» со знакомой вам рабочей системой.
3. Ответить на 30 вопросов для собеседования (по 10 в конце каждого файла).

## Когда двигаться дальше

- Можете обосновать, почему для новой команды из 8 человек лучше выбрать
  модульный монолит, чем 15 микросервисов.
- Понимаете правило направления зависимостей в Clean Architecture и роль
  Bounded Context в DDD.
- Знаете, почему gRPC не балансируется стандартным L4 Kubernetes `Service`
  и зачем мутирующему `POST` нужен `Idempotency-Key`.
- Дальше:
  [02_performance_caching_and_scaling](../02_performance_caching_and_scaling/).
