local function IronmonConnect()
	local self = {}
	self.version = "1.1"
	self.name = "Ironmon Connect"
	self.author = "Omnyist Productions"
	self.description = "Uses BizHawk's socket functionality to provide run data to an external source."
	self.github = "omnypro/ironmon-connect"
	self.url = string.format("https://github.com/%s", self.github or "")

	self.seed = nil

	--------------------------------------
	-- INTERNAL SCRIPT FUNCTIONS BELOW
	--------------------------------------

  -- Checkpoint Data 
	local Checkpoints = {
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

	-- Variables
	self.currentCheckpointIndex = 1
	self.currentCheckpoint = Checkpoints[self.currentCheckpointIndex]
	self.checkpointsNotified = {}

	-- Functions
	local function send(data)
		packet = FileManager.JsonLibrary.encode(data)
		comm.socketServerSend(packet)
	end

	local function sendCheckpointNotification(checkpoint)
		local payload = {
			["type"] = "checkpoint",
			["metadata"] = {
				["id"] = self.currentCheckpointIndex,
				["name"] = checkpoint,
			},
		}
		send(payload)
	end
	
	function self.initializeCheckpoints()
		for checkpoint, _ in pairs(Checkpoints) do
			self.checkpointsNotified[checkpoint] = false
		end
	end

	function self.handleCheckpoint()
		-- Progression Flags
		local Progression = {
			LAB = true,
			RIVAL1 = Program.hasDefeatedTrainer(326) or Program.hasDefeatedTrainer(327) or Program.hasDefeatedTrainer(328),
			FIRSTTRAINER = Program.hasDefeatedTrainer(102) or Program.hasDefeatedTrainer(115),
			RIVAL2 = Program.hasDefeatedTrainer(329) or Program.hasDefeatedTrainer(330) or Program.hasDefeatedTrainer(331),
			BROCK = Program.hasDefeatedTrainer(414),
			RIVAL3 = Program.hasDefeatedTrainer(332) or Program.hasDefeatedTrainer(333) or Program.hasDefeatedTrainer(334),
			RIVAL4 = Program.hasDefeatedTrainer(426) or Program.hasDefeatedTrainer(427) or Program.hasDefeatedTrainer(428),
			MISTY = Program.hasDefeatedTrainer(415),
			SURGE = Program.hasDefeatedTrainer(416),
			RIVAL5 = Program.hasDefeatedTrainer(429) or Program.hasDefeatedTrainer(430) or Program.hasDefeatedTrainer(431),
			ROCKETHIDEOUT = Program.hasDefeatedTrainer(348),
			ERIKA = Program.hasDefeatedTrainer(417),
			KOGA = Program.hasDefeatedTrainer(418),
			RIVAL6 = Program.hasDefeatedTrainer(432) or Program.hasDefeatedTrainer(433) or Program.hasDefeatedTrainer(434),
			SILPHCO = Program.hasDefeatedTrainer(349),
			SABRINA = Program.hasDefeatedTrainer(420),
			BLAINE = Program.hasDefeatedTrainer(419),
			GIOVANNI = Program.hasDefeatedTrainer(350),
			RIVAL7 = Program.hasDefeatedTrainer(435) or Program.hasDefeatedTrainer(436) or Program.hasDefeatedTrainer(437),
			LORELAI = Program.hasDefeatedTrainer(410) or Program.hasDefeatedTrainer(735),
			BRUNO = Program.hasDefeatedTrainer(411) or Program.hasDefeatedTrainer(736),
			AGATHA = Program.hasDefeatedTrainer(412) or Program.hasDefeatedTrainer(737),
			LANCE = Program.hasDefeatedTrainer(413) or Program.hasDefeatedTrainer(738),
			CHAMP = Program.hasDefeatedTrainer(438) or Program.hasDefeatedTrainer(439) or Program.hasDefeatedTrainer(440)
		}

		local nextCheckpoint = Checkpoints[self.currentCheckpointIndex]
		local condition = Progression[nextCheckpoint]

		if condition and nextCheckpoint == self.currentCheckpoint and not self.checkpointsNotified[nextCheckpoint] then
			console.log("> IMC: Current checkpoint: " .. self.currentCheckpointIndex .. " > " .. self.currentCheckpoint)
			sendCheckpointNotification(nextCheckpoint)
			self.checkpointsNotified[nextCheckpoint] = true
			self.currentCheckpointIndex = self.currentCheckpointIndex + 1  -- Move to the next checkpoint
			self.currentCheckpoint = Checkpoints[self.currentCheckpointIndex]  -- Update the current checkpoint
		end
	end

	--------------------------------------
	-- INTENRAL TRACKER FUNCTIONS BELOW
	--------------------------------------

	function self.isPlayingFRLG()
		return GameSettings.game == 3
	end

	function self.handleSeed() 
		self.seed = Main.currentSeed
		console.log("> IMC: Seed number is now " .. self.seed .. ".")

		local seed = {
			["type"] = "seed",
			["metadata"] = {
				["count"] = Main.currentSeed
			}
		}
		send(seed)
	end

	function self.resetSeedVars()
		self.initializeCheckpoints()
		self.currentCheckpointIndex = 1
		self.currentCheckpoint = Checkpoints[self.currentCheckpointIndex]
		self.checkpointsNotified = {}
		self.seed = nil
	end

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
		local payload = {
			["type"] = "init",
			["metadata"] = {
				["version"] = self.version,
				["game"] = GameSettings.game,
			},
		}
		send(payload)

		-- Populate the current seed number, which should exist upon startup.
		self.handleSeed()

		-- Initialize the checkpoint notification flags.
		self.initializeCheckpoints()
	end

	-- Executed once every 30 frames, after most data from game memory is read in
	function self.afterProgramDataUpdate()
		-- Once per seed, when the player is able to move their character, initiate the seed data.
		if not self.isPlayingFRLG() or not Program.isValidMapLocation() then
			return
		elseif not loadedVarsThisSeed then
			self.resetSeedVars()
			loadedVarsThisSeed = true
			console.log("> IMC: Seed variables reset.")
		end

		self.handleCheckpoint()
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
