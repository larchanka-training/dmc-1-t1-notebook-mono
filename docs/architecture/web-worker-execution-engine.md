# Web Worker Execution Engine — Developer Reference

Этот документ описывает **фактическую реализацию** движка выполнения ячеек.
Исходный дизайн предлагал QuickJS WASM (`docs/architecture/execution-architecture.md`);
в shipped MVP используется обычный Web Worker с patched browser API —
проще в реализации, та же гарантия неблокирующего UI, но с более слабой изоляцией песочницы.

---

## Карта файлов

| Файл | Роль |
|---|---|
| `ui/src/features/notebook/lib/jsExecutor.worker.js` | Web Worker скрипт — выполняет код пользователя, патчит async API, отправляет сообщения |
| `ui/src/features/notebook/model/useNotebookExecutor.ts` | React `ExecutorProvider` + хук `useExecutor()` |
| `ui/src/features/notebook/model/useRunCell.ts` | Thin re-export `runCell` из `useExecutor()` |
| `ui/src/features/notebook/lib/jsExecutor.worker.test.js` | Unit-тесты worker (Node `vm` harness) |
| `ui/src/features/notebook/model/useNotebookExecutor.test.tsx` | Integration-тесты React-слоя (MockWorker) |

---

## Как выполняется ячейка — end-to-end

```
UI (React)                       jsExecutor.worker.js
   │                                     │
   │── postMessage(EXECUTE_CELL) ────────▶│
   │                                     │  (0, eval)(code)  ← indirect eval на worker global
   │◀─ postMessage(CONSOLE_OUTPUT) ───────│  console intercept сработал
   │◀─ postMessage(CONSOLE_OUTPUT) ───────│  ...ещё вывод...
   │◀─ postMessage(CELL_EXECUTION_COMPLETE)│  sync done + все async ops завершены
   │                                     │
```

При ошибке:
```
   │◀─ postMessage(EXECUTION_ERROR) ──────│  sync throw пойман, или unhandledrejection
```

---

## Протокол сообщений

### UI → Worker

| `type` | Поля | Описание |
|---|---|---|
| `EXECUTE_CELL` | `cellId: string`, `code: string` | Выполнить одну ячейку |

### Worker → UI

| `type` | Поля | Описание |
|---|---|---|
| `CONSOLE_OUTPUT` | `cellId`, `stream: "stdout"\|"stderr"`, `text: string` | Один вызов console (с переносом строки) |
| `CELL_EXECUTION_COMPLETE` | `cellId`, `executionCount: number` | Ячейка завершена успешно; весь async work завершён |
| `EXECUTION_ERROR` | `cellId`, `ename`, `evalue`, `traceback: string[]` | Sync throw или unhandled rejection |

Сообщения `CONSOLE_OUTPUT` приходят **до** `CELL_EXECUTION_COMPLETE`.
`EXECUTION_ERROR` взаимоисключающ с `CELL_EXECUTION_COMPLETE` для данного запуска ячейки.

---

## Скрипт Worker

### Механизм выполнения

Код пользователя выполняется через **indirect eval**:

```js
(0, eval)(code);
```

Indirect eval выполняется в глобальной области worker (`self`).
Это означает, что объявления `var` привязываются к `self` и сохраняются между запусками ячеек.
`let` и `const` — block-scoped внутри вызова eval и **не** сохраняются.

```js
// Cell 1:  var x = 42;    → x живёт на self, доступен в Cell 2
// Cell 1:  let y = 99;    → y исчезает после завершения Cell 1
```

Worker загружается с `{ type: "classic" }` (не ES module), чтобы indirect eval
привязывал `var` к глобалу worker, а не к module scope.

### Перехват console

`self.console` заменяется перед выполнением любого кода пользователя:

```js
self.console = {
  log:   (...a) => sendConsole('stdout', a),
  warn:  (...a) => sendConsole('stdout', ['[warn]', ...a]),
  error: (...a) => sendConsole('stderr', a),
  info:  (...a) => sendConsole('stdout', a),
  debug: (...a) => sendConsole('stdout', a),
};
```

`sendConsole` сериализует каждый аргумент через `JSON.stringify` (fallback на `String()`)
и отправляет сообщение `CONSOLE_OUTPUT`.

### Ограничения API

`indexedDB` удаляется (или устанавливается в `undefined`) при загрузке worker.
`fetch`, `WebSockets` и DOM API остаются доступны — worker **не** является
zero-trust песочницей, как QuickJS WASM. Это компромисс MVP.

---

## Отслеживание async-завершения

Worker должен знать, когда ячейка действительно завершена — не только когда последний sync-оператор
выполнен, но и когда все async-callback'и завершились. Используется счётчик ссылок:

```
pendingAsyncCount:  сколько in-flight async ops существует
syncDone:           true после возврата (0, eval)(code)
```

`CELL_EXECUTION_COMPLETE` срабатывает когда `syncDone && pendingAsyncCount === 0`.

Следующие API патчатся для инкремента/декремента счётчика:

| API | Поведение |
|---|---|
| `setTimeout` | `+1` при планировании, `-1` при срабатывании callback (или при очистке) |
| `clearTimeout` | `-1` если id был pending, затем нативная отмена |
| `setInterval` | `+1` при первом планировании; считается как один pending op до `clearInterval` |
| `clearInterval` | `-1` для interval, затем нативная отмена |
| `fetch` | `+1` при вызове; `-1` отложенно через `setTimeout(0)` после settle промиса fetch, давая `.then()` цепочкам время зарегистрировать новый async work |
| `Response.json/.text/.blob/.arrayBuffer/.formData` | `+1` при вызове, `-1` после settle промиса body (также отложенно через `setTimeout(0)`) |

Отложенность fetch тонкая: без неё `asyncEnd` от fetch срабатывает раньше,
чем цепочка `.then(r => r.json())` пользователя выполнится, что приводит к преждевременному завершению ячейки.

---

## Обработка ошибок и откат var

Перед `(0, eval)(code)` делается снимок всех пользовательских глобалов:

```js
const snap = snapshotUserVars();  // ключи не в BUILTIN_KEYS
```

`BUILTIN_KEYS` фиксируется один раз при старте worker (до любого пользовательского кода),
поэтому отражает pristine-окружение worker.

При sync throw:
1. `restoreUserVars(snap)` удаляет новые vars, добавленные во время неудачного запуска, и
   восстанавливает изменённые vars.
2. Отправляется `EXECUTION_ERROR`.
3. `CELL_EXECUTION_COMPLETE` **не** отправляется.

При unhandled rejection — тот же путь отката + `EXECUTION_ERROR` через
`self.onunhandledrejection`.

---

## React-интеграция

### Дерево провайдеров

```
<NotebookProvider>          ← владеет состоянием notebook + reducer
  <ExecutorProvider>        ← владеет lifecycle Worker + pending map
    <YourNotebookUI />
  </ExecutorProvider>
</NotebookProvider>
```

`ExecutorProvider` определён в `useNotebookExecutor.ts`.
Он должен быть внутри `NotebookProvider`, потому что читает и диспатчит в
notebook context.

### Хук `useExecutor()`

Возвращает:

```typescript
interface ExecutorContextValue {
  runCell: (cellId: string) => Promise<void>;
  runAll: () => Promise<void>;
  interruptWorker: () => void;
  isRunning: boolean;
}
```

- **`runCell`** — диспатчит `START_EXECUTION`, отправляет `EXECUTE_CELL` в worker,
  резолвится при `CELL_EXECUTION_COMPLETE` или `EXECUTION_ERROR`.
  При успехе авто-переход к следующей ячейке.
- **`runAll`** — помечает все непустые code-ячейки как `queued`, затем последовательно
  ожидает `runCell`. Останавливается при вызове `interruptWorker`.
- **`interruptWorker`** — терминирует текущий Worker (все переменные в памяти теряются),
  резолвит все pending promises, диспатчит `RESTART_KERNEL` для сброса состояний ячеек,
  затем создаёт новый Worker.
- **`isRunning`** — `true` пока любая ячейка имеет незрезолвленный promise в pending map.

### Pending execution map

`pendingRef` — это `Map<cellId, PendingExecution>`:

```typescript
interface PendingExecution {
  resolve: () => void;       // резолвит Promise, возвращённый runCell
  outputChunks: string[];    // stdout chunks из CONSOLE_OUTPUT
  errorChunks: string[];     // stderr chunks из CONSOLE_OUTPUT
}
```

При `CELL_EXECUTION_COMPLETE` накопленные chunks объединяются и диспатчатся как
единый `StreamOutput` в reducer. `CONSOLE_OUTPUT`, пришедший после завершения
(например, от предыдущего прерванного запуска), тихо отбрасывается.

---

## Interrupt: последствия для состояния

`interruptWorker()` вызывает `worker.terminate()`. Это единственный способ остановить
бесконечный цикл. Последствие: **все `var` переменные, объявленные в предыдущих ячейках, теряются**.
Пользователю нужно перезапустить ячейки с нуля после interrupt.

Это то же ограничение, что и "Raw Web Worker", отмеченное в design-документе.
Interrupt handler QuickJS WASM избежал бы потери состояния, но этот путь
не был реализован в MVP.

---

## Тестирование

### Unit-тесты worker (`jsExecutor.worker.test.js`)

Запускаются в Node через Vitest с `@vitest-environment node`.
Скрипт worker загружается через `readFileSync` и выполняется в свежем `vm.runInNewContext`
sandbox, где `self` — mock-объект, предоставляющий `postMessage`, `setTimeout`, `fetch`,
`Response`, и т.д. Это имитирует поведение browser worker без запуска реального Worker.

Ключевые группы тестов:
- Синхронное выполнение (перехват console, ошибки, счётчик выполнения)
- Scoping `var` между ячейками и откат при throw
- `setTimeout` / nested timeout tracking
- `fetch` + `response.json()` async chain tracking

### Тесты React-слоя (`useNotebookExecutor.test.tsx`)

`Worker` глобально заменяется на `MockWorker` (vi stub).
`MockWorker.instance.emit(data)` симулирует сообщения от worker.
Тесты покрывают: lifecycle mount/unmount, `runCell` / `runAll` последовательность, interrupt,
и отбрасывание поздних `CONSOLE_OUTPUT`.

---

## Известные ограничения (vs. QuickJS WASM design)

| Проблема | Текущее (Web Worker + eval) | Запланировано (QuickJS WASM) |
|---|---|---|
| `fetch` / сетевой доступ | Доступен | Заблокирован по умолчанию |
| Бесконечный цикл | Останавливается только через `terminate()` — теряет всё состояние | Interrupt handler — состояние сохраняется |
| `let`/`const` персистентность | Block-scoped; не сохраняются | Сохранялись бы внутри WASM VM |
| Размер бандла | Без доп. payload | +~1 MB WASM binary |
| Покрытие JS spec | Нативный движок браузера | ES2023 (может отставать от новейших proposals) |

Апгрейд до QuickJS WASM — основной путь для исправления изоляции песочницы и
state-preserving interrupts.
