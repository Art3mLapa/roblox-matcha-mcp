# MCP tools reference

## Session

### `list-clients`

Lists connected Matcha sessions (player, place, job ID). Call first if you might have multiple clients.

### `set-active-client`

Sets which `clientId` receives tool calls.

---

## Execution

### `execute`

Runs Luau in Matcha. **No return value.** Use for side effects (hooks, toggles, prints).

### `execute-file`

Runs a `.lua` / `.luau` file from disk on the host (path on your PC, executed in the game).

### `get-data-by-code`

Runs Luau and returns serialized values.

**Good for:** `return game.PlaceId`, `return game.Players.LocalPlayer.Name`, small tables.

**Avoid:** huge tables, full instances, `game:GetService(...)` chains (use dot paths), complex multiline logic (use `execute` + `get-descendants-tree`).

Response shape: `{ "count": N, "values": [...] }`.

---

## Exploration

### `get-descendants-tree`

Walks children under an instance path.

- `summaryOnly: true` (default) — class counts only, cheap
- `summaryOnly: false` — named children up to `maxDepth` / `maxChildren`

Example root: `game.Players.LocalPlayer.Backpack`

### `search-instances`

Finds instances matching a **class filter** under a root (e.g. all `Tool` under backpack).

### `get-game-info`

PlaceId, GameId, JobId, place name, executor string, connector version.

---

## Scripts

### `script-grep`

**Search decompiled code** already uploaded to the server. Like grep across a partial snapshot of the game.

- Use when you know a **word** (`FireServer`, `ToolManagment`)
- `literal: true` for exact text
- Index may be partial until mapping finishes (see dashboard)

### `semantic-search-scripts`

Behavior-based search using embeddings. Needs API keys configured in the dashboard. Use when you don't know exact names.

### `get-script-content`

Decompiles a script by **path** or script getter. Use `startLine` / `endLine` for large files.

Example: `game.Players.LocalPlayer.Backpack.ToolManagment`

---

## Console

### `get-console-output`

Recent lines from a hooked `print` buffer (and LogService history when available). Low `limit` for quick checks after `execute`.

---

## Memory (unsafe)

Requires Matcha unsafe Luau.

### `get-memory-base`

Base address of `RobloxPlayerBeta.exe`.

### `memory-read` / `memory-write`

Read/write typed values at an address.

---

## Recommended workflow

1. `list-clients` → `set-active-client` if needed  
2. `get-descendants-tree` or `search-instances` to find paths  
3. `script-grep` to find where something is used  
4. `get-script-content` with line range for the interesting part  
5. `execute` to test a small patch; `get-console-output` to verify  
