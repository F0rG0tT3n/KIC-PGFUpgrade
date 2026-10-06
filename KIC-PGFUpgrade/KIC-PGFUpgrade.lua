local ADDON_NAME = ...

local DUNGEON_CATEGORY_ID = 2
local MIN_KEYSTONE_LEVEL = 2

local issecretvalue = issecretvalue or function()
    return false
end

local canaccesstable = canaccesstable or function()
    return true
end

local frame = CreateFrame("Frame")
local searchPanel
local toggleButton
local playerClass
local currentCategoryID
local initialized = false
local applyingFilter = false
local targetsReady = false
local targetByChallengeID = {}
local challengeByInstanceMapID = {}
local targetRows = {}

local function Print(message)
    print("|cff33ff99KIC PGF Upgrade|r: " .. message)
end

local function IsSafeValue(value)
    return not issecretvalue(value)
end

local function IsAccessibleTable(value)
    return value ~= nil and not issecretvalue(value) and canaccesstable(value)
end

local function SafeNumber(value)
    if not IsSafeValue(value) or type(value) ~= "number" then
        return nil
    end

    return value
end

local function GetBestLevel(runInfo)
    if not IsAccessibleTable(runInfo) then
        return 0
    end

    return SafeNumber(runInfo.level) or 0
end

local function RebuildTargets()
    wipe(targetByChallengeID)
    wipe(challengeByInstanceMapID)
    wipe(targetRows)
    targetsReady = false

    if not C_ChallengeMode or not C_ChallengeMode.GetMapTable or not C_ChallengeMode.GetMapUIInfo then
        return
    end

    if C_MythicPlus and C_MythicPlus.RequestMapInfo then
        C_MythicPlus.RequestMapInfo()
    end

    local challengeMapIDs = C_ChallengeMode.GetMapTable()
    if not IsAccessibleTable(challengeMapIDs) then
        return
    end

    for _, challengeMapID in ipairs(challengeMapIDs) do
        challengeMapID = SafeNumber(challengeMapID)
        if challengeMapID then
            local name, _, _, _, _, instanceMapID = C_ChallengeMode.GetMapUIInfo(challengeMapID)
            local bestLevel = 0

            if C_MythicPlus and C_MythicPlus.GetSeasonBestForMap then
                local inTimeInfo, overTimeInfo = C_MythicPlus.GetSeasonBestForMap(challengeMapID)
                bestLevel = math.max(GetBestLevel(inTimeInfo), GetBestLevel(overTimeInfo))
            end

            local targetLevel = math.max(MIN_KEYSTONE_LEVEL, bestLevel + 1)
            targetByChallengeID[challengeMapID] = targetLevel

            instanceMapID = SafeNumber(instanceMapID)
            if instanceMapID then
                challengeByInstanceMapID[instanceMapID] = challengeMapID
            end

            if IsSafeValue(name) and type(name) == "string" then
                targetRows[#targetRows + 1] = {
                    name = name,
                    level = targetLevel,
                }
            end

            targetsReady = true
        end
    end

    table.sort(targetRows, function(left, right)
        return left.name < right.name
    end)
end

local function GetChallengeMapID(activityID)
    if not C_LFGList.GetActivityInfoTable then
        return nil
    end

    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
    if not IsAccessibleTable(activityInfo) then
        return nil
    end

    local isMythicPlus = activityInfo.isMythicPlusActivity
    if not IsSafeValue(isMythicPlus) or not isMythicPlus then
        return nil
    end

    local mapID = SafeNumber(activityInfo.mapID)
    if not mapID then
        return nil
    end

    return challengeByInstanceMapID[mapID] or (targetByChallengeID[mapID] and mapID) or nil
end

local function ActivityMatchesUpgrade(activityID, exactSearchLevel)
    activityID = SafeNumber(activityID)
    if not activityID then
        return false
    end

    local challengeMapID = GetChallengeMapID(activityID)
    if not challengeMapID then
        return false
    end

    return exactSearchLevel == nil or targetByChallengeID[challengeMapID] == exactSearchLevel
end

local function ResultMatchesUpgrade(searchResultInfo, exactSearchLevel)
    local activityIDs = searchResultInfo.activityIDs
    if IsAccessibleTable(activityIDs) then
        for _, activityID in ipairs(activityIDs) do
            if ActivityMatchesUpgrade(activityID, exactSearchLevel) then
                return true
            end
        end

        return false
    end

    -- Compatibility with clients that expose one activity ID instead of activityIDs.
    return ActivityMatchesUpgrade(searchResultInfo.activityID, exactSearchLevel)
end

local function GetExactSearchLevel()
    if not searchPanel or not searchPanel.SearchBox then
        return nil
    end

    local searchText = searchPanel.SearchBox:GetText()
    if not IsSafeValue(searchText) or type(searchText) ~= "string" then
        return nil
    end

    local minimumLevel, maximumLevel = searchText:match("^%s*%+?(%d+)%s*[-:]%s*%+?(%d+)%s*$")
    minimumLevel = tonumber(minimumLevel)
    maximumLevel = tonumber(maximumLevel)
    if minimumLevel and minimumLevel == maximumLevel then
        return minimumLevel
    end

    return nil
end

local function ResultHasPlayerClass(resultID, numMembers)
    if C_LFGList.GetSearchResultMemberCounts then
        local memberCounts = C_LFGList.GetSearchResultMemberCounts(resultID)
        if IsAccessibleTable(memberCounts) then
            local classCount = SafeNumber(memberCounts[playerClass])
            if classCount ~= nil then
                return classCount > 0
            end
        end
    end

    numMembers = SafeNumber(numMembers)
    if not numMembers then
        return nil
    end

    for memberIndex = 1, numMembers do
        if C_LFGList.GetSearchResultPlayerInfo then
            local memberInfo = C_LFGList.GetSearchResultPlayerInfo(resultID, memberIndex)
            if not IsAccessibleTable(memberInfo) then
                return nil
            end

            local classFilename = memberInfo.classFilename
            if not IsSafeValue(classFilename) or type(classFilename) ~= "string" then
                return nil
            end

            if classFilename == playerClass then
                return true
            end
        elseif C_LFGList.GetSearchResultMemberInfo then
            local _, classFilename = C_LFGList.GetSearchResultMemberInfo(resultID, memberIndex)
            if not IsSafeValue(classFilename) or type(classFilename) ~= "string" then
                return nil
            end

            if classFilename == playerClass then
                return true
            end
        else
            return nil
        end
    end

    return false
end

local function ResultPasses(resultID, exactSearchLevel)
    local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
    if not IsAccessibleTable(searchResultInfo) then
        return false
    end

    if not ResultMatchesUpgrade(searchResultInfo, exactSearchLevel) then
        return false
    end

    return ResultHasPlayerClass(resultID, searchResultInfo.numMembers) == false
end

local function IsFilterActive()
    return KICPGFUpgradeDB
        and KICPGFUpgradeDB.enabled
        and currentCategoryID == DUNGEON_CATEGORY_ID
        and targetsReady
end

local function UpdateButton()
    if not toggleButton then
        return
    end

    if currentCategoryID == DUNGEON_CATEGORY_ID then
        toggleButton:Show()
    else
        toggleButton:Hide()
    end

    local fontString = toggleButton:GetFontString()
    if KICPGFUpgradeDB and KICPGFUpgradeDB.enabled then
        toggleButton:SetText("KIC +1")
        if fontString then
            fontString:SetTextColor(0.25, 1, 0.35)
        end
    else
        toggleButton:SetText("KIC +1")
        if fontString then
            fontString:SetTextColor(1, 0.82, 0)
        end
    end
end

local function RefreshResults()
    if searchPanel and searchPanel:IsShown() and LFGListSearchPanel_UpdateResultList then
        LFGListSearchPanel_UpdateResultList(searchPanel)
    end
end

local function ApplyFilter(panel)
    if applyingFilter or panel ~= searchPanel or not IsFilterActive() then
        return
    end

    if not IsAccessibleTable(panel.results) then
        return
    end

    applyingFilter = true

    local filteredResults = {}
    local resultSeen = {}
    local exactSearchLevel = GetExactSearchLevel()
    for _, resultID in ipairs(panel.results) do
        if IsSafeValue(resultID) and ResultPasses(resultID, exactSearchLevel) then
            filteredResults[#filteredResults + 1] = resultID
            resultSeen[resultID] = true
        end
    end

    panel.results = filteredResults

    local totalResults = #filteredResults
    if IsAccessibleTable(panel.applications) then
        for _, resultID in ipairs(panel.applications) do
            if IsSafeValue(resultID) and not resultSeen[resultID] then
                totalResults = totalResults + 1
            end
        end
    end
    panel.totalResults = totalResults

    if LFGListSearchPanel_UpdateResults then
        LFGListSearchPanel_UpdateResults(panel)
    end

    applyingFilter = false
end

local function AddTooltipLine(text, red, green, blue)
    GameTooltip:AddLine(text, red or 1, green or 1, blue or 1, true)
end

local function ShowButtonTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText("KIC PGF Upgrade")

    if KICPGFUpgradeDB and KICPGFUpgradeDB.enabled then
        AddTooltipLine("Bekapcsolva", 0.25, 1, 0.35)
    else
        AddTooltipLine("Kikapcsolva", 1, 0.82, 0)
    end

    AddTooltipLine("Kiszűri a nem Mythic+ találatokat és azokat a dungeonöket, amelyekhez nem a beírt pontos szint a következő upgrade-ed.", 0.9, 0.9, 0.9)
    AddTooltipLine("Kiszűri azokat a csoportokat, amelyekben már van a karaktereddel azonos class.", 0.9, 0.9, 0.9)
    AddTooltipLine("Pontos +1 listához keress tartománnyal, például: 20-20.", 0.55, 0.75, 1)
    AddTooltipLine("Ha még nincs teljesített kulcsod, a cél +2.", 0.7, 0.7, 0.7)

    if targetsReady and #targetRows > 0 then
        AddTooltipLine(" ")
        AddTooltipLine("Jelenlegi célok:", 1, 0.82, 0)
        for _, row in ipairs(targetRows) do
            AddTooltipLine(row.name .. ": |cff33ff99+" .. row.level .. "|r", 1, 1, 1)
        end
    else
        AddTooltipLine("A Mythic+ adatok betöltésére vár...", 1, 0.4, 0.2)
    end

    AddTooltipLine("Kattintás: szűrő be/ki", 0.55, 0.75, 1)
    GameTooltip:Show()
end

local function ToggleFilter()
    KICPGFUpgradeDB.enabled = not KICPGFUpgradeDB.enabled
    RebuildTargets()
    UpdateButton()
    RefreshResults()

    if KICPGFUpgradeDB.enabled then
        Print("a +1 szűrő bekapcsolva.")
        if not GetExactSearchLevel() then
            Print("pontos +1 listához írj be egy pontos tartományt, például: 20-20.")
        end
    else
        Print("a +1 szűrő kikapcsolva.")
    end
end

local function CreateToggleButton(panel)
    toggleButton = CreateFrame("Button", "KICPGFUpgradeButton", panel, "UIPanelButtonTemplate")
    toggleButton:SetSize(64, 22)
    toggleButton:SetFrameLevel(panel:GetFrameLevel() + 10)
    toggleButton:SetScript("OnClick", ToggleFilter)
    toggleButton:SetScript("OnEnter", ShowButtonTooltip)
    toggleButton:SetScript("OnLeave", GameTooltip_Hide)
    UpdateButton()
end

local function PositionToggleButton(panel)
    if not toggleButton then
        return
    end

    toggleButton:ClearAllPoints()
    if panel.CategoryName then
        local titleWidth = math.ceil(panel.CategoryName:GetStringWidth() or 0)
        toggleButton:SetPoint("LEFT", panel.CategoryName, "LEFT", titleWidth + 8, 0)
    else
        toggleButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 104, -31)
    end
end

local function InitializeGroupFinder()
    if initialized or not LFGListFrame or not LFGListFrame.SearchPanel then
        return
    end

    initialized = true
    searchPanel = LFGListFrame.SearchPanel
    currentCategoryID = SafeNumber(searchPanel.categoryID)

    CreateToggleButton(searchPanel)
    PositionToggleButton(searchPanel)

    hooksecurefunc("LFGListSearchPanel_SetCategory", function(panel, categoryID)
        if panel ~= searchPanel then
            return
        end

        currentCategoryID = SafeNumber(categoryID)
        PositionToggleButton(panel)
        UpdateButton()
    end)

    hooksecurefunc("LFGListSearchPanel_UpdateResultList", function(panel)
        ApplyFilter(panel)
    end)
end

local function InitializeAddon()
    KICPGFUpgradeDB = KICPGFUpgradeDB or {}
    if KICPGFUpgradeDB.enabled == nil then
        KICPGFUpgradeDB.enabled = false
    end

    _, playerClass = UnitClass("player")
    RebuildTargets()

    SLASH_KICPGFUPGRADE1 = "/kicupgrade"
    SlashCmdList.KICPGFUPGRADE = function(message)
        message = strtrim(message or ""):lower()
        if message == "on" then
            KICPGFUpgradeDB.enabled = true
            RebuildTargets()
            UpdateButton()
            RefreshResults()
            Print("a +1 szűrő bekapcsolva.")
        elseif message == "off" then
            KICPGFUpgradeDB.enabled = false
            UpdateButton()
            RefreshResults()
            Print("a +1 szűrő kikapcsolva.")
        else
            ToggleFilter()
        end
    end

    InitializeGroupFinder()
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitializeAddon()
        elseif arg1 == "Blizzard_GroupFinder" then
            InitializeGroupFinder()
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        _, playerClass = UnitClass("player")
    end

    RebuildTargets()
    UpdateButton()
    RefreshResults()

    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            RebuildTargets()
            UpdateButton()
            RefreshResults()
        end)
    end
end)
