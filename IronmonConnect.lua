-- IronmonConnect v2.0 - Refactored with configuration system
local function IronmonConnect()
    local self = {}
    self.version = "2.0"
    self.name = "Ironmon Connect"
    self.author = "Omnyist Productions"
    self.description = "Uses BizHawk's socket functionality to provide run data to an external source."
    self.github = "omnypro/ironmon-connect"
    self.url = string.format("https://github.com/%s", self.github or "")
    
    -- Load modules
    local Config = dofile(FileManager.getPathForFile("Config.lua") or "Config.lua")
    local Utils = dofile(FileManager.getPathForFile("Utils.lua") or "Utils.lua")
    
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
    
    -- Temporary FRLG checkpoints (will be moved to JSON)
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
            frame = emu.framecount()
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
        
        -- This is the existing checkpoint logic - will be replaced in Phase 3
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
