-- Decompile + export LocalPlayer Backpack (tools like StoneFree) to clipboard as .rbxlx XML
-- Run in Matcha after: loadstring(game:HttpGet("...SaveInstance.lua"))() is NOT needed — this loads it.

_G.CONFIG = {
    root = game:GetService("Players").LocalPlayer:WaitForChild("Backpack"),
    decompileScripts = true,
    excludePlayers = false,
    showConsole = true,
}

loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Matt-T-123/SaveInstance/refs/heads/main/SaveInstance.lua"
))()
