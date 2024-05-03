local function IronmonConnect()
	local self = {}
	self.version = "0.6"
	self.name = "Ironmon Connect"
	self.author = "Omnyist Productions"
	self.description = "Uses BizHawk's socket functionality to provide run data to an external source."
	self.github = "omnypro/ironmon-connect"
	self.url = string.format("https://github.com/%s", self.github or "") -- Remove this attribute if no host website available for this extension

	--------------------------------------
	-- HELPER FUNCTIONS BELOW
	--------------------------------------

	local function enum(tbl)
		local length = #tbl
		for i = 0, length - 1 do
			local v = tbl[i + 1]
			tbl[v] = i3
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

	self.seed = nil
	self.seedVariables = {
		["Checkpoint"] = nil,
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

	function self.updateSeedVars()
		local V = self.seedVariables

		if self.isPlayingFRLG() then
			V.Progression.DefeatedFirstTrainer = Progression.DefeatedFirstTrainer
			V.Progression.DefeatedRocketHideout = Progression.DefeatedRocketHideout
			V.Progression.DefeatedSilph = Progression.DefeatedSilph
			V.Progression.DefeatedRival1 = Progression.DefeatedRival1
			V.Progression.DefeatedRival2 = Progression.DefeatedRival2
			V.Progression.DefeatedRival3 = Progression.DefeatedRival3
			V.Progression.DefeatedRival4 = Progression.DefeatedRival4
			V.Progression.DefeatedRival5 = Progression.DefeatedRival5
			V.Progression.DefeatedRival6 = Progression.DefeatedRival6
			V.Progression.DefeatedRival7 = Progression.DefeatedRival7
			V.Progression.DefeatedChamp = Progression.DefeatedChamp
			V.Progression.DefeatedBrock = Progression.DefeatedBrock
			V.Progression.DefeatedMisty = Progression.DefeatedMisty
			V.Progression.DefeatedSurge = Progression.DefeatedSurge
			V.Progression.DefeatedErika = Progression.DefeatedErika
			V.Progression.DefeatedKoga = Progression.DefeatedKoga
			V.Progression.DefeatedSabrina = Progression.DefeatedSabrina
			V.Progression.DefeatedBlaine = Progression.DefeatedBlaine
			V.Progression.DefeatedGiovanni = Progression.DefeatedGiovanni
			V.Progression.DefeatedLorelai = Progression.DefeatedLorelai
			V.Progression.DefeatedBruno = Progression.DefeatedBruno
			V.Progression.DefeatedAgatha = Progression.DefeatedAgatha
			V.Progression.DefeatedLance = Progression.DefeatedLance
		end
	end

	function self.handleCheckpoint()
		local V = self.seedVariables
		local checkpoint

		if not Progression.DefeatedRival1 then
			checkpoint = Checkpoints.LAB
		end
		if not V.Progression.DefeatedRival1 and Progression.DefeatedRival1 then
			checkpoint = Checkpoints.RIVAL1
			V.Progression.DefeatedRival1 = true
		end
		if not V.Progression.DefeatedFirstTrainer and Progression.DefeatedFirstTrainer then
			checkpoint = Checkpoints.FIRSTTRAINER
			V.Progression.DefeatedFirstTrainer = true
		end
		if not V.Progression.DefeatedRival2 and Progression.DefeatedRival2 then
			checkpoint = Checkpoints.RIVAL2
			V.Progression.DefeatedRival2 = true
		end
		if not V.Progression.DefeatedBrock and Progression.DefeatedBrock then
			checkpoint = Checkpoints.BROCK
			V.Progression.DefeatedBrock = true
		end
		if not V.Progression.DefeatedRival3 and Progression.DefeatedRival3 then
			checkpoint = Checkpoints.RIVAL3
			V.Progression.DefeatedRival3 = true
		end
		if not V.Progression.DefeatedRival4 and Progression.DefeatedRival4 then
			checkpoint = Checkpoints.RIVAL4
			V.Progression.DefeatedRival4 = true
		end
		if not V.Progression.DefeatedMisty and Progression.DefeatedMisty then
			checkpoint = Checkpoints.MISTY
			V.Progression.DefeatedMisty = true
		end
		if not V.Progression.DefeatedSurge and Progression.DefeatedSurge then
			checkpoint = Checkpoints.SURGE
			V.Progression.DefeatedSurge = true
		end
		if not V.Progression.DefeatedRival5 and Progression.DefeatedRival5 then
			checkpoint = Checkpoints.RIVAL5
			V.Progression.DefeatedRival5 = true
		end
		if not V.Progression.DefeatedRocketHideout and Progression.DefeatedRocketHideout then
			checkpoint = Checkpoints.ROCKETHIDEOUT
			V.Progression.DefeatedRocketHideout = true
		end
		if not V.Progression.DefeatedErika and Progression.DefeatedErika then
			checkpoint = Checkpoints.ERIKA
			V.Progression.DefeatedErika = true
		end
		if not V.Progression.DefeatedKoga and Progression.DefeatedKoga then
			checkpoint = Checkpoints.KOGA
			V.Progression.DefeatedKoga = true
		end
		if not V.Progression.DefeatedRival6 and Progression.DefeatedRival6 then
			checkpoint = Checkpoints.RIVAL6
			V.Progression.DefeatedRival6 = true
		end
		if not V.Progression.DefeatedSilph and Progression.DefeatedSilph then
			checkpoint = Checkpoints.SILPHCO
			V.Progression.DefeatedSilph = true
		end
		if not V.Progression.DefeatedSabrina and Progression.DefeatedSabrina then
			checkpoint = Checkpoints.SABRINA
			V.Progression.DefeatedSabrina = true
		end
		if not V.Progression.DefeatedBlaine and Progression.DefeatedBlaine then
			checkpoint = Checkpoints.BLAINE
			V.Progression.DefeatedBlaine = true
		end
		if not V.Progression.DefeatedGiovanni and Progression.DefeatedGiovanni then
			checkpoint = Checkpoints.GIOVANNI
			V.Progression.DefeatedGiovanni = true
		end
		if not V.Progression.DefeatedRival7 and Progression.DefeatedRival7 then
			checkpoint = Checkpoints.RIVAL7
			V.Progression.DefeatedRival7 = true
		end
		if not V.Progression.DefeatedLorelai and Progression.DefeatedLorelai then
			checkpoint = Checkpoints.LORELAI
			V.Progression.DefeatedLorelai = true
		end
		if not V.Progression.DefeatedBruno and Progression.DefeatedBruno then
			checkpoint = Checkpoints.BRUNO
			V.Progression.DefeatedBruno = true
		end
		if not V.Progression.DefeatedAgatha and Progression.DefeatedAgatha then
			checkpoint = Checkpoints.AGATHA
			V.Progression.DefeatedAgatha = true
		end
		if not V.Progression.DefeatedLance and Progression.DefeatedLance then
			checkpoint = Checkpoints.LANCE
			V.Progression.DefeatedLance = true
		end
		if not V.Progression.DefeatedChamp and Progression.DefeatedChamp then
			checkpoint = Checkpoints.CHAMP
			V.Progression.DefeatedChamp = true
		end

		-- Notify the server of the current Checkpoint.
		if V.Checkpoint ~= checkpoint then
			local payload = {
				["type"] = "checkpoint",
				["checkpoint"] = checkpoint
			}
			send(payload)

			console.log("> IMC: Checkpoint has changed to " .. checkpoint .. ".")
			V.Checkpoint = checkpoint
		end
	end


	--------------------------------------
	-- INTENRAL TRACKER FUNCTIONS BELOW
	--------------------------------------

	-- To properly determine when new items are acquired, need to load them in first at least once.
	local loadedVarsThisSeed

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
		console.log(string.format("> IMC: Version %s successfully loaded.", self.version))
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
		-- Once per seed, when the player is able to move their character, initiate the seed data.
		if not self.isPlayingFRLG() or not Program.isValidMapLocation() then
			return
		elseif not loadedVarsThisSeed then
			self.updateSeedVars()
			loadedVarsThisSeed = true
			console.log("> IMC: Seed variables reset.")
		end

		self.handleCheckpoint()
		self.updateSeedVars()
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
