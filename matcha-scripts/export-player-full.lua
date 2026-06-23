-- Export everything under LocalPlayer: Backpack, PlayerScripts, PlayerGui (includes StoneFree tool scripts)
_G.CONFIG = {
    root = game:GetService("Players").LocalPlayer,
    decompileScripts = true,
    excludePlayers = false,
    showConsole = true,
}

loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Matt-T-123/SaveInstance/refs/heads/main/SaveInstance.lua"
))()
