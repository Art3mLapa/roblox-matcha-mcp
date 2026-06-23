# Matcha LuaVM primer

Official docs: **[doc.wabisabi.mom/matcha](https://doc.wabisabi.mom/matcha/)**

## What Matcha is

Matcha is a **LuaVM** that talks to Roblox from **outside** the process. It emulates Roblox APIs — it does **not** hook internal engine functions like a traditional executor.

| | Executor | Matcha |
|---|----------|--------|
| Detection model | In-process hooks | External emulation |
| `request()` / WebSocket | Often available | **No** — use `game:HttpGet` / `HttpPost` |
| `decompile()` | Varies | **Native** [`decompile(script)`](https://doc.wabisabi.mom/matcha/) |
| `setthreadidentity` | Common | **Not available** |
| Memory R/W | Varies | [`memory_read` / `memory_write`](https://doc.wabisabi.mom/matcha/) (unsafe Luau) |

Because there is no hook layer, features like **remote spy**, **GUI automation**, and **internal-only APIs** are not available through Matcha or this MCP.

## What this MCP uses from Matcha

### HTTP (bridge transport)

Matcha only exposes HTTP via the game API. The connector polls `http://localhost:16385/poll` and posts responses to `/respond`. There is no WebSocket path.

### Script inspection

- **`decompile(script)`** — source for `get-script-content` and the script index
- **`getscripts()`** — optional full script list when building the index
- **`getgetname()`** — place display name in `get-game-info`
- **`identifyexecutor()`** — returns `"Matcha"` + version

### Execution

User Luau runs via `load` / `loadstring` inside the connector. Matcha **blocks nested dynamic eval** in many cases, so `get-data-by-code` uses:

- Fast paths for `game.PlaceId`-style dot paths and literals
- Built-in probes (e.g. backpack listing when code mentions `Backpack` + `GetChildren`)
- Full `load(..., _G)` for other chunks when it works

Prefer **`get-descendants-tree`** and **`game.Players.LocalPlayer.Name`** (dot paths) over `game:GetService("Players")` in `get-data-by-code`.

### Memory (optional)

Requires **unsafe Luau** enabled in Matcha:

- `getbase()` — module base of RobloxPlayerBeta.exe
- `memory_read(type, address)` / `memory_write(type, address, value)`

Exposed as MCP tools `get-memory-base`, `memory-read`, `memory-write`.

### Garbage collector (not in MCP v1)

Matcha documents [`getgc` / `setgc` / `applygc`](https://doc.wabisabi.mom/matcha/). Not wired into MCP tools yet; use `execute` with Matcha globals if you need them.

## Loader pattern

```lua
_G.MatchaMCP = {
    BridgeURL = "localhost:16385",
    MaxScriptMapping = 700,  -- optional
}

loadstring(game:HttpGet("http://" .. _G.MatchaMCP.BridgeURL .. "/script.luau"))()
```

Run **once** per session. Re-running without stopping the old connector can leave duplicate poll loops — restart the script or rejoin if the bridge acts weird.

## Useful official doc sections

| Topic | Link |
|-------|------|
| Getting started | [doc.wabisabi.mom/matcha](https://doc.wabisabi.mom/matcha/) |
| Globals (`loadstring`, `decompile`, `getscripts`) | [Globals](https://matcha-latte.gitbook.io/matcha/luau-environment/functions/globals-functions) |
| Classes (`game`, `Players`, instances) | [Classes](https://doc.wabisabi.mom/matcha/classes/) |
| Console / input | [Console](https://doc.wabisabi.mom/matcha/) (site index) |
| Memory | [Memory](https://doc.wabisabi.mom/matcha/) (site index) |
| Drawing API | [Drawing](https://doc.wabisabi.mom/matcha/) (site index) |

GitBook also supports `?ask=` on `.md` URLs for targeted questions — see [Matcha GitBook](https://matcha-latte.gitbook.io/matcha).

## Dumping more scripts than the index

The MCP indexes **up to 700** decompiled scripts on connect (player/backpack first). For full dumps, use presets in [`matcha-scripts/`](../matcha-scripts/) with [SaveInstance](https://github.com/Matt-T-123/SaveInstance) — export to clipboard as `.rbxlx`, then open in Studio or grep locally.
