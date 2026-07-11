# Matcha MCP

**English** | [Русский](README_RU.md)

MCP server that connects AI assistants to a live [Matcha LuaVM](https://doc.wabisabi.mom/matcha/) session. Your agent can run Luau, explore the game tree, decompile scripts, search code, and use Matcha memory APIs — all from Cursor, Claude Code, or any MCP client.

**Repository:** [github.com/wavelyz/roblox-matcha-mcp](https://github.com/wavelyz/roblox-matcha-mcp)

```
AI client  ←stdio→  matcha-mcp (Node, :16385)
                        ↑ HTTP poll / register / respond
                   matcha-connector.luau (inside Matcha)
                        ↑
                   Matcha LuaVM ↔ Roblox
```

## Requirements

- **Node.js** 18+
- **[Matcha](https://doc.wabisabi.mom/matcha/)** attached to a Roblox session
- An MCP-capable editor (Cursor, Claude Desktop, Claude Code, Windsurf, etc.)

## Quick start

### 1. Build the server

```bash
git clone https://github.com/wavelyz/roblox-matcha-mcp.git
cd roblox-matcha-mcp/matcha-mcp
npm install
npm run build
```

### 2. Add to your MCP client

Use the **absolute path** to `matcha-mcp/dist/index.js`.

**Cursor** — `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "matcha-mcp": {
      "command": "node",
      "args": ["/absolute/path/to/matcha-mcp/dist/index.js"]
    }
  }
}
```

**Claude Code:**

```bash
claude mcp add --global matcha-mcp -- node /absolute/path/to/matcha-mcp/dist/index.js
```

**Claude Desktop** — `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "matcha-mcp": {
      "command": "node",
      "args": ["/absolute/path/to/matcha-mcp/dist/index.js"]
    }
  }
}
```

**Codex / OpenAI:**

```toml
[mcp_servers.matcha-mcp]
command = "node"
args = ["/absolute/path/to/matcha-mcp/dist/index.js"]
```

> See [docs/setup.md](docs/setup.md) for Windsurf and other clients.

Restart your editor after changing the config.

### 3. Connect Matcha

Run once per Roblox session (Matcha auto-run / script hub):

```lua
_G.MatchaMCP = _G.MatchaMCP or {}
_G.MatchaMCP.BridgeURL = _G.MatchaMCP.BridgeURL or "localhost:16385"

loadstring(game:HttpGet("http://" .. _G.MatchaMCP.BridgeURL .. "/script.luau"))()
```

Or just run [`matcha-loader.luau`](matcha-loader.luau).

The connector is served from the MCP server at `http://localhost:16385/script.luau` — no separate download.

**Dashboard:** [http://localhost:16385/](http://localhost:16385/) — connection status and script index progress.

### 4. Verify

In your AI client, call `list-clients`. You should see your player name and place ID. Then try `get-game-info` or `get-descendants-tree` on `game.Players.LocalPlayer.Backpack`.

## Tools

### Session

| Tool | Description |
|------|-------------|
| `list-clients` | List connected Matcha sessions (player, place, job ID) |
| `set-active-client` | Set which `clientId` receives tool calls |

### Execution

| Tool | Description |
|------|-------------|
| `execute` | Run Luau in Matcha (no return value — use for side effects) |
| `execute-file` | Run a `.lua` / `.luau` file from disk on the host |
| `get-data-by-code` | Run Luau and return serialized values (small probes) |

### Exploration

| Tool | Description |
|------|-------------|
| `get-descendants-tree` | Walk children under an instance path |
| `search-instances` | Find instances by class/tag/name/property under a root |
| `get-game-info` | PlaceId, JobId, game name, executor version |

### Scripts

| Tool | Description |
|------|-------------|
| `get-script-content` | Decompile a script by path (with line ranges) |
| `script-grep` | Search decompiled sources for text/regex |
| `semantic-search-scripts` | Search scripts by behavior (needs embedding config) |

### Console & memory

| Tool | Description |
|------|-------------|
| `get-console-output` | Recent print/warn output from the session |
| `get-memory-base` | Base address of `RobloxPlayerBeta.exe` (unsafe Luau) |
| `memory-read` / `memory-write` | Read/write typed values at an address (unsafe Luau) |

Full tool guide: [docs/tools.md](docs/tools.md)

## How it works

```
1. AI calls an MCP tool (e.g. get-descendants-tree)
2. Node queues a JSON command for the client's HTTP poll
3. Connector receives the command in the poll response
4. Handler runs (resolve path, walk tree, decompile, etc.)
5. Connector POSTs the result to /respond
6. Node resolves the promise and returns text to the AI
```

The connector also decompiles up to 700 scripts on connect (player/backpack first) and uploads them to the server for `script-grep`.

## Connector config

Set on `_G.MatchaMCP` before loading:

| Key | Default | Description |
|-----|---------|-------------|
| `BridgeURL` | `localhost:16385` | MCP HTTP host |
| `MaxScriptMapping` | `700` | Max scripts to decompile for `script-grep` on connect |
| `DisableInitialScriptDecompMapping` | — | Set `true` to skip script index |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| MCP won't start | Run `npm run build`; check the Node path in config |
| No clients in `list-clients` | Run the loader in Matcha; check the dashboard at `:16385` |
| Tools timeout | Matcha HTTP may be blocked; bridge URL must match `BridgeURL` |
| Stale connector after updates | Stop the old script, then run the loader once (don't stack reloads) |
| `script-grep` returns nothing | Wait for the index on the dashboard; backpack scripts index first |

## Repo layout

| Path | Purpose |
|------|---------|
| `matcha-mcp/` | Node MCP server + dashboard |
| `matcha-mcp/matcha-connector.luau` | In-VM bridge (served at `/script.luau`) |
| `matcha-loader.luau` | Minimal loader snippet |
| `matcha-scripts/` | Optional [SaveInstance](https://github.com/Matt-T-123/SaveInstance) export presets |
| `docs/` | Architecture, Matcha LuaVM notes, setup, tools |

## Security

- Port **16385** has **no authentication**. Use on **localhost** only — never expose to the internet.
- `memory-read` / `memory-write` can corrupt the Roblox process. Enable only if you understand the risk.

## Documentation

- [Matcha LuaVM primer](docs/matcha-luavm.md) — what Matcha is, APIs, limits vs executors
- [Architecture](docs/architecture.md) — how the bridge works
- [Tools](docs/tools.md) — when to use each MCP tool
- [Setup (all clients)](docs/setup.md)
- [Official Matcha docs](https://doc.wabisabi.mom/matcha/)

## Credits

Inspired by [roblox-executor-mcp](https://github.com/notpoiu/roblox-executor-mcp). Rebuilt for Matcha's HTTP-only, hook-free LuaVM.

## License

MIT — see [LICENSE](LICENSE).
