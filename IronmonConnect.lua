-- IronmonConnect v2.0 - Single file version for Ironmon Tracker
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
            console.log("> IMC: Warning: TrackerAPI not available, using defaults")
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
            console.log("> IMC: Configuration loaded successfully")
        end
    end
    
    -- Save a setting
    function Config.set(key, value)
        if Config.defaults[key] == nil then
            console.log("> IMC: Warning: Unknown setting key: " .. tostring(key))
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
        -- Currently no validation needed
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
            console.log(string.format("> IMC: [%s] %s", level:upper(), message))
        end
    end
    
    -- ===========================================
    -- UTILS MODULE (embedded)
    -- ===========================================
    local Utils = {}
    
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
    
    -- ===========================================
    -- MAIN IRONMONCONNECT LOGIC
    -- ===========================================
    
    -- Internal state
    local state = {
        initialized = false,
        frameCounter = 0,
        lastSeed = nil,
        lastArea = nil,
        checkpointsNotified = {},
        currentCheckpointIndex = 1,
        wasConnected = false,  -- Track connection state changes
        lastTeamHash = {},  -- Track team changes per slot
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
    
    -- Helper function to create events with timestamps
    local function createEvent(eventType, eventData)
        return {
            type = eventType,
            data = eventData,
            timestamp = os.time(),
            frame = emu and emu.framecount and emu.framecount() or 0
        }
    end
    
    -- Enhanced send function with connection checking
    local function send(data)
        -- Check if connected before sending
        if not comm.socketServerIsConnected() then
            if state.wasConnected then
                Config.log("error", "Lost connection to server")
                state.wasConnected = false
            end
            return false
        end
        
        -- Update connection state
        if not state.wasConnected then
            Config.log("info", "Connection established")
            state.wasConnected = true
        end
        
        -- Send the data
        local packet = FileManager.JsonLibrary.encode(data)
        comm.socketServerSend(packet)
        
        -- Check if send was successful
        if comm.socketServerSuccessful() then
            if Config.get("debug") then
                Config.log("debug", "Sent: " .. data.type)
            end
            return true
        else
            Config.log("warn", "Failed to send: " .. data.type)
            return false
        end
    end
    
    -- Initialize the extension
    function self.startup()
        -- Initialize configuration
        Config.initialize()
        
        -- Log startup
        Config.log("info", string.format("Version %s successfully loaded.", self.version))
        Config.log("info", string.format("Using settings file: %s", Options and Options.FILES and Options.FILES["Settings File"] or "Unknown"))
        
        -- Check initial connection status
        if comm.socketServerIsConnected() then
            Config.log("info", "Connected to server: " .. (comm.socketServerGetInfo and comm.socketServerGetInfo() or "Connected"))
            state.wasConnected = true
        else
            Config.log("warn", "No connection to server - start your server application and restart BizHawk")
        end
        
        -- Send initialization event
        send(createEvent("init", {
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
        }))
        
        -- Process initial seed if available
        if Main and Main.currentSeed then
            self.processSeed()
        end
        
        -- Initialize checkpoint flags
        for _, checkpoint in ipairs(Checkpoints) do
            state.checkpointsNotified[checkpoint] = false
        end
        
        -- Send initial team state
        if Config.isFeatureEnabled("teamUpdates") then
            self.processTeam()
        end
        
        state.initialized = true
    end
    
    -- Process team changes
    function self.processTeam()
        if not Config.isFeatureEnabled("teamUpdates") then return end
        
        -- Check each party slot for changes
        for slot = 1, 6 do
            local pokemon = TrackerAPI.getPlayerPokemon(slot)
            if pokemon and pokemon.pokemonID > 0 then
                local hash = Utils.hashPokemonState(pokemon)
                if hash ~= state.lastTeamHash[slot] then
                    -- Team change detected!
                    self.sendTeamUpdate(slot, pokemon)
                    state.lastTeamHash[slot] = hash
                end
            elseif state.lastTeamHash[slot] then
                -- Pokemon was removed from this slot
                send(createEvent("team_update", {
                    slot = slot,
                    pokemon = nil
                }))
                state.lastTeamHash[slot] = nil
            end
        end
    end
    
    -- Send team update event
    function self.sendTeamUpdate(slot, pokemon)
        local pokemonData = {
            id = pokemon.pokemonID,
            name = PokemonData.Pokemon[pokemon.pokemonID] and PokemonData.Pokemon[pokemon.pokemonID].name or "Unknown",
            level = pokemon.level,
            hp = {
                current = pokemon.curHP,
                max = pokemon.stats and pokemon.stats.hp or 0
            },
            status = pokemon.status,
            item = pokemon.heldItem
        }
        
        -- Add moves if available
        if pokemon.moves then
            pokemonData.moves = {}
            for i = 1, 4 do
                if pokemon.moves[i] and pokemon.moves[i] > 0 then
                    local moveData = MoveData.Moves[pokemon.moves[i]]
                    table.insert(pokemonData.moves, {
                        id = pokemon.moves[i],
                        name = moveData and moveData.name or "Unknown",
                        pp = pokemon.movePPs and pokemon.movePPs[i] or 0
                    })
                end
            end
        end
        
        send(createEvent("team_update", {
            slot = slot,
            pokemon = pokemonData
        }))
    end
    
    -- Process seed changes
    function self.processSeed()
        if not Config.isFeatureEnabled("runTracking") then return end
        
        local currentSeed = Main.currentSeed
        if currentSeed ~= state.lastSeed then
            Config.log("info", "Seed number is now " .. tostring(currentSeed) .. ".")
            
            send(createEvent("seed", {
                value = currentSeed,
                attempt = currentSeed -- Main.currentSeed represents attempt number
            }))
            
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
            
            send(createEvent("location", {
                mapId = mapId,
                name = locationName
            }))
            
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
                send(createEvent("checkpoint", {
                    name = checkpointName,
                    index = index,
                    total = #Checkpoints,
                    seed = state.lastSeed
                }))
                
                state.checkpointsNotified[checkpointName] = true
                state.currentCheckpointIndex = index + 1
            end
        end
    end
    
    -- Hook: Called after each frame
    function self.afterProgramDataUpdate()
        if not state.initialized then return end
        
        state.frameCounter = state.frameCounter + 1
        
        -- Check for changes every 30 frames (0.5 seconds)
        if state.frameCounter >= 30 then
            state.frameCounter = 0
            
            -- Mark systems as dirty instead of processing immediately
            state.dirtyFlags.seed = true
            state.dirtyFlags.location = true
            state.dirtyFlags.checkpoint = true
            state.dirtyFlags.team = true
        end
    end
    
    -- Hook: Called on program update tick (more efficient than every frame)
    function self.onProgramUpdateTick()
        if not state.initialized then return end
        
        -- Periodic connection status check
        if state.frameCounter % 300 == 0 then  -- Check every ~5 seconds at 60fps
            local isConnected = comm.socketServerIsConnected()
            if isConnected ~= state.wasConnected then
                if isConnected then
                    Config.log("info", "Connection restored")
                else
                    Config.log("error", "Connection lost")
                end
                state.wasConnected = isConnected
            end
        end
        
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
        
        if state.dirtyFlags.team then
            self.processTeam()
            state.dirtyFlags.team = false
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
        
        -- Clean up
        state.initialized = false
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
        send(createEvent("reset", {
            reason = "game_state_reloaded"
        }))
    end
    
    return self
end

return IronmonConnect