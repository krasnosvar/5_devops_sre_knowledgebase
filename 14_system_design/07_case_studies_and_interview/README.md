# 07. System Design интервью и сквозные архитектурные кейсы

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — тайминг интервью,
> таблица констант и разбор 4 классических кейсов одним экраном.

## Зачем

Знать отдельные строительные блоки (кэши, шардинг, очереди, балансировщики)
недостаточно — на архитектурном ревью и на System Design собеседовании нужно
уметь за 45 минут собрать из них цельную, экономически оправданную систему
под конкретные цифры трафика, защитить её от гонок и каскадных сбоев и
обосновать каждый компромисс.

## Пререквизиты

- Все предыдущие темы раздела `14_system_design`:
  [01_architecture_and_api_styles](../01_architecture_and_api_styles/),
  [02_performance_caching_and_scaling](../02_performance_caching_and_scaling/),
  [03_distributed_components_and_data](../03_distributed_components_and_data/),
  [04_single_vs_multi_cluster](../04_single_vs_multi_cluster/),
  [05_cicd_at_scale](../05_cicd_at_scale/),
  [06_iac_at_scale](../06_iac_at_scale/).

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: 4 фазы интервью, константы
  задержек и пропускной способности, матрица компонентов и 4 кейса.
-
[01_theory/01_interview_framework_and_estimations.md](./01_theory/01_interview_framework_and_estimations.md)
  — пошаговый фреймворк прохождения System Design интервью (45–60 минут),
  сбор функциональных и нефункциональных требований, быстрые расчёты «на
  салфетке» (QPS, пики, диски за 5 лет, полоса сети, RAM кэша), таблица
  задержек и пропускной способности одного узла, матрица выбора компонентов.
-
[01_theory/02_case_studies_transfers_and_media.md](./01_theory/02_case_studies_transfers_and_media.md)
  — глубокий сквозной разбор четырёх систем:
  1) **Денежные переводы и платежи** (`ACID`, `Idempotency-Key`,
     `Double-Entry Ledger`, защита от `Lost Update` и `Deadlock` через
     сортировку `FOR UPDATE`, `Transactional Outbox`, межшардовая `Saga`);
  2) **Галерея изображений и медиа-хостинг** (`S3 Presigned URLs`,
     дедупликация по `SHA-256`, асинхронный пайплайн ресайза через Kafka и
     KEDA, `CDN` + `Origin Shield`);
  3) **Сокращатель ссылок (URL Shortener)** (`Base62`, `Snowflake` vs
     диапазоны с сетью Фейстеля, `301` vs `302`, аналитика кликов в
     `ClickHouse`);
  4) **Лента новостей (News Feed)** (`Fan-out on Write` vs `Fan-out on Read`,
     гибридная схема для знаменитостей и `K-way Merge`).

Без лабы: практические примеры кода и упражнения по этим кейсам на Python и
Go доступны в связанных репозиториях:
- [Python: 04_case_studies](../../../4_python_my_knowledgebase/4_system_design/04_case_studies/)
- [Go: 04_case_studies](../../../3_go_my_knowledgebase/3_system_design/04_case_studies/)

## Как проходить

1. Изучить методологию расчётов в `01_interview_framework_and_estimations.md`
   и потренироваться устно за 2 минуты считать RPS и объём диска для любого
   DAU.
2. Перед чтением каждого из 4 кейсов в `02_case_studies_transfers_and_media.md`
   взять лист бумаги и за 15 минут набросать собственную схему, после чего
   сравнить её с эталонным разбором и подводными камнями.
3. Ответить на 20 вопросов для собеседования в конце файлов теории.

## Когда двигаться дальше

- Можете за 3 минуты без калькулятора перевести `50M DAU` в пиковый RPS,
  объём БД за 5 лет, трафик CDN и размер кэша в Redis.
- Можете без подсказки написать схему таблиц `Double-Entry Ledger` и
  объяснить, почему `ORDER BY account_id FOR UPDATE` спасает от дедлоков.
- Можете объяснить гибридный Fan-out для ленты новостей и разницу между
  `301` и `302` редиректами для аналитики.
- Дальше: финальный сквозной проект
  [0_lab_setup/05_capstone_project](../../0_lab_setup/05_capstone_project/).
