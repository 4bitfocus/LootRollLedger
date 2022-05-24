LootRollLedger = LibStub("AceAddon-3.0"):NewAddon("LootRollLedger", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

function LootRollLedger:OnInitialize()
    local options = {
        name = "LootRollLedger",
        handler = LootRollLedger,
        type = 'group',
        args = {
            enable = {
                order = 1,
                width = "full",
                name = "Enable",
                desc = "Enable or disable all loot roll tracking and reporting",
                descStyle = "inline",
                type = "toggle",
                set = "SetEnableAddon",
                get = "GetEnableAddon",
            },
            reporting = {
                order = 2,
                width = "full",
                name = "Reporting",
                desc = "Enable or disable reporting results to raid or instance chat",
                descStyle = "inline",
                type = "toggle",
                set = "SetReporting",
                get = "GetReporting",
            },
            debug = {
                order = 3,
                name = "Debugging",
                desc = "Enable or disable additional logging",
                type = "toggle",
                set = "SetDebugging",
                get = "GetDebugging",
                hidden = true,
            },
            instructions = {
                order = 4,
                width = 1.77,
                name = "Show Instructions",
                desc = "Print instructions to raid or instance chat window",
                type = "execute",
                func = "DisplayInstructions",
            },
            settings = {
                order = 5,
                width = 1.77,
                name = "Show Settings",
                desc = "Display current addon settings",
                type = "execute",
                func = "ShowCurrentSettings",
            },
            clear = {
                order = 6,
                width = "full",
                name = "Clear Rolls",
                desc = "Clear all active loot rolls",
                type = "execute",
                func = "ClearActiveRolls",
            },
            test = {
                order = 7,
                hidden = true,
                name = "Test",
                desc = "Test item link parsing",
                type = "input",
                set = "SetTestMessage",
            },
            history = {
                order = 8,
                width = "full",
                name = "History Window",
                desc = "Display loot roll history window",
                type = "execute",
                func = "History",
            },
            search = {
                order = 9,
                width = "full",
                name = "Search",
                desc = "Search previous item rolls",
                type = "input",
                set = "Search",
            },
        },
    }

    -- TODO Add a command to print the loot roll instructions

    LibStub("AceConfig-3.0"):RegisterOptionsTable("LootRollLedger", options, {"lootrollledger", "lrl"})

    local defaults = {
      profile = {
        enabled = true,
        reporting = true,
        debug = false,
      },
      global = {
          dbVersion = 1,
          activeRolls = {},
          archivedRolls = {},
      },
    }

    self.db = LibStub("AceDB-3.0"):New("LootRollLedgerDB", defaults)
    self.configDialog = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("LootRollLedger", "Loot Roll Ledger")
    self.scrollingTable = nil
    self.historyFrame = nil
    self.showingHistory = false
    self.raidLeader = false
    self.whisperWarnings = {}

    LootRollLedger:RegisterEvent("CHAT_MSG_RAID")
    LootRollLedger:RegisterEvent("CHAT_MSG_RAID_LEADER")
    LootRollLedger:RegisterEvent("CHAT_MSG_RAID_WARNING")
    LootRollLedger:RegisterEvent("CHAT_MSG_SYSTEM")
    LootRollLedger:RegisterEvent("PARTY_LEADER_CHANGED")
    LootRollLedger:RegisterEvent("GROUP_ROSTER_UPDATE")
end

function LootRollLedger:OnEnable()
    -- Called when the addon is enabled
    LootRollLedger:Print("Archived rolls database size: " .. #self.db.global.archivedRolls)
    LootRollLedger:ScheduleRepeatingTimer("RollTimerExpired", 2)
    LootRollLedger:CheckForNewRaidLeader()
end

function LootRollLedger:OnDisable()
    -- Called when the addon is disabled
    LootRollLedger:Print("Disabling")
end

function LootRollLedger:SetEnableAddon(info, val)
    self.db.profile.enabled = val
    LootRollLedger:Print("Setting enabled status to: " .. (self.db.profile.enabled and "true" or "false"))
end

function LootRollLedger:GetEnableAddon(info)
    return self.db.profile.enabled
end

function LootRollLedger:SetReporting(info, val)
    self.db.profile.reporting = val
    LootRollLedger:Print("Setting reporting status to: " .. (self.db.profile.reporting and "true" or "false"))
end

function LootRollLedger:GetReporting(info)
    return self.db.profile.reporting
end

function LootRollLedger:SetDebugging(info, val)
    self.db.profile.debug = val
    LootRollLedger:Print("Setting debug status to: " .. (self.db.profile.debug and "true" or "false"))
end

function LootRollLedger:GetDebugging(info)
    return self.db.profile.debug
end

function LootRollLedger:ShowCurrentSettings(info)
    LootRollLedger:Print("enabled: " .. (self.db.profile.enabled and "true" or "false"))
    LootRollLedger:Print("reporting: " .. (self.db.profile.reporting and "true" or "false"))
    LootRollLedger:Print("debug: " .. (self.db.profile.debug and "true" or "false"))
end

function LootRollLedger:ClearActiveRolls(info)
    for activeKey, activeData in pairs(self.db.global.activeRolls) do
        LootRollLedger:Print("Clearing roll (" .. activeData.max .. ") from " .. activeData.from .. " for item " .. activeData.item)
    end
    self.db.global.activeRolls = { }
    --LootRollLedger:Print("All active rolls cleared")
end

function LootRollLedger:DisplayInstructions(info)
    LootRollLedger:SendSmartMessage("If you have an item to put up for roll, link the item in raid chat followed by a number (10-9999)")
    LootRollLedger:SendSmartMessage("If you want to roll for an item, you *must* use the number shared with item and type: /roll <number>")
    LootRollLedger:SendSmartMessage("After two minutes, I will announce the winner")
end

function LootRollLedger:SetTestMessage(info, input)
    local name, realm = UnitName("player")
    if realm == nil then
        realm = GetRealmName()
    end
    LootRollLedger:ProcessRaidMessage(input, name .. "-" .. realm)
end

function LootRollLedger:History(info, input)
    if self.historyFrame == nil then
        LootRollLedger:CreateHistoryFrame()
    end
    self.historyFrame:Show()
    LootRollLedger:OnVerticalScroll()
end

-- Removed the trailing server name (e.g. Kegshatter-Malygos) if found
function LootRollLedger:RemoveServerName(name)
    local index = string.find(name, "-")
    if index then
        return string.sub(name, 0, index-1)
    else
        return name
    end
end

function LootRollLedger:Search(info, input)
    -- Add commands for:
    --    (1) Search for results based on item name returning most recent. /lrl search <partial item name>
    --    (2) Search for results based on the max roll number returning most recent. /lrl search <max roll number>
    if string.len(input) == 0 then
        LootRollLedger:Print("/lrl search <number, item, or text>")
        return
    end
    local itemColor, itemParts, itemName = LootRollLedger:MatchItemLink(input)
    if itemColor then
        input = itemName
    end
    local inputNum = tonumber(input)
    local searchByRollNumber = false
    if inputNum then
        LootRollLedger:Print("Searching by roll number: " .. inputNum)
        searchByRollNumber = true
    else
        LootRollLedger:Print("Searching by item string: " .. input)
    end

    for i = #self.db.global.archivedRolls, 1, -1 do
        local archivedData = self.db.global.archivedRolls[i]
        local foundMatch = false
        if not searchByRollNumber and string.match(archivedData.item, input) then
            foundMatch = true
        elseif searchByRollNumber and inputNum == archivedData.max then
            foundMatch = true
        end
        if foundMatch then
            local winnerIndex, runnerUpIndex = LootRollLedger:FindTopRoll(archivedData)
            if winnerIndex < 0 then
                LootRollLedger:Print("No one rolled on " .. archivedData.item)
            else
                local firstResult = archivedData.rolls[winnerIndex]
                LootRollLedger:Print("The winner of " .. archivedData.item .. " from " .. LootRollLedger:RemoveServerName(archivedData.from) .. " is " .. firstResult.name .. " with a roll of " .. firstResult.result)
                if runnerUpIndex >= 0 then
                    secondResult = archivedData.rolls[runnerUpIndex]
                    LootRollLedger:Print("The runner-up was " .. secondResult.name .. " with a roll of " .. secondResult.result)
                end
            end
            return
        end
    end
end

-- Looks through all the rolls found in data.rolls and returns the first place and second place
-- indexes for those positions.
function LootRollLedger:FindTopRoll(rollData)
    local topRollResult = 0
    local topRollIndex = -1
    local secondRollResult = 0
    local secondRollIndex = -1
    -- Search all rolls for the first and second place values
    --LootRollLedger:Print("Searching for top role in " .. #data.rolls .. " rolls")
    for key, data in pairs(rollData.rolls) do
        if data.result > topRollResult then
            topRollResult = data.result
            topRollIndex = key
        end
    end
    for key, data in pairs(rollData.rolls) do
        if data.result > secondRollResult and key ~= topRollIndex then
            secondRollResult = data.result
            secondRollIndex = key
        end
    end
    return topRollIndex, secondRollIndex
end

function LootRollLedger:MatchItemLink(msg)
    --local itemString, itemName = msg:match("|H(.*)|h%[(.*)%]|h")
    local itemColor, itemString, itemName = msg:match("|c(.*)|H(.*)|h%[(.*)%]|h|r")
    if not itemColor then
        return nil
    else
        local _, itemLink = GetItemInfo(itemString)
        if not itemLink then return nil end
        return itemColor, itemString, itemName
    end
end

function LootRollLedger:IndexOfItemLink(msg)
    return msg:find("|c(.*)|H(.*)|h%[(.*)%]|h|r")
end

function LootRollLedger:CreateItemLink(color, parts, name)
    return "|c" .. color .. "|H" .. parts .. "|h[" .. name .. "]|h|r"
end

function LootRollLedger:PrintableItemLink(item)
    return gsub(item, "\124", "\124\124"); -- 124 is the ascii code for '|'
end

-- Callback to handle raid chat messages to parse the incoming roll requests
function LootRollLedger:ProcessRaidMessage(msg, author)
    if not self.db.profile.enabled then return end

    -- Ignore any of the messages that this addon sends containing an item link
    -- via SendSmartMessage() to the raid/party channel
    if msg:find("The winner of ") or msg:find("No one rolled on ") then
        return
    end

    local itemColor, itemParts, itemName = LootRollLedger:MatchItemLink(msg)
    if not itemColor then return end

    -- Reassemble the item link
    local itemLink = LootRollLedger:CreateItemLink(itemColor, itemParts, itemName)

    --LootRollLedger:Print("Linked item detected! " .. itemName .. " => " .. itemLink)
    --LootRollLedger:Print("Item roll started by " .. author)

    local startIndex, endIndex = LootRollLedger:IndexOfItemLink(msg)
    if startIndex then
        local submsg = string.sub(msg, 0, startIndex) .. string.sub(msg, endIndex)
        local number = submsg:match("(%d+)")
        if number then
            number = tonumber(number)
            -- Exclude a few numbers that are hard to deal with, or at least not currently handled
            if number == 100 or number <= 1 then
                LootRollLedger:SendSmartMessage("Awkward! That number (" .. number .. ") cannot be used for item rolls :(")
            end
            local duplicateMax = false
            -- Check for a duplicate active roll for that number
            for activeKey, activeData in pairs(self.db.global.activeRolls) do
                if number == activeData.max then
                    if self.db.profile.debug then
                        LootRollLedger:Print("Duplicate roll found (" .. activeData.max .. ") from " .. activeData.from .. " for item " .. activeData.item)
                    end
                    duplicateMax = true
                end
            end
            if duplicateMax then
                LootRollLedger:SendSmartMessage("Rut roh! That number (" .. number .. ") is already being used for an item roll :(")
            else
                -- Data structure for the activeRolls table
                local data = {
                    from = author,
                    item = itemLink,
                    max = number,
                    time = GetServerTime(),
                    rolls = { },
                }
                table.insert(self.db.global.activeRolls, data) -- append to the end
                if self.db.profile.debug then
                    LootRollLedger:Print("Tracking loot roll (" .. number .. ") from " .. author .. " for " .. itemLink)
                end
            end
        end
    end
end

-- Callback from the scheduled timer for when a roll expires for an item
function LootRollLedger:RollTimerExpired()
    if #self.db.global.activeRolls == 0 then
        return
    end
    --LootRollLedger:Print("Monitoring " .. #self.db.global.activeRolls .. " active rolls")
    for loopCount = 1, 5 do
        local now = GetServerTime()
        local skipRemaining = false
        for activeKey, activeData in pairs(self.db.global.activeRolls) do
            if not skipRemaining then
                -- Allow at least 2 minutes for player rolls
                if (now - activeData.time) >= 120 then
                    local winnerIndex, runnerUpIndex = LootRollLedger:FindTopRoll(activeData)
                    if winnerIndex < 0 then
                        LootRollLedger:SendSmartMessage("No one rolled on " .. activeData.item)
                    else
                        winnerData = activeData.rolls[winnerIndex]
                        LootRollLedger:SendSmartMessage("The winner of " .. activeData.item .. " is " .. winnerData.name .. "! Open trade with " .. LootRollLedger:RemoveServerName(activeData.from) .. " for your new item.")
                    end
                    table.remove(self.db.global.activeRolls, activeKey)
                    table.insert(self.db.global.archivedRolls, activeData)
                    -- Since we modified the table, skip the remaining rolls and let the top 'for' loop restart the check
                    skipRemaining = true
                end
            end
        end
    end
end

-- Callback to handle system /roll messages from players.
function LootRollLedger:ProcessLootRoll(msg)
    if not self.db.profile.enabled then return end

    -- TODO look into using the global string RANDOM_ROLL_RESULT to make this localization friendly
    local name, rollResult, minRoll, maxRoll = msg:match("^(.+) rolls (%d+) %((%d+)%-(%d+)%)$")
    if not name then
        return
    end

    local rollResult = tonumber(rollResult)
    local maxRoll = tonumber(maxRoll)
    local minRoll = tonumber(minRoll)
    local foundActiveMatch = false

    for k1, v1 in pairs(self.db.global.activeRolls) do
        if v1.max == maxRoll and minRoll == 1 then
            foundActiveMatch = true
            local alreadyRolled = false
            for k2, v2 in pairs(v1.rolls) do
                if v2.name == name then
                    alreadyRolled = true
                end
            end
            if alreadyRolled then
                if self.db.profile.debug then
                    LootRollLedger:Print("Ignoring multiple rolls from " .. name .. " for " .. v1.item)
                end
            else
                local data = {
                    name = name,
                    result = rollResult,
                }
                table.insert(v1.rolls, data)
                if self.db.profile.debug then
                    LootRollLedger:Print("Captured good roll from " .. name .. " for " .. v1.item)
                end
            end
        end
    end

    if foundActiveMatch == false and #self.db.global.activeRolls > 0 then
        LootRollLedger:SendRollWarning(name)
    end
end

function LootRollLedger:SendRollWarning(playerName)
    -- Only send the whisper warning one time
    if self.whisperWarnings[playerName] == nil then
        self.whisperWarnings[playerName] = true
        SendChatMessage("Your /roll command does not match an active item roll. Please make sure it is correct.", "WHISPER", "Common", playerName)
    end
end

function LootRollLedger:CheckForNewRaidLeader()
    local oldRaidLeader = self.raidLeader
    if LootRollLedger:IsRaidLeader() then
        self.raidLeader = true
    else
        self.raidLeader = false
    end
    -- Log the state change if applicable
    if oldRaidLeader == true and self.raidLeader == false then
        LootRollLedger:Print("Raid lead/assist status changed, loot reporting not allowed")
    elseif oldRaidLeader == false and self.raidLeader == true then
        LootRollLedger:Print("Raid lead/assist status changed, loot reporting allowed")
    end
end

function LootRollLedger:IsPlayerInRaidGroup()
    local inRaid = UnitInRaid("player")
    if inRaid == nil then
        return false
    else
        return true
    end
end

-- Determine if the current player is the raid leader or a raid assistant
function LootRollLedger:IsRaidLeader()
    if IsPartyLFG and IsPartyLFG() then
        return false -- never use in LFG
    end
    if GetNumGroupMembers() == 0 and self.db.profile.debug then
        return true -- testing, party of one, testing
    end
    if LootRollLedger:IsPlayerInRaidGroup() == false then
        return false -- don't use in 5-man parties
    end
    -- Consider the actual leader or someone with assist as a raid leader
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- NOTE: Any message that is logged here will also be sent back to this addon and needs
-- to be filtered from ProcessRaidMessage() if it would trigger another roll.
function LootRollLedger:SendSmartMessage(msg)
    local chatType = "UNKNOWN"
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        chatType = "INSTANCE_CHAT"
    elseif IsInRaid() then
        chatType = "RAID"
    elseif IsInGroup() then
        chatType = "PARTY"
    end
    -- To message the entire raid, the player running this addon must have raid lead or raid
    -- assist permissions. Otherwise, it will just be reported privately to that user.
    if chatType ~= "UNKNOWN" and self.raidLeader and self.db.profile.reporting then
        SendChatMessage(msg, chatType)
    else
        LootRollLedger:Print(msg)
    end
end

function LootRollLedger:CHAT_MSG_RAID(eventName, msg, author)
    LootRollLedger:ProcessRaidMessage(msg, author)
end

function LootRollLedger:CHAT_MSG_RAID_LEADER(eventName, msg, author)
    LootRollLedger:ProcessRaidMessage(msg, author)
end

function LootRollLedger:CHAT_MSG_RAID_WARNING(eventName, msg, author)
    LootRollLedger:ProcessRaidMessage(msg, author)
end

function LootRollLedger:CHAT_MSG_SYSTEM(eventName, msg)
    LootRollLedger:ProcessLootRoll(msg)
end

function LootRollLedger:PARTY_LEADER_CHANGED(eventName)
    --LootRollLedger:Print("Party leader status changed")
    self:ScheduleTimer("CheckForNewRaidLeader", 1)
end

function LootRollLedger:GROUP_ROSTER_UPDATE(eventName)
    --LootRollLedger:Print("Group roster status changed")
    self:ScheduleTimer("CheckForNewRaidLeader", 1)
end
