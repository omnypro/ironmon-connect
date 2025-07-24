local Config = {}

-- Default configuration values
Config.defaults = {
    -- Connection settings
    wsHost = "localhost",
    wsPort = 8080,
    reconnectAttempts = 5,
    reconnectDelay = 5000, -- milliseconds
    
    -- Performance settings
    updateFrequency = 30, -- frames between updates
    batchSize = 10, -- max events per batch
    batchInterval = 60, -- frames between batch sends
    
    -- Feature toggles
    runTracking = true,
    battleEvents = true,
    checkpoints = true,
    teamUpdates = true,
    locationTracking = true,
    
    -- Debug settings
    debug = false,
    logLevel = "info" -- "debug", "info", "warn", "error"
}

-- Current configuration (will be populated from saved settings)
Config.current = {}

-- Initialize configuration from saved settings
function Config.initialize()
    -- Copy defaults first
    for key, value in pairs(Config.defaults) do
        Config.current[key] = value
    end
    
    -- Load saved settings from TrackerAPI
    Config.load()
    
    -- Validate loaded settings
    Config.validate()
end

-- Load settings from TrackerAPI
function Config.load()
    if not TrackerAPI then
        print("[IronmonConnect] Warning: TrackerAPI not available, using defaults")
        return
    end
    
    -- Load each setting
    for key, defaultValue in pairs(Config.defaults) do
        local saved = TrackerAPI.getExtensionSetting("IronmonConnect", key)
        if saved ~= nil then
            -- Handle type conversion
            if type(defaultValue) == "boolean" then
                Config.current[key] = saved == true or saved == "true" or saved == 1
            elseif type(defaultValue) == "number" then
                Config.current[key] = tonumber(saved) or defaultValue
            else
                Config.current[key] = saved
            end
        end
    end
    
    if Config.current.debug then
        print("[IronmonConnect] Configuration loaded successfully")
    end
end

-- Save a setting
function Config.set(key, value)
    if Config.defaults[key] == nil then
        print("[IronmonConnect] Warning: Unknown setting key: " .. tostring(key))
        return false
    end
    
    Config.current[key] = value
    
    if TrackerAPI then
        TrackerAPI.saveExtensionSetting("IronmonConnect", key, value)
    end
    
    return true
end

-- Get a setting value
function Config.get(key)
    return Config.current[key] or Config.defaults[key]
end

-- Validate configuration values
function Config.validate()
    -- Validate port range
    if Config.current.wsPort < 1 or Config.current.wsPort > 65535 then
        Config.current.wsPort = Config.defaults.wsPort
        print("[IronmonConnect] Invalid port number, using default: " .. Config.defaults.wsPort)
    end
    
    -- Validate update frequency
    if Config.current.updateFrequency < 1 or Config.current.updateFrequency > 300 then
        Config.current.updateFrequency = Config.defaults.updateFrequency
    end
    
    -- Validate batch settings
    if Config.current.batchSize < 1 then
        Config.current.batchSize = 1
    elseif Config.current.batchSize > 100 then
        Config.current.batchSize = 100
    end
    
    -- Validate reconnect attempts
    if Config.current.reconnectAttempts < 0 then
        Config.current.reconnectAttempts = 0
    elseif Config.current.reconnectAttempts > 20 then
        Config.current.reconnectAttempts = 20
    end
end

-- Reset to defaults
function Config.reset()
    for key, value in pairs(Config.defaults) do
        Config.current[key] = value
        if TrackerAPI then
            TrackerAPI.saveExtensionSetting("IronmonConnect", key, value)
        end
    end
    print("[IronmonConnect] Configuration reset to defaults")
end

-- Get WebSocket URL
function Config.getWebSocketUrl()
    return string.format("ws://%s:%d", Config.current.wsHost, Config.current.wsPort)
end

-- Check if a feature is enabled
function Config.isFeatureEnabled(feature)
    return Config.current[feature] == true
end

-- Export configuration for debugging
function Config.export()
    local export = {}
    for key, value in pairs(Config.current) do
        export[key] = value
    end
    return export
end

-- Logging helper
function Config.log(level, message)
    local levels = { debug = 1, info = 2, warn = 3, error = 4 }
    local currentLevel = levels[Config.current.logLevel] or 2
    local messageLevel = levels[level] or 2
    
    if messageLevel >= currentLevel then
        print(string.format("[IronmonConnect][%s] %s", level:upper(), message))
    end
end

return Config
