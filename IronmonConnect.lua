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
        encounterTracking = true,
        battleAnalytics = true,
        moveTracking = true,
        
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
        battleStartFrame = nil,  -- Track battle duration
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
                locationTracking = Config.get("locationTracking"),
                encounterTracking = Config.get("encounterTracking"),
                battleAnalytics = Config.get("battleAnalytics"),
                moveTracking = Config.get("moveTracking")
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
    
    -- Hook: Called when battle starts
    function self.afterBattleBegins()
        if not Config.isFeatureEnabled("battleEvents") then return end
        
        -- Get battle information
        local isWildEncounter = Battle and Battle.isWildEncounter or false
        local trainerId = Battle and Battle.opposingTrainerId or nil
        
        -- Get opponent Pokemon using Battle.getViewedPokemon or Tracker.getPokemon
        local opposingPokemon = nil
        
        -- First try to get the enemy Pokemon slot from Battle.Combatants
        if Battle and Battle.Combatants and Battle.Combatants.LeftOther then
            opposingPokemon = Tracker.getPokemon(Battle.Combatants.LeftOther, false)
        end
        
        -- If that doesn't work, try slot 1 for enemy team
        if not opposingPokemon then
            opposingPokemon = Tracker.getPokemon(1, false)
        end
        
        local opponentData = nil
        
        if opposingPokemon and opposingPokemon.pokemonID and opposingPokemon.pokemonID > 0 then
            opponentData = {
                id = opposingPokemon.pokemonID,
                name = opposingPokemon.name or (PokemonData.Pokemon[opposingPokemon.pokemonID] and PokemonData.Pokemon[opposingPokemon.pokemonID].name) or "Unknown",
                level = opposingPokemon.level or 0,
                hp = {
                    current = opposingPokemon.hp or 0,
                    max = opposingPokemon.hpmax or 0
                }
            }
        end
        
        -- Store battle opponent for encounter tracking
        if isWildEncounter and opponentData then
            state.lastBattleOpponent = {
                pokemonID = opponentData.id,
                level = opponentData.level,
                mapId = TrackerAPI.getMapId()
            }
            state.isWildBattle = true
        else
            state.isWildBattle = false
        end
        
        -- Get encounter data if available
        local encounterData = nil
        if isWildEncounter and opponentData then
            local mapId = TrackerAPI.getMapId()
            local routeInfo = RouteData.Info[mapId]
            
            -- Get total encounters for this Pokemon
            local wildEncounters = Tracker.getEncounters and Tracker.getEncounters(opponentData.id, true) or 0
            local trainerEncounters = Tracker.getEncounters and Tracker.getEncounters(opponentData.id, false) or 0
            
            encounterData = {
                location = routeInfo and routeInfo.name or "Unknown",
                mapId = mapId,
                totalWildEncounters = wildEncounters,
                totalTrainerEncounters = trainerEncounters
            }
        end
        
        -- Get known moves for this Pokemon
        local knownMoves = nil
        if Config.isFeatureEnabled("moveTracking") and opposingPokemon then
            local moves = Tracker.getMoves and Tracker.getMoves(opposingPokemon.pokemonID, opposingPokemon.level) or {}
            if next(moves) then  -- Check if table has any entries
                knownMoves = {}
                for _, move in pairs(moves) do
                    if move and move.id and move.id > 0 then
                        local moveData = MoveData.Moves[move.id]
                        table.insert(knownMoves, {
                            id = move.id,
                            name = moveData and moveData.name or "Unknown",
                            type = moveData and moveData.type or "Unknown",
                            minLevel = move.minLv,
                            maxLevel = move.maxLv
                        })
                    end
                end
            end
        end
        
        -- Send enhanced battle start event
        send(createEvent("battle_started", {
            isWild = isWildEncounter,
            trainerId = trainerId,
            opponent = opponentData,
            encounter = encounterData,
            knownMoves = knownMoves
        }))
        
        Config.log("info", string.format("Battle started: %s", 
            isWildEncounter and "Wild encounter" or "Trainer battle"))
    end
    
    -- Hook: Called when battle ends
    function self.afterBattleEnds()
        if not Config.isFeatureEnabled("battleEvents") then return end
        
        -- Try to determine battle outcome
        local playerWon = true  -- Default assumption
        
        -- Check if player's lead Pokemon fainted
        local leadPokemon = TrackerAPI.getPlayerPokemon(1)
        if leadPokemon and leadPokemon.hp == 0 then
            -- Check if any Pokemon are still alive
            local hasAlivePokemon = false
            for i = 1, 6 do
                local pokemon = TrackerAPI.getPlayerPokemon(i)
                if pokemon and pokemon.hp > 0 then
                    hasAlivePokemon = true
                    break
                end
            end
            playerWon = hasAlivePokemon
        end
        
        -- Send battle end event
        send(createEvent("battle_ended", {
            playerWon = playerWon,
            duration = state.battleStartFrame and (emu.framecount() - state.battleStartFrame) or 0
        }))
        
        Config.log("info", string.format("Battle ended: %s", 
            playerWon and "Victory" or "Defeat"))
        
        -- Track encounter if it was a wild battle
        if Config.isFeatureEnabled("encounterTracking") and state.isWildBattle and state.lastBattleOpponent then
            self.trackEncounter(state.lastBattleOpponent)
        end
        
        -- Reset battle state
        state.battleStartFrame = nil
        state.battleTurn = 0
        state.lastBattleOpponent = nil
        state.isWildBattle = false
        
        -- Clear HP and move tracking
        for k, v in pairs(state) do
            if string.find(k, "_hp_") or string.find(k, "moves_") then
                state[k] = nil
            end
        end
    end
    
    -- Hook: Called when battle data updates
    function self.afterBattleDataUpdate()
        if not Config.isFeatureEnabled("battleEvents") then return end
        
        -- Track battle start frame if not set
        if not state.battleStartFrame then
            state.battleStartFrame = emu.framecount()
        end
        
        -- Track battle moves and damage
        if Config.isFeatureEnabled("battleAnalytics") and state.frameCounter % 10 == 0 then  -- Check every 10 frames during battle
            self.processBattleAnalytics()
        end
    end
    
    -- Track encounter statistics
    function self.trackEncounter(encounterInfo)
        if not encounterInfo or not encounterInfo.pokemonID then return end
        
        local mapId = encounterInfo.mapId
        local routeInfo = RouteData.Info[mapId]
        
        -- Get route encounters if available
        local routeEncounters = {}
        if Tracker.getRouteEncounters then
            -- Try to get encounters for different terrain types
            for _, area in ipairs({"land", "surfing", "fishing", "underwater"}) do
                local encounters = Tracker.getRouteEncounters(mapId, area)
                if encounters and #encounters > 0 then
                    routeEncounters[area] = encounters
                end
            end
        end
        
        -- Send encounter event with statistics
        send(createEvent("encounter", {
            pokemon = {
                id = encounterInfo.pokemonID,
                name = PokemonData.Pokemon[encounterInfo.pokemonID] and PokemonData.Pokemon[encounterInfo.pokemonID].name or "Unknown",
                level = encounterInfo.level
            },
            location = {
                mapId = mapId,
                name = routeInfo and routeInfo.name or "Unknown",
                routeEncounters = routeEncounters
            },
            statistics = {
                totalEncountersHere = #(routeEncounters.land or {}) + #(routeEncounters.surfing or {}) + #(routeEncounters.fishing or {}),
                isFirstOnRoute = not self.hasEncounteredOnRoute(encounterInfo.pokemonID, mapId, routeEncounters)
            }
        }))
    end
    
    -- Check if Pokemon was previously encountered on this route
    function self.hasEncounteredOnRoute(pokemonID, mapId, routeEncounters)
        for area, encounters in pairs(routeEncounters or {}) do
            for _, encounteredId in ipairs(encounters) do
                if encounteredId == pokemonID then
                    return true
                end
            end
        end
        return false
    end
    
    -- Process battle analytics during combat
    function self.processBattleAnalytics()
        if not Battle or not Battle.inActiveBattle then return end
        
        -- Get active Pokemon
        local playerMon = TrackerAPI.getPlayerPokemon(Battle.Combatants and Battle.Combatants.LeftOwn or 1)
        local enemyMon = Tracker.getPokemon(Battle.Combatants and Battle.Combatants.LeftOther or 1, false)
        
        if not playerMon or not enemyMon then return end
        
        -- Check for HP changes (damage dealt/received)
        local playerHPKey = "player_hp_" .. (playerMon.pokemonID or 0)
        local enemyHPKey = "enemy_hp_" .. (enemyMon.pokemonID or 0)
        
        local playerPrevHP = state[playerHPKey] or playerMon.curHP
        local enemyPrevHP = state[enemyHPKey] or enemyMon.hp
        
        local playerDamage = playerPrevHP - (playerMon.curHP or 0)
        local enemyDamage = enemyPrevHP - (enemyMon.hp or 0)
        
        -- Send damage event if significant damage occurred
        if playerDamage > 0 or enemyDamage > 0 then
            send(createEvent("battle_damage", {
                turn = state.battleTurn or 0,
                playerDamage = playerDamage > 0 and playerDamage or 0,
                enemyDamage = enemyDamage > 0 and enemyDamage or 0,
                playerMon = {
                    id = playerMon.pokemonID,
                    currentHP = playerMon.curHP,
                    maxHP = playerMon.stats and playerMon.stats.hp or 0,
                    level = playerMon.level
                },
                enemyMon = {
                    id = enemyMon.pokemonID,
                    currentHP = enemyMon.hp or 0,
                    maxHP = enemyMon.hpmax or 0,
                    level = enemyMon.level
                }
            }))
            
            state.battleTurn = (state.battleTurn or 0) + 1
        end
        
        -- Update HP tracking
        state[playerHPKey] = playerMon.curHP
        state[enemyHPKey] = enemyMon.hp
        
        -- Track moves if enabled
        if Config.isFeatureEnabled("moveTracking") then
            self.trackBattleMoves(enemyMon)
        end
    end
    
    -- Track moves used by enemy Pokemon
    function self.trackBattleMoves(enemyMon)
        if not enemyMon or not enemyMon.pokemonID then return end
        
        -- Get known moves for this Pokemon
        local knownMoves = Tracker.getMoves and Tracker.getMoves(enemyMon.pokemonID, enemyMon.level) or {}
        
        -- Check if we have new move data to report
        local moveListKey = "moves_" .. enemyMon.pokemonID .. "_" .. (enemyMon.level or 0)
        local previousMoveCount = state[moveListKey] or 0
        local currentMoveCount = 0
        
        -- Count valid moves
        for _, move in pairs(knownMoves) do
            if move and move.id and move.id > 0 then
                currentMoveCount = currentMoveCount + 1
            end
        end
        
        -- If we have new moves, send an update
        if currentMoveCount > previousMoveCount then
            local moveList = {}
            for _, move in pairs(knownMoves) do
                if move and move.id and move.id > 0 then
                    local moveData = MoveData.Moves[move.id]
                    table.insert(moveList, {
                        id = move.id,
                        name = moveData and moveData.name or "Unknown",
                        type = moveData and moveData.type or "Unknown",
                        power = moveData and moveData.power or 0,
                        accuracy = moveData and moveData.accuracy or 0,
                        pp = moveData and moveData.pp or 0,
                        level = move.level or enemyMon.level
                    })
                end
            end
            
            -- Send move history event
            send(createEvent("move_history", {
                pokemon = {
                    id = enemyMon.pokemonID,
                    name = PokemonData.Pokemon[enemyMon.pokemonID] and PokemonData.Pokemon[enemyMon.pokemonID].name or "Unknown",
                    level = enemyMon.level
                },
                moves = moveList,
                totalMovesKnown = currentMoveCount,
                allMovesKnown = currentMoveCount >= 4
            }))
            
            state[moveListKey] = currentMoveCount
            Config.log("info", string.format("Tracked %d moves for %s", 
                currentMoveCount, 
                PokemonData.Pokemon[enemyMon.pokemonID] and PokemonData.Pokemon[enemyMon.pokemonID].name or "Pokemon"))
        end
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
        
        -- CHECKPOINT DETECTION STRATEGY:
        -- We use a hybrid approach for checkpoint detection:
        -- 1. Trainer class names for specific story battles (RIVAL1, FIRSTTRAINER)
        -- 2. Trainer IDs for all other checkpoints (more reliable than class names)
        -- This is intentional - DO NOT change without careful consideration
        
        -- Trainer class name mappings (for battles with unique class names)
        local CLASS_NAME_CHECKPOINTS = {
            ["Youngster 1"] = "RIVAL1",      -- Oak's Lab (verified)
            ["Bug Catcher 3"] = "FIRSTTRAINER"  -- Viridian Forest (verified)
        }
        
        -- Trainer ID mappings (from Ironmon Tracker's TrainerData.lua)
        -- Using constants for better readability and maintainability
        local TRAINER_ID_CHECKPOINTS = {
            -- Rival battles
            RIVAL2 = {326, 327},  -- Route 22 (first encounter)
            RIVAL3 = {328, 329},  -- Cerulean City
            RIVAL4 = {330, 331},  -- S.S. Anne
            RIVAL5 = {332, 333},  -- Pokemon Tower
            RIVAL6 = {334, 335},  -- Silph Co.
            RIVAL7 = {336, 337},  -- Route 22 (second encounter)
            
            -- Giovanni battles
            ROCKETHIDEOUT = {348},  -- Rocket Hideout
            SILPHCO = {349},        -- Silph Co.
            
            -- Elite Four
            LORELAI = {410},
            BRUNO = {411},
            AGATHA = {412},
            LANCE = {413},
            
            -- Champion
            CHAMP = {438, 439, 440}
        }
        
        -- Check trainer class names first (for special cases)
        for trainerName, checkpointName in pairs(CLASS_NAME_CHECKPOINTS) do
            if currentTrainers[trainerName] and not state.checkpointsNotified[checkpointName] then
                return checkpointName
            end
        end
        
        -- Check trainer IDs for all other checkpoints
        for checkpointName, trainerIds in pairs(TRAINER_ID_CHECKPOINTS) do
            for _, trainerId in ipairs(trainerIds) do
                if Program.hasDefeatedTrainer and Program.hasDefeatedTrainer(trainerId) then
                    if not state.checkpointsNotified[checkpointName] then
                        return checkpointName
                    end
                end
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
