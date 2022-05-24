local GlobalMaxVisibleRows = 12
local GlobalPixelsPerLine = 28
local GlobalPixelGapPerEntry = 6

function LootRollLedger:CreateHistoryFrame()
    local frame = CreateFrame("Frame", "LootRollLedgerHistoryFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    frame.width = 690
    frame.height = 420
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetSize(frame.width, frame.height)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile    = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile  = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile      = true,
        tileSize  = 32,
        edgeSize  = 32,
        insets    = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)	
    frame:SetMovable(true)
    frame:SetResizable(enable)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self, button) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:EnableMouse(true)
    self.historyFrame = frame

    -- Scrolling body
    -- https://wowwiki-archive.fandom.com/wiki/Making_a_scrollable_list_using_FauxScrollFrameTemplate
    local scroll = CreateFrame("ScrollFrame", "LootRollLedgerScrollFrame", frame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, 16, -15)
    scroll:SetPoint("BOTTOMRIGHT", frame, -38, 50)
    
    local function vertScroll() LootRollLedger:OnVerticalScroll() end
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, GlobalPixelsPerLine, vertScroll)
        end)
    self.scrollFrame = scroll

	local button = CreateFrame("Button", nil, self.historyFrame, "UIPanelButtonTemplate")
    button:SetText("Close")
    button:SetWidth(100)
    button:SetHeight(22)
    button:SetPoint("BOTTOMRIGHT", self.historyFrame, "BOTTOMRIGHT", -16, 20)
    button:SetScript("OnClick", function(this) self.historyFrame:Hide() end)

    self.scrollEntries = {}
    for row = 1, GlobalMaxVisibleRows do
        local fromLabel = LootRollLedger:CreateLabelButton(self.scrollFrame, 390)
        local itemLabel = LootRollLedger:CreateLabelButton(self.scrollFrame, 390)
        local firstLabel = LootRollLedger:CreateLabelButton(self.scrollFrame, 250)
        local secondLabel = LootRollLedger:CreateLabelButton(self.scrollFrame, 250)
        if row == 1 then
            -- First row
            fromLabel:SetPoint("TOPLEFT", self.scrollFrame, "TOPLEFT", 0, 0)
        else
            -- All other rows
            fromLabel:SetPoint("TOP", self.scrollEntries[row - 1].item, "BOTTOM", 0, -GlobalPixelGapPerEntry)
        end
        itemLabel:SetPoint("TOPLEFT", fromLabel, "BOTTOMLEFT", 0, 0)
        firstLabel:SetPoint("LEFT", fromLabel, "RIGHT", 0, 0)
        secondLabel:SetPoint("LEFT", itemLabel, "RIGHT", 0, 0)
        -- Rough idea for each row:
        --
        -- [FROM LABEL]          [FIRST LABEL]
        -- [ITEM LABEL]          [SECOND LABEL]
        --
        -- 2021-11-22 21:33 from Kieron range 1-543          Winner: Luvly with 345
        -- [Grips of Occult Reminiscence]                    [Full Results]
        --
        -- 2021-11-22 21:33 from Kieron range 1-543          Winner: Luvly with 345
        -- [Grips of Occult Reminiscence]                    [Full Results]
        --
        self.scrollEntries[row] = {
            item = itemLabel,
            from = fromLabel,
            first = firstLabel,
            second = secondLabel,
        }
    end

    LootRollLedger:OnVerticalScroll()
end

function LootRollLedger:CreateLabelButton(parentFrame, frameWidth)
    local button = CreateFrame("Button", nil, parentFrame)
    button:SetWidth(frameWidth)
    button:SetHeight(12)
    local text = button:CreateFontString(nil, nil, "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetAllPoints(button)
    button:SetFontString(text)
    button:SetText("BLANK")
    button:Show()
    return button
end

function LootRollLedger:AddItemRoll(frame, verticalOffset)
    roll = self.db.global.archivedRolls[0]
end

function LootRollLedger:OnVerticalScroll()
    local maxItems = #self.db.global.archivedRolls
    FauxScrollFrame_Update(self.scrollFrame, maxItems, GlobalMaxVisibleRows, GlobalPixelsPerLine, nil, nil, nil, nil, nil, nil, true)
    local frameOffset = FauxScrollFrame_GetOffset(self.scrollFrame)

    local row
    for row = 1, GlobalMaxVisibleRows do
        local offsetRow = row + frameOffset
        if offsetRow <= maxItems then
            -- Add 1 because the data table is zero-based and the faux scroll frame is one-based
            local archivedData = self.db.global.archivedRolls[maxItems - offsetRow + 1]
            local winnerIndex, runnerUpIndex = LootRollLedger:FindTopRoll(archivedData)
            local winnerText = "Winner: None"
            local otherText = "Second: None"
            if winnerIndex >= 0 then
                winnerText = "Winner: " .. archivedData.rolls[winnerIndex].name .. " with a " .. archivedData.rolls[winnerIndex].result
            end
            local colorFromPlayer = "|cffffff00" -- yellow
            local colorAllResults = "|cff88ff88" -- light green
            local colorReset = "|r"
            -- Extra processing if there's at least one runner up for the item
            if runnerUpIndex >= 0 then
                -- Create a list of winners for the tooltip
                if #archivedData.rolls > 2 then
                    otherText = colorAllResults .. "Hover to view all rolls for this item" .. colorReset
                -- Only a single runner up, display directly
                else
                    otherText = "Second: " .. archivedData.rolls[runnerUpIndex].name .. " with a " .. archivedData.rolls[runnerUpIndex].result
                end
            end
            local dateStr = date("%m/%d/%y %H:%M", archivedData.time)
            self.scrollEntries[row].from:SetText(dateStr .. " from " .. colorFromPlayer .. archivedData.from .. colorReset .. " range 1-" .. archivedData.max)
            self.scrollEntries[row].item:SetText(archivedData.item)
            self.scrollEntries[row].item:HookScript("OnLeave", function() GameTooltip:Hide() end)
            self.scrollEntries[row].item:HookScript("OnEnter", function()
                GameTooltip:SetOwner(self.scrollEntries[row].item, "ANCHOR_TOPLEFT", 0, 12)
                GameTooltip:SetHyperlink(archivedData.item)
                GameTooltip:Show()
            end)
            self.scrollEntries[row].first:SetText(winnerText)
            self.scrollEntries[row].second:SetText(otherText)
            -- Clear any previous tooltip hooks
            self.scrollEntries[row].second:HookScript("OnLeave", function() GameTooltip:Hide() end)
            self.scrollEntries[row].second:HookScript("OnEnter", function() GameTooltip:Hide() end)
            -- Add a tooltip hook if there was more than 2 rollers for this item
            if #archivedData.rolls > 2 then
                self.scrollEntries[row].second:HookScript("OnEnter", function()
                    GameTooltip:SetOwner(self.scrollEntries[row].second, "ANCHOR_TOPLEFT", 0, 12)
                    GameTooltip:AddLine("All rolls for this item:")
                    table.sort(archivedData.rolls, function (a, b) return a.result > b.result end)
                    for _, data in pairs(archivedData.rolls) do
                        GameTooltip:AddLine("   " .. data.name .. " with a " .. data.result)
                    end
                    GameTooltip:Show()
                end)
            end
            self.scrollEntries[row].from:Show()
            self.scrollEntries[row].item:Show()
            self.scrollEntries[row].first:Show()
            self.scrollEntries[row].second:Show()
        else
            self.scrollEntries[row].from:Hide()
            self.scrollEntries[row].item:Hide()
            self.scrollEntries[row].item:HookScript("OnLeave", function() GameTooltip:Hide() end)
            self.scrollEntries[row].item:HookScript("OnEnter", function() GameTooltip:Hide() end)
            self.scrollEntries[row].first:Hide()
            self.scrollEntries[row].second:Hide()
            self.scrollEntries[row].second:HookScript("OnLeave", function() GameTooltip:Hide() end)
            self.scrollEntries[row].second:HookScript("OnEnter", function() GameTooltip:Hide() end)
        end
    end
end
