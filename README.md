# Matcha MCP

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

- **Node.js** 18+ (to run the MCP server)
- **[Matcha](https://doc.wabisabi.mom/matcha/)** attached to a Roblox session
- An MCP-capable editor (Cursor, Claude Desktop, Windsurf, etc.)

## Install

### 1. Clone and build the server

```bash
git clone https://github.com/wavelyz/roblox-matcha-mcp.git
cd roblox-matcha-mcp/matcha-mcp
npm install
npm run build
```

### 2. Add to MCP config

**Cursor** — project `.cursor/mcp.json` or global `~/.cursor/mcp.json`:

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

See [docs/setup.md](docs/setup.md) for Windsurf, Codex, and other clients.

Restart the MCP server in your editor after changing config.

### 3. Connect Matcha to the bridge

Run once per Roblox session (Matcha auto-run / script hub):

```lua
-- matcha-loader.luau (or paste this)
_G.MatchaMCP = _G.MatchaMCP or {}
_G.MatchaMCP.BridgeURL = _G.MatchaMCP.BridgeURL or "localhost:16385"

loadstring(game:HttpGet("http://" .. _G.MatchaMCP.BridgeURL .. "/script.luau"))()
```

The connector is served from the MCP server at `http://localhost:16385/script.luau` — no separate download.

**Dashboard:** [http://localhost:16385/](http://localhost:16385/) — connection status, script index progress.

### 4. Verify

In your AI client, call `list-clients`. You should see your player name and place ID. Then try `get-game-info` or `get-descendants-tree` on `game.Players.LocalPlayer.Backpack`.

## What the agent can do

| Tool | What it does |
|------|----------------|
| `list-clients` / `set-active-client` | See and pick which Roblox session to talk to |
| `execute` / `execute-file` | Run Luau in Matcha (no return value) |
| `get-data-by-code` | Run Luau and get return values (small probes) |
| `get-descendants-tree` | Explore instance hierarchy under a path |
| `search-instances` | Find instances by class under a root |
| `get-game-info` | PlaceId, JobId, game name, executor version |
| `get-script-content` | Decompile a script by path (line ranges) |
| `script-grep` | Search decompiled sources for text/regex |
| `semantic-search-scripts` | Search scripts by behavior (needs embedding config) |
| `get-console-output` | Recent print output from the session |
| `memory-read` / `memory-write` / `get-memory-base` | Matcha process memory (unsafe Luau) |

Full tool guide: [docs/tools.md](docs/tools.md)

**Not included** (executor-only features): remote spy, GUI click/type, screenshots, WebSocket transport.

## Repo layout

| Path | Purpose |
|------|---------|
| `matcha-mcp/` | Node MCP server + dashboard |
| `matcha-mcp/matcha-connector.luau` | In-VM bridge (served at `/script.luau`) |
| `matcha-loader.luau` | Minimal loader snippet |
| `matcha-scripts/` | Optional [SaveInstance](https://github.com/Matt-T-123/SaveInstance) export presets |
| `docs/` | Architecture, Matcha LuaVM notes, setup |

## Connector config

Set on `_G.MatchaMCP` before loading:

| Key | Default | Description |
|-----|---------|-------------|
| `BridgeURL` | `localhost:16385` | MCP HTTP host |
| `MaxScriptMapping` | `700` | Max scripts to decompile for `script-grep` on connect |
| `DisableInitialScriptDecompMapping` | — | Set `true` to skip script index |

Index order: Backpack → PlayerScripts → PlayerGui → Character → Workspace.Entities → ReplicatedStorage → `getscripts()` until cap.

## Security

- Port **16385** has **no authentication**. Use on **localhost** only. Never expose to the internet.
- `memory-read` / `memory-write` can corrupt the Roblox process. Enable only if you understand the risk.

## Docs

- [Matcha LuaVM primer](docs/matcha-luavm.md) — what Matcha is, APIs, limits vs executors
- [Architecture](docs/architecture.md) — how the bridge works
- [Tools](docs/tools.md) — when to use each MCP tool
- [Setup (all clients)](docs/setup.md)
- [Official Matcha docs](https://doc.wabisabi.mom/matcha/)

## Credits

Inspired by [roblox-executor-mcp](https://github.com/notpoiu/roblox-executor-mcp). Rebuilt for Matcha's HTTP-only, hook-free LuaVM.

## License

MIT — see [LICENSE](LICENSE).
