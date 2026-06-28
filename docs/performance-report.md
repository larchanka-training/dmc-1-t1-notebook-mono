# Performance Report (Отчёт о производительности)

> Issue [#178](https://github.com/larchanka-training/js-notebook/issues/178) — Performance Investigation

Дата замеров: 2026-06-28

## Условия тестирования

| Параметр | Значение |
|----------|----------|
| Окружение | Локальная разработка (non-Docker) |
| API | uvicorn, Python 3.12, `127.0.0.1:8000` |
| UI | Vite 7 dev server, `127.0.0.1:5173` |
| БД | PostgreSQL 16 (Docker контейнер, `localhost:5432`) |
| Браузер | Chromium (Playwright) |
| Сеть | localhost (без сетевой задержки) |

## Результаты замеров

### 1. Размер bundle

| Файл | Raw | Gzip |
|------|-----|------|
| `index-*.js` | 6\.8 MB | 2\.5 MB |
| `index-*.css` | 30 KB | 6\.4 KB |
| `jsExecutor.worker-*.js` | 2\.5 KB | 1 KB |
| **Итого** | **6\.9 MB** | **2\.5 MB** |

Vite предупреждает: chunk `index-*.js` превышает 500 KB лимит.

**Крупнейшие зависимости** (по `package.json`):

| Зависимость | Назначение | Оценочный вес |
|-------------|------------|---------------|
| `@mlc-ai/web-llm` | Browser LLM (WebGPU) | ~4 MB |
| `@uiw/react-codemirror` + `@codemirror/*` | Редактор кода | ~500 KB |
| `react` + `react-dom` | UI framework | ~130 KB |
| `react-markdown` + `remark-gfm` | Markdown рендеринг | ~200 KB |
| `@reduxjs/toolkit` + `react-redux` | State management | ~100 KB |

### 2. Latency API

#### Endpoints без БД (auth middleware only)

| Endpoint | Метод | Median | Min | Max |
|----------|-------|--------|-----|-----|
| `/docs` | GET | 0\.5 ms | 0\.4 ms | 1\.0 ms |
| `/api/v1/notebooks` (401) | GET | 0\.7 ms | 0\.6 ms | 1\.0 ms |
| `/api/v1/analytics/dashboard` (401) | GET | 0\.6 ms | 0\.5 ms | 1\.4 ms |

#### Endpoints с БД (PostgreSQL)

| Endpoint | Метод | Median | Min | Max |
|----------|-------|--------|-----|-----|
| `/api/v1/auth/login` | POST | 178 ms | 176 ms | 188 ms |
| `/api/v1/auth/register` | POST | 180 ms | 178 ms | 184 ms |
| `/api/v1/notebooks` (list) | GET | 2\.5 ms | 2\.0 ms | 6\.8 ms |
| `/api/v1/notebooks` (create) | POST | 5\.1 ms | 4\.9 ms | 7\.0 ms |
| `/api/v1/analytics/dashboard` | GET | 3\.2 ms | 3\.0 ms | 8\.4 ms |
| `/api/v1/analytics/events` (create) | POST | 4\.4 ms | 4\.2 ms | 7\.0 ms |

#### Время открытия notebook (API + UI)

| Операция | Median | Min | Max |
|----------|--------|-----|-----|
| POST `/api/v1/notebooks` (create) | 7 ms | 6 ms | 9 ms |
| GET `/api/v1/notebooks/{id}` (fetch) | 4 ms | 4 ms | 6 ms |
| **Total API (create + fetch)** | **11 ms** | **10 ms** | **14 ms** |

### 3. Время открытия notebook (UI)

| Метрика | Median | Min | Max |
|---------|--------|-----|-----|
| Click "New notebook" → render heading | 31 ms | 23 ms | 39 ms |

### 4. Время запуска cell

| Метрика | Median | Min | Max |
|---------|--------|-----|-----|
| Click Run → output visible | 106 ms | 49 ms | 121 ms |

### 5. Время загрузки страницы

| Метрика | Median | Min | Max |
|---------|--------|-----|-----|
| DOM Content Loaded | 50 ms | 47 ms | 140 ms |
| Full render (heading/form visible) | 68 ms | 64 ms | 169 ms |

### 6. Метрики браузера

| Метрика | Значение |
|---------|----------|
| JS Heap Used | 35 MB |
| JS Heap Total | 42 MB |
| Total Resources | 75 |
| Total Transfer Size | 17 KB (dev mode, без bundle) |

## Анализ и предложения

### Критично: размер bundle (6\.8 MB / 2\.5 MB gzip)

**Проблема:** Главный chunk `index-*.js` весит 6\.8 MB (2\.5 MB gzip). Vite выдаёт предупреждение о превышении 500 KB лимита. Это замедляет initial load в production.

**Корневая причина:** `@mlc-ai/web-llm` (~4 MB) включён в главный bundle. Библиотека используется только для Browser LLM фичи, которая помечена как `error` в UI.

**Предложения:**

1.  **Code-split `@mlc-ai/web-llm`** — динамический `import()` внутри компонента Browser LLM. Загрузка по требованию, когда пользователь впервые обращается к AI фичи.
    ```typescript
    const webLLM = await import('@mlc-ai/web-llm');
    ```
    **Ожидаемый эффект:** главный chunk уменьшится с 6\.8 MB до ~2\.8 MB (gzip ~1 MB).

2.  **Code-split `react-markdown` + `remark-gfm`** — динамический импорт в компоненте Markdown ячейки. Markdown ячейки создаются реже, чем code ячейки.
    **Ожидаемый эффект:** ~200 KB из главного chunk.

3.  **`manualChunks` в `vite.config.ts`** — разделить vendor chunks для лучшего кэширования:
    ```typescript
    build: {
      rollupOptions: {
        output: {
          manualChunks: {
            'react-vendor': ['react', 'react-dom', 'react-router-dom'],
            'codemirror': ['@uiw/react-codemirror', '@codemirror/lang-javascript', '@codemirror/lang-markdown'],
            'redux': ['@reduxjs/toolkit', 'react-redux'],
          }
        }
      }
    }
    ```

### Средне: latency auth endpoints (178 ms)

**Проблема:** `POST /api/v1/auth/login` и `POST /api/v1/auth/register` занимают ~178 ms, что в 35 раз медленнее чем остальные endpoints (2-5 ms).

**Корневая причина:** bcrypt хэширование пароля (CPU-bound операция). Это ожидаемое поведение для bcrypt с высоким cost factor.

**Предложения:**

1.  **Снизить cost factor bcrypt** — если используется `rounds=12` или выше, можно снизить до `rounds=10` (стандарт для web-приложений). Это уменьшит время с ~178 ms до ~50 ms.
2.  **Кэшировать JWT токен** — клиент может хранить `access_token` и использовать `refresh_token` для продления сессии без повторного login.

### Низко: initial page load (dev mode)

**Наблюдение:** В dev mode страница загружается за 50-170 ms, но это не показатель production-производительности. В production с собранным bundle (6\.8 MB) initial load будет значительно дольше.

**Предложение:** Добавить `vite-plugin-compression` для gzip/brotli сжатия production bundle.

### Не требует действий

| Метрика | Значение | Оценка |
|---------|----------|--------|
| Notebook open (UI) | 31 ms | Отлично |
| Cell execution | 106 ms | Отлично |
| API CRUD (notebooks, analytics) | 2-5 ms | Отлично |
| JS Heap | 35 MB | Нормально |

## Приоритеты улучшений

| Приоритет | Улучшение | Ожидаемый эффект | Сложность |
|-----------|-----------|------------------|-----------|
| 1 | Code-split `@mlc-ai/web-llm` | Bundle: 6\.8 MB → 2\.8 MB | Низкая |
| 2 | `manualChunks` для vendor libs | Лучшее кэширование | Низкая |
| 3 | Code-split `react-markdown` | Bundle: -200 KB | Низкая |
| 4 | Снизить bcrypt cost factor | Auth: 178 ms → 50 ms | Низкая |

## Методология

- **API latency:** `curl` 10 запросов на endpoint, замер `time_total`
- **UI метрики:** Playwright `page.evaluate()` + `performance.now()` polling
- **Bundle size:** `vite build` + `du` + `gzip`
- **Browser metrics:** `performance.getEntriesByType('navigation')` + `performance.memory`
