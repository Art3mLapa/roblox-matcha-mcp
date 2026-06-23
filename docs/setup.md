# MCP client setup

Build first:

```bash
cd matcha-mcp && npm install && npm run build
```

Use the **absolute path** to `matcha-mcp/dist/index.js` in all examples below.

## Cursor

Project file: `.cursor/mcp.json`  
Global: `~/.cursor/mcp.json` (Windows: `%USERPROFILE%\.cursor\mcp.json`)

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

Restart MCP in Cursor settings. Green dot = server started; you still need the Matcha loader running in-game.

## Claude Code

```bash
claude mcp add --global matcha-mcp -- node /absolute/path/to/matcha-mcp/dist/index.js
claude mcp list
```

## Claude Desktop

Edit `claude_desktop_config.json`:

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

## Windsurf / Antigravity

Same JSON shape as Cursor in the MCP servers section of settings.

## Codex / OpenAI

Add to your Codex MCP config:

```toml
[mcp_servers.matcha-mcp]
command = "node"
args = ["/absolute/path/to/matcha-mcp/dist/index.js"]
```

## Connect the game

After the MCP server is running, execute in Matcha:

```lua
loadstring(game:HttpGet("http://localhost:16385/script.luau"))()
```

Or use [`matcha-loader.luau`](../matcha-loader.luau).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| MCP red / won't start | `npm run build`, check Node path in config |
| No clients in `list-clients` | Run loader in Matcha; check dashboard at :16385 |
| Tools timeout | Matcha HTTP blocked? Bridge URL must match `BridgeURL` |
| Stale connector after updates | Stop old script; run loader once (don't stack `execute` reloads) |
| `script-grep` empty | Wait for index on dashboard; backpack scripts index first |
