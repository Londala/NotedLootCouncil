-------------------------------------------------------------------------
--
-- Copyright (c) 2022 by Alex Londal.
-- Vinheim-Benediction (NA East) - WoW Classic Alliance
--
-- Noted Loot Council may be distributed to anyone WITHOUT ANY WARRANTY
-- Please make backups of your loot lists. The author is not
-- responsible for any lost data or information
--
-------------------------------------------------------------------------


-------------------------------------------------------------------------
-- Addon Variables
-------------------------------------------------------------------------

-- Globals
NotedLootCouncil = LibStub("AceAddon-3.0"):NewAddon("NotedLootCouncil", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")

nlc_constants = {}; -- Saved Loot Lists, Tooltips
local AceGUI = LibStub("AceGUI-3.0")

local _G = getfenv(0)

-- Addon Information
local nlc_local_version = "0.0.1"

local nlc_local_ldb = LibStub("LibDataBroker-1.1")
local nlc_broker = nil
local nlc_local_minimapicon = LibStub("LibDBIcon-1.0")
local nlc_local_brokervalue = nil
local nlc_local_brokerlabel = nil

-- Addon Communication
local nlc_local_prefix = "NLC_Channel"
local nlc_local_versionprefix = "NLC_Version"
local nlc_local_syncprefix = "NLC_Sync"
local nlc_local_selectprefix = "NLC_Select"
local nlc_local_voteprefix = "NLC_Vote"

local nlc_local_commandprefix = "NLC_Command"

-- Toon Info
local nlc_local_realmKey = GetRealmName()
local nlc_local_toonKey = UnitName("player") .. "-" .. nlc_local_realmKey
local nlc_local_toonInGuild = IsInGuild()
local nlc_local_guildName, nlc_local_guildRank, nlc_local_guildRankIndex = (function()
    if nlc_local_toonInGuild then
        return GetGuildInfo("player")
    else
        return nil, nil, nil
    end
end)

-- Banned Loot
local bannedItems = {}

-- Defaults
local defaults = {
    profile = {
        selectOptions = "BiS,Upgrade,Alt Bis,Alt Upgrade,OS/PVP,Pass",
        linkLoot = true,
        debugMode = false,
    },
}

local inv_types = {
    ["head"] = 1,
    ["neck"] = 2,
    ["shoulder"] = 3,
    ["chest"] = 5,
    ["waist"] = 6,
    ["legs"] = 7,
    ["feet"] = 8,
    ["wrist"] = 9,
    ["hands"] = 10,
    ["ring1"] = 11,
    ["ring2"] = 12,
    ["trinket1"] = 13,
    ["trinket2"] = 14,
    ["back"] = 15,
    ["mainhand"] = 16,
    ["offhand"] = 17,
    ["wand"] = 18,
}

local invTypeToSlot = {
    [""] = 0,
    ["INVTYPE_RANGEDRIGHT"] 		= 18,
    ["INVTYPE_SHIELD"] 				= 17,
    ["INVTYPE_RANGED"] 				= 0,
    ["INVTYPE_WEAPON"] 				= 16,
    ["INVTYPE_2HWEAPON"] 			= 16,
    ["INVTYPE_WRIST"]				= 9,
    ["INVTYPE_TRINKET"]				= 13,
    ["INVTYPE_ROBE"]				= 5,
    ["INVTYPE_CLOAK"]				= 15,
    ["INVTYPE_HEAD"]				= 1,
    ["INVTYPE_HOLDABLE"]			= 18,
    ["INVTYPE_CHEST"]				= 5,
    ["INVTYPE_NECK"]				= 2,
    ["INVTYPE_TABARD"]				= 19,
    ["INVTYPE_LEGS"]				= 7,
    ["INVTYPE_HAND"]				= 10,
    ["INVTYPE_WAIST"]				= 6,
    ["INVTYPE_FEET"]				= 8,
    ["INVTYPE_SHOULDER"]			= 3,
    ["INVTYPE_FINGER"]				= 11,
    ["INVTYPE_BAG"]					= 0,
    ["INVTYPE_AMMO"]				= 0,
    ["INVTYPE_BODY"]				= 4, -- Shirt
    ["INVTYPE_QUIVER"]				= 0,
    ["INVTYPE_RELIC"]				= 18,
    ["INVTYPE_THROWN"]				= 18,
    ["INVTYPE_WEAPONMAINHAND"] 		= 16,
    ["INVTYPE_WEAPONMAINHAND_PET"]	= 16,	-- "Main Attack"
    ["INVTYPE_WEAPONOFFHAND"]		= 17,
}

-------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------

local nlc_options = {
    name = "NotedLootCouncil",
    handler = NotedLootCouncil,
    desc = "Options for Noted Loot Council",
    type = "group",
    args = {
        selectOptions = {
            name = "Loot Select Options",
            desc = "A comma seperated string of loot select options",
            type = "input",
            get = "GetSelectOptions",
            set = "SetSelectOptions",
        },
        link_loot = {
            name = "Link Loot",
            desc = "Links good loot in raids",
            type = "toggle",
            get = "isLinkLoot",
            set = "toggleLinkLoot",
        },
        debug_mode = {
            name = "Debug Mode",
            desc = "Enable printing of debugging output",
            type = "toggle",
            get = "isDebug",
            set = "toggleDebug",
        },
    },
}

-------------------------------------------------------------------------
-- Event: Addon Init
-------------------------------------------------------------------------

function NotedLootCouncil:OnInitialize()
    -- DB
    self.db = LibStub("AceDB-3.0"):New("NLC_DB", defaults, true)

    LibStub("AceConfig-3.0"):RegisterOptionsTable("NotedLootCouncil", nlc_options, nil)

    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("NotedLootCouncil"):SetParent(InterfaceOptionsFramePanelContainer)

    -- Local Unsaved vars
    self.lootSlotInfo = {}
    self.lootReady = false

    self:RegisterChatCommand("nlc", "HandleSlashCommands")

    self.lootCache = {}
    self.lootSelectOptions = {}
    self.sessionInfo = {}
    NotedLootCouncil:parseLootSelectOptions()
end

-------------------------------------------------------------------------
-- Event: Addon Enable
-------------------------------------------------------------------------

function NotedLootCouncil:OnEnable()
    C_ChatInfo.RegisterAddonMessagePrefix(nlc_local_prefix)
	C_ChatInfo.RegisterAddonMessagePrefix(nlc_local_versionprefix)
    C_ChatInfo.RegisterAddonMessagePrefix(nlc_local_selectprefix)
    C_ChatInfo.RegisterAddonMessagePrefix(nlc_local_syncprefix)
    C_ChatInfo.RegisterAddonMessagePrefix(nlc_local_voteprefix)

    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("LOOT_READY")
    self:RegisterEvent("LOOT_SLOT_CLEARED")
    self:RegisterEvent("LOOT_CLOSED")
    -- self:RegisterEvent("BAG_UPDATE")

    self:Print("|cffff00ff[Noted Loot Council]|r Enabled")
end

-------------------------------------------------------------------------
-- Event: Addon Disable
-------------------------------------------------------------------------

function NotedLootCouncil:OnDisable()
    self:Print("|cffff00ff[Noted Loot Council]|r Disabled")
end

-------------------------------------------------------------------------
-- Debug Output Helper
-------------------------------------------------------------------------

function NotedLootCouncil:Debug(str)
    if self:isDebug() then
        self:Print("|cffff6060Debug:|r |cFFD3D3D3"..str.."|r")
    end
end

-------------------------------------------------------------------------
-- Misc Helpers
-------------------------------------------------------------------------

function NotedLootCouncil:parseLootSelectOptions()
    local opts = self:GetSelectOptions()
    for str in string.gmatch(opts, "([^"..",".."]+)") do
        table.insert(self.lootSelectOptions, str)
    end
end

local function GUIDtoID(guid)
	local type,_,serverID,instanceID,zoneUID,id,spawnID = strsplit("-", guid or "")
	return tonumber(id or 0)
end

local function getChatType(toSay)
	local isInInstance = IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
	local isInParty = IsInGroup()
	local isInRaid = IsInRaid()
	local playerName = nil
	local chat_type = (isInInstance and "INSTANCE_CHAT") or (isInRaid and "RAID") or (isInParty and "PARTY")
	if not chat_type and not toSay then
		chat_type = "WHISPER"
		playerName = UnitName("player") 
	elseif not chat_type then
		chat_type = "SAY"
	end
	return chat_type, playerName
end

-- Access raid/boss items
function NotedLootCouncil:getBossItems(boss)
    for n, itemID in pairs(nlc_constants.sscItemDict[boss]) do
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            local link = item:GetItemLink()
            local level = item:GetCurrentItemLevel()
            NotedLootCouncil:Print("Item "..n..": "..link.." ("..level..")")
        end)
    end
end

function NotedLootCouncil:GenTest()
    table.insert(self.lootCache, "\124cffa335ee\124Hitem:40396::::::::80:::::\124h[The Turning Tide]\124h\124r")
    table.insert(self.lootCache, "\124cffa335ee\124Hitem:44661::::::::80:::::\124h[Wyrmrest Necklace of Power]\124h\124r")
    table.insert(self.lootCache, "\124cffff8000\124Hitem:19019::::::::80:::::\124h[Thunderfury, Blessed Blade of the Windseeker]\124h\124r")
    table.insert(self.lootCache, "\124cffa335ee\124Hitem:40348::::::::80:::::\124h[Damnation]\124h\124r")
    table.insert(self.lootCache, "\124cffa335ee\124Hitem:39766::::::::80:::::\124h[Matriarch's Spawn]\124h\124r")
    table.insert(self.lootCache, "\124cffa335ee\124Hitem:40255::::::::80:::::\124h[Dying Curse]\124h\124r")
    table.insert(self.lootCache, "\124cffa335ee\124Hitem:39199::::::::80:::::\124h[Watchful Eye]\124h\124r")
    table.insert(self.lootCache, "\124cffa335ee\124Hitem:40396::::::::80:::::\124h[The Turning Tide]\124h\124r")
    table.insert(self.lootCache, "\124cffa335ee\124Hitem:44661::::::::80:::::\124h[Wyrmrest Necklace of Power]\124h\124r")
    table.insert(self.lootCache, "\124cffff8000\124Hitem:19019::::::::80:::::\124h[Thunderfury, Blessed Blade of the Windseeker]\124h\124r")
    self.lootSelectOptions = {"BiS", "Upgrade", "Alt Bis", "Alt Upgrade", "OS/PVP", "Pass"}
    for i,s in ipairs(self.lootSelectOptions) do
        self:Debug(s)
    end
    self:buildSessionInfo()
    NotedLootCouncil:OpenLootFrame()
end

-------------------------------------------------------------------------
-- Event: CHAT_MSG_ADDON
-------------------------------------------------------------------------

function NotedLootCouncil:CHAT_MSG_ADDON(event, arg1, arg2, arg3, arg4)
    if arg1 == nlc_local_prefix then
        self:Debug("Chat recieved in correct channel")
    elseif arg1 == nlc_local_syncprefix then
        self:GetSyncItems(arg2)
    elseif arg1 == nlc_local_selectprefix then
        self:GetSelection(arg2,arg4)
    elseif arg1 == nlc_local_versionprefix then
        self:Print("v0.0.1")
    elseif arg1 == nlc_local_voteprefix then
        self:GetVote(arg2, arg4)
    end
end

function NotedLootCouncil:SendAddonMsg(str)
    C_ChatInfo.SendAddonMessage(nlc_local_prefix, str, getChatType(false))
end

function NotedLootCouncil:SyncItems()
    for k,item in pairs(self.lootCache) do
        C_ChatInfo.SendAddonMessage(nlc_local_syncprefix, item, getChatType(false))
    end
    C_ChatInfo.SendAddonMessage(nlc_local_syncprefix, "END SYNC", getChatType(false))
end

function NotedLootCouncil:GetSyncItems(msg)
    if msg == "END SYNC" then
        self:buildSessionInfo()
    else
        table.insert(self.lootCache, msg)
    end
end

function NotedLootCouncil:SendSelection(idx, item, equipedItem)
    local _, playerClass = UnitClass("player")
    local str = idx .. "=" .. item .. "=" .. equipedItem .. "=" .. playerClass
    NotedLootCouncil:Debug(str)
    C_ChatInfo.SendAddonMessage(nlc_local_selectprefix, str, getChatType(false))
end

function NotedLootCouncil:GetSelection(msg, player)
    local sep = "="
    local t={}
    for str in string.gmatch(msg, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    self:Debug(t[1])
    self:Debug(t[2])
    self:Debug(t[3])
    self:Debug(player)
    self.sessionInfo[t[2]]["selections"][player] = {selection=tonumber(t[1]), name=player, equiped=t[3], votes=0, voteSet={}, class=t[4]}
end

function NotedLootCouncil:SendVote(itemLink, player)
    local str = itemLink .. "=" .. player
    NotedLootCouncil:Debug("Vote: " .. str)
    C_ChatInfo.SendAddonMessage(nlc_local_voteprefix, str, getChatType(false))
end

function NotedLootCouncil:GetVote(msg, sender)
    local sep = "="
    local t={}
    for str in string.gmatch(msg, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    self.sessionInfo[t[1]]["selections"][t[2]]["voteSet"][sender] = true
    
    local votes = 0
    for i, k in pairs(self.sessionInfo[t[1]]["selections"][t[2]]["voteSet"]) do
        votes = votes + 1
    end
    self.sessionInfo[t[1]]["selections"][t[2]]["votes"] = votes
end

-------------------------------------------------------------------------
-- Event: Add Loot to Bag
-------------------------------------------------------------------------
-- function NotedLootCouncil:BAG_UPDATE(event)
--     if NotedLootCouncil:isLinkLoot() then
--         NotedLootCouncil:Print("Bag Updated")
--     end
-- end

-------------------------------------------------------------------------
-- Event: Open Loot Window and link loot
-------------------------------------------------------------------------

function NotedLootCouncil:LOOT_READY(event)
    wipe(self.lootSlotInfo)
    self.lootReady = true
    local lootMethod = GetLootMethod()

    local linkAnyway = true

    local count = GetNumLootItems()

    if count == 0 then
        self:Debug("No items to loot")
    end

	local cache = {}
	local numLink = 0
	local chat_type, playerName = getChatType()
	for i=1,count do
		local sourceGUID = GetLootSourceInfo(i)
		if sourceGUID then
			local mobID = GUIDtoID(sourceGUID)
			if linkAnyway then
				local itemLink =  GetLootSlotLink(i)
				local _, itemName, itemQuantity, _, quality = GetLootSlotInfo(i)
				if itemLink and (quality and quality >= 0) then
					local itemID = itemLink:match("item:(%d+)")
					if not itemID or not bannedItems[itemID] then
						numLink = numLink + 1
                        if self:isLinkLoot() then
                            local _, _, _, iLevel = GetItemInfo(itemLink)
                            self:Debug(numLink..": "..itemLink..(iLevel and (" ("..iLevel..")") or "") .. (itemQuantity > 1 and " x"..itemQuantity.."" or ""))
                            SendChatMessage(numLink..": "..itemLink..(iLevel and (" ("..iLevel..")") or ""),chat_type,nil,playerName)
                        end
                        self.lootSlotInfo[i] = {
                            name = itemName,
                            link = itemLink,
                            quality = quality,
                            quantity = itemQuantity,
                            looted = false,
                        }
					end
				end
			end
 			cache[sourceGUID] = true
 		end
	end
end

function NotedLootCouncil:LOOT_SLOT_CLEARED(event, slot)
    if self.lootSlotInfo[slot] and not self.lootSlotInfo[slot].looted then
        local itemLink = self.lootSlotInfo[slot].link
        local itemQuantity = self.lootSlotInfo[slot].quality

        self:Debug(itemLink.. (itemQuantity > 1 and " x"..itemQuantity.."" or "") .. " has been looted")

        table.insert(self.lootCache, itemLink)

        self.lootSlotInfo[slot].looted = true
    end
end

function NotedLootCouncil:LOOT_CLOSED()
    if not self.lootReady then return end
    local numDrops = 0
    local numLooted = 0
    for n, item in pairs(self.lootSlotInfo) do
        numDrops = numDrops + 1
        if not item.looted then
            self:Debug(item.link..(item.quantity > 1 and " x"..item.quantity.."" or "").. " left on mob!")
        else
            numLooted = numLooted + 1
        end
    end

    if numLooted == numDrops then
        if self.lootReady then
            self.lootReady = false
            if numLooted > 0 then
                self:Debug("All "..numLooted.." items looted.")
            end
            wipe(self.lootSlotInfo)
        end
    else
        self:Debug(numDrops-numLooted .. " items left on mob.")
    end
end

-------------------------------------------------------------------------
-- COUNCIL FRAME
-------------------------------------------------------------------------

function NotedLootCouncil:OpenCouncilFrame()
    local itemTabs = {}
    for k,itemInfo in pairs(self.sessionInfo) do
        local itemLink = itemInfo["link"]
        local item = _G.Item:CreateFromItemLink(itemLink)

        local name = ""
        item:ContinueOnItemLoad(function()
            name = item:GetItemName()
        end)

        table.insert(itemTabs, {text=name, value=k})
    end

    -- function that draws the widgets for each tab
    local function DrawItemGroup(container, itemInfo)
        local itemTable = self.sessionInfo[itemInfo]

        local itemContainer = AceGUI:Create("SimpleGroup")
        itemContainer:SetLayout("Flow")
        itemContainer:SetRelativeWidth(1.0)

        local item = _G.Item:CreateFromItemLink(itemTable["link"])

        local icon = ""
        item:ContinueOnItemLoad(function()
            icon = item:GetItemIcon()
        end)

        local itemWidget = AceGUI:Create("Icon")

        itemWidget:SetImage(icon)
        itemWidget:SetImageSize(32,32)
        itemWidget:SetFullWidth(true)
        itemWidget:SetHeight(48)
        itemWidget:SetLabel(item:GetItemLink())
        itemContainer:AddChild(itemWidget)
        itemWidget:SetCallback("OnEnter", function()
            GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
            GameTooltip:SetHyperlink(itemTable["link"])
            GameTooltip:Show()
        end)

        itemWidget:SetCallback("OnLeave", function ()
            GameTooltip:Hide()
        end)

        container:AddChild(itemContainer)

        local scrollcontainer = AceGUI:Create("SimpleGroup")
        scrollcontainer:SetFullWidth(true)
        scrollcontainer:SetFullHeight(true) -- probably?
        scrollcontainer:SetLayout("Fill") -- important!
        container:AddChild(scrollcontainer)

        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetLayout("Flow")
        scrollcontainer:AddChild(scroll)

        local selectionWidgets = {
            [1] = {},
            [2] = {},
            [3] = {},
            [4] = {},
            [5] = {},
            [6] = {},
            [7] = {},
            [8] = {},
            [9] = {},
            [10] = {},
            [11] = {},
            [12] = {},
            [13] = {},
            [14] = {},
            [15] = {}
        }
        for k,opts in pairs(itemTable["selections"]) do
            local selectContainer = AceGUI:Create("SimpleGroup")
            selectContainer:SetLayout("Flow")
            selectContainer:SetFullWidth(true)

            local playerName = AceGUI:Create("Label")
            local t = {}
            for str in string.gmatch(opts["name"], "([^".."-".."]+)") do
                table.insert(t, str)
            end
            local tempName = t[1]

            local playerClass = opts["class"]
            local _, _, _, color = _G.GetClassColor(playerClass)
            playerName:SetText("|c".. color .. tempName .."|r")
            playerName:SetWidth(100)

            local playerSelect = AceGUI:Create("Label")
            local selectionLabel = ""
            local selectIdx = opts["selection"]

            for i, s in pairs(self.lootSelectOptions) do
                if i == selectIdx then
                    selectionLabel = s
                end
            end
            playerSelect:SetText(selectionLabel)
            playerSelect:SetWidth(100)

            local item = _G.Item:CreateFromItemLink(opts["equiped"])

            local icon = ""
            item:ContinueOnItemLoad(function()
                icon = item:GetItemIcon()
            end)

            local itemWidget = AceGUI:Create("Icon")

            itemWidget:SetImage(icon)
            itemWidget:SetImageSize(16,16)
            itemWidget:SetWidth(32)
            itemWidget:SetHeight(24)

            itemWidget:SetCallback("OnEnter", function()
                GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
                GameTooltip:SetHyperlink(opts["equiped"])
                GameTooltip:Show()
            end)

            itemWidget:SetCallback("OnLeave", function ()
                GameTooltip:Hide()
            end)

            local playerVotes = AceGUI:Create("Label")
            playerVotes:SetText(opts["votes"])
            playerVotes:SetWidth(100)

            local voteButton = AceGUI:Create("Button")
            voteButton:SetText("Vote")

            voteButton:SetHeight(32)
            voteButton:SetWidth(100)

            local lnk = itemTable["link"]
            local nme = opts["name"]

            voteButton:SetCallback("OnClick", function()
                NotedLootCouncil:SendVote(lnk, nme)
            end)

            local awardButton = AceGUI:Create("Button")
            awardButton:SetText("Award")

            awardButton:SetHeight(32)
            awardButton:SetWidth(100)

            awardButton:SetCallback("OnClick", function()
                print("award")
            end)

            selectContainer:AddChild(playerName)
            selectContainer:AddChild(playerSelect)
            selectContainer:AddChild(itemWidget)
            selectContainer:AddChild(playerVotes)
            selectContainer:AddChild(voteButton)
            selectContainer:AddChild(awardButton)
            table.insert(selectionWidgets[selectIdx], selectContainer)
        end

        for i, t in pairs(selectionWidgets) do
            for j, cont in pairs(t) do 
                scroll:AddChild(cont)
            end
        end
    end

    local currentGroup = ""
    -- Callback function for OnGroupSelected
    local function SelectGroup(container, event, group)
        container:ReleaseChildren()
        currentGroup = group
        DrawItemGroup(container, currentGroup)
    end

    -- Create the frame container
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Noted Loot Council")
    frame:SetStatusText("Loot Council: OK")

    -- Fill Layout - the TabGroup widget will fill the whole frame
    frame:SetLayout("Fill")

    -- Create the TabGroup
    local tab =  AceGUI:Create("TabGroup")
    tab:SetLayout("Flow")
    -- Setup which tabs to show
    -- tab:SetTabs({{text="Tab 1", value="tab1"}, {text="Tab 2", value="tab2"}})
    tab:SetTabs(itemTabs)
    -- Register callback
    tab:SetCallback("OnGroupSelected", SelectGroup)
    -- Set initial Tab (this will fire the OnGroupSelected callback)
    -- tab:SelectTab("tab1")
    tab:SelectTab(itemTabs[1]["value"])

    -- add to the frame container
    frame:AddChild(tab)
    local mytimer = _G.C_Timer.NewTicker(2.0, function()
        tab:ReleaseChildren()
        DrawItemGroup(tab, currentGroup)
    end)

    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget); mytimer:Cancel() end)
end

-------------------------------------------------------------------------
-- LOOT FRAME
-------------------------------------------------------------------------

function NotedLootCouncil:OpenLootFrame()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Noted Loot Council")
    frame:SetStatusText("Loot Frame: OK")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetLayout("Fill")

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow") -- probably?
    scroll:SetFullHeight(true)-- probably?
    scroll:SetAutoAdjustHeight(true)
    frame:AddChild(scroll)
    for k,itemInfo in pairs(self.sessionInfo) do
        local itemLink = itemInfo["link"]
        local itemContainer = AceGUI:Create("SimpleGroup")
        itemContainer:SetLayout("Flow")
        itemContainer:SetRelativeWidth(1.0)

        NotedLootCouncil:Debug(_G.GetItemCount(itemLink))

        local item = _G.Item:CreateFromItemLink(itemLink)

        local slot = ""

        item:ContinueOnItemLoad(function()
            slot = item:GetInventoryTypeName()
        end)

        local itemWidget = AceGUI:Create("Icon")

        itemWidget:SetImage(item:GetItemIcon())
        itemWidget:SetImageSize(32,32)
        itemWidget:SetRelativeWidth(0.19)
        itemWidget:SetHeight(48)
        itemWidget:SetLabel(item:GetItemLink())
        itemContainer:AddChild(itemWidget)
        itemWidget:SetCallback("OnEnter", function()
            self:Debug("Show Tooltip")
            GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()
        end)

        itemWidget:SetCallback("OnLeave", function ()
            self:Debug("Hide Tooltip")
            GameTooltip:Hide()
        end)

        local optWidgets = {}
        for i, opt in pairs(self.lootSelectOptions) do
            local optButton = AceGUI:Create("Button")
            optButton:SetText(opt)

            optButton:SetHeight(32)
            optButton:SetRelativeWidth(0.8 / #self.lootSelectOptions)

            optButton:SetCallback("OnClick", function()
                for i, w in pairs(optWidgets) do
                    w["wid"]:SetText(w["text"])
                end
                optButton:SetText("|cffff00ff".. opt .."|r")
                local equipSlot = invTypeToSlot[slot]
                local equipedItem = GetInventoryItemLink("player", equipSlot)
                NotedLootCouncil:Debug(i)
                NotedLootCouncil:Debug(itemLink)
                NotedLootCouncil:SendSelection(i, itemLink, equipedItem)
            end)

            table.insert(optWidgets, {wid = optButton, text = opt})
        end

        for i, w in pairs(optWidgets) do
            itemContainer:AddChild(w["wid"])
        end
        scroll:AddChild(itemContainer)
    end
end

-------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------

function NotedLootCouncil:HandleSlashCommands(input)
    if not input or input:trim() == "" then
        NotedLootCouncil:OpenLootFrame()
    elseif input:trim() == "options" then
        InterfaceOptionsFrame_OpenToCategory("NotedLootCouncil")
    elseif input:trim() == "test" then
        self:GenTest()
        -- NotedLootCouncil:getBossItems("Morogrim Tidewalker")
    elseif input:trim() == "synctest" then
        NotedLootCouncil:Print("Syncing...")
        self:SendAddonMsg("hello world")
    elseif input:trim() == "sync" then
        self:SyncItems()
    elseif input:trim() == "cache" then
        NotedLootCouncil:Print("Cache:")
        for k,v in pairs(self.lootCache) do
            NotedLootCouncil:Print(v)
        end
    elseif input:trim() == "reset" then
        self.lootCache = {}
        NotedLootCouncil:Print("Loot Reset")
    elseif input:trim() == "vote" then
        NotedLootCouncil:OpenLootFrame()
    else
        local _, _, cmd, args = string.find(input, "%s?(%w+)%s?(.*)")
        if cmd == "add" and args ~= "" then
            self:Debug("adding " .. args)
            table.insert(self.lootCache, args)
        elseif cmd == "session" and args == "end" then
            self:StartSession()
        elseif cmd == "session" then
            self:StartSession()
        else
            LibStub("AceConfigCmd-3.0"):HandleCommand("nlc", "NotedLootCouncil", input)
        end
    end
end

function NotedLootCouncil:GetSelectOptions(info)
    return self.db.char.selectOptions
end

function NotedLootCouncil:SetSelectOptions(info, newValue)
    self.db.char.selectOptions = newValue
    NotedLootCouncil:parseLootSelectOptions()
end

function NotedLootCouncil:isLinkLoot(info)
    return self.db.char.linkLoot
end

function NotedLootCouncil:toggleLinkLoot(info, newValue)
    self.db.char.linkLoot = newValue
end

function NotedLootCouncil:isDebug(info)
    return self.db.char.debugMode
end

function NotedLootCouncil:toggleDebug(info, newValue)
    self.db.char.debugMode = newValue
end

function NotedLootCouncil:buildSessionInfo()
    self:Debug("Building Session Info")
    for k,itemLink in pairs(self.lootCache) do
        local item = _G.Item:CreateFromItemLink(itemLink)

        NotedLootCouncil:Debug(itemLink)

        local name = ""

        item:ContinueOnItemLoad(function()
            name = item:GetItemName()
        end)

        self.sessionInfo[itemLink] = {
            name = name,
            link = itemLink,
            count = _G.GetItemCount(itemLink),
            selections = {}
        }
    end
end

function NotedLootCouncil:StartSession()
    self:buildSessionInfo()
    self:OpenCouncilFrame()
end
