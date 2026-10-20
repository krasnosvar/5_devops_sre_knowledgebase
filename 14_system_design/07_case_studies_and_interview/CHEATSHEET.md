# System Design интервью, расчёты на салфетке и сквозные кейсы — шпаргалка

Подробности и объяснения — в
[01_interview_framework_and_estimations.md](./01_theory/01_interview_framework_and_estimations.md)
и
[02_case_studies_transfers_and_media.md](./01_theory/02_case_studies_transfers_and_media.md).
⚠️ — опасная команда или частая ловушка.

## Тайминг System Design интервью (45–60 минут)

| Фаза | Время | Что обязательно зафиксировать |
| :--- | :--- | :--- |
| **1. Requirements** | 5–8 мин | 3–4 ключевых сценария (FR), DAU, соотношение Read:Write, CAP (CP vs AP), Latency SLO |
| **2. Estimations & API** | 5–7 мин | Средний и пиковый RPS (`x3–x5`), Storage за 5 лет, Bandwidth, RAM кэша (20% суточных), сигнатуры API |
| **3. High-Level Design** | 10–15 мин | Сквозной путь чтения и записи (`Client -> LB -> API -> Cache/DB/Queue`), без SPOF |
| **4. Deep Dive** | 15–25 мин | Шардирование, гонки, дедлоки, идемпотентность, кэш-аномалии, отказы дата-центра и мониторинг |

## Константы для расчётов «на салфетке» (Back-of-the-Envelope)

| Величина | Значение для быстрого устного счёта |
| :--- | :--- |
| Секунд в сутках / в году / за 5 лет | $1\text{ день} \approx \mathbf{10^5\text{ с}}$ ($86\,400$) \| $1\text{ год} \approx \mathbf{3 \times 10^7\text{ с}}$ \| $5\text{ лет} \approx \mathbf{1.5 \times 10^8\text{ с}}$ |
| Степени байтов | $10^3 = \text{1 КБ}$ \| $10^6 = \text{1 МБ}$ \| $10^9 = \text{1 ГБ}$ \| $10^{12} = \text{1 ТБ}$ \| $10^{15} = \text{1 ПБ}$ |
| Задержка чтения: RAM / NVMe / RTT в AZ | **RAM**: `100 нс` \| **NVMe SSD**: `20–100 мкс` \| **Сеть внутри AZ**: `0.5 мс` \| **Между континентами**: `100–150 мс` |
| Задержка сервисов: Redis / Postgres | **Redis (L2)**: `0.5–1.5 мс` \| **PostgreSQL (PK lookup)**: `1–5 мс` |
| Ёмкость 1 узла (ориентиры) | **Redis**: `100k–300k RPS` \| **Postgres Master**: `5k–20k Write TPS`, `20k–50k Read QPS` \| **Kafka**: `100k–500k msg/s` |

## Матрица строительных блоков («Задача → Компонент»)

| Задача | Архитектурное решение |
| :--- | :--- |
| Загрузка и раздача тяжёлых медиа (`> 5 МБ`) | Прямой `PUT` клиента в **S3 по Presigned URL** (`Multipart Upload`) + раздача через **CDN** |
| Счетчики просмотров / лайков (`100k+ RPS`) | Агрегация в памяти + **Redis (`HINCRBY`)** с асинхронным батчевым сбросом в БД (**Write-Behind**) |
| Защита платежа от повторного списания | Заголовок **`Idempotency-Key` (UUID)** + уникальный индекс в таблице переводов в одной ACID-транзакции |
| Поиск по тексту и 20 фильтрам | **Elasticsearch / OpenSearch**, синхронизируемый из основной БД асинхронно через **CDC (Debezium) / Kafka** |
| Real-time доставка событий на клиент | **SSE (Server-Sent Events)** для одностороннего стрима от сервера; **WebSockets** для двустороннего чата |

## Четыре эталонных кейса: ключевые узлы и ловушки

| Кейс | Главные архитектурные решения | Главная ловушка на собеседовании (⚠️) |
| :--- | :--- | :--- |
| **1. Денежные переводы (Payments)** | Тип `BIGINT` (копейки) / `Decimal`; `Idempotency-Key`; двойная запись (**Double-Entry Ledger**, $\sum = 0$); `Transactional Outbox`; межшардовый перевод через **Saga (Hold -> Credit)** | ⚠️ **Deadlock** при встречных переводах ($A \to B$ и $B \to A$) → всегда сортировать блокировки `ORDER BY account_id ASC FOR UPDATE`! |
| **2. Галерея медиа (Image Hosting)** | `Presigned URL` в S3 в обход бэкенда; дедупликация по `SHA-256`; ресайз в `WebP` асинхронными CPU-воркерами из Kafka (KEDA); CDN с `immutable` кэшем | ⚠️ Прокачивать байты картинок через память веб-воркеров или хранить `BLOB` в реляционной БД |
| **3. Сокращатель ссылок (URL Shortener)** | Алфавит **Base62** (7 символов = $62^7 \approx 3.5\text{ трлн}$); генерация через **Snowflake ID** или блоки счётчиков + Feistel cipher; чтение через Redis + Bloom Filter | ⚠️ Код `301` кэшируется браузером навсегда и **убивает аналитику кликов** → для аналитики нужен `302` + Kafka → ClickHouse |
| **4. Лента новостей (News Feed)** | **Гибридный Fan-out**: Push (`Fan-out on Write` в Redis списки `post_id`) для обычных людей + Pull (`Fan-out on Read` на лету с K-way Merge) для знаменитостей | ⚠️ Делать Push в Redis для звезды с 50 млн подписчиков или хранить в списках лент полные JSON постов вместо `post_id` |

## Быстрая формула расчёта из DAU

$$\text{RPS}_{\text{avg}} = \frac{\text{DAU} \times
\text{ActionsPerUser}}{10^5}, \qquad \text{RPS}_{\text{peak}} =
\text{RPS}_{\text{avg}} \times K_{\text{peak}} \quad (K_{\text{peak}} \in
[3..5])$$

$$\text{Storage}_{5\text{y}} = \text{RPS}_{\text{write\_avg}} \times
\text{RecordSize} \times 1.5 \times 10^8 \times K_{\text{indexes\_and\_bloat}}
\quad (K \approx 2..3)$$

> Проверка: все формулы и числовые оценки (мощности $62^7$, задержки
> памяти/сети,
> SQL-конструкции) проверены аналитически; не проверено: — (справочный
> материал).
