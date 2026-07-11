-- Matcha MCP connector — HTTP polling bridge for Matcha LuaVM
-- Docs: https://doc.wabisabi.mom/matcha/

-- ponytail: Matcha has no game:IsLoaded
local function waitForGame()
    local players = game:GetService("Players")
    local deadline = os.clock() + 30
    repeat
        if (game.PlaceId or 0) > 0 then return end
        if players.LocalPlayer then return end
        task.wait(0.1)
    until os.clock() >= deadline
end
waitForGame()

local Config = _G.MatchaMCP or {}
local BridgeURL = Config.BridgeURL or "localhost:16385"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ponytail: Matcha serializes HTTP — one in flight; poll priority over uploads
local httpBusy = false
local httpPollWaiting = false

local function httpRequestRaw(opts)
    local url = opts.Url
    local method = (opts.Method or "GET"):upper()
    local headers = opts.Headers or {}
    local body = opts.Body or ""

    local ok, result = pcall(function()
        if method == "GET" then
            return game:HttpGet(url, headers)
        end
        if method == "POST" then
            local contentType = headers["Content-Type"] or "application/json"
            return game:HttpPost(url, body, contentType, headers)
        end
        assert(false, "unsupported HTTP method: " .. method)
    end)

    if not ok then
        if method == "GET" then
            return { StatusCode = 204, Body = "" }
        end
        return { StatusCode = 500, Body = tostring(result) }
    end

    if method == "GET" and (result == nil or result == "") then
        return { StatusCode = 204, Body = "" }
    end

    return { StatusCode = 200, Body = result }
end

local function httpRequest(opts, priority)
    if priority == "poll" then
        while httpBusy do
            httpPollWaiting = true
            task.wait(0.05)
        end
        httpBusy = true
        local response = httpRequestRaw(opts)
        httpBusy = false
        if httpPollWaiting then
            httpPollWaiting = false
        end
        return response
    end

    while httpBusy or httpPollWaiting do
        task.wait(0.05)
    end
    httpBusy = true
    local response = httpRequestRaw(opts)
    httpBusy = false
    return response
end

local LuaEncode
do
    local ok = pcall(function()
        local source = game:HttpGet(
            "https://raw.githubusercontent.com/chadhyatt/LuaEncode/refs/heads/master/src/LuaEncode.lua"
        )
        if not source or source == "" then return end
        -- ponytail: Matcha's loadstring drops return values — capture via global
        _G.__mcp_luaencode = nil
        local wrapped = 'local __r = (function()\n' .. source .. '\nend)(); _G.__mcp_luaencode = __r'
        loadstring(wrapped)()
    end)
    if ok and _G.__mcp_luaencode then
        LuaEncode = _G.__mcp_luaencode
        _G.__mcp_luaencode = nil
    end
end

-- ponytail: server tools prepend setthreadidentity — Matcha doesn't have it
local function stripThreadPrefix(source)
    if typeof(source) ~= "string" then return "" end
    return (source:gsub("^%s*setthreadidentity%s*%(%s*%d+%s*%)%s*;?", ""))
end

local EVAL_ENV = _G

local function packValues(...)
    if typeof(table.pack) == "function" then
        return table.pack(...)
    end
    local n = select("#", ...)
    local t = { n = n }
    for i = 1, n do
        t[i] = select(i, ...)
    end
    return t
end

-- ponytail: Matcha's loadstring drops top-level return values.
-- Expose packValues so wrapped chunks can store results via _G.
_G.__mcp_pack = packValues

local function loadChunk(source, chunkname)
    local fn, err
    -- ponytail: Matcha's load only takes (chunk, chunkname) — extra args ignored
    if typeof(loadstring) == "function" then
        fn, err = loadstring(source, chunkname)
    elseif typeof(load) == "function" then
        fn, err = load(source, chunkname)
    end
    -- ponytail: Matcha always returns a function (syntax errors print on call,
    -- never nil+err), so fn should not be nil. Guard anyway with assert.
    if not fn then
        assert(false, tostring(err or "compile failed"))
    end
    return fn
end

local function tryEvalAtom(expr)
    expr = expr:match("^%s*(.-)%s*$")
    if expr == "" then return nil end

    local num = tonumber(expr)
    if num then return num end
    if expr == "true" then return true end
    if expr == "false" then return false end

    local str = expr:match('^"(.*)"$') or expr:match("^'(.*)'$")
    if str then return str end

    if expr:match("^game%.") or expr == "game" then
        local ok, value = pcall(function()
            local path = expr
            if path == "game" then return game end
            local obj = game
            local rest = path:sub(6)
            local segments = {}
            for seg in string.gmatch(rest, "[^%.]+") do
                table.insert(segments, seg)
            end
            for i, seg in ipairs(segments) do
                if i == #segments then
                    local child = obj:FindFirstChild(seg)
                    if child then return child end
                    return obj[seg]
                end
                local nextObj = obj:FindFirstChild(seg) or obj[seg]
                if nextObj == nil then return nil end
                obj = nextObj
            end
            return obj
        end)
        if ok and value ~= nil then return value end
    end

    return nil
end

local function probeBackpack()
    local lp = Players.LocalPlayer
    if not lp then return nil end
    local out = { player = lp.Name, tools = {} }
    local bp = lp:FindFirstChild("Backpack")
    if bp then
        for _, t in bp:GetChildren() do
            table.insert(out.tools, { name = t.Name, class = t.ClassName })
        end
    end
    return out
end

local function tryFastEval(source)
    local stripped = stripThreadPrefix(source)
    if stripped:find("Backpack", 1, true) and stripped:find("GetChildren", 1, true) then
        local summary = probeBackpack()
        if summary then return packValues(summary) end
    end

    local body = stripped:match("^%s*return%s+(.+)%s*;?%s*$")
    if not body then return nil end

    if not body:find(",", 1, true) then
        local v = tryEvalAtom(body)
        if v ~= nil then return packValues(v) end
        return nil
    end

    local vals, n = {}, 0
    for part in string.gmatch(body, "([^,]+)") do
        local v = tryEvalAtom(part)
        if v == nil then return nil end
        n += 1
        vals[n] = v
    end
    if n == 1 then return packValues(vals[1]) end
    if n == 2 then return packValues(vals[1], vals[2]) end
    if n == 3 then return packValues(vals[1], vals[2], vals[3]) end
    local unpack = table.unpack or unpack
    if unpack and n > 0 then return packValues(unpack(vals, 1, n)) end
    return nil
end

local function evalChunkReturns(source)
    -- Fast path: atoms, dot-paths, backpack probe (avoids loadstring entirely)
    local fast = tryFastEval(source)
    if fast and fast.n > 0 then
        return fast
    end

    -- ponytail: Matcha's loadstring drops top-level return values.
    -- Workaround: wrap source in a function, call it, store results via _G.
    source = stripThreadPrefix(source or "")
    assert(source ~= "", "no source code provided")

    _G.__mcp_results = nil

    -- Wrap in a function so return values are preserved as a regular
    -- function call result (not a chunk top-level return, which Matcha drops).
    local wrapped = 'local function __mcp_fn()\n' .. source .. '\nend\n_G.__mcp_results = _G.__mcp_pack(__mcp_fn())'

    local fn = loadChunk(wrapped, "MatchaMCP")
    fn() -- runtime errors are pcall-caught by HandleMessage

    local results = _G.__mcp_results
    _G.__mcp_results = nil
    if results == nil then
        return packValues()
    end
    return results
end

local function runSource(source)
    local packed = evalChunkReturns(source)
    if packed.n == 0 then
        assert(false, "code returned no values")
    end
    return packed[1]
end

local function runChunk(source)
    source = stripThreadPrefix(source or "")
    assert(source ~= "", "no source code provided")
    local fn = loadChunk(source, "MatchaMCP")
    fn()
end

local function resolveInstancePath(path)
    if not path or path == "" or path == "game" then
        return game
    end
    local ok, inst = pcall(function()
        return runSource("return " .. path)
    end)
    if ok and inst and typeof(inst) == "Instance" then
        return inst
    end
    local current = game
    for segment in string.gmatch(path, "[^%.]+") do
        if segment == "game" then
            continue
        elseif segment == "LocalPlayer" and current:IsA("Players") then
            current = current.LocalPlayer
            if not current then return nil end
        else
            local nextInst = current:FindFirstChild(segment)
            if not nextInst then
                return nil
            end
            current = nextInst
        end
    end
    return current
end

local SANITIZE_MAX_DEPTH = 8
local SANITIZE_MAX_ENTRIES = 60
local SANITIZE_MAX_STRING = 500

local function SanitizeForOutput(value, depth, seen)
    depth = depth or 0
    local valueType = typeof(value)

    if valueType == "Instance" then
        local ok, full = pcall(function() return value:GetFullName() end)
        return ok and full or tostring(value)
    elseif valueType == "string" then
        if #value > SANITIZE_MAX_STRING then
            return string.sub(value, 1, SANITIZE_MAX_STRING)
                .. "(+" .. (#value - SANITIZE_MAX_STRING) .. " chars omitted)"
        end
        return value
    elseif valueType == "number" or valueType == "boolean" or valueType == "nil" then
        return value
    elseif valueType ~= "table" then
        return tostring(value)
    end

    if depth >= SANITIZE_MAX_DEPTH then
        return "<table: max depth reached>"
    end

    seen = seen or {}
    if seen[value] then
        return "<cyclic table>"
    end
    seen[value] = true

    local result = {}
    local count = 0
    local omitted = 0
    for k, v in pairs(value) do
        if count >= SANITIZE_MAX_ENTRIES then
            omitted += 1
            continue
        end
        count += 1
        local key = k
        if typeof(k) ~= "string" and typeof(k) ~= "number" then
            key = tostring(k)
        end
        result[key] = SanitizeForOutput(v, depth + 1, seen)
    end
    if omitted > 0 then
        result._omitted = omitted .. " more entries omitted"
    end
    return result
end

local function serializePacked(packed)
    local values = {}
    for i = 1, packed.n do
        local ok, sanitized = pcall(SanitizeForOutput, packed[i])
        values[i] = ok and sanitized or tostring(sanitized)
    end
    if packed.n == 0 then
        return HttpService:JSONEncode({
            count = 0,
            error = "code returned no values",
            values = {},
        })
    end
    -- ponytail: string-key root only — Matcha JSONEncode chokes on mixed array/dict roots
    local ok, json = pcall(function()
        return HttpService:JSONEncode({ count = packed.n, values = values })
    end)
    if not ok then
        assert(false, "JSONEncode: " .. tostring(json))
    end
    return json
end

local function ScriptId(script)
    if typeof(script.GetDebugId) == "function" then
        local ok, id = pcall(function() return script:GetDebugId() end)
        if ok and id then return tostring(id) end
    end
    return tostring(script.Address)
end

local function DecompileScriptSource(script)
    if typeof(decompile) ~= "function" then return nil end
    local ok, source = pcall(decompile, script)
    return ok and source or nil
end

-- ponytail: class-name selector only; upgrade path: full CSS selector engine
local function QueryDescendants(root, selector)
    if typeof(root.QueryDescendants) == "function" then
        local ok, results = pcall(function() return root:QueryDescendants(selector) end)
        if ok and results then return results end
    end

    local results = {}
    for _, inst in root:GetDescendants() do
        if selector == "LuaSourceContainer" then
            if inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
                table.insert(results, inst)
            end
        elseif inst:IsA(selector) then
            table.insert(results, inst)
        end
    end
    return results
end

local ConsoleLogs = {}
if not _G.__MatchaMCPConsoleHooked then
    _G.__MatchaMCPConsoleHooked = true
    local oldPrint = print
    local oldWarn = warn

    local function captureLog(levelName, ...)
        local parts = { ... }
        for i = 1, #parts do
            parts[i] = tostring(parts[i])
        end
        local msg = table.concat(parts, "\t")
        table.insert(ConsoleLogs, {
            message = msg,
            timestamp = os.time(),
            messageType = { Name = levelName },
        })
        if #ConsoleLogs > 500 then
            table.remove(ConsoleLogs, 1)
        end
    end

    -- ponytail: Matcha's print/warn are real globals — hook them to capture output
    print = function(...)
        captureLog("Message", ...)
        return oldPrint(...)
    end
    if oldWarn then
        warn = function(...)
            captureLog("Warning", ...)
            return oldWarn(...)
        end
    end
end

local function GetRegistrationInfo()
    local player = Players.LocalPlayer
    local placeName = "Unknown"
    if typeof(getgamename) == "function" then
        local ok, name = pcall(getgamename)
        if ok and name then placeName = name end
    end
    return {
        type = "register",
        username = player and player.Name or "Unknown",
        userId = player and player.UserId or 0,
        placeId = game.PlaceId,
        jobId = game.JobId,
        placeName = placeName,
    }
end

local BaseBridge = {}
BaseBridge.__index = BaseBridge

function BaseBridge:BindToType(type, callback)
    self.Callbacks[type] = callback
end

function BaseBridge:BindToTypeRaw(type, callback)
    self.Callbacks[type] = callback
    self.RawCallbacks = self.RawCallbacks or {}
    self.RawCallbacks[type] = true
end

function BaseBridge:HandleMessage(data)
    if not self.Callbacks[data.type] then return nil end

    local success, result = pcall(function()
        return self.Callbacks[data.type](data)
    end)

    if success and result == nil then return nil end
    if not success then
        return self:FormatResponse(result, data.id, true)
    end
    if self.RawCallbacks and self.RawCallbacks[data.type] then
        return { output = tostring(result), success = true, id = data.id }
    end
    return self:FormatResponse(result, data.id, false)
end

function BaseBridge:FormatResponse(message, id, isError)
    if isError then
        return { error = tostring(message), success = false, id = id }
    end

    local output = SanitizeForOutput(message)
    if typeof(output) ~= "table" then
        output = { output }
    end

    return {
        output = LuaEncode
            and LuaEncode(output, { Prettify = false })
            or HttpService:JSONEncode(output),
        success = true,
        id = id,
    }
end

function BaseBridge:IsAlive()
    local ok, alive = pcall(function()
        local response = httpRequest({ Url = "http://" .. BridgeURL, Method = "GET" })
        return response.StatusCode == 200 or response.StatusCode == 426
    end)
    return ok and alive
end

local HTTPBridge = setmetatable({}, { __index = BaseBridge })
HTTPBridge.__index = HTTPBridge

function HTTPBridge.new()
    local self = setmetatable({}, HTTPBridge)
    self.Connected = true
    self.Callbacks = {}
    self.PollInterval = Config.PollInterval or 0.35
    self.ClientId = Config.ClientId or (_G.MatchaMCP and _G.MatchaMCP.ClientId)

    local retryDelay = 0.5
    local attempts = 0
    while not self:IsAlive() do
        attempts += 1
        if attempts >= 10 then
            assert(false, "Matcha MCP: bridge not reachable at " .. BridgeURL)
        end
        task.wait(retryDelay)
        retryDelay = math.min(retryDelay * 1.5, 5)
    end

    local function tryRegister()
        local reg = httpRequest({
            Url = "http://" .. BridgeURL .. "/register",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(GetRegistrationInfo()),
        })
        if reg.StatusCode == 200 and reg.Body and reg.Body ~= "" then
            local regData = HttpService:JSONDecode(reg.Body)
            if regData.clientId then
                self.ClientId = regData.clientId
                _G.MatchaMCP = _G.MatchaMCP or {}
                _G.MatchaMCP.ClientId = self.ClientId
            end
        end
    end

    if not self.ClientId then
        pcall(tryRegister)
    else
        -- ponytail: reuse clientId — poll refreshes lastHttpPoll on server
        local probe = httpRequest({
            Url = "http://" .. BridgeURL .. "/poll?clientId=" .. self.ClientId,
            Method = "GET",
        }, "poll")
        if probe.StatusCode == 404
            or (probe.Body and string.find(probe.Body, "Unknown clientId", 1, true)) then
            self.ClientId = nil
            pcall(tryRegister)
        end
    end

    self.PollThread = task.spawn(function()
        local backoff = self.PollInterval
        while self.Connected do
            local gotCommands = false
            pcall(function()
                local pollUrl = "http://" .. BridgeURL .. "/poll"
                if self.ClientId then
                    pollUrl = pollUrl .. "?clientId=" .. self.ClientId
                end
                local response = httpRequest({ Url = pollUrl, Method = "GET" }, "poll")

                if response.StatusCode ~= 204 and response.StatusCode ~= 200 then
                    backoff = math.min(backoff * 1.5, 3)
                    return
                end

                backoff = self.PollInterval

                if not response.Body or response.Body == "" then
                    return
                end

                local decodeOk, data = pcall(function()
                    return HttpService:JSONDecode(response.Body)
                end)
                if not decodeOk then
                    return
                end

                local commands = {}
                if typeof(data) == "table" and data.type == nil and #data > 0 then
                    commands = data
                elseif typeof(data) == "table" and data.type ~= nil then
                    commands = { data }
                end

                for _, command in ipairs(commands) do
                    gotCommands = true
                    task.spawn(function()
                        local result = self:HandleMessage(command)
                        if result == nil then return end
                        httpRequest({
                            Url = "http://" .. BridgeURL .. "/respond",
                            Method = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body = HttpService:JSONEncode(result),
                        })
                    end)
                end
            end)

            task.wait(gotCommands and 0.05 or backoff)
        end
    end)

    return self
end

function HTTPBridge:WaitForDisconnect()
    while self.Connected do
        task.wait(0.1)
    end
end

-- Script source index (uploaded to MCP server for script-grep)
local MappedScriptIds = {}
local ScriptInstanceMap = setmetatable({}, { __mode = "v" })
local ScriptSourceUploadClientId = nil
local HasStartedMapping = false

local function UploadScriptSourceBatch(clientId, scripts, hasFinishedMapping, sourcesToMap, processedSources, mappedSources)
    if not clientId then return false end
    local ok, response = pcall(function()
        return httpRequest({
            Url = "http://" .. BridgeURL .. "/script-sources",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                clientId = clientId,
                scripts = scripts or {},
                hasFinishedMapping = hasFinishedMapping,
                sourcesToMap = sourcesToMap or 0,
                processedSources = processedSources or 0,
                skippedSources = math.max(0, (processedSources or 0) - (mappedSources or 0)),
            }),
        })
    end)
    return ok and response and response.StatusCode == 200
end

local function GetScriptByDebugId(debugId)
    if ScriptInstanceMap[debugId] then return ScriptInstanceMap[debugId] end
    for _, script in QueryDescendants(game, "LuaSourceContainer") do
        if ScriptId(script) == debugId then
            ScriptInstanceMap[debugId] = script
            return script
        end
    end
    return nil
end

local function CollectScriptsPrioritized(maxScripts)
    local seen = {}
    local out = {}

    local function tryAdd(script)
        if #out >= maxScripts then return true end
        if not script or not script:IsA("LuaSourceContainer") then return false end
        local id = ScriptId(script)
        if seen[id] then return false end
        seen[id] = true
        table.insert(out, script)
        return #out >= maxScripts
    end

    local function scanRoot(root)
        if not root then return end
        for _, inst in root:GetDescendants() do
            if inst:IsA("LocalScript") or inst:IsA("ModuleScript") or inst:IsA("Script") then
                if tryAdd(inst) then return end
            end
        end
    end

    -- ponytail: player/backpack first — don't burn cap on random game scripts
    local lp = Players.LocalPlayer
    if lp then
        scanRoot(lp:FindFirstChild("Backpack"))
        scanRoot(lp:FindFirstChild("PlayerScripts"))
        scanRoot(lp:FindFirstChild("PlayerGui"))
        scanRoot(lp.Character)
    end
    scanRoot(game.Workspace:FindFirstChild("Entities"))
    scanRoot(game:GetService("ReplicatedStorage"))

    if #out < maxScripts and typeof(getscripts) == "function" then
        local ok, all = pcall(getscripts)
        if ok and typeof(all) == "table" then
            for _, script in all do
                if tryAdd(script) then break end
                if #out % 100 == 0 then task.wait() end
            end
        end
    end

    return out
end

local function StartScriptMapping(clientId)
    if HasStartedMapping then return end
    if Config.DisableInitialScriptDecompMapping == true then return end
    HasStartedMapping = true
    ScriptSourceUploadClientId = clientId

    task.spawn(function()
        local maxScripts = Config.MaxScriptMapping or 700
        local scripts = CollectScriptsPrioritized(maxScripts)
        local sourcesToMap = #scripts
        local processed = 0
        local mapped = 0

        for _, script in scripts do
            processed += 1
            local id = ScriptId(script)
            if MappedScriptIds[id] then continue end

            local source = DecompileScriptSource(script)
            if source then
                mapped += 1
                MappedScriptIds[id] = true
                ScriptInstanceMap[id] = script
                UploadScriptSourceBatch(clientId, {
                    { debugId = id, path = script:GetFullName(), source = source },
                }, false, sourcesToMap, processed, mapped)
            elseif processed % 10 == 0 then
                task.wait() -- ponytail: poll thread gets a turn when decompile skips pile up
            end
        end

        UploadScriptSourceBatch(clientId, {}, true, sourcesToMap, processed, mapped)
    end)
end

local function WaitForBridgeClientId(bridge)
    local deadline = os.clock() + 5
    repeat
        if bridge.ClientId then return bridge.ClientId end
        if not bridge.Connected then return nil end
        task.wait(0.05)
    until os.clock() >= deadline
    return nil
end

while true do
    local ok, bridge = pcall(function() return HTTPBridge.new() end)
    if not ok then
        task.wait(5)
        continue
    end

    bridge:BindToType("execute", function(data)
        -- ponytail: Matcha's task.defer is a no-op — run directly instead
        runChunk(data.source or data.code)
    end)

    bridge:BindToTypeRaw("get-console-output", function(data)
        local limit = math.max(1, math.min(tonumber(data.limit) or 20, 200))
        local logsOrder = data.logsOrder or "NewestFirst"
        local filter = data.filter
        local hasFilter = typeof(filter) == "string" and filter ~= ""
        local summaryOnly = data.summaryOnly == true

        local logs = ConsoleLogs
        -- ponytail: try LogService:GetLogHistory() (may not exist in Matcha)
        local lsOk, logService = pcall(function() return game:GetService("LogService") end)
        if lsOk and logService then
            local histOk, history = pcall(function() return logService:GetLogHistory() end)
            if histOk and history and #history > 0 then
                logs = history
            end
        end

        local results = {}
        local matchedCount = 0
        local countsByLevel = {}

        local function matchesFilter(entry)
            if not hasFilter then return true end
            return string.find(tostring(entry.message), filter, 1, true) ~= nil
        end

        if logsOrder == "NewestFirst" then
            for i = #logs, 1, -1 do
                local entry = logs[i]
                if not matchesFilter(entry) then continue end
                matchedCount += 1
                local level = entry.messageType and entry.messageType.Name or "Message"
                countsByLevel[level] = (countsByLevel[level] or 0) + 1
                if #results < limit then table.insert(results, entry) end
            end
        else
            for _, entry in logs do
                if not matchesFilter(entry) then continue end
                matchedCount += 1
                local level = entry.messageType and entry.messageType.Name or "Message"
                countsByLevel[level] = (countsByLevel[level] or 0) + 1
                if #results < limit then table.insert(results, entry) end
            end
        end

        if summaryOnly then
            local lines = { string.format("Matched %d logs.", matchedCount) }
            for level, count in countsByLevel do
                table.insert(lines, string.format("%s: %d", level, count))
            end
            return table.concat(lines, "\n")
        end

        local lines = { string.format("Displaying %d/%d logs:", #results, matchedCount) }
        for _, entry in results do
            local level = entry.messageType and entry.messageType.Name or "Message"
            table.insert(lines, string.format("[%s] %s", level, tostring(entry.message)))
        end
        return table.concat(lines, "\n")
    end)

    bridge:BindToTypeRaw("get-data-by-code", function(data)
        local chunk = data.source or data.code
        if not chunk or chunk == "" then
            assert(false, "no code in request")
        end
        return serializePacked(evalChunkReturns(chunk))
    end)

    bridge:BindToTypeRaw("get-script-content", function(data)
        local scriptInstance
        if data.debugId then
            scriptInstance = GetScriptByDebugId(data.debugId)
            assert(scriptInstance, "No script for id: " .. tostring(data.debugId))
        else
            local getter = data.source
            if getter and string.match(getter, "^%s*return%s+game%.") then
                local path = getter:match("^%s*return%s+(.+)%s*;?%s*$")
                if path then
                    scriptInstance = resolveInstancePath(path)
                end
            end
            if not scriptInstance then
                scriptInstance = runSource(getter)
            end
            assert(typeof(scriptInstance) == "Instance", "Expected Instance")
        end

        local source = DecompileScriptSource(scriptInstance)
        assert(source, "decompile failed")

        local id = ScriptId(scriptInstance)
        if ScriptSourceUploadClientId and not MappedScriptIds[id] then
            if UploadScriptSourceBatch(ScriptSourceUploadClientId, {
                { debugId = id, path = scriptInstance:GetFullName(), source = source },
            }, false, 1, 1, 1) then
                MappedScriptIds[id] = true
            end
        end

        local lines = {}
        for line in string.gmatch(source .. "\n", "(.-)\n") do
            table.insert(lines, line)
        end

        local totalLines = #lines
        local maxLines = math.max(1, math.min(tonumber(data.maxLines) or 200, 2000))
        local startLine = data.startLine and math.max(1, math.min(data.startLine, totalLines)) or 1
        local endLine = math.min(
            data.endLine and math.max(startLine, math.min(data.endLine, totalLines)) or totalLines,
            startLine + maxLines - 1
        )

        local sliced = {}
        for i = startLine, endLine do
            table.insert(sliced, lines[i])
        end

        return "-- Lines " .. startLine .. "-" .. endLine .. " of " .. totalLines .. "\n"
            .. table.concat(sliced, "\n")
    end)

    bridge:BindToType("search-instances", function(data)
        local rootInstance = resolveInstancePath(data.root)
        assert(rootInstance, "invalid root: " .. tostring(data.root))
        local instances = QueryDescendants(rootInstance, data.selector)
        local limit = math.max(1, math.min(tonumber(data.limit) or 20, 100))
        local results = {}

        for i, instance in instances do
            if i > limit then break end
            local fullName = instance.Name
            pcall(function() fullName = instance:GetFullName() end)
            table.insert(results, {
                Name = instance.Name,
                ClassName = instance.ClassName,
                Path = fullName,
                DebugId = ScriptId(instance),
            })
        end

        return { count = #instances, limited = #instances > limit, results = results }
    end)

    bridge:BindToType("get-game-info", function()
        local placeName = "Unknown"
        if typeof(getgamename) == "function" then
            local ok, name = pcall(getgamename)
            if ok and name then placeName = name end
        end
        local executor = "Matcha"
        if typeof(identifyexecutor) == "function" then
            local ok, name, ver = pcall(identifyexecutor)
            if ok then executor = ver and (name .. " " .. ver) or name end
        end
        return {
            PlaceId = game.PlaceId,
            GameId = game.GameId,
            JobId = game.JobId,
            PlaceName = placeName,
            Executor = executor,
            ConnectorVersion = "matcha-fix-2",
        }
    end)

    bridge:BindToType("get-descendants-tree", function(data)
        local rootInstance = resolveInstancePath(data.root)
        assert(rootInstance, "invalid root: " .. tostring(data.root))

        local maxDepth = math.max(0, math.min(tonumber(data.maxDepth) or 2, 5))
        local maxChildren = math.max(1, math.min(tonumber(data.maxChildren) or 20, 30))
        local classFilter = data.classFilter or ""
        local hasFilter = classFilter ~= ""
        local summaryOnly = data.summaryOnly == true

        if summaryOnly then
            local classCounts = {}
            local visited, matched = 0, 0
            local function walk(inst, depth)
                if depth > maxDepth then return end
                for _, child in inst:GetChildren() do
                    visited += 1
                    if not hasFilter or child:IsA(classFilter) then
                        matched += 1
                        classCounts[child.ClassName] = (classCounts[child.ClassName] or 0) + 1
                    end
                    if depth < maxDepth then walk(child, depth + 1) end
                end
            end
            walk(rootInstance, 1)
            return {
                Root = { Name = rootInstance.Name, ClassName = rootInstance.ClassName, ChildCount = #rootInstance:GetChildren() },
                VisitedDescendants = visited,
                MatchedDescendants = matched,
                ClassCounts = classCounts,
            }
        end

        local function buildTree(inst, depth)
            if depth > maxDepth then return nil end
            local children = inst:GetChildren()
            local childNodes, shown = {}, 0
            for _, child in children do
                if shown >= maxChildren then break end
                if hasFilter and not child:IsA(classFilter) then continue end
                local node = { Name = child.Name, ClassName = child.ClassName, ChildCount = #child:GetChildren() }
                if depth < maxDepth and node.ChildCount > 0 then
                    local sub = buildTree(child, depth + 1)
                    if sub then node.Children = sub.Children end
                end
                table.insert(childNodes, node)
                shown += 1
            end
            return { Name = inst.Name, ClassName = inst.ClassName, ChildCount = #children, Children = childNodes }
        end

        return buildTree(rootInstance, 0)
    end)

    bridge:BindToType("memory-read", function(data)
        assert(typeof(memory_read) == "function", "memory_read unavailable (enable unsafe Luau)")
        local address = tonumber(data.address)
        assert(address, "address required")
        return memory_read(data.memoryType or "uintptr_t", address)
    end)

    bridge:BindToType("memory-write", function(data)
        assert(typeof(memory_write) == "function", "memory_write unavailable (enable unsafe Luau)")
        local address = tonumber(data.address)
        assert(address, "address required")
        memory_write(data.memoryType or "uintptr_t", address, data.value)
        return true
    end)

    bridge:BindToType("get-memory-base", function()
        assert(typeof(getbase) == "function", "getbase unavailable")
        return getbase()
    end)

    local clientId = WaitForBridgeClientId(bridge)
    if clientId then
        StartScriptMapping(clientId)
    end

    bridge:WaitForDisconnect()
    -- ponytail: only reached if Connected=false (shouldn't happen); long backoff
    task.wait(30)
end
