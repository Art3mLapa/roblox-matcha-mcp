# Architecture

## Components

### `matcha-mcp` (Node)

- MCP server over **stdio** (Cursor talks to `dist/index.js`)
- HTTP server on **port 16385** (configurable via env — see `matcha-mcp/src/config.ts`)
- Routes: `/poll`, `/register`, `/respond`, `/script-sources`, `/script.luau`, dashboard UI
- Stores decompiled script index in memory for `script-grep` / `semantic-search-scripts`
- Optional semantic embeddings (configure via dashboard)

### `matcha-connector.luau` (inside Matcha)

- Loaded by `game:HttpGet("http://localhost:16385/script.luau")`
- Registers client ID, polls for MCP tool commands, runs handlers, POSTs results
- Serial HTTP: one request at a time; poll has priority over script uploads
- On connect: decompiles up to `MaxScriptMapping` scripts, uploads each to `/script-sources` immediately

### `matcha-loader.luau`

- Thin wrapper: sets `_G.MatchaMCP` defaults and fetches the connector.

## Request flow

```
1. AI calls MCP tool (e.g. get-descendants-tree)
2. Node queues JSON command for clientId on HTTP poll
3. Connector receives command in poll response
4. Handler runs (resolve path, walk tree, etc.)
5. Connector POSTs /respond with output
6. Node resolves promise, returns text to AI
```

## Path resolution

Instance paths like `game.Players.LocalPlayer.Backpack` use a **FindFirstChild walk** with a `LocalPlayer` special-case — not nested `loadstring`, because Matcha's eval is unreliable for `game.*` in dynamic chunks.

## Script index

1. Collect scripts: Backpack → PlayerScripts → PlayerGui → Character → `Workspace.Entities` → ReplicatedStorage → `getscripts()` until cap
2. Decompile one at a time with native `decompile()`
3. POST each source to `/script-sources`
4. Server builds grep index; dashboard shows progress

`get-script-content` can also decompile on demand by path even if not indexed yet.

## Differences from executor MCP

| Removed | Reason |
|---------|--------|
| WebSocket client transport | Matcha has no `WebSocket.connect` |
| Cobalt remote spy | No hook layer |
| GUI click / type | No `VirtualInputManager` |
| Win32 screenshot tools | Not VM-specific |
| External decompiler URLs | Matcha `decompile()` |
| `setthreadidentity` prefix | API absent in Matcha |

## Security model

- No TLS, no tokens — trust boundary is **your machine**
- Any local process can POST to `:16385` if the port is open
- Treat memory tools as **write-anywhere** capability on the Roblox process
