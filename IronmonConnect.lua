local function IronmonConnect()
	local self = {}
	self.version = "0.5"
	self.name = "Ironmon Connect"
	self.author = "Omnyist Productions"
	self.description = "Uses BizHawk's socket functionality to provide run data to an external source."
	self.github = "omnypro/ironmon-connect"
	self.url = string.format("https://github.com/%s", self.github or "") -- Remove this attribute if no host website available for this extension

	-- Program-Specific Variables

	self.seed = nil
	self.seedVariables = {
		["Checkpoint"] = nil,
		["pokemonDead"] = false,
		["Progression"] = {
			["DefeatedFirstTrainer"] = false,
			["DefeatedRocketHideout"] = false,
			["DefeatedSilph"] = false,
			["DefeatedRival1"] = false,
			["DefeatedRival2"] = false,
			["DefeatedRival3"] = false,
			["DefeatedRival4"] = false,
			["DefeatedRival5"] = false,
			["DefeatedRival6"] = false,
			["DefeatedRival7"] = false,
			["DefeatedChamp"] = false,
			["DefeatedBrock"] = false,
			["DefeatedMisty"] = false,
			["DefeatedSurge"] = false,
			["DefeatedErika"] = false,
			["DefeatedKoga"] = false,
			["DefeatedSabrina"] = false,
			["DefeatedBlaine"] = false,
			["DefeatedGiovanni"] = false,
			["DefeatedLorelai"] = false,
			["DefeatedBruno"] = false,
			["DefeatedAgatha"] = false,
			["DefeatedLance"] = false
		}
	}

	-- To properly determine when new items are acquired, need to load them in first at least once.
	local loadedVarsThisSeed

	--------------------------------------
	-- HELPER FUNCTIONS BELOW
	--------------------------------------

	local function enum(tbl)
		local length = #tbl
		for i = 1, length do
			local v = tbl[i]
			tbl[v] = i
		end

		return tbl
	end

	local function send(data)
		packet = FileManager.JsonLibrary.encode(data)
		comm.socketServerSend(packet)
	end

	--------------------------------------
	-- INTERNAL SCRIPT FUNCTIONS BELOW
	--------------------------------------

	local function getHpPercent()
		local leadPokemon = Tracker.getPokemon(1, true) or Tracker.getDefaultPokemon()
		if PokemonData.isValid(leadPokemon.pokemonID) then
			local hpPercentage = (leadPokemon.curHP or 0) / (leadPokemon.stats.hp) or 100
			if hpPercentage >= 0 then
				return hpPercentage
			end
		end
	end

	local function handleSeed() 
		self.seed = Main.currentSeed
		console.log("> IMC: Seed number has changed to " .. self.seed .. ".")

		local seed = {
			["type"] = "seed",
			["number"] = Main.currentSeed
		}		
		send(seed)
	end

	function self.isPlayingFRLG()
		return GameSettings.game == 3
	end

	function self.resetSeedVars()
		local V = self.seedVariables
		V.Checkpoint = Checkpoints.LAB
	end

  -- Enumerations 
	Checkpoints = enum {
		"LAB",
		"RIVAL1",
		"FIRSTTRAINER",
		"RIVAL2",
		"BROCK",
		"RIVAL3",
		"RIVAL4",
		"MISTY",
		"SURGE",
		"RIVAL5",
		"ROCKETHIDEOUT",
		"ERIKA",
		"KOGA",
		"RIVAL6",
		"SILPHCO",
		"SABRINA",
		"BLAINE",
		"GIOVANNI",
		"RIVAL7",
		"LORELAI",
		"BRUNO",
		"AGATHA",
		"LANCE",
		"CHAMP"
	}

	-- Progression Table
	local Progression = {
    -- Location Progression
    DefeatedFirstTrainer = Program.hasDefeatedTrainer(102) or Program.hasDefeatedTrainer(115),
    DefeatedRocketHideout = Program.hasDefeatedTrainer(348),
  	DefeatedSilph = Program.hasDefeatedTrainer(349),

		-- Rival Progression
    DefeatedRival1 = Program.hasDefeatedTrainer(326) or Program.hasDefeatedTrainer(327) or Program.hasDefeatedTrainer(328),
    DefeatedRival2 = Program.hasDefeatedTrainer(329) or Program.hasDefeatedTrainer(330) or Program.hasDefeatedTrainer(331),
    DefeatedRival3 = Program.hasDefeatedTrainer(332) or Program.hasDefeatedTrainer(333) or Program.hasDefeatedTrainer(334),
    DefeatedRival4 = Program.hasDefeatedTrainer(426) or Program.hasDefeatedTrainer(427) or Program.hasDefeatedTrainer(428),
    DefeatedRival5 = Program.hasDefeatedTrainer(429) or Program.hasDefeatedTrainer(430) or Program.hasDefeatedTrainer(431),
    DefeatedRival6 = Program.hasDefeatedTrainer(432) or Program.hasDefeatedTrainer(433) or Program.hasDefeatedTrainer(434),
    DefeatedRival7 = Program.hasDefeatedTrainer(435) or Program.hasDefeatedTrainer(436) or Program.hasDefeatedTrainer(437),
    DefeatedChamp = Program.hasDefeatedTrainer(438) or Program.hasDefeatedTrainer(439) or Program.hasDefeatedTrainer(440),

		-- Gym Progression
    DefeatedBrock = Program.hasDefeatedTrainer(414),
    DefeatedMisty = Program.hasDefeatedTrainer(415),
    DefeatedSurge = Program.hasDefeatedTrainer(416),
    DefeatedErika = Program.hasDefeatedTrainer(417),
    DefeatedKoga = Program.hasDefeatedTrainer(418),
    DefeatedSabrina = Program.hasDefeatedTrainer(420),
    DefeatedBlaine = Program.hasDefeatedTrainer(419),
    DefeatedGiovanni = Program.hasDefeatedTrainer(350),

		-- Elite 4 Progression
    DefeatedLorelai = Program.hasDefeatedTrainer(410) or Program.hasDefeatedTrainer(735),
    DefeatedBruno = Program.hasDefeatedTrainer(411) or Program.hasDefeatedTrainer(736),
    DefeatedAgatha = Program.hasDefeatedTrainer(412) or Program.hasDefeatedTrainer(737),
    DefeatedLance = Program.hasDefeatedTrainer(413) or Program.hasDefeatedTrainer(738)
	}

	function self.handleCheckpoint()
		local V = self.seedVariables
		local checkpoint

		if not V.Progression.DefeatedRival1 and Progression.DefeatedRival1 then
			checkpoint = Checkpoints.RIVAL1
			V.Progression.DefeatedRival1 = true
			console.log("> IMC: Defeated Rival 1.")
		end
		if not V.Progression.DefeatedFirstTrainer and Progression.DefeatedFirstTrainer then
			checkpoint = Checkpoints.FIRSTTRAINER
			V.Progression.DefeatedFirstTrainer = true
			console.log("> IMC: Defeated First Trainer.")
		end
		if not V.Progression.DefeatedRival2 and Progression.DefeatedRival2 then
			checkpoint = Checkpoints.RIVAL2
			V.Progression.DefeatedRival2 = true
			console.log("> IMC: Defeated Rival 2.")
		end
		if not V.DefeatedBrock and Progression.DefeatedBrock then
			checkpoint = Checkpoints.BROCK
			V.DefeatedBrock = true
			console.log("> IMC: Defeated Brock.")
		end
		if not V.DefeatedRival3 and Progression.DefeatedRival3 then
			checkpoint = Checkpoints.RIVAL3
			V.DefeatedRival3 = true
			console.log("> IMC: Defeated Rival 3.")
		end
		if not V.DefeatedRival4 and Progression.DefeatedRival4 then
			checkpoint = Checkpoints.RIVAL4
			V.DefeatedRival4 = true
			console.log("> IMC: Defeated Rival 4.")
		end
		if not V.DefeatedMisty and Progression.DefeatedMisty then
			checkpoint = Checkpoints.MISTY
			V.DefeatedMisty = true
			console.log("> IMC: Defeated Misty.")
		end
		if not V.DefeatedSurge and Progression.DefeatedSurge then
			checkpoint = Checkpoints.SURGE
			V.DefeatedSurge = true
			console.log("> IMC: Defeated Surge.")
		end
		if not V.DefeatedRival5 and Progression.DefeatedRival5 then
			checkpoint = Checkpoints.RIVAL5
			V.DefeatedRival5 = true
			console.log("> IMC: Defeated Rival 5.")
		end
		if not V.DefeatedRocketHideout and Progression.DefeatedRocketHideout then
			checkpoint = Checkpoints.ROCKETHIDEOUT
			V.DefeatedRocketHideout = true
			console.log("> IMC: Defeated Rocket Hideout.")
		end
		if not V.DefeatedErika and Progression.DefeatedErika then
			checkpoint = Checkpoints.ERIKA
			V.DefeatedErika = true
			console.log("> IMC: Defeated Erika.")
		end
		if not V.DefeatedKoga and Progression.DefeatedKoga then
			checkpoint = Checkpoints.KOGA
			V.DefeatedKoga = true
			console.log("> IMC: Defeated Koga.")
		end
		if not V.DefeatedRival6 and Progression.DefeatedRival6 then
			checkpoint = Checkpoints.RIVAL6
			V.DefeatedRival6 = true
			console.log("> IMC: Defeated Rival 6.")
		end
		if not V.DefeatedSilph and Progression.DefeatedSilph then
			checkpoint = Checkpoints.SILPHCO
			V.DefeatedSilph = true
			console.log("> IMC: Defeated Silph Co.")
		end
		if not V.DefeatedSabrina and Progression.DefeatedSabrina then
			checkpoint = Checkpoints.SABRINA
			V.DefeatedSabrina = true
			console.log("> IMC: Defeated Sabrina.")
		end
		if not V.DefeatedBlaine and Progression.DefeatedBlaine then
			checkpoint = Checkpoints.BLAINE
			V.DefeatedBlaine = true
			console.log("> IMC: Defeated Blaine.")
		end
		if not V.DefeatedGiovanni and Progression.DefeatedGiovanni then
			checkpoint = Checkpoints.GIOVANNI
			V.DefeatedGiovanni = true
			console.log("> IMC: Defeated Giovanni.")
		end
		if not V.DefeatedRival7 and Progression.DefeatedRival7 then
			checkpoint = Checkpoints.RIVAL7
			V.DefeatedRival7 = true
			console.log("> IMC: Defeated Rival 7.")
		end
		if not V.DefeatedLorelai and Progression.DefeatedLorelai then
			checkpoint = Checkpoints.LORELAI
			V.DefeatedLorelai = true
			console.log("> IMC: Defeated Lorelai.")
		end
		if not V.DefeatedBruno and Progression.DefeatedBruno then
			checkpoint = Checkpoints.BRUNO
			V.DefeatedBruno = true
			console.log("> IMC: Defeated Bruno.")
		end
		if not V.DefeatedAgatha and Progression.DefeatedAgatha then
			checkpoint = Checkpoints.AGATHA
			V.DefeatedAgatha = true
			console.log("> IMC: Defeated Agatha.")
		end
		if not V.DefeatedLance and Progression.DefeatedLance then
			checkpoint = Checkpoints.LANCE
			V.DefeatedLance = true
			console.log("> IMC: Defeated Lance.")
		end
		if not V.DefeatedChamp and Progression.DefeatedChamp then
			checkpoint = Checkpoints.CHAMP
			V.DefeatedChamp = true
			console.log("> IMC: Defeated the Champion.")
		end

		-- Notify the server of the current Checkpoint.
		if V.Checkpoint ~= checkpoint then
			local payload = {
				["type"] = "Checkpoint",
				["Checkpoint"] = checkpoint
			}
			send(payload)
			V.Checkpoint = checkpoint
		end
	end

	--------------------------------------
	-- INTENRAL TRACKER FUNCTIONS BELOW
	--------------------------------------

	-- Executed when the user clicks the "Check for Updates" button while viewing the extension details within the Tracker's UI
	-- Returns [true, downloadUrl] if an update is available (downloadUrl auto opens in browser for user); otherwise returns [false, downloadUrl]
	-- Remove this function if you choose not to implement a version update check for your extension
	function self.checkForUpdates()
		-- Update the pattern below to match your version. You can check what this looks like by visiting the latest release url on your repo
		local versionResponsePattern = '"tag_name":%s+"%w+(%d+%.%d+)"' -- matches "1.0" in "tag_name": "v1.0"
		local versionCheckUrl = string.format("https://api.github.com/repos/%s/releases/latest", self.github or "")
		local downloadUrl = string.format("%s/releases/latest", self.url or "")
		local compareFunc = function(a, b) return a ~= b and not Utils.isNewerVersion(a, b) end -- if current version is *older* than online version
		local isUpdateAvailable = Utils.checkForVersionUpdate(versionCheckUrl, self.version, versionResponsePattern, compareFunc)
		return isUpdateAvailable, downloadUrl
	end

	-- Executed only once: When the extension is enabled by the user, and/or when the Tracker first starts up, after it loads all other required files and code
	function self.startup()
		console.log(string.format("> IMC: (v%s) successfully loaded.", self.version))
		console.log("> IMC: Connected to server: " .. comm.socketServerGetInfo())

		-- Output an init message to help verify things are working on that end.
		local init = {
			["type"] = "init",
			["version"] = self.version,
			["game"] = GameSettings.game,
		}
		send(init)

		-- Populate the current seed number, which should exist upon startup.
		self.seed = Main.currentSeed
		handleSeed()

		loadedVarsThisSeed = false
	end

	-- Executed once every 30 frames, after most data from game memory is read in
	function self.afterProgramDataUpdate()
		-- Check the seed number and inform the server it if it has changed.
		if self.seed ~= Main.currentSeed then
			handleSeed()
		end

		-- Once per seed, when the player is able to move their character, initiate the seed data.
		if not self.isPlayingFRLG() or not Program.isValidMapLocation() then
			return
		elseif not loadedVarsThisSeed then
			self.resetSeedVars()
			loadedVarsThisSeed = true
			console.log("> IMC: Seed variables reset.")
		end

		self.handleCheckpoint()

		local V = self.seedVariables		

		-- Set up HP% variable for use in the following conditions.
		local hpPercent = getHpPercent()

		-- The lead pokemon has died and the run will be reset.
		if hpPercentage ~= nil and hpPercentage == 0 and V.pokemonDead == false then
			console.log("> IMC: Pokemon has fainted.")
			V.pokemonDead = true
		end
	end

	-- Executed once every 30 frames, after any battle related data from game memory is read in
	function self.afterBattleDataUpdate()
		-- [ADD CODE HERE]
	end

	-- Executed once every 30 frames or after any redraw event is scheduled (i.e. most button presses)
	function self.afterRedraw()
		-- [ADD CODE HERE]
	end

	-- Executed before a button's onClick() is processed, and only once per click per button
	-- Param: button: the button object being clicked
	function self.onButtonClicked(button)
		-- [ADD CODE HERE]
	end

	-- Executed after a new battle begins (wild or trainer), and only once per battle
	function self.afterBattleBegins()
		-- [ADD CODE HERE]
	end

	-- Executed after a battle ends, and only once per battle
	function self.afterBattleEnds()
		-- [ADD CODE HERE]
	end

	-- [Bizhawk only] Executed each frame (60 frames per second)
	-- CAUTION: Avoid unnecessary calculations here, as this can easily affect performance.
	function self.inputCheckBizhawk()
		-- Uncomment to use, otherwise leave commented out
			-- local mouseInput = input.getmouse() -- lowercase 'input' pulls directly from Bizhawk API
			-- local joypadButtons = Input.getJoypadInputFormatted() -- uppercase 'Input' uses Tracker formatted input
		-- [ADD CODE HERE]
	end

	-- Executed each frame of the game loop, after most data from game memory is read in but before any natural redraw events occur
	-- CAUTION: Avoid code here if possible, as this can easily affect performance. Most Tracker updates occur at 30-frame intervals, some at 10-frame.
	function self.afterEachFrame()
		-- [ADD CODE HERE]
	end

	return self
end
return IronmonConnect
