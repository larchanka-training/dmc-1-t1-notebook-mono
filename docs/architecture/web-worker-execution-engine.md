# Web Worker Execution Engine — Developer Reference

This document describes the **actual implementation** of the cell execution engine.
The original design proposed QuickJS WASM (`docs/architecture/execution-architecture.md`);
the shipped MVP uses a plain Web Worker with patched browser APIs instead —
simpler to ship, same non-blocking UI guarantee, but with weaker sandbox isolation.

---

## File map

| File | Role |
|---|---|
| `ui/src/features/notebook/lib/jsExecutor.worker.js` | Web Worker script — evaluates user code, patches async APIs, posts messages |
| `ui/src/features/notebook/model/useNotebookExecutor.ts` | React `ExecutorProvider` + `useExecutor()` hook |
| `ui/src/features/notebook/model/useRunCell.ts` | Thin re-export of `runCell` from `useExecutor()` |
| `ui/src/features/notebook/lib/jsExecutor.worker.test.js` | Unit tests for the worker (Node `vm` harness) |
| `ui/src/features/notebook/model/useNotebookExecutor.test.tsx` | Integration tests for the React layer (MockWorker) |

---

## How a cell runs — end-to-end

```
UI (React)                       jsExecutor.worker.js
   │                                     │
   │── postMessage(EXECUTE_CELL) ────────▶│
   │                                     │  (0, eval)(code)  ← indirect eval on worker global
   │◀─ postMessage(CONSOLE_OUTPUT) ───────│  console intercept fires
   │◀─ postMessage(CONSOLE_OUTPUT) ───────│  ...more output...
   │◀─ postMessage(CELL_EXECUTION_COMPLETE)│  sync done + all async ops settled
   │                                     │
```

On error:
```
   │◀─ postMessage(EXECUTION_ERROR) ──────│  sync throw caught, or unhandledrejection
```

---

## Message protocol

### UI → Worker

| `type` | Fields | Description |
|---|---|---|
| `EXECUTE_CELL` | `cellId: string`, `code: string` | Execute one cell |

### Worker → UI

| `type` | Fields | Description |
|---|---|---|
| `CONSOLE_OUTPUT` | `cellId`, `stream: "stdout"\|"stderr"`, `text: string` | One console call (newline-terminated) |
| `CELL_EXECUTION_COMPLETE` | `cellId`, `executionCount: number` | Cell finished successfully; all async work settled |
| `EXECUTION_ERROR` | `cellId`, `ename`, `evalue`, `traceback: string[]` | Sync throw or unhandled rejection |

`CONSOLE_OUTPUT` messages arrive **before** `CELL_EXECUTION_COMPLETE`.
`EXECUTION_ERROR` is mutually exclusive with `CELL_EXECUTION_COMPLETE` for a given cell run.

---

## The Worker script

### Execution mechanism

User code is run via **indirect eval**:

```js
(0, eval)(code);
```

Indirect eval executes in the worker's global scope (`self`).
This means `var` declarations bind to `self` and persist across cell runs.
`let` and `const` are block-scoped to the eval call and do **not** persist.

```js
// Cell 1:  var x = 42;    → x lives on self, survives to Cell 2
// Cell 1:  let y = 99;    → y is gone after Cell 1 completes
```

The worker file is loaded with `{ type: "classic" }` (not ES module) so that
indirect eval binds `var` to the worker global rather than a module scope.

### Console intercept

`self.console` is replaced before any user code runs:

```js
self.console = {
  log:   (...a) => sendConsole('stdout', a),
  warn:  (...a) => sendConsole('stdout', ['[warn]', ...a]),
  error: (...a) => sendConsole('stderr', a),
  info:  (...a) => sendConsole('stdout', a),
  debug: (...a) => sendConsole('stdout', a),
};
```

`sendConsole` serialises each argument with `JSON.stringify` (falls back to `String()`)
and posts a `CONSOLE_OUTPUT` message.

### API restrictions

`indexedDB` is deleted (or set to `undefined`) at worker boot.
`fetch`, `WebSockets`, and DOM APIs remain available — the worker is **not** a
zero-trust sandbox like QuickJS WASM would be. Treat this as an MVP trade-off.

---

## Async completion tracking

The worker must know when a cell is truly done — not just when the last sync statement
ran, but after all async callbacks have settled. It uses a reference counter:

```
pendingAsyncCount:  how many in-flight async ops exist
syncDone:           true after (0, eval)(code) returns
```

`CELL_EXECUTION_COMPLETE` fires when `syncDone && pendingAsyncCount === 0`.

The following APIs are patched to increment/decrement the counter:

| API | Behaviour |
|---|---|
| `setTimeout` | `+1` on schedule, `-1` when callback fires (or when cleared) |
| `clearTimeout` | `-1` if the id was pending, then cancels natively |
| `setInterval` | `+1` on first schedule; counts as one pending op until `clearInterval` |
| `clearInterval` | `-1` for the interval, then cancels natively |
| `fetch` | `+1` on call; `-1` deferred to `setTimeout(0)` after the fetch promise settles, giving `.then()` chains time to register new async work |
| `Response.json/.text/.blob/.arrayBuffer/.formData` | `+1` on call, `-1` after the body promise settles (also deferred via `setTimeout(0)`) |

The fetch deferral is subtle: without it, `asyncEnd` from the fetch fires before the
user's `.then(r => r.json())` chain runs, causing the cell to complete prematurely.

---

## Error handling and var rollback

Before `(0, eval)(code)` runs, a snapshot of all user-declared globals is taken:

```js
const snap = snapshotUserVars();  // keys not in BUILTIN_KEYS
```

`BUILTIN_KEYS` is captured once at worker startup (before any user code),
so it reflects the pristine worker environment.

On a sync throw:
1. `restoreUserVars(snap)` removes any new vars added during the failed run and
   restores any vars that were mutated.
2. `EXECUTION_ERROR` is posted.
3. `CELL_EXECUTION_COMPLETE` is **not** posted.

On an unhandled rejection, the same rollback + `EXECUTION_ERROR` path fires via
`self.onunhandledrejection`.

---

## React integration

### Provider tree

```
<NotebookProvider>          ← owns notebook state + reducer
  <ExecutorProvider>        ← owns Worker lifecycle + pending map
    <YourNotebookUI />
  </ExecutorProvider>
</NotebookProvider>
```

`ExecutorProvider` is defined in `useNotebookExecutor.ts`.
It must be nested inside `NotebookProvider` because it reads and dispatches to the
notebook context.

### `useExecutor()` hook

Returns:

```typescript
interface ExecutorContextValue {
  runCell: (cellId: string) => Promise<void>;
  runAll: () => Promise<void>;
  interruptWorker: () => void;
  isRunning: boolean;
}
```

- **`runCell`** — dispatches `START_EXECUTION`, sends `EXECUTE_CELL` to the worker,
  resolves when `CELL_EXECUTION_COMPLETE` or `EXECUTION_ERROR` arrives.
  On success, auto-advances selection to the next cell.
- **`runAll`** — marks all non-empty code cells as `queued`, then awaits `runCell`
  sequentially. Stops early if `interruptWorker` was called.
- **`interruptWorker`** — terminates the current Worker (all in-memory state is lost),
  resolves all pending promises, dispatches `RESTART_KERNEL` to reset cell states,
  then creates a fresh Worker.
- **`isRunning`** — `true` while any cell has an unresolved promise in the pending map.

### Pending execution map

`pendingRef` is a `Map<cellId, PendingExecution>` holding:

```typescript
interface PendingExecution {
  resolve: () => void;       // resolves the Promise returned by runCell
  outputChunks: string[];    // stdout chunks from CONSOLE_OUTPUT
  errorChunks: string[];     // stderr chunks from CONSOLE_OUTPUT
}
```

On `CELL_EXECUTION_COMPLETE` the accumulated chunks are joined and dispatched as a
single `StreamOutput` to the reducer. `CONSOLE_OUTPUT` arriving after completion
(e.g. from a previous interrupted run) is silently dropped.

---

## Interrupt: state implications

`interruptWorker()` calls `worker.terminate()`. This is the only way to stop an
infinite loop. Consequence: **all `var` variables declared in previous cells are lost**.
The user must re-run cells from scratch after an interrupt.

This is the same limitation as a "Raw Web Worker" noted in the design doc.
QuickJS WASM's interrupt handler would avoid state loss, but that path was not
implemented in the MVP.

---

## Testing

### Worker unit tests (`jsExecutor.worker.test.js`)

Run in Node via Vitest with `@vitest-environment node`.
The worker script is loaded with `readFileSync` and executed in a fresh `vm.runInNewContext`
sandbox where `self` is a mock object exposing `postMessage`, `setTimeout`, `fetch`,
`Response`, etc. This mirrors browser worker behaviour without spinning up a real Worker.

Key test groups:
- Synchronous execution (console capture, errors, execution count)
- `var` scoping across cells and rollback on throw
- `setTimeout` / nested timeout tracking
- `fetch` + `response.json()` async chain tracking

### React layer tests (`useNotebookExecutor.test.tsx`)

`Worker` is replaced globally with `MockWorker` (a vi stub).
`MockWorker.instance.emit(data)` simulates messages arriving from the worker.
Tests cover: mount/unmount lifecycle, `runCell` / `runAll` sequencing, interrupt,
and late `CONSOLE_OUTPUT` being silently dropped.

---

## Known limitations (vs. QuickJS WASM design)

| Concern | Current (Web Worker + eval) | Planned (QuickJS WASM) |
|---|---|---|
| `fetch` / network access | Available | Blocked by default |
| Infinite loop | Only stoppable via `terminate()` — loses all state | Interrupt handler — state preserved |
| `let`/`const` persistence | Block-scoped; don't persist | Would persist inside WASM VM |
| Bundle size | No extra payload | +~1 MB WASM binary |
| JS spec coverage | Native browser engine | ES2023 (may lag newest proposals) |

Upgrading to QuickJS WASM is the primary path to fixing sandbox isolation and
state-preserving interrupts.
