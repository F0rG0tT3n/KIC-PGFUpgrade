local ADDON_NAME = ...

local DUNGEON_CATEGORY_ID = 2
local MIN_KEYSTONE_LEVEL = 2
local ROLE_REMAINING_KEYS = {
    TANK = "TANK_REMAINING",
    HEALER = "HEALER_REMAINING",
    DAMAGER = "DAMAGER_REMAINING",
}
local BLOODLUST_CLASSES = {
    EVOKER = true,
    HUNTER = true,
    MAGE = true,
    SHAMAN = true,
}
local INACTIVE_APPLICATION_STATUSES = {
    cancelled = true,
    declined = true,
    declined_delisted = true,
    declined_full = true,
    failed = true,
    invitedeclined = true,
    timedout = true,
}

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

local function GetSearchLevelRange()
    if not searchPanel or not searchPanel.SearchBox then
        return nil, nil
    end

    local searchText = searchPanel.SearchBox:GetText()
    if not IsSafeValue(searchText) or type(searchText) ~= "string" then
        return nil, nil
    end

    local minimumLevel, maximumLevel = searchText:match("^%s*%+?(%d+)%s*[-:]%s*%+?(%d+)%s*$")
    minimumLevel = tonumber(minimumLevel)
    maximumLevel = tonumber(maximumLevel)
    if not minimumLevel or not maximumLevel then
        return nil, nil
    end

    if minimumLevel > maximumLevel then
        minimumLevel, maximumLevel = maximumLevel, minimumLevel
    end

    return minimumLevel, maximumLevel
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

local function ActivityMatchesUpgrade(activityID)
    activityID = SafeNumber(activityID)
    if not activityID then
        return false
    end

    local challengeMapID = GetChallengeMapID(activityID)
    if not challengeMapID then
        return false
    end

    return true
end

local function ResultMatchesUpgrade(searchResultInfo)
    local activityIDs = searchResultInfo.activityIDs
    if IsAccessibleTable(activityIDs) then
        for _, activityID in ipairs(activityIDs) do
            if ActivityMatchesUpgrade(activityID) then
                return true
            end
        end

        return false
    end

    -- Compatibility with clients that expose one activity ID instead of activityIDs.
    return ActivityMatchesUpgrade(searchResultInfo.activityID)
end

local function GetResultTargetLevel(searchResultInfo)
    local activityIDs = searchResultInfo.activityIDs
    if IsAccessibleTable(activityIDs) then
        for _, activityID in ipairs(activityIDs) do
            activityID = SafeNumber(activityID)
            if activityID then
                local challengeMapID = GetChallengeMapID(activityID)
                if challengeMapID then
                    return targetByChallengeID[challengeMapID], challengeMapID
                end
            end
        end

        return nil
    end

    local activityID = SafeNumber(searchResultInfo.activityID)
    local challengeMapID = activityID and GetChallengeMapID(activityID)
    if challengeMapID then
        return targetByChallengeID[challengeMapID], challengeMapID
    end

    return nil, nil
end

local function GetUnitRole(unit)
    local role = UnitGroupRolesAssigned(unit)
    if not IsSafeValue(role) or type(role) ~= "string" or role == "NONE" then
        return "DAMAGER"
    end

    if ROLE_REMAINING_KEYS[role] then
        return role
    end

    return "DAMAGER"
end

local function GetPlayerSpecializationRole()
    local specializationIndex = GetSpecialization()
    if not specializationIndex then
        return "DAMAGER"
    end

    local role = GetSpecializationRole(specializationIndex)
    if not IsSafeValue(role) or not ROLE_REMAINING_KEYS[role] then
        return "DAMAGER"
    end

    return role
end

local function ForEachCurrentGroupUnit(callback)
    local numGroupMembers = GetNumGroupMembers()
    if numGroupMembers == 0 then
        callback("player")
        return
    end

    if IsInRaid() then
        for memberIndex = 1, numGroupMembers do
            callback("raid" .. memberIndex)
        end
        return
    end

    callback("player")
    for memberIndex = 1, numGroupMembers - 1 do
        callback("party" .. memberIndex)
    end
end

local function GetCurrentPartyRoles()
    local partyRoles = {
        TANK = 0,
        HEALER = 0,
        DAMAGER = 0,
    }

    if GetNumGroupMembers() == 0 then
        partyRoles[GetPlayerSpecializationRole()] = 1
        return partyRoles
    end

    ForEachCurrentGroupUnit(function(unit)
        local role = GetUnitRole(unit)
        partyRoles[role] = partyRoles[role] + 1
    end)

    return partyRoles
end

local function CurrentPartyHasBloodlust()
    local hasBloodlust = false
    ForEachCurrentGroupUnit(function(unit)
        if hasBloodlust then
            return
        end

        local _, classFilename = UnitClass(unit)
        if IsSafeValue(classFilename) and BLOODLUST_CLASSES[classFilename] then
            hasBloodlust = true
        end
    end)

    return hasBloodlust
end

local function ListedGroupHasBloodlust(memberCounts)
    for classFilename in pairs(BLOODLUST_CLASSES) do
        local classCount = SafeNumber(memberCounts[classFilename])
        if classCount and classCount > 0 then
            return true
        end
    end

    return false
end

local function PartyAndBloodlustFit(memberCounts, partyRoles, partyHasBloodlust)
    if not IsAccessibleTable(memberCounts) then
        return false
    end

    local remainingAfterJoin = {}
    for role, remainingKey in pairs(ROLE_REMAINING_KEYS) do
        local remainingSlots = SafeNumber(memberCounts[remainingKey])
        if remainingSlots == nil or remainingSlots < partyRoles[role] then
            return false
        end

        remainingAfterJoin[role] = remainingSlots - partyRoles[role]
    end

    if partyHasBloodlust or ListedGroupHasBloodlust(memberCounts) then
        return true
    end

    return remainingAfterJoin.HEALER > 0 or remainingAfterJoin.DAMAGER > 0
end

local function ResultHasPlayerClass(resultID, numMembers, memberCounts)
    if IsAccessibleTable(memberCounts) then
        local classCount = SafeNumber(memberCounts[playerClass])
        if classCount ~= nil then
            return classCount > 0
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

local function ResultPasses(resultID, minimumLevel, maximumLevel, partyRoles, partyHasBloodlust)
    local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
    if not IsAccessibleTable(searchResultInfo) then
        return false
    end

    if not ResultMatchesUpgrade(searchResultInfo) then
        return false
    end

    local targetLevel, challengeMapID = GetResultTargetLevel(searchResultInfo)
    if not targetLevel then
        return false
    end

    if minimumLevel and (targetLevel < minimumLevel or targetLevel > maximumLevel) then
        return false
    end

    local memberCounts
    if C_LFGList.GetSearchResultMemberCounts then
        memberCounts = C_LFGList.GetSearchResultMemberCounts(resultID)
    end

    if not PartyAndBloodlustFit(memberCounts, partyRoles, partyHasBloodlust) then
        return false
    end

    if ResultHasPlayerClass(resultID, searchResultInfo.numMembers, memberCounts) ~= false then
        return false
    end

    local leaderScore = SafeNumber(searchResultInfo.leaderOverallDungeonScore) or 0
    return true, targetLevel, challengeMapID, leaderScore
end

local function ApplicationStillFits(resultID, partyRoles, partyHasBloodlust)
    local _, applicationStatus, pendingStatus = C_LFGList.GetApplicationInfo(resultID)
    if not IsSafeValue(applicationStatus) or not IsSafeValue(pendingStatus) then
        return false
    end

    if INACTIVE_APPLICATION_STATUSES[applicationStatus]
        or INACTIVE_APPLICATION_STATUSES[pendingStatus]
    then
        return false
    end

    local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
    if not IsAccessibleTable(searchResultInfo) then
        return false
    end

    local isDelisted = searchResultInfo.isDelisted
    if not IsSafeValue(isDelisted) or isDelisted then
        return false
    end

    if not C_LFGList.GetSearchResultMemberCounts then
        return false
    end

    local memberCounts = C_LFGList.GetSearchResultMemberCounts(resultID)
    return PartyAndBloodlustFit(memberCounts, partyRoles, partyHasBloodlust)
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

    local fittingApplications = {}
    local nonFittingApplications = {}
    local applicationSet = {}
    local filteredResults = {}
    local resultOrder = {}
    local resultTargets = {}
    local resultMaps = {}
    local resultScores = {}
    local minimumLevel, maximumLevel = GetSearchLevelRange()
    local partyRoles = GetCurrentPartyRoles()
    local partyHasBloodlust = CurrentPartyHasBloodlust()

    if IsAccessibleTable(panel.applications) then
        for _, resultID in ipairs(panel.applications) do
            if IsSafeValue(resultID) and not applicationSet[resultID] then
                applicationSet[resultID] = true
                if ApplicationStillFits(resultID, partyRoles, partyHasBloodlust) then
                    fittingApplications[#fittingApplications + 1] = resultID
                else
                    nonFittingApplications[#nonFittingApplications + 1] = resultID
                end
            end
        end
    end

    for originalIndex, resultID in ipairs(panel.results) do
        local passes, targetLevel, challengeMapID, leaderScore
        if IsSafeValue(resultID) and not applicationSet[resultID] then
            passes, targetLevel, challengeMapID, leaderScore = ResultPasses(
                resultID,
                minimumLevel,
                maximumLevel,
                partyRoles,
                partyHasBloodlust
            )
        end

        if passes then
            filteredResults[#filteredResults + 1] = resultID
            resultOrder[resultID] = originalIndex
            resultTargets[resultID] = targetLevel
            resultMaps[resultID] = challengeMapID or 0
            resultScores[resultID] = leaderScore or 0
        end
    end

    table.sort(filteredResults, function(leftResultID, rightResultID)
        local leftScore = resultScores[leftResultID]
        local rightScore = resultScores[rightResultID]
        if leftScore ~= rightScore then
            return leftScore > rightScore
        end

        local leftTarget = resultTargets[leftResultID]
        local rightTarget = resultTargets[rightResultID]
        if leftTarget ~= rightTarget then
            return leftTarget < rightTarget
        end

        local leftMap = resultMaps[leftResultID]
        local rightMap = resultMaps[rightResultID]
        if leftMap ~= rightMap then
            return leftMap < rightMap
        end

        return resultOrder[leftResultID] < resultOrder[rightResultID]
    end)

    local orderedResults = {}
    for _, resultID in ipairs(fittingApplications) do
        orderedResults[#orderedResults + 1] = resultID
    end
    for _, resultID in ipairs(nonFittingApplications) do
        orderedResults[#orderedResults + 1] = resultID
    end
    for _, resultID in ipairs(filteredResults) do
        orderedResults[#orderedResults + 1] = resultID
    end

    panel.results = orderedResults
    panel.totalResults = #orderedResults

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

    AddTooltipLine("A keresőbe írt tartományon belül csak azokat a dungeonöket mutatja, amelyek következő upgrade-szintje beleesik a tartományba.", 0.9, 0.9, 0.9)
    AddTooltipLine("Kiszűri azokat a csoportokat, amelyekben már van a karaktereddel azonos class.", 0.9, 0.9, 0.9)
    AddTooltipLine("Csak olyan csoportot mutat, amelybe a teljes jelenlegi party szerepkörei beférnek.", 0.9, 0.9, 0.9)
    AddTooltipLine("Bloodlust nélkül csak akkor enged át egy csoportot, ha belépés után marad healer- vagy DPS-hely Bloodlustos classnak.", 0.9, 0.9, 0.9)
    AddTooltipLine("Rendezés: megfelelő jelentkezések, már nem megfelelő jelentkezések, majd a többi group leader score szerint.", 0.55, 0.75, 1)
    AddTooltipLine("Példa: 20-21. Pontos tartománynál (20-20) a tényleges upgrade [UPGRADE +N] jelölést kap.", 0.25, 1, 0.55)
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
    else
        Print("a +1 szűrő kikapcsolva.")
    end
end

local function UpdateResultTargetBadge(button)
    if not button then
        return
    end

    if not button.KICUpgradeTarget then
        local targetText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        targetText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -10, 6)
        targetText:SetJustifyH("RIGHT")
        button.KICUpgradeTarget = targetText
    end

    local targetText = button.KICUpgradeTarget
    if not IsFilterActive() or not button.resultID then
        targetText:Hide()
        return
    end

    local searchResultInfo = C_LFGList.GetSearchResultInfo(button.resultID)
    if not IsAccessibleTable(searchResultInfo) then
        targetText:Hide()
        return
    end

    local targetLevel = GetResultTargetLevel(searchResultInfo)
    if targetLevel then
        local minimumLevel, maximumLevel = GetSearchLevelRange()
        local isExactUpgrade = minimumLevel
            and minimumLevel == maximumLevel
            and targetLevel == minimumLevel

        if isExactUpgrade then
            targetText:SetText("[UPGRADE +" .. targetLevel .. "]")
            targetText:SetTextColor(0.25, 1, 0.35)
            targetText:Show()
        else
            targetText:Hide()
        end
    else
        targetText:Hide()
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

    hooksecurefunc("LFGListSearchEntry_Update", UpdateResultTargetBadge)
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
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("ROLE_CHANGED_INFORM")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitializeAddon()
        elseif arg1 == "Blizzard_GroupFinder" then
            InitializeGroupFinder()
        end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "ROLE_CHANGED_INFORM" then
        RefreshResults()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if not arg1 or arg1 == "player" then
            RefreshResults()
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
