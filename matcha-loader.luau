-- Matcha MCP loader — see README.md
_G.MatchaMCP = _G.MatchaMCP or {}
_G.MatchaMCP.BridgeURL = _G.MatchaMCP.BridgeURL or "localhost:16385"
_G.MatchaMCP.MaxScriptMapping = _G.MatchaMCP.MaxScriptMapping or 700

loadstring(game:HttpGet("http://" .. _G.MatchaMCP.BridgeURL .. "/script.luau"))()
