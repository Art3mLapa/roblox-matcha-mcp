-- Full game script dump: ReplicatedStorage + Workspace + StarterGui (decompiled LocalScripts/ModuleScripts)
-- Output: clipboard (paste into .rbxlx file or Dex/Synapse save tools)

_G.CONFIG = {
    root = game,
    includeServices = {
        ReplicatedStorage = true,
        Workspace = true,
        StarterGui = true,
        StarterPlayer = true,
        Lighting = true,
    },
    decompileScripts = true,
    excludePlayers = true,
    showConsole = true,
}

loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Matt-T-123/SaveInstance/refs/heads/main/SaveInstance.lua"
))()
