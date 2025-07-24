-- IronmonConnect v2.0
local function IronmonConnect()
    local self = {}
    self.version = "2.0"
    self.name = "Ironmon Connect"
    self.author = "Omnyist Productions"
    self.description = "Uses BizHawk's socket functionality to provide run data to an external source."
    self.github = "omnypro/ironmon-connect"
    self.url = string.format("https://github.com/%s", self.github or "")
    
    -- ===========================================
    -- CONFIG MODULE (embedded)
    -- ===========================================
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
    
    -- Get WebSocket URL
    function Config.getWebSocketUrl()
        return string.format("ws://%s:%d", Config.current.wsHost, Config.current.wsPort)
    end
    
    -- Check if a feature is enabled
    function Config.isFeatureEnabled(feature)
        return Config.current[feature] == true
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
    
    -- ===========================================
    -- UTILS MODULE (embedded)
    -- ===========================================
    local Utils = {}
    
    -- JSON encoding using Ironmon Tracker's JSON library
    function Utils.jsonEncode(data)
        if FileManager and FileManager.JsonLibrary then
            return FileManager.JsonLibrary.encode(data)
        else
            -- Fallback to simple implementation
            return Utils.simpleJsonEncode(data)
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
    
    -- ===========================================
    -- MAIN IRONMONCONNECT LOGIC
    -- ===========================================
    
    -- Internal state
    local state = {
        initialized = false,
        connected = false,
        frameCounter = 0,
        lastSeed = nil,
        lastArea = nil,
        checkpointsNotified = {},
        currentCheckpointIndex = 1,
        eventQueue = {},
        dirtyFlags = {
            seed = false,
            location = false,
            checkpoint = false,
            team = false
        }
    }
    
    -- Temporary FRLG checkpoints (will be moved to JSON in future)
    local Checkpoints = {
        "RIVAL1", "FIRSTTRAINER", "RIVAL2", "BROCK", "RIVAL3", "RIVAL4",
        "MISTY", "SURGE", "RIVAL5", "ROCKETHIDEOUT", "ERIKA", "KOGA",
        "RIVAL6", "SILPHCO", "SABRINA", "BLAINE", "GIOVANNI", "RIVAL7",
        "LORELAI", "BRUNO", "AGATHA", "LANCE", "CHAMP"
    }
    
    -- Initialize the extension
    function self.startup()
        -- Initialize configuration
        Config.initialize()
        
        -- Log startup
        Config.log("info", string.format("%s v%s starting up", self.name, self.version))
        
        -- Initialize connection
        if Config.isFeatureEnabled("wsEnabled") ~= false then
            self.connect()
        end
        
        -- Send initialization event
        self.queueEvent("init", {
            version = self.version,
            tracker_version = Main.TrackerVersion or "Unknown",
            game = GameSettings.game or "Unknown",
            features = {
                runTracking = Config.get("runTracking"),
                battleEvents = Config.get("battleEvents"),
                checkpoints = Config.get("checkpoints"),
                teamUpdates = Config.get("teamUpdates"),
                locationTracking = Config.get("locationTracking")
            }
        })
        
        state.initialized = true
    end
    
    -- Queue an event for sending
    function self.queueEvent(eventType, data)
        if not state.initialized then return end
        
        local event = {
            type = eventType,
            data = data,
            timestamp = os.time(),
            frame = emu and emu.framecount and emu.framecount() or 0
        }
        
        table.insert(state.eventQueue, event)
        
        -- Immediate send for critical events
        if eventType == "init" or eventType == "run_start" or eventType == "run_end" then
            self.flushEventQueue()
        end
    end
    
    -- Send queued events
    function self.flushEventQueue()
        if #state.eventQueue == 0 then return end
        
        local batchSize = Config.get("batchSize")
        local events = {}
        
        -- Get up to batchSize events
        for i = 1, math.min(#state.eventQueue, batchSize) do
            table.insert(events, table.remove(state.eventQueue, 1))
        end
        
        -- Send the batch
        local success = self.send({
            type = "batch",
            events = events,
            count = #events
        })
        
        -- If send failed, put events back in queue
        if not success then
            for i = #events, 1, -1 do
                table.insert(state.eventQueue, 1, events[i])
            end
        end
    end
    
    -- Send data over websocket
    function self.send(data)
        if not state.connected then
            Config.log("debug", "Not connected, queuing event")
            return false
        end
        
        local message = Utils.jsonEncode(data)
        local success, err = Utils.pcallWithContext(function()
            comm.socketServerSend(message)
        end, "WebSocket Send")
        
        if not success then
            Config.log("error", "Failed to send: " .. tostring(err))
            state.connected = false
            return false
        end
        
        Config.log("debug", "Sent: " .. data.type)
        return true
    end
    
    -- Connect to websocket
    function self.connect()
        Config.log("info", "Attempting to connect to " .. Config.getWebSocketUrl())
        
        -- In BizHawk, the socket connection is implicit through comm.socketServerSend
        -- We'll mark as connected and let the first send determine actual state
        state.connected = true
        
        return true
    end
    
    -- Process seed changes
    function self.processSeed()
        if not Config.isFeatureEnabled("runTracking") then return end
        
        local currentSeed = Main.currentSeed
        if currentSeed ~= state.lastSeed then
            Config.log("info", "Seed changed: " .. tostring(currentSeed))
            
            self.queueEvent("seed", {
                value = currentSeed,
                attempt = currentSeed -- Main.currentSeed represents attempt number
            })
            
            state.lastSeed = currentSeed
            
            -- Reset checkpoint progress on new seed
            state.checkpointsNotified = {}
            state.currentCheckpointIndex = 1
        end
    end
    
    -- Process location changes
    function self.processLocation()
        if not Config.isFeatureEnabled("locationTracking") then return end
        
        local mapId = TrackerAPI.getMapId()
        if mapId ~= state.lastArea then
            local routeInfo = RouteData.Info[mapId]
            local locationName = routeInfo and routeInfo.name or "Unknown"
            
            self.queueEvent("location", {
                mapId = mapId,
                name = locationName
            })
            
            state.lastArea = mapId
        end
    end
    
    -- Process checkpoint detection (temporary implementation)
    function self.processCheckpoints()
        if not Config.isFeatureEnabled("checkpoints") then return end
        if GameSettings.game ~= "Pokemon FireRed" and GameSettings.game ~= "Pokemon LeafGreen" then
            return -- Only FRLG supported for now
        end
        
        -- This is the existing checkpoint logic - will be replaced in future phases
        local defeatedTrainer = self.determineSplitChange()
        if defeatedTrainer and defeatedTrainer ~= "" then
            local checkpointName, index = defeatedTrainer, nil
            
            -- Find the checkpoint index
            for i, checkpoint in ipairs(Checkpoints) do
                if checkpoint == defeatedTrainer then
                    index = i
                    break
                end
            end
            
            if index and not state.checkpointsNotified[checkpointName] then
                self.queueEvent("checkpoint", {
                    name = checkpointName,
                    index = index,
                    total = #Checkpoints
                })
                
                state.checkpointsNotified[checkpointName] = true
                state.currentCheckpointIndex = index + 1
            end
        end
    end
    
    -- Hook: Called after each frame
    function self.afterProgramDataUpdate()
        if not state.initialized then return end
        
        state.frameCounter = state.frameCounter + 1
        
        -- Check for changes every N frames
        if state.frameCounter >= Config.get("updateFrequency") then
            state.frameCounter = 0
            
            -- Mark systems as dirty instead of processing immediately
            state.dirtyFlags.seed = true
            state.dirtyFlags.location = true
            state.dirtyFlags.checkpoint = true
        end
    end
    
    -- Hook: Called on program update tick (more efficient than every frame)
    function self.onProgramUpdateTick()
        if not state.initialized then return end
        
        -- Process dirty flags
        if state.dirtyFlags.seed then
            self.processSeed()
            state.dirtyFlags.seed = false
        end
        
        if state.dirtyFlags.location then
            self.processLocation()
            state.dirtyFlags.location = false
        end
        
        if state.dirtyFlags.checkpoint then
            self.processCheckpoints()
            state.dirtyFlags.checkpoint = false
        end
        
        -- Flush event queue periodically
        if #state.eventQueue > 0 then
            self.flushEventQueue()
        end
    end
    
    -- Hook: Called when battle data updates
    function self.afterBattleDataUpdate()
        if not Config.isFeatureEnabled("battleEvents") then return end
        
        -- Mark battle system as dirty for processing
        state.dirtyFlags.battle = true
    end
    
    -- Temporary checkpoint detection (from original code)
    function self.determineSplitChange()
        local defeatedTrainers = Program.getDefeatedTrainersByLocation()
        local currentTrainers = {}
        
        for _, trainer in pairs(defeatedTrainers) do
            local lookup = TrainerData.getTrainerInfo(trainer)
            if lookup and lookup.class and lookup.class.name then
                currentTrainers[lookup.class.name] = true
            end
        end
        
        -- FRLG specific logic (will be replaced with JSON config)
        local rivalMapping = {
            ["Youngster 1"] = "RIVAL1",
            ["Bug Catcher 3"] = "FIRSTTRAINER",
            -- ... rest of the mappings would go here
        }
        
        for trainerName, checkpointName in pairs(rivalMapping) do
            if currentTrainers[trainerName] and not state.checkpointsNotified[checkpointName] then
                return checkpointName
            end
        end
        
        -- Badge detection
        local badges = TrackerAPI.getBadgeList()
        local badgeMapping = {
            [1] = "BROCK", [2] = "MISTY", [3] = "SURGE", [4] = "ERIKA",
            [5] = "KOGA", [6] = "SABRINA", [7] = "BLAINE", [8] = "GIOVANNI"
        }
        
        for i, obtained in ipairs(badges) do
            local checkpointName = badgeMapping[i]
            if obtained and checkpointName and not state.checkpointsNotified[checkpointName] then
                return checkpointName
            end
        end
        
        return nil
    end
    
    -- Hook: Called when unloading
    function self.unload()
        Config.log("info", "Shutting down " .. self.name)
        
        -- Send any remaining events
        self.flushEventQueue()
        
        -- Clean up
        state.initialized = false
        state.connected = false
    end
    
    -- Hook: Called when game is reset
    function self.afterGameStateReloaded()
        Config.log("info", "Game state reloaded")
        
        -- Reset state
        state.lastSeed = nil
        state.lastArea = nil
        state.checkpointsNotified = {}
        state.currentCheckpointIndex = 1
        
        -- Send reset event
        self.queueEvent("reset", {
            reason = "game_state_reloaded"
        })
    end
    
    return self
end

return IronmonConnect
