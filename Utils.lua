local Utils = {}

-- JSON encoding/decoding (using existing Utilities module if available)
function Utils.jsonEncode(data)
    if Utilities and Utilities.jsonEncode then
        return Utilities.jsonEncode(data)
    else
        -- Fallback to simple implementation
        return Utils.simpleJsonEncode(data)
    end
end

function Utils.jsonDecode(str)
    if Utilities and Utilities.jsonDecode then
        return Utilities.jsonDecode(str)
    else
        -- Fallback would go here
        error("JSON decode not available")
    end
end

-- Simple JSON encoder for fallback
function Utils.simpleJsonEncode(data)
    local t = type(data)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return tostring(data)
    elseif t == "number" then
        return tostring(data)
    elseif t == "string" then
        return string.format('"%s"', data:gsub('"', '\\"'))
    elseif t == "table" then
        local isArray = #data > 0
        local parts = {}
        
        if isArray then
            for i, v in ipairs(data) do
                parts[i] = Utils.simpleJsonEncode(v)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(data) do
                table.insert(parts, string.format('"%s":%s', k, Utils.simpleJsonEncode(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return "null"
    end
end

-- Generate UUID v4
function Utils.generateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- Deep copy a table
function Utils.deepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in next, orig, nil do
            copy[Utils.deepCopy(k)] = Utils.deepCopy(v)
        end
        setmetatable(copy, Utils.deepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Merge two tables (shallow)
function Utils.tableMerge(t1, t2)
    local result = {}
    for k, v in pairs(t1) do
        result[k] = v
    end
    for k, v in pairs(t2) do
        result[k] = v
    end
    return result
end

-- Check if a table contains a value
function Utils.tableContains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- Get table size (including non-numeric keys)
function Utils.tableSize(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- Create a debounced function
function Utils.debounce(func, delay)
    local timer = 0
    return function(...)
        local args = {...}
        timer = delay
        return function()
            if timer > 0 then
                timer = timer - 1
            else
                func(unpack(args))
            end
        end
    end
end

-- Format time in seconds to readable format
function Utils.formatTime(seconds)
    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
    else
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        return string.format("%dh %dm", hours, minutes)
    end
end

-- Calculate hash of a pokemon state for change detection
function Utils.hashPokemonState(pokemon)
    if not pokemon then return "" end
    
    return string.format("%d:%d:%d:%d:%d",
        pokemon.pokemonID or 0,
        pokemon.level or 0,
        pokemon.curHP or 0,
        pokemon.status or 0,
        pokemon.heldItem or 0
    )
end

-- Safe table access with default value
function Utils.getTableValue(table, path, default)
    local current = table
    for key in string.gmatch(path, "[^%.]+") do
        if type(current) ~= "table" then
            return default
        end
        current = current[key]
    end
    return current or default
end

-- Create a class-like table
function Utils.createClass(base)
    local cls = {}
    cls.__index = cls
    
    if base then
        setmetatable(cls, {
            __index = base,
            __call = function(c, ...)
                local obj = setmetatable({}, c)
                if obj.initialize then
                    obj:initialize(...)
                end
                return obj
            end
        })
    else
        setmetatable(cls, {
            __call = function(c, ...)
                local obj = setmetatable({}, c)
                if obj.initialize then
                    obj:initialize(...)
                end
                return obj
            end
        })
    end
    
    return cls
end

-- Rate limiter
function Utils.createRateLimiter(maxCalls, timeWindow)
    local calls = {}
    
    return function()
        local now = os.time()
        local windowStart = now - timeWindow
        
        -- Remove old calls
        local newCalls = {}
        for _, callTime in ipairs(calls) do
            if callTime > windowStart then
                table.insert(newCalls, callTime)
            end
        end
        calls = newCalls
        
        -- Check if we can make a new call
        if #calls < maxCalls then
            table.insert(calls, now)
            return true
        end
        
        return false
    end
end

-- Error handler with context
function Utils.pcallWithContext(func, context, ...)
    local args = {...}
    local success, result = pcall(function()
        return func(unpack(args))
    end)
    
    if not success then
        local errorMsg = string.format("[%s] Error: %s", context or "Unknown", tostring(result))
        return false, errorMsg
    end
    
    return true, result
end

return Utils
