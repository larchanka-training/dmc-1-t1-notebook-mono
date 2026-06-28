# Cost Analysis (Анализ затрат)

> Issue [#177](https://github.com/larchanka-training/js-notebook/issues/177) — Cost Optimization

Дата: 2026-06-28

## Методология

Оценка стоимости эксплуатации инфраструктуры в AWS (регион `eu-north-1`, Stockholm) для трёх масштабов: 100, 1000 и 10000 пользователей.

Цены основаны на публичных тарифах AWS на момент составления отчёта. Цены для `eu-north-1` могут незначительно отличаться от `us-east-1` (обычно +5–10%).

---

## Инфраструктура

Текущая конфигурация (Terraform, `infra/envs/prod/`):

| Компонент | Конфигурация | Файл |
|-----------|-------------|------|
| VPC | 1 VPC, 2 public + 2 private subnets, 1 NAT Gateway | `infra/shared/main.tf` |
| CloudFront | 1 distribution, HTTPS → ALB | `infra/shared/main.tf:289` |
| ALB | 1 Application Load Balancer, HTTP:80 | `infra/shared/main.tf:197` |
| ECS API | Fargate, 0.25 vCPU, 1 GB, 1 task | `infra/modules/environment/main.tf:119` |
| ECS UI | Fargate, 0.25 vCPU, 0.5 GB, 1 task | `infra/modules/environment/main.tf:210` |
| ADOT sidecar | В API task (shared CPU/RAM) | `infra/modules/environment/main.tf:166` |
| RDS | PostgreSQL 15, db.t3.micro, 20 GB gp3, single-AZ | `infra/modules/environment/main.tf:48` |
| Secrets Manager | 2 секрета (DB password, GHCR credentials) | `infra/modules/environment/main.tf:24-39` |
| CloudWatch | 4 log groups, retention 7 дней | `infra/modules/environment/main.tf:7-15` |
| VPC Endpoint | Bedrock runtime, Interface, 2 AZ | `infra/modules/environment/bedrock.tf:20` |
| X-Ray | Tracing, sampling 0.3 (prod) | `infra/modules/environment/observability.tf` |
| Bedrock | Nova Pro v1:0 (prod tfvars) | `infra/envs/prod/terraform.tfvars:5` |

---

## Допущения

| Параметр | Значение | Обоснование |
|----------|----------|-------------|
| AI запросов на пользователя в день | 10 | Rate limit 50 RPD, среднее использование ~20% |
| Input tokens на запрос | ~4,000 | Prompt + notebook context (~32K chars max, среднее ~16K chars ≈ 4K tokens) |
| Output tokens на запрос | ~2,000 | Код + валидация, max 4096 |
| Попыток генерации на запрос (avg) | 1.5 | Валидация с retry до 3 попыток, большинство с 1-й |
| Notebook data на пользователя | ~100 KB | ~10 notebooks × ~10 KB каждый |
| Просмотров страниц на пользователя в день | 20 | Открытие/обновление notebooks |
| API запросов на пользователя в день | 100 | CRUD, analytics, AI |
| Размер UI bundle | ~4.5 MB | Performance report (#178) |
| Средний размер API ответа | ~2 KB | JSON с notebook данными |
| Дней в месяц | 30 | — |

---

## 1. Фиксированные затраты (инфраструктура)

Цены для `eu-north-1`, на основе публичных тарифов AWS.

| Компонент | Цена | Месяц (730 ч) |
|-----------|------|---------------|
| NAT Gateway | $0.048/ч + $0.045/GB | $35.04 + data |
| ALB | $0.025/ч + $0.008/LCU-ч | $18.25 + LCU |
| CloudFront | $0.085/GB + $0.0075/10K req | по трафику |
| VPC Endpoint (2 AZ) | $0.01/ч × 2 AZ | $14.60 |
| Secrets Manager | $0.40/секрет × 2 | $0.80 |
| CloudWatch Logs (ingestion) | $0.50/GB | по логам |
| X-Ray | 100K traces free, $5/100K выше | по трассам |
| Route 53 (опционально) | $0.50/zone + $0.40/1M queries | ~$1.00 |

### ECS Fargate (фиксированная часть)

| Сервис | vCPU | RAM | Цена/ч | Месяц |
|--------|------|-----|--------|-------|
| API (1 task) | 0.25 | 1 GB | $0.0165 | $12.05 |
| UI (1 task) | 0.25 | 0.5 GB | $0.0140 | $10.22 |
| **Итого Fargate** | | | | **$22.27** |

> Цена: $0.046/vCPU-ч + $0.005/GB-ч (eu-north-1, Linux/x86)

### RDS (фиксированная часть)

| Параметр | Цена | Месяц |
|----------|------|-------|
| db.t3.micro (1 AZ) | $0.020/ч | $14.60 |
| Storage gp3, 20 GB | $0.110/GB | $2.20 |
| **Итого RDS** | | **$16.80** |

### Итого фиксированные затраты

| Компонент | Месяц |
|-----------|-------|
| NAT Gateway (base) | $35.04 |
| ALB (base) | $18.25 |
| VPC Endpoint | $14.60 |
| ECS Fargate (1+1 task) | $22.27 |
| RDS (db.t3.micro, 20 GB) | $16.80 |
| Secrets Manager | $0.80 |
| CloudWatch Logs (base, ~5 GB) | $2.50 |
| X-Ray (free tier) | $0.00 |
| **Итого** | **$110.26** |

---

## 2. Переменные затраты

### 2.1. Bedrock (AI генерация)

Prod использует **Nova Pro v1:0** (`terraform.tfvars:5`).

| Параметр | Значение |
|----------|----------|
| Input цена | $0.80 / 1M tokens |
| Output цена | $3.20 / 1M tokens |

**Формула:** `cost = users × 10 req/day × 30 days × 1.5 attempts × (4000 input × $0.80/1M + 2000 output × $3.20/1M)`

Стоимость одного запроса (с retry):
- Input: 4000 × 1.5 = 6000 tokens → $0.0048
- Output: 2000 × 1.5 = 3000 tokens → $0.0096
- **~$0.0144 за запрос**

| Пользователи | Запросов/мес | Bedrock/мес |
|-------------|-------------|-------------|
| 100 | 30,000 | $432.00 |
| 1,000 | 300,000 | $4,320.00 |
| 10,000 | 3,000,000 | $43,200.00 |

#### Альтернатива: Nova Lite v1:0

Dev использует Nova Lite. Если переключить prod на Nova Lite:

| Параметр | Значение |
|----------|----------|
| Input цена | $0.06 / 1M tokens |
| Output цена | $0.24 / 1M tokens |

Стоимость одного запроса: ~$0.00108 (в **13.3×** дешевле)

| Пользователи | Nova Pro/мес | Nova Lite/мес | Экономия |
|-------------|-------------|--------------|----------|
| 100 | $432 | $32.40 | 93% |
| 1,000 | $4,320 | $324 | 93% |
| 10,000 | $43,200 | $3,240 | 93% |

### 2.2. Трафик (CloudFront + NAT Gateway)

**Трафик на пользователя в день:**
- UI bundle: 4.5 MB × 1 (cache после первой загрузки) ≈ 0.5 MB (cached)
- API ответы: 100 × 2 KB = 200 KB
- AI ответы: 10 × 4 KB = 40 KB
- **~0.74 MB/день** (с CloudFront cache)

| Пользователи | Трафик/мес | CloudFront | NAT GW processing |
|-------------|-----------|------------|-------------------|
| 100 | 2.2 GB | $0.19 | $0.10 |
| 1,000 | 22 GB | $1.87 | $0.99 |
| 10,000 | 222 GB | $18.87 | $9.99 |

> CloudFront: $0.085/GB. NAT Gateway: $0.045/GB (только исходящий в интернет; Bedrock через VPC endpoint — без NAT).

### 2.3. Storage (RDS)

| Пользователи | Notebook data | Сессии + analytics | Всего | Стоимость/мес |
|-------------|--------------|-------------------|-------|--------------|
| 100 | 10 MB | ~5 MB | ~15 MB | $2.20 (base 20 GB) |
| 1,000 | 100 MB | ~50 MB | ~150 MB | $2.20 (base 20 GB) |
| 10,000 | 1 GB | ~500 MB | ~1.5 GB | $2.20 (base 20 GB) |

> gp3: $0.110/GB. Базовые 20 GB достаточно до ~10K пользователей.

### 2.4. CloudWatch Logs

| Пользователи | Логов/мес | Стоимость |
|-------------|----------|-----------|
| 100 | ~10 GB | $5.00 |
| 1,000 | ~50 GB | $25.00 |
| 10,000 | ~300 GB | $150.00 |

> $0.50/GB ingestion. Retention 7 дней. Включая Bedrock invocation logs.

### 2.5. ECS Fargate (масштабирование)

Для больших нагрузок требуется больше API tasks:

| Пользователи | API tasks | UI tasks | Fargate/мес |
|-------------|-----------|----------|-------------|
| 100 | 1 | 1 | $22.27 |
| 1,000 | 2 | 2 | $44.54 |
| 10,000 | 5 | 3 | $133.62 |

> API: 0.25 vCPU, 1 GB = $12.05/task. UI: 0.25 vCPU, 0.5 GB = $10.22/task.

### 2.6. RDS (масштабирование)

| Пользователи | Instance | Storage | RDS/мес |
|-------------|----------|---------|---------|
| 100 | db.t3.micro | 20 GB | $16.80 |
| 1,000 | db.t3.small | 20 GB | $33.60 |
| 10,000 | db.t3.medium + Multi-AZ | 50 GB | $134.40 |

> db.t3.micro: $0.020/ч, db.t3.small: $0.040/ч, db.t3.medium: $0.080/ч. Multi-AZ × 2.

---

## 3. Сводные таблицы по масштабу

### 100 пользователей

| Категория | Компонент | Месяц |
|-----------|-----------|-------|
| **AWS** | NAT Gateway | $35.04 |
| **AWS** | ALB | $18.25 |
| **AWS** | VPC Endpoint | $14.60 |
| **AWS** | Secrets Manager | $0.80 |
| **AWS** | CloudFront | $0.19 |
| **AWS** | CloudWatch Logs | $5.00 |
| **AWS** | X-Ray | $0.00 |
| **AWS** | Route 53 | $1.00 |
| **Compute** | ECS Fargate (1+1) | $22.27 |
| **Storage** | RDS (db.t3.micro, 20 GB) | $16.80 |
| **Bedrock** | Nova Pro (30K req/mes) | $432.00 |
| **Traffic** | NAT data processing | $0.10 |
| | **Итого** | **$546.05** |

### 1,000 пользователей

| Категория | Компонент | Месяц |
|-----------|-----------|-------|
| **AWS** | NAT Gateway | $35.04 |
| **AWS** | ALB | $18.25 |
| **AWS** | VPC Endpoint | $14.60 |
| **AWS** | Secrets Manager | $0.80 |
| **AWS** | CloudFront | $1.87 |
| **AWS** | CloudWatch Logs | $25.00 |
| **AWS** | X-Ray | $5.00 |
| **AWS** | Route 53 | $1.00 |
| **Compute** | ECS Fargate (2+2) | $44.54 |
| **Storage** | RDS (db.t3.small, 20 GB) | $33.60 |
| **Bedrock** | Nova Pro (300K req/mes) | $4,320.00 |
| **Traffic** | NAT data processing | $0.99 |
| | **Итого** | **$5,005.69** |

### 10,000 пользователей

| Категория | Компонент | Месяц |
|-----------|-----------|-------|
| **AWS** | NAT Gateway | $35.04 |
| **AWS** | ALB | $18.25 |
| **AWS** | VPC Endpoint | $14.60 |
| **AWS** | Secrets Manager | $0.80 |
| **AWS** | CloudFront | $18.87 |
| **AWS** | CloudWatch Logs | $150.00 |
| **AWS** | X-Ray | $25.00 |
| **AWS** | Route 53 | $1.50 |
| **Compute** | ECS Fargate (5+3) | $133.62 |
| **Storage** | RDS (db.t3.medium, Multi-AZ, 50 GB) | $134.40 |
| **Bedrock** | Nova Pro (3M req/mes) | $43,200.00 |
| **Traffic** | NAT data processing | $9.99 |
| | **Итого** | **$44,743.07** |

---

## 4. Сравнение по категориям

| Категория | 100 users | 1,000 users | 10,000 users |
|-----------|-----------|------------|-------------|
| AWS (infra) | $74.88 | $101.56 | $254.06 |
| Compute (Fargate) | $22.27 | $44.54 | $133.62 |
| Storage (RDS) | $16.80 | $33.60 | $134.40 |
| Bedrock (AI) | $432.00 | $4,320.00 | $43,200.00 |
| Traffic | $0.29 | $2.86 | $28.86 |
| **Итого** | **$546.05** | **$5,005.69** | **$44,743.07** |
| **На пользователя** | **$5.46** | **$5.01** | **$4.47** |

---

## 5. Оптимизация

### 5.1. Переключение на Nova Lite (основная экономия)

Bedrock — **79%** всех затрат. Nova Lite в 13.3× дешевле Nova Pro.

| Пользователи | Nova Pro | Nova Lite | Экономия/мес | Экономия % |
|-------------|----------|-----------|-------------|-----------|
| 100 | $432 | $32 | $400 | 73% |
| 1,000 | $4,320 | $324 | $3,996 | 80% |
| 10,000 | $43,200 | $3,240 | $39,960 | 89% |

Nova Lite достаточен для генерации JS-кода (задача проще, чем general reasoning). Качество можно проверить A/B тестом.

### 5.2. Уменьшение retry attempts

Текущий pipeline делает до 3 попыток. Если улучшить prompt engineering или использовать более строгую валидацию, можно снизить avg attempts с 1.5 до 1.2.

Экономия: ~20% от Bedrock cost = $86 (100 users) / $864 (1K) / $8,640 (10K).

### 5.3. Fargate Spot для UI

UI контейнер stateless — подходит для Fargate Spot (до 70% скидки).

| Масштаб | UI Fargate | UI Spot | Экономия |
|---------|-----------|---------|----------|
| 100 | $10.22 | $3.07 | $7.15 |
| 1,000 | $20.44 | $6.13 | $14.31 |
| 10,000 | $30.66 | $9.20 | $21.46 |

### 5.4. CloudWatch Logs — снижение ingestion

- Уменьшить retention с 7 до 3 дней: экономия ~40% storage cost.
- Отключить Bedrock invocation logging в non-prod.
- Использовать log level WARNING вместо INFO в prod.

### 5.5. NAT Gateway → VPC Endpoints

Уже частично реализовано (Bedrock через VPC endpoint). Можно добавить VPC endpoints для:
- ECR (pull образов без NAT) — экономия ~$2-5/мес
- CloudWatch Logs — экономия ~$1-3/мес
- Secrets Manager — экономия ~$0.50/мес

### 5.6. RDS: Aurora Serverless v2

Для 10K пользователей Aurora Serverless v2 может быть дешевле Multi-AZ db.t3.medium, так как масштабируется автоматически.

| Вариант | Цена/мес |
|---------|---------|
| db.t3.medium Multi-AZ | $134.40 |
| Aurora Serverless v2 (2-8 ACU) | ~$80-120 |

### 5.7. Резюме оптимизаций

| Оптимизация | 100 users | 1,000 users | 10,000 users |
|-------------|-----------|------------|-------------|
| Nova Lite вместо Nova Pro | -$400 | -$3,996 | -$39,960 |
| Reduce retry (1.5→1.2) | -$86 | -$864 | -$8,640 |
| Fargate Spot для UI | -$7 | -$14 | -$21 |
| Logs retention 3 дня | -$2 | -$10 | -$60 |
| **Итого экономия** | **$495** | **$4,884** | **$48,681** |
| **Оптимизированный итог** | **$51** | **$122** | **-$3,938** → ~$4,062 |

> При всех оптимизациях: 100 users ≈ $51/мес, 1,000 users ≈ $122/мес, 10,000 users ≈ ~$4,062/мес.

---

## 6. Выводы

1. **Bedrock — основная статья расходов (79–96%)**. Переключение с Nova Pro на Nova Lite — самая значимая оптимизация (93% экономия на AI).
2. **Фиксированная инфраструктура (~$110/мес)** — незначительна по сравнению с AI затратами при росте пользователей.
3. **Storage и traffic** — практически не влияют на стоимость до 10K пользователей.
4. **Compute (Fargate)** — линейно масштабируется, но остаётся малой долей.
5. **При всех оптимизациях** стоимость на пользователя: $0.51 (100), $0.12 (1K), $0.41 (10K).
