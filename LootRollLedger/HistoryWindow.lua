function LootRollLedger:CreateScrollingTable()
    tableLib = LibStub("ScrollingTable")
    local columns = {
        { name = "Time",      width = 130 },
        { name = "Item Name", width = 260 },
        { name = "Player",    width = 150 },
        { name = "Result",    width = 75  },
    }
    LootRollLedger:CreateHistoryFrame()
    self.scrollingTable = tableLib:CreateST(columns, 21, 15, nil, self.historyFrame)
    self.scrollingTable.frame:ClearAllPoints()
    self.scrollingTable.frame:SetPoint("TOP", self.historyFrame, "TOP", 0, -30)
end

function LootRollLedger:CreateHistoryFrame()
    local frame = CreateFrame("Frame", "LootRollLedgerHistoryFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    frame.width = 690
    frame.height = 405
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

	local button = CreateFrame("Button", nil, self.historyFrame, "UIPanelButtonTemplate")
    button:SetText("Close")
    button:SetWidth(100)
    button:SetHeight(22)
    button:SetPoint("BOTTOMRIGHT", self.historyFrame, "BOTTOMRIGHT", -20, 20)
    button:SetScript("OnClick", function(this) self.historyFrame:Hide() end)
end

function LootRollLedger:UpdateTable()
    local rows = { }
    for i = #self.db.global.archivedRolls, 1, -1 do
        local archivedData = self.db.global.archivedRolls[i]
        local winnerIndex, runnerUpIndex = LootRollLedger:FindTopRoll(archivedData)
        local winnerName = "No Winner"
        local winnerResult = "0/0"
        local dateStr = date("%m/%d/%y %H:%M:%S", archivedData.time)
        local dateSortIndex = 97
        if winnerIndex >= 0 then
            local firstResult = archivedData.rolls[winnerIndex]
            winnerName = LootRollLedger:RemoveServerName(firstResult.name)
            winnerResult = "" .. firstResult.result .. "/" .. archivedData.max
        end
        local cols = {
            { value = dateStr .. ".99" },
            { value = archivedData.item },
            { value = LootRollLedger:RemoveServerName(archivedData.from) },
            { value = archivedData.max },
        }
        local row = {
            cols = cols,
            color = { r=0.0, g=1.0, b=0.0, a=1.0 }
        }
        table.insert(rows, row)
        -- TODO Can this table be sorted by the 'result' value?
        local winnerIndex, runnerUpIndex = LootRollLedger:FindTopRoll(archivedData)
        for key, data in pairs(archivedData.rolls) do
            local cols = {
                { value = dateStr .. "." .. dateSortIndex },
                { value = "" },
                { value = data.name },
                { value = data.result },
            }
            local row = {
                cols = cols,
            }
            if key == winnerIndex then
                -- Make the winning roll stand out
                cols[1].value = dateStr .. "." .. 98
                cols[2].value = "** winner **"
                cols[2].color = { r=1.0, g=1.0, b=0.0, a=1.0 }
                cols[3].color = { r=1.0, g=1.0, b=0.0, a=1.0 }
                cols[4].color = { r=1.0, g=1.0, b=0.0, a=1.0 }
            else
                dateSortIndex = dateSortIndex - 1
            end
            table.insert(rows, row)
        end
    end
    
    self.scrollingTable:SetData(rows)
end
