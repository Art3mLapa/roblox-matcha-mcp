# Matcha helper scripts

Optional **SaveInstance** presets for dumping scripts the MCP index does not cover. See [SaveInstance](https://github.com/Matt-T-123/SaveInstance).

Part of [Matcha MCP](../README.md).

## Quick run (Matcha)

**Backpack only** (tools + modules in backpack):

```lua
_G.CONFIG = {
    root = game.Players.LocalPlayer:WaitForChild("Backpack"),
    decompileScripts = true,
    excludePlayers = false,
    showConsole = true,
}
loadstring(game:HttpGet("https://raw.githubusercontent.com/Matt-T-123/SaveInstance/refs/heads/main/SaveInstance.lua"))()
```

**Full player** (Backpack + PlayerScripts + PlayerGui):

```lua
_G.CONFIG = {
    root = game.Players.LocalPlayer,
    decompileScripts = true,
    excludePlayers = false,
    showConsole = true,
}
loadstring(game:HttpGet("https://raw.githubusercontent.com/Matt-T-123/SaveInstance/refs/heads/main/SaveInstance.lua"))()
```

Output lands on clipboard — save as `.rbxlx` and open in Studio, or grep the XML locally.

## Files

- `SaveInstance.lua` — upstream copy
- `export-backpack.lua` — backpack preset
- `export-player-full.lua` — all under LocalPlayer
- `export-game-scripts.lua` — main game services only