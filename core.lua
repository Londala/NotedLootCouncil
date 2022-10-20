-------------------------------------------------------------------------
--
-- Copyright (c) 2022 by Alex Londal.
-- Vinheim of Benediction (NA East) - WoW Classic Alliance
--
-- Noted Loot List may be distributed to anyone WITHOUT ANY WARRANTY
-- Please make backups of your loot lists. The author is not
-- responsible for any lost data or information
--
-------------------------------------------------------------------------



-------------------------------------------------------------------------
-- Addon Variables
-------------------------------------------------------------------------



-- Globals
NotedLootList = LibStub("AceAddon-3.0"):NewAddon("NotedLootList", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")

nll_constants = {}; -- Saved Loot Lists, Tooltips
local AceGUI = LibStub("AceGUI-3.0")

local _G = getfenv(0)

-- Addon Information
local nll_local_version = "0.0.1"



local nll_local_ldb = LibStub("LibDataBroker-1.1")
local nll_broker = nil
local nll_local_minimapicon = LibStub("LibDBIcon-1.0")
local nll_local_brokervalue = nil
local nll_local_brokerlabel = nil

-- Addon Communication
local nll_local_prefix = "NLL_Channel"
local nll_local_versionprefix = "NLL_Version"
local nll_local_syncprefix = "NLL_Sync"
local nll_local_selectprefix = "NLL_Select"


-- Toon Info
local nll_local_realmKey = GetRealmName()
local nll_local_toonKey = UnitName("player") .. "-" .. nll_local_realmKey
local nll_local_toonInGuild = IsInGuild()
local nll_local_guildName, nll_local_guildRank, nll_local_guildRankIndex = (function() if nll_local_toonInGuild then return GetGuildInfo("player") else return nil, nil, nil end end)

-- Banned Loot
local bannedItems = {}

-- Defaults
local defaults = {
    profile = {
        testMsg = "This is the default test message",
        linkLoot = true,
        debugMode = false,
    },
}


-------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------

local nll_options = {
    name = "NotedLootList",
    handler = NotedLootList,
    desc = "Options for Noted Loot List",
    type = "group",
    args = {
        test_message = {
            name = "Test Message",
            desc = "The message output in testing",
            type = "input",
            get = "GetTestMessage",
            set = "SetTestMessage",
            
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

function NotedLootList:OnInitialize()
    -- DB
    self.db = LibStub("AceDB-3.0"):New("NLL_DB", defaults, true)

    LibStub("AceConfig-3.0"):RegisterOptionsTable("NotedLootList", nll_options, nil)
    
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("NotedLootList"):SetParent(InterfaceOptionsFramePanelContainer)

    -- Local Unsaved vars
    self.lootSlotInfo = {}
    self.lootReady = false

    self:RegisterChatCommand("nll", "HandleSlashCommands")

    self.lootCache = {}
    self.lootSelectOptions = {}
end

-------------------------------------------------------------------------
-- Event: Addon Enable
-------------------------------------------------------------------------

function NotedLootList:OnEnable()

    C_ChatInfo.RegisterAddonMessagePrefix(nll_local_prefix)
	C_ChatInfo.RegisterAddonMessagePrefix(nll_local_versionprefix)
    C_ChatInfo.RegisterAddonMessagePrefix(nll_local_selectprefix)
    C_ChatInfo.RegisterAddonMessagePrefix(nll_local_syncprefix)


    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("LOOT_READY")
    self:RegisterEvent("LOOT_SLOT_CLEARED")
    self:RegisterEvent("LOOT_CLOSED")
    -- self:RegisterEvent("BAG_UPDATE")

    self:Print("|cffff00ff[Noted Loot List]|r Enabled")
end

-------------------------------------------------------------------------
-- Event: Addon Disable
-------------------------------------------------------------------------

function NotedLootList:OnDisable()
    self:Print("|cffff00ff[Noted Loot List]|r Disabled")
end

-------------------------------------------------------------------------
-- Debug Output Helper
-------------------------------------------------------------------------

function NotedLootList:Debug(str)
    if self:isDebug() then
        self:Print("|cffff6060Debug:|r |cFFD3D3D3"..str.."|r")
    end
end

-------------------------------------------------------------------------
-- Misc Helpers
-------------------------------------------------------------------------

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
function NotedLootList:getBossItems(boss)
    for n, itemID in pairs(nll_constants.sscItemDict[boss]) do
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            local link = item:GetItemLink()
            local level = item:GetCurrentItemLevel()
            NotedLootList:Print("Item "..n..": "..link.." ("..level..")") -- "Red Winter Hat", 133169
        end)
    end
end

-------------------------------------------------------------------------
-- Event: OnCommReceived
-------------------------------------------------------------------------
function NotedLootList:OnCommReceived(prefix, message, distribution, sender)
    self:Debug("Comm Recieved")
    self:Debug(prefix)
    self:Debug(message)
    self:Debug(distribution)
    self:Debug(sender)
end

function NotedLootList:GetSelection(msg)
    local sep = "="
    local t={}
    for str in string.gmatch(msg, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    self:Debug(t[1])
    self:Debug(t[2])
end

function NotedLootList:CHAT_MSG_ADDON(event, arg1, arg2, arg3, arg4)
    if arg1 == nll_local_prefix then
        self:Print("Chat recieved in correct channel")
        self:Print(arg2)
    elseif arg1 == nll_local_syncprefix then
        self:Print(arg2)
    elseif arg1 == nll_local_selectprefix then
        self:Print(arg2)
        self:GetSelection(arg2)
    elseif arg1 == nll_local_versionprefix then
        self:Print("v0.0.1")
    end
end

function NotedLootList:SendAddonMsg(str)
    C_ChatInfo.SendAddonMessage(nll_local_prefix, str, "WHISPER", UnitName("player"))
end

function NotedLootList:SyncItems()
    for k,item in pairs(self.lootCache) do
        C_ChatInfo.SendAddonMessage(nll_local_syncprefix, item, "WHISPER", UnitName("player"))
    end
end

function NotedLootList:SendSelection(idx, item)
    local str = item .. "=" .. idx
    NotedLootList:Debug(str)
    C_ChatInfo.SendAddonMessage(nll_local_selectprefix, str, "WHISPER", UnitName("player"))
end

-------------------------------------------------------------------------
-- Event: Add Loot to Bag
-------------------------------------------------------------------------
-- function NotedLootList:BAG_UPDATE(event)
--     if NotedLootList:isLinkLoot() then
--         NotedLootList:Print("Bag Updated")
--     end
-- end

-------------------------------------------------------------------------
-- Event: Open Loot Window and link loot
-------------------------------------------------------------------------

function NotedLootList:LOOT_READY(event)
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

function NotedLootList:LOOT_SLOT_CLEARED(event, slot)
    if self.lootSlotInfo[slot] and not self.lootSlotInfo[slot].looted then
        local itemLink = self.lootSlotInfo[slot].link
        local itemQuantity = self.lootSlotInfo[slot].quality

        self:Debug(itemLink.. (itemQuantity > 1 and " x"..itemQuantity.."" or "") .. " has been looted")

        table.insert(self.lootCache, itemLink)

        self.lootSlotInfo[slot].looted = true
    end
end

function NotedLootList:LOOT_CLOSED()
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
-- Frame
-------------------------------------------------------------------------
function NotedLootList:OpenLootFrame()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Noted Loot List")
    frame:SetStatusText("Frame Status: OK")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetLayout("Fill")

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow") -- probably?
    scroll:SetFullHeight(true)-- probably?
    scroll:SetAutoAdjustHeight(true)
    frame:AddChild(scroll)

    local widgets = {}
    for k,itemLink in pairs(self.lootCache) do
        local itemContainer = AceGUI:Create("SimpleGroup")
        itemContainer:SetLayout("Flow")
        itemContainer:SetRelativeWidth(1.0)
        scroll:AddChild(itemContainer)
        NotedLootList:Debug(_G.GetItemCount(itemLink))

        local item = _G.Item:CreateFromItemLink(itemLink)

        local name = ""
        local icon = ""
        local color = ""

        item:ContinueOnItemLoad(function()
            name = item:GetItemName()
            icon = item:GetItemIcon()
            color = item:GetItemQualityColor()
            print(name, icon, color) -- "Red Winter Hat", 133169
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

        for i, opt in pairs(self.lootSelectOptions) do
            local optButton = AceGUI:Create("Button")
            optButton:SetText(opt)

            optButton:SetHeight(32)
            optButton:SetRelativeWidth(0.8 / #self.lootSelectOptions)

            optButton:SetCallback("OnClick", function()
                NotedLootList:Debug(i)
                NotedLootList:Debug(itemLink)
                NotedLootList:SendSelection(i, itemLink)
            end)

            itemContainer:AddChild(optButton)
        end

        table.insert(widgets, k, itemWidget)

    end
end

-------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------

function NotedLootList:HandleSlashCommands(input)
    if not input or input:trim() == "" then
        NotedLootList:Debug("TODO: Open Interface")
        NotedLootList:OpenLootFrame()
    elseif input:trim() == "options" then
        InterfaceOptionsFrame_OpenToCategory("NotedLootList")
    elseif input:trim() == "test" then
        NotedLootList:Print(NotedLootList:GetTestMessage())
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
        NotedLootList:OpenLootFrame()
        -- NotedLootList:getBossItems("Morogrim Tidewalker")
    elseif input:trim() == "synctest" then
        NotedLootList:Print("syncing")
        self:SendAddonMsg("hello world")
    elseif input:trim() == "sync" then
        self:SyncItems()
    elseif input:trim() == "cache" then
        NotedLootList:Print("cache")
        for k,v in pairs(self.lootCache) do
            NotedLootList:Print(v)
        end
    elseif input:trim() == "reset" then
        self.lootCache = {}
        NotedLootList:Print("Loot Reset")
    elseif input:trim() == "vote" then
        NotedLootList:Debug("TODO: Vote Interface")
        NotedLootList:OpenLootFrame()
    else
        local _, _, cmd, args = string.find(input, "%s?(%w+)%s?(.*)")
        if cmd == "add" and args ~= "" then
            self:Debug("adding " .. args)
            table.insert(self.lootCache, args)
        else
            LibStub("AceConfigCmd-3.0"):HandleCommand("nll", "NotedLootList", input)
        end
    end
end

function NotedLootList:GetTestMessage(info)
    return self.db.char.message
end

function NotedLootList:SetTestMessage(info, newValue)
    self.db.char.message = newValue
end

function NotedLootList:isLinkLoot(info)
    return self.db.char.linkLoot
end

function NotedLootList:toggleLinkLoot(info, newValue)
    self.db.char.linkLoot = newValue
end

function NotedLootList:isDebug(info)
    return self.db.char.debugMode
end

function NotedLootList:toggleDebug(info, newValue)
    self.db.char.debugMode = newValue
end
