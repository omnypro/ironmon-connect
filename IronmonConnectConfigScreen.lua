-- Configuration screen for IronmonConnect
IronmonConnectConfigScreen = {
    currentTab = 1,
    settingsLoaded = false
}

IronmonConnectConfigScreen.Tabs = {
    Connection = 1,
    Features = 2,
    Advanced = 3
}

IronmonConnectConfigScreen.Buttons = {}

function IronmonConnectConfigScreen.initialize()
    local Config = dofile(FileManager.getPathForFile("Config.lua") or "Config.lua")
    IronmonConnectConfigScreen.Config = Config
    
    IronmonConnectConfigScreen.createButtons()
    IronmonConnectConfigScreen.refreshButtons()
end

function IronmonConnectConfigScreen.createButtons()
    local startX = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 3
    local startY = Constants.SCREEN.MARGIN + 20
    local colX = startX + 65
    
    -- Tab buttons
    IronmonConnectConfigScreen.Buttons.TabConnection = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function() return "Connection" end,
        box = { startX, startY - 15, 50, 11 },
        isVisible = function() return true end,
        onClick = function()
            IronmonConnectConfigScreen.currentTab = IronmonConnectConfigScreen.Tabs.Connection
            Program.redraw(true)
        end
    }
    
    IronmonConnectConfigScreen.Buttons.TabFeatures = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function() return "Features" end,
        box = { startX + 55, startY - 15, 40, 11 },
        isVisible = function() return true end,
        onClick = function()
            IronmonConnectConfigScreen.currentTab = IronmonConnectConfigScreen.Tabs.Features
            Program.redraw(true)
        end
    }
    
    IronmonConnectConfigScreen.Buttons.TabAdvanced = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function() return "Advanced" end,
        box = { startX + 100, startY - 15, 45, 11 },
        isVisible = function() return true end,
        onClick = function()
            IronmonConnectConfigScreen.currentTab = IronmonConnectConfigScreen.Tabs.Advanced
            Program.redraw(true)
        end
    }
    
    -- Connection Tab
    IronmonConnectConfigScreen.Buttons.HostLabel = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function() return "Host:" end,
        box = { startX, startY + 10, 30, 11 },
        isVisible = function() return IronmonConnectConfigScreen.currentTab == IronmonConnectConfigScreen.Tabs.Connection end
    }
    
    IronmonConnectConfigScreen.Buttons.HostValue = {
        type = Constants.ButtonTypes.RECTANGLE,
        getText = function() return IronmonConnectConfigScreen.Config.get("wsHost") or "localhost" end,
        box = { colX, startY + 10, 70, 11 },
        isVisible = function() return IronmonConnectConfigScreen.currentTab == IronmonConnectConfigScreen.Tabs.Connection end,
        onClick = function()
            -- In a real implementation, this would open an input dialog
            print("[IronmonConnect] Host editing not yet implemented")
        end
    }
    
    IronmonConnectConfigScreen.Buttons.PortLabel = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function() return "Port:" end,
        box = { startX, startY + 25, 30, 11 },
        isVisible = function() return IronmonConnectConfigScreen.currentTab == IronmonConnectConfigScreen.Tabs.Connection end
    }
    
    IronmonConnectConfigScreen.Buttons.PortValue = {
        type = Constants.ButtonTypes.RECTANGLE,
        getText = function() return tostring(IronmonConnectConfigScreen.Config.get("wsPort") or 8080) end,
        box = { colX, startY + 25, 40, 11 },
        isVisible = function() return IronmonConnectConfigScreen.currentTab == IronmonConnectConfigScreen.Tabs.Connection end,
        onClick = function()
            -- In a real implementation, this would open an input dialog
            print("[IronmonConnect] Port editing not yet implemented")
        end
    }
    
    -- Features Tab
    local featureY = startY + 10
    local features = {
        { key = "runTracking", label = "Run Tracking" },
        { key = "battleEvents", label = "Battle Events" },
        { key = "checkpoints", label = "Checkpoints" },
        { key = "teamUpdates", label = "Team Updates" },
        { key = "locationTracking", label = "Location Tracking" }
    }
    
    for i, feature in ipairs(features) do
        IronmonConnectConfigScreen.Buttons["Feature" .. feature.key] = {
            type = Constants.ButtonTypes.CHECKBOX,
            getText = function() return feature.label end,
            clickableArea = { startX, featureY + (i-1) * 15, Constants.SCREEN.RIGHT_GAP - 12, 11 },
            box = { startX, featureY + (i-1) * 15, 8, 8 },
            toggleState = IronmonConnectConfigScreen.Config.get(feature.key) == true,
            isVisible = function() return IronmonConnectConfigScreen.currentTab == IronmonConnectConfigScreen.Tabs.Features end,
            onClick = function(self)
                self.toggleState = not self.toggleState
                IronmonConnectConfigScreen.Config.set(feature.key, self.toggleState)
                Program.redraw(true)
            end
        }
    end
    
    -- Advanced Tab
    IronmonConnectConfigScreen.Buttons.UpdateFreqLabel = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function() return "Update Freq:" end,
        box = { startX, startY + 10, 55, 11 },
        isVisible = function() return IronmonConnectConfigScreen.currentTab == IronmonConnectConfigScreen.Tabs.Advanced end
    }
    
    IronmonConnectConfigScreen.Buttons.UpdateFreqValue = {
        type = Constants.ButtonTypes.RECTANGLE,
        getText = function() return tostring(IronmonConnectConfigScreen.Config.get("updateFrequency") or 30) .. " frames" end,
        box = { colX + 15, startY + 10, 50, 11 },
        isVisible = function() return IronmonConnectConfigScreen.currentTab == IronmonConnectConfigScreen.Tabs.Advanced end,
        onClick = function()
            -- Cycle through common values
            local current = IronmonConnectConfigScreen.Config.get("updateFrequency") or 30
            local values = { 15, 30, 60, 120 }
            local nextIndex = 1
            for i, v in ipairs(values) do
                if v == current then
                    nextIndex = (i % #values) + 1
                    break
                end
            end
            IronmonConnectConfigScreen.Config.set("updateFrequency", values[nextIndex])
            Program.redraw(true)
        end
    }
    
    IronmonConnectConfigScreen.Buttons.DebugMode = {
        type = Constants.ButtonTypes.CHECKBOX,
        getText = function() return "Debug Mode" end,
        clickableArea = { startX, startY + 40, Constants.SCREEN.RIGHT_GAP - 12, 11 },
        box = { startX, startY + 40, 8, 8 },
        toggleState = IronmonConnectConfigScreen.Config.get("debug") == true,
        isVisible = function() return IronmonConnectConfigScreen.currentTab == IronmonConnectConfigScreen.Tabs.Advanced end,
        onClick = function(self)
            self.toggleState = not self.toggleState
            IronmonConnectConfigScreen.Config.set("debug", self.toggleState)
            Program.redraw(true)
        end
    }
    
    -- Common buttons
    IronmonConnectConfigScreen.Buttons.Save = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function() return "Save" end,
        box = { startX + 20, Constants.SCREEN.HEIGHT - 20, 30, 11 },
        isVisible = function() return true end,
        onClick = function()
            -- Config saves automatically, just go back
            Program.changeScreenView(NavigationMenu)
        end
    }
    
    IronmonConnectConfigScreen.Buttons.Cancel = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function() return "Cancel" end,
        box = { startX + 60, Constants.SCREEN.HEIGHT - 20, 35, 11 },
        isVisible = function() return true end,
        onClick = function()
            -- Reload config to discard changes
            IronmonConnectConfigScreen.Config.load()
            Program.changeScreenView(NavigationMenu)
        end
    }
    
    IronmonConnectConfigScreen.Buttons.Reset = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function() return "Reset" end,
        box = { startX + 105, Constants.SCREEN.HEIGHT - 20, 30, 11 },
        isVisible = function() return true end,
        onClick = function()
            IronmonConnectConfigScreen.Config.reset()
            IronmonConnectConfigScreen.refreshButtons()
            Program.redraw(true)
        end
    }
end

function IronmonConnectConfigScreen.refreshButtons()
    -- Update checkbox states
    for key, button in pairs(IronmonConnectConfigScreen.Buttons) do
        if key:find("Feature") and button.type == Constants.ButtonTypes.CHECKBOX then
            local featureKey = key:gsub("Feature", "")
            button.toggleState = IronmonConnectConfigScreen.Config.get(featureKey) == true
        end
    end
end

-- USER INPUT FUNCTIONS
function IronmonConnectConfigScreen.checkInput(xmouse, ymouse)
    Input.checkButtonsClicked(xmouse, ymouse, IronmonConnectConfigScreen.Buttons)
end

-- DRAWING FUNCTIONS
function IronmonConnectConfigScreen.drawScreen()
    Drawing.drawBackgroundAndMargins()
    
    -- Draw header
    local headerText = "IronmonConnect Settings"
    local headerX = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 3
    local headerY = Constants.SCREEN.MARGIN + 2
    Drawing.drawText(headerX, headerY, headerText, Theme.COLORS["Intermediate text"], Theme.COLORS["Main background"])
    
    -- Draw current tab indicator
    local tabY = Constants.SCREEN.MARGIN + 17
    local tabWidth = 50
    if IronmonConnectConfigScreen.currentTab == IronmonConnectConfigScreen.Tabs.Connection then
        gui.drawLine(headerX, tabY, headerX + tabWidth, tabY, Theme.COLORS["Intermediate text"])
    elseif IronmonConnectConfigScreen.currentTab == IronmonConnectConfigScreen.Tabs.Features then
        gui.drawLine(headerX + 55, tabY, headerX + 55 + 40, tabY, Theme.COLORS["Intermediate text"])
    elseif IronmonConnectConfigScreen.currentTab == IronmonConnectConfigScreen.Tabs.Advanced then
        gui.drawLine(headerX + 100, tabY, headerX + 100 + 45, tabY, Theme.COLORS["Intermediate text"])
    end
    
    -- Draw all buttons
    for _, button in pairs(IronmonConnectConfigScreen.Buttons) do
        if button.isVisible and button:isVisible() then
            Drawing.drawButton(button, Theme.COLORS["Main background"])
        end
    end
    
    -- Draw connection status (if on connection tab)
    if IronmonConnectConfigScreen.currentTab == IronmonConnectConfigScreen.Tabs.Connection then
        local statusY = Constants.SCREEN.MARGIN + 60
        local statusText = "Status: Disconnected" -- Would check actual connection state
        local statusColor = Theme.COLORS["Negative text"]
        Drawing.drawText(headerX, statusY, statusText, statusColor, Theme.COLORS["Main background"])
    end
end

return IronmonConnectConfigScreen
