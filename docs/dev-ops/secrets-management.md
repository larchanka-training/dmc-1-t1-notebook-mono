# Управление секретами

Все секреты хранятся в AWS Secrets Manager. Никаких паролей в коде или переменных окружения контейнеров.

---

## Секреты в dev окружении

### `dmc-1-t1-notebook-dev-jwt-secret`

Случайная строка для подписи JWT access-токенов:

```
<минимум 32 случайных байта, base64 или hex>
```

- Создаётся вручную и добавляется в Secrets Manager
- ECS получает значение при старте задачи как переменную окружения `JWT_SECRET`
- Утечка этого секрета позволяет создавать произвольные access-токены — относитесь к нему как к паролю

Сгенерировать значение:

```bash
openssl rand -hex 32
```

> **Локальная разработка:** `.env.example` содержит слабый дефолт `dev-jwt-secret-replace-in-production`. Для локальной работы этого достаточно — в production значение **обязательно** переопределяется через этот секрет.

---

### `dmc-1-t1-notebook-dev-db-password`

Полная строка подключения к базе данных:

```
postgresql://postgres:<пароль>@<rds-endpoint>/notebook
```

- Создаётся автоматически при `terraform apply`
- Пароль генерирует Terraform (`random_password`, 16 символов, без спецсимволов)
- Хранится в Terraform state (S3, шифрование включено)
- ECS получает значение при старте задачи через блок `secrets` в task definition

### `dmc-1-t1-notebook-dev-ghcr-credentials`

JSON для аутентификации в GitHub Container Registry:

```json
{"username": "CroixANI", "password": "<PAT с read:packages>"}
```

- Создаётся Terraform (пустым), значение добавляется вручную
- Нужен для pull Docker-образов из GHCR в приватных подсетях
- ECS получает значение через `repositoryCredentials` в task definition

---

## Как ECS получает секреты

ECS-агент при старте задачи обращается к Secrets Manager от имени IAM execution role и передаёт значения в контейнер. В task definition используются два механизма:

**`secrets` блок** — значение становится переменной окружения внутри контейнера:

```json
"secrets": [
  {
    "name": "DATABASE_URL",
    "valueFrom": "arn:aws:secretsmanager:...:secret:dmc-1-t1-notebook-dev-db-password-..."
  },
  {
    "name": "JWT_SECRET",
    "valueFrom": "arn:aws:secretsmanager:...:secret:dmc-1-t1-notebook-dev-jwt-secret-..."
  }
]
```

**`repositoryCredentials`** — используется для аутентификации при pull образа, до запуска контейнера:

```json
"repositoryCredentials": {
  "credentialsParameter": "arn:aws:secretsmanager:...:secret:dmc-1-t1-notebook-dev-ghcr-credentials-..."
}
```

---

## Кто имеет доступ

IAM роль `dmc-1-t1-notebook-dev-ecs-execution-role` имеет право `secretsmanager:GetSecretValue` только на эти три секрета (`db-password`, `ghcr-credentials`, `jwt-secret`). Никакого широкого доступа к Secrets Manager нет.

---

## Как обновить GHCR credentials

Используется одноразовый GitHub Actions workflow (при необходимости создаётся заново из шаблона):

```yaml
- name: Put GHCR credentials into Secrets Manager
  run: |
    aws secretsmanager put-secret-value \
      --secret-id dmc-1-t1-notebook-dev-ghcr-credentials \
      --secret-string '{"username":"CroixANI","password":"<новый PAT>"}'
```

После обновления секрета нужно форсировать новый деплой ECS-сервисов чтобы они подхватили новые credentials.

---

## PAT для GHCR

- Тип: Classic token (не Fine-grained)
- Необходимые права: только `read:packages`
- Срок действия: 90 дней (текущий истекает Aug 28, 2026)

Перед истечением PAT нужно:
1. Создать новый Classic token с `read:packages`
2. Обновить секрет `ghcr-credentials` через workflow
3. Форсировать деплой обоих ECS сервисов
