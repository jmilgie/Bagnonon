--[[
	Ludwig_SellValue -
		Originally based on SellValueLite, this addon allows viewing of sellvalues
--]]

local currentPlayer = UnitName("player")

--[[ Local Functions ]]--

local function LinkToID(link)
	if link then
		local _, _, id = string.find(link, "(%d+):")
		return tonumber(id)
	end
end

local function AddOwners(frame, id)
	if not(frame and id and BagnonSets.showForeverTooltips) then return end
--Items on current character
			local invCount = BagnonDB.GetItemTotal(id, currentPlayer, -2)
			local totalCount = 0
			for bagID = 0, 4 do
				invCount = invCount + BagnonDB.GetItemTotal(id, currentPlayer, bagID)
			end

			local bankCount = BagnonDB.GetItemTotal(id, currentPlayer, -1)
			for bagID = 5, 10 do
				bankCount = bankCount + BagnonDB.GetItemTotal(id, currentPlayer, bagID)
			end
			if (invCount + bankCount) > 0 then
				--local tooltipString = BagnonDB.GetClass(currentPlayer) .. currentPlayer .. "|cffFFFFFF:|cffFFD100" .. invCount+bankCount .. " (Bags:" .. invCount .. " Bank:" .. bankCount .. ")"
				local invString=""
				local bankString=""
				local spaceString=""
				if (invCount > 0) then
					invString="|cffFFFFFFBags: |cff00FF96" .. invCount
					totalCount=totalCount+invCount
				end
				if (bankCount >0) then
					bankString="|cffFFFFFFBank: |cff00FF96" .. bankCount
					spaceString=" "
					totalCount=totalCount+bankCount
				end
				frame:AddDoubleLine(BagnonDB.GetClass(currentPlayer) .. currentPlayer,"|cffFF7D0A" .. invCount+bankCount .. " |cffFFFFFF(" .. invString .. spaceString .. bankString .. "|cffFFFFFF)", 1,0,0, 0,0,1);
				--frame:AddDoubleLine("Total",tostring(totalCount));
			end
--Items on account characters
	for player in BagnonDB.GetPlayers() do
		if player ~= currentPlayer then
			local invCount = BagnonDB.GetItemTotal(id, player, -2)
			for bagID = 0, 4 do
				invCount = invCount + BagnonDB.GetItemTotal(id, player, bagID)
			end

			local bankCount = BagnonDB.GetItemTotal(id, player, -1)
			for bagID = 5, 10 do
				bankCount = bankCount + BagnonDB.GetItemTotal(id, player, bagID)
			end

			if (invCount + bankCount) > 0 then
				--local tooltipString = BagnonDB.GetClass(player) .. player .. "|cffFFFFFF:|cffFFD100" .. invCount+bankCount .. " (Bags:" .. invCount .. " Bank:" .. bankCount .. ")"
				--frame:AddLine(tooltipString, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
				local invString=""
				local bankString=""
				local spaceString=""
				if (invCount > 0) then
					invString="|cffFFFFFFBags: |cff00FF96" .. invCount
					totalCount=totalCount+invCount
				end
				if (bankCount >0) then
					bankString="|cffFFFFFFBank: |cff00FF96" .. bankCount
					spaceString=" "
					totalCount=totalCount+bankCount
				end
				frame:AddDoubleLine(BagnonDB.GetClass(player) .. player,"|cffFF7D0A" .. invCount+bankCount .. " |cffFFFFFF(" .. invString .. spaceString .. bankString .. "|cffFFFFFF)", 1,0,0, 0,0,1)
				
			end
		end
	end
	frame:AddDoubleLine("Total",tostring(totalCount));
	frame:Show()
end

--[[  Function Hooks ]]--

local Blizz_GameTooltip_SetBagItem = GameTooltip.SetBagItem
GameTooltip.SetBagItem = function(self, bag, slot)
	Blizz_GameTooltip_SetBagItem(self, bag, slot)

	AddOwners(self, LinkToID(GetContainerItemLink(bag, slot)))
end

local Bliz_GameTooltip_SetLootItem = GameTooltip.SetLootItem
GameTooltip.SetLootItem = function(self, slot)
	Bliz_GameTooltip_SetLootItem(self, slot)

	AddOwners(self, LinkToID(GetLootSlotLink(slot)))
end

local Bliz_SetHyperlink = GameTooltip.SetHyperlink
GameTooltip.SetHyperlink = function(self, link, count)
	Bliz_SetHyperlink(self, link, count)

	AddOwners(self, LinkToID(link))
end

local Bliz_ItemRefTooltip_SetHyperlink = ItemRefTooltip.SetHyperlink
ItemRefTooltip.SetHyperlink = function(self, link, count)
	Bliz_ItemRefTooltip_SetHyperlink(self, link, count)

	AddOwners(self, LinkToID(link))
end

local Bliz_GameTooltip_SetLootRollItem = GameTooltip.SetLootRollItem
GameTooltip.SetLootRollItem = function(self, rollID)
	Bliz_GameTooltip_SetLootRollItem(self, rollID)

	AddOwners(self, LinkToID(GetLootRollItemLink(rollID)))
end

local Bliz_GameTooltip_SetAuctionItem = GameTooltip.SetAuctionItem
GameTooltip.SetAuctionItem = function(self, type, index)
	Bliz_GameTooltip_SetAuctionItem(self, type, index)

	AddOwners(self, LinkToID(GetAuctionItemLink(type, index)))
end

--[[ Money Frame Tooltip ]]--

--Alters the tooltip of bagnon moneyframes to show total gold across all characters on the current realm
function BagnonFrameMoney_OnEnter()
	if this:GetLeft() > (UIParent:GetRight() / 2) then
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	end
	GameTooltip:SetText(string.format(BAGNON_FOREVER_MONEY_ON_REALM, GetRealmName()))
	local money = 0
	for player in BagnonDB.GetPlayers() do
		money = money + BagnonDB.GetMoney(player)
	end

	SetTooltipMoney(GameTooltip, money)
	GameTooltip:Show()
end