--[[
	Banknon
		Combines the player's bank into a single frame
--]]

local BANKNON_GROUPING_HELP = {
	"/banknon groups - list groupings",
	"/banknon add <name> <slots> - add grouping",
	"/banknon set <index> <slots> - resize grouping",
	"/banknon rename <index> <name> - rename grouping",
	"/banknon del <index> - delete grouping",
	"/banknon clear - remove all groupings",
	"/banknon editor - toggle grouping editor",
};

local BANKNON_GROUP_GAP_ROWS = 1;
local BANKNON_EDITOR_MAX_ROWS = 8;
local BANKNON_LAYOUT_TOP = 46;
local BANKNON_FRAME_BASE_HEIGHT = 79;

--[[ Loading Functions ]]--

function Banknon_OnLoad()
	--Create the confirmation dialog when purchasing a bank slot
	StaticPopupDialogs["CONFIRM_BUY_BANK_SLOT_BANKNON"] = {
		text = TEXT(CONFIRM_BUY_BANK_SLOT),
		button1 = TEXT(YES),
		button2 = TEXT(NO),

		OnAccept = function()
			PurchaseSlot();
		end,

		OnShow = function()
			MoneyFrame_Update(this:GetName().."MoneyFrame", GetBankSlotCost(GetNumBankSlots()) );
		end,

		hasMoneyFrame = 1,
		timeout = 0,
		hideOnEscape = 1,
	};

	this:RegisterEvent("ADDON_LOADED");
end

--[[ Event Handler ]]--

function Banknon_OnEvent(event)
	if ( event == "PLAYER_MONEY" or event == "PLAYERBANKBAGSLOTS_CHANGED") then
		if(Banknon:IsShown() ) then
			Banknon_UpdateSlotCost();
		end
	elseif( event == "BAG_UPDATE" or event == "PLAYERBANKSLOTS_CHANGED") then
		if(Banknon:IsShown() ) then
			Banknon_ApplyGroupingLayout();
		end
	elseif ( event == "BANKFRAME_OPENED") then
		Banknon_UpdatePurchaseButtonVis();
	elseif ( event == "BANKFRAME_CLOSED") then
		Banknon_UpdatePurchaseButtonVis();
	elseif ( event == "ADDON_LOADED" and arg1 == "Banknon") then
		Banknon:UnregisterEvent("ADDON_LOADED");
		Banknon_Load();
	end
end

function Banknon_Load()
	BagnonFrame_Load(Banknon, {-1, 5, 6, 7, 8, 9, 10}, BAGNON_BANK_TITLE);

	if(CT_BankFrame_AcceptFrame) then
		CT_BankFrame_AcceptFrame:SetParent(Banknon);
	end

	Banknon:RegisterEvent("PLAYER_MONEY");
	Banknon:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED");
	Banknon:RegisterEvent("PLAYERBANKSLOTS_CHANGED");
	Banknon:RegisterEvent("BAG_UPDATE");
	Banknon:RegisterEvent("BANKFRAME_OPENED");
	Banknon:RegisterEvent("BANKFRAME_CLOSED");

	Banknon_RegisterSlashCommands();
	Banknon_CreateGroupingEditor();
	Banknon_UpdateSlotCost();
	Banknon_ApplyGroupingLayout();
end

--[[ UI Functions ]]--

--OnShow
function Banknon_OnShow()
	Banknon_UpdatePurchaseButtonVis();
	Banknon_ApplyGroupingLayout();
	PlaySound("igMainMenuOpen");
end

--OnHide
function Banknon_OnHide()
	if(Banknon.groupEditor and Banknon.groupEditor:IsShown() ) then
		Banknon.groupEditor:Hide();
	end
	PlaySound("igMainMenuClose");
	CloseBankFrame();
end

--[[ Grouping Functions ]]--

local function Banknon_GetGroups()
	if(not BagnonSets["Banknon"]) then
		BagnonSets["Banknon"] = {};
	end

	if(not BagnonSets["Banknon"].groups) then
		BagnonSets["Banknon"].groups = {};
	end

	return BagnonSets["Banknon"].groups;
end

local function Banknon_SanitizeGroups()
	local groups = Banknon_GetGroups();
	local changed;

	for i = table.getn(groups), 1, -1 do
		local group = groups[i];
		if(not group or not tonumber(group.size) or tonumber(group.size) <= 0) then
			table.remove(groups, i);
			changed = 1;
		else
			group.size = math.floor(tonumber(group.size));
			if(not group.name or group.name == "") then
				group.name = "Group " .. i;
				changed = 1;
			end
		end
	end

	return changed;
end

local function Banknon_GetUsedCount(groupStart, groupStop)
	local used = 0;
	for slot = groupStart, groupStop do
		local item = getglobal("BanknonItem" .. slot);
		if(item and item:IsShown()) then
			local bagID = item:GetParent():GetID();
			if(GetContainerItemLink(bagID, item:GetID())) then
				used = used + 1;
			end
		end
	end
	return used;
end

local function Banknon_GetDisplayRows(groups, totalSlots, cols)
	if(totalSlots <= 0) then
		return 0;
	end

	local remaining = totalSlots;
	local rows = 0;

	for i = 1, table.getn(groups) do
		if(remaining <= 0) then
			break;
		end

		local size = tonumber(groups[i].size) or remaining;
		if(size < 0) then size = 0; end
		if(size > remaining) then size = remaining; end

		if(size > 0) then
			rows = rows + math.ceil(size / cols);
			remaining = remaining - size;
		end

		if(remaining > 0) then
			rows = rows + BANKNON_GROUP_GAP_ROWS;
		end
	end

	if(remaining > 0) then
		rows = rows + math.ceil(remaining / cols);
	end

	return rows;
end

local function Banknon_UpdateFrameSizeForGrouping(frame, rows)
	if(not rows or rows <= 0) then
		BagnonFrame_TrimToSize(frame);
		return;
	end

	local size = frame.size;
	local cols = frame.cols or 8;
	local space = frame.space or 2;

	if(size < cols) then
		frame:SetWidth((37 + space) * size + 16 - space);
	else
		frame:SetWidth((37 + space) * cols + 16 - space);
	end

	local height = (37 + space) * rows + BANKNON_FRAME_BASE_HEIGHT - space;
	local bagFrame = getglobal(frame:GetName() .. "Bags");

	if(bagFrame and bagFrame:IsShown() ) then
		frame:SetHeight(height + bagFrame:GetHeight());
		if(frame:GetWidth() < bagFrame:GetWidth()) then
			frame:SetWidth(bagFrame:GetWidth() + 8);
		end
	else
		frame:SetHeight(height);
	end

	BagnonFrame_SavePosition(frame);
end

local function Banknon_UpdateSummaryText(usedTotal, totalSlots, groupsShown)
	if(not Banknon.summaryText) then
		Banknon.summaryText = Banknon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		Banknon.summaryText:SetPoint("BOTTOMLEFT", Banknon, "BOTTOMLEFT", 178, 9);
		Banknon.summaryText:SetTextColor(0.9, 0.9, 0.9);
	end

	local free = totalSlots - usedTotal;
	Banknon.summaryText:SetText("Groups: " .. groupsShown .. "  Free: " .. free);
end

local function Banknon_UpdateEditorList()
	if(not Banknon.groupEditor) then
		return;
	end

	local groups = Banknon_GetGroups();
	for i = 1, BANKNON_EDITOR_MAX_ROWS do
		local row = Banknon.groupEditor.rows[i];
		local group = groups[i];
		if(group) then
			local used = 0;
			if(Banknon.groupSlotRanges and Banknon.groupSlotRanges[i]) then
				used = Banknon_GetUsedCount(Banknon.groupSlotRanges[i].start, Banknon.groupSlotRanges[i].stop);
			end
			row:SetText(i .. ". " .. group.name .. " (" .. used .. "/" .. group.size .. ")");
			row:Show();
		else
			row:Hide();
		end
	end
end

function Banknon_ApplyGroupingLayout()
	if(not Banknon or not Banknon.size or Banknon.size == 0) then
		return;
	end

	Banknon_SanitizeGroups();

	local groups = Banknon_GetGroups();
	local totalSlots = Banknon.size;
	local cols = Banknon.cols or 8;
	local space = Banknon.space or 2;
	local slot = 1;
	local row = 0;
	local col = 0;
	local usedTotal = 0;
	local groupCount = 0;

	if(not Banknon.totalSlotsText) then
		Banknon.totalSlotsText = Banknon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		Banknon.totalSlotsText:SetPoint("BOTTOMLEFT", Banknon, "BOTTOMLEFT", 92, 9);
		Banknon.totalSlotsText:SetTextColor(1, 0.82, 0);
	end

	if(not Banknon.groupLabels) then
		Banknon.groupLabels = {};
	end

	Banknon.groupSlotRanges = {};

	for i = 1, table.getn(Banknon.groupLabels) do
		Banknon.groupLabels[i]:Hide();
	end

	for i = 1, table.getn(groups) do
		if(slot > totalSlots) then
			break;
		end

		local group = groups[i];
		local size = tonumber(group.size) or 0;
		if(size > 0) then
			local startSlot = slot;
			local endSlot = math.min(totalSlots, slot + size - 1);
			local displaySize = endSlot - startSlot + 1;

			groupCount = groupCount + 1;
			local label = Banknon.groupLabels[groupCount];
			if(not label) then
				label = Banknon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
				label:SetTextColor(1, 1, 1);
				Banknon.groupLabels[groupCount] = label;
			end

			label:ClearAllPoints();
			label:SetPoint("TOPLEFT", Banknon, "TOPLEFT", 8 + col * (37 + space), -BANKNON_LAYOUT_TOP - row * (37 + space) + 12);
			label:Show();

			while(slot <= endSlot) do
				local button = getglobal("BanknonItem" .. slot);
				if(button) then
					button:ClearAllPoints();
					button:SetPoint("TOPLEFT", Banknon, "TOPLEFT", 8 + col * (37 + space), -BANKNON_LAYOUT_TOP - row * (37 + space));
				end

				col = col + 1;
				if(col >= cols) then
					col = 0;
					row = row + 1;
				end
				slot = slot + 1;
			end

			Banknon.groupSlotRanges[i] = {start = startSlot, stop = endSlot};
			local used = Banknon_GetUsedCount(startSlot, endSlot);
			usedTotal = usedTotal + used;
			label:SetText((group.name or ("Group " .. i)) .. " (" .. used .. "/" .. displaySize .. ")");

			if(slot <= totalSlots) then
				if(col ~= 0) then
					col = 0;
					row = row + 1;
				end
				row = row + BANKNON_GROUP_GAP_ROWS;
			end
		end
	end

	if(slot <= totalSlots) then
		local startSlot = slot;
		local endSlot = totalSlots;
		local count = endSlot - startSlot + 1;
		local used = Banknon_GetUsedCount(startSlot, endSlot);
		usedTotal = usedTotal + used;

		groupCount = groupCount + 1;
		local label = Banknon.groupLabels[groupCount];
		if(not label) then
			label = Banknon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
			label:SetTextColor(1, 1, 1);
			Banknon.groupLabels[groupCount] = label;
		end

		label:ClearAllPoints();
		label:SetPoint("TOPLEFT", Banknon, "TOPLEFT", 8 + col * (37 + space), -BANKNON_LAYOUT_TOP - row * (37 + space) + 12);
		label:SetText("Ungrouped (" .. used .. "/" .. count .. ")");
		label:Show();

		while(slot <= totalSlots) do
			local button = getglobal("BanknonItem" .. slot);
			if(button) then
				button:ClearAllPoints();
				button:SetPoint("TOPLEFT", Banknon, "TOPLEFT", 8 + col * (37 + space), -BANKNON_LAYOUT_TOP - row * (37 + space));
			end

			col = col + 1;
			if(col >= cols) then
				col = 0;
				row = row + 1;
			end

			slot = slot + 1;
		end
	end

	Banknon.totalSlotsText:SetText("Total Slots: " .. usedTotal .. "/" .. totalSlots);
	Banknon_UpdateSummaryText(usedTotal, totalSlots, table.getn(groups));
	Banknon_UpdateFrameSizeForGrouping(Banknon, Banknon_GetDisplayRows(groups, totalSlots, cols));
	Banknon_UpdateEditorList();
end

local function Banknon_PrintGroupList()
	local groups = Banknon_GetGroups();
	if(table.getn(groups) == 0) then
		BagnonMsg("Banknon: no groupings configured");
	else
		BagnonMsg("Banknon groupings:");
		for i = 1, table.getn(groups) do
			local group = groups[i];
			BagnonMsg(i .. ". " .. (group.name or ("Group " .. i)) .. " - " .. (group.size or 0) .. " slots");
		end
	end
end

local function Banknon_RefreshAfterGroupingChange()
	if(Banknon) then
		if(Banknon.groupEditor and Banknon.groupEditor:IsShown() ) then
			Banknon_UpdateEditorList();
		end

		if(Banknon:IsShown() ) then
			BagnonFrame_Generate(Banknon);
			Banknon_ApplyGroupingLayout();
		end
	end
end

local function Banknon_ParseNameAndSize(rest)
	if(not rest) then return; end

	local quotedName, quotedSize = string.match(rest, '^"(.+)"%s+(%d+)$');
	if(quotedName and quotedSize) then
		return quotedName, tonumber(quotedSize);
	end

	local name, size = string.match(rest, "^(.+)%s+(%d+)$");
	if(name and size) then
		return name, tonumber(size);
	end
end

local function Banknon_CreateGroup(name, size)
	if(not name or name == "" or not size or size <= 0) then
		return;
	end

	local groups = Banknon_GetGroups();
	table.insert(groups, {name = name, size = math.floor(size)});
	BagnonMsg("Added bank grouping '" .. name .. "' with " .. size .. " slots");
	Banknon_RefreshAfterGroupingChange();
end

function Banknon_HandleSlash(msg)
	local cmd, rest = string.match(msg or "", "^(%S+)%s*(.-)$");
	cmd = string.lower(cmd or "");

	if(cmd == "" or cmd == "help") then
		for i = 1, table.getn(BANKNON_GROUPING_HELP) do
			BagnonMsg(BANKNON_GROUPING_HELP[i]);
		end
		return;
	end

	if(cmd == "groups") then
		Banknon_PrintGroupList();
		return;
	end

	if(cmd == "editor") then
		Banknon_ToggleGroupingEditor();
		return;
	end

	local groups = Banknon_GetGroups();

	if(cmd == "add") then
		local name, size = Banknon_ParseNameAndSize(rest);
		if(name and size) then
			Banknon_CreateGroup(name, size);
		else
			BagnonMsg("Usage: /banknon add <name> <slots>");
		end
	elseif(cmd == "set") then
		local index, size = string.match(rest, "^(%d+)%s+(%d+)$");
		index = tonumber(index);
		size = tonumber(size);
		if(index and size and groups[index] and size > 0) then
			groups[index].size = size;
			BagnonMsg("Updated grouping " .. index .. " to " .. size .. " slots");
			Banknon_RefreshAfterGroupingChange();
		else
			BagnonMsg("Usage: /banknon set <index> <slots>");
		end
	elseif(cmd == "rename") then
		local index, name = string.match(rest, "^(%d+)%s+(.+)$");
		index = tonumber(index);
		if(index and name and groups[index]) then
			groups[index].name = name;
			BagnonMsg("Renamed grouping " .. index .. " to '" .. name .. "'");
			Banknon_RefreshAfterGroupingChange();
		else
			BagnonMsg("Usage: /banknon rename <index> <name>");
		end
	elseif(cmd == "del") then
		local index = tonumber(rest);
		if(index and groups[index]) then
			local name = groups[index].name or ("Group " .. index);
			table.remove(groups, index);
			BagnonMsg("Deleted grouping '" .. name .. "'");
			Banknon_RefreshAfterGroupingChange();
		else
			BagnonMsg("Usage: /banknon del <index>");
		end
	elseif(cmd == "clear") then
		BagnonSets["Banknon"].groups = {};
		BagnonMsg("Cleared all Banknon groupings");
		Banknon_RefreshAfterGroupingChange();
	else
		BagnonMsg("Unknown Banknon command. Type /banknon help");
	end
end

function Banknon_RegisterSlashCommands()
	if(Banknon.slashLoaded) then
		return;
	end

	SlashCmdList["BanknonCOMMAND"] = Banknon_HandleSlash;
	SLASH_BanknonCOMMAND1 = "/banknon";
	SLASH_BanknonCOMMAND2 = "/bnk";
	Banknon.slashLoaded = 1;
end

--[[ Grouping Editor ]]--

local function Banknon_SelectEditorGroup(index)
	if(not Banknon.groupEditor) then return; end

	local groups = Banknon_GetGroups();
	local group = groups[index];
	if(group) then
		Banknon.groupEditor.selectedIndex = index;
		Banknon.groupEditor.nameBox:SetText(group.name);
		Banknon.groupEditor.sizeBox:SetText(group.size);
	end
end

function Banknon_CreateGroupingEditor()
	if(Banknon.groupEditor) then
		return;
	end

	local toggle = CreateFrame("Button", "BanknonGroupsToggle", Banknon, "UIPanelButtonTemplate");
	toggle:SetWidth(54);
	toggle:SetHeight(18);
	toggle:SetText("Groups");
	toggle:SetPoint("BOTTOMLEFT", BanknonShowBags, "TOPLEFT", 0, 2);
	toggle:SetScript("OnClick", function()
		Banknon_ToggleGroupingEditor();
	end);
	Banknon.groupsButton = toggle;

	local editor = CreateFrame("Frame", "BanknonGroupEditor", Banknon);
	editor:SetWidth(250);
	editor:SetHeight(208);
	editor:SetPoint("TOPLEFT", Banknon, "TOPRIGHT", 6, -4);
	editor:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = 1,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	});
	editor:SetBackdropColor(0, 0, 0, 0.95);
	editor:SetFrameStrata("HIGH");
	editor:Hide();

	local title = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	title:SetPoint("TOPLEFT", editor, "TOPLEFT", 10, -8);
	title:SetText("Bank Groupings");

	editor.rows = {};
	for i = 1, BANKNON_EDITOR_MAX_ROWS do
		local index = i;
		local row = CreateFrame("Button", nil, editor);
		row:SetWidth(228);
		row:SetHeight(14);
		row:SetPoint("TOPLEFT", editor, "TOPLEFT", 10, -20 - (i * 14));
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		row.text:SetPoint("LEFT", row, "LEFT", 0, 0);
		row:SetScript("OnClick", function()
			Banknon_SelectEditorGroup(index);
		end);
		row.SetText = function(self, text)
			self.text:SetText(text);
		end
		editor.rows[i] = row;
	end

	local nameLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	nameLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 10, -146);
	nameLabel:SetText("Name");

	local nameBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate");
	nameBox:SetWidth(150);
	nameBox:SetHeight(18);
	nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 4, 0);
	nameBox:SetAutoFocus(false);
	nameBox:SetScript("OnEscapePressed", function() this:ClearFocus(); end);
	editor.nameBox = nameBox;

	local sizeLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	sizeLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 10, -168);
	sizeLabel:SetText("Slots");

	local sizeBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate");
	sizeBox:SetWidth(42);
	sizeBox:SetHeight(18);
	sizeBox:SetPoint("LEFT", sizeLabel, "RIGHT", 4, 0);
	sizeBox:SetAutoFocus(false);
	sizeBox:SetMaxLetters(3);
	sizeBox:SetScript("OnEscapePressed", function() this:ClearFocus(); end);
	editor.sizeBox = sizeBox;

	local addButton = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate");
	addButton:SetWidth(64);
	addButton:SetHeight(20);
	addButton:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 10, 10);
	addButton:SetText("Add");
	addButton:SetScript("OnClick", function()
		local name = editor.nameBox:GetText();
		local size = tonumber(editor.sizeBox:GetText());
		if(name and name ~= "" and size and size > 0) then
			Banknon_CreateGroup(name, size);
			editor.nameBox:SetText("");
			editor.sizeBox:SetText("");
		end
	end);

	local saveButton = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate");
	saveButton:SetWidth(64);
	saveButton:SetHeight(20);
	saveButton:SetPoint("LEFT", addButton, "RIGHT", 4, 0);
	saveButton:SetText("Save");
	saveButton:SetScript("OnClick", function()
		local index = editor.selectedIndex;
		local groups = Banknon_GetGroups();
		if(index and groups[index]) then
			local name = editor.nameBox:GetText();
			local size = tonumber(editor.sizeBox:GetText());
			if(name and name ~= "" and size and size > 0) then
				groups[index].name = name;
				groups[index].size = math.floor(size);
				Banknon_RefreshAfterGroupingChange();
			end
		end
	end);

	local delButton = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate");
	delButton:SetWidth(64);
	delButton:SetHeight(20);
	delButton:SetPoint("LEFT", saveButton, "RIGHT", 4, 0);
	delButton:SetText("Delete");
	delButton:SetScript("OnClick", function()
		local index = editor.selectedIndex;
		local groups = Banknon_GetGroups();
		if(index and groups[index]) then
			table.remove(groups, index);
			editor.selectedIndex = nil;
			Banknon_RefreshAfterGroupingChange();
		end
	end);

	local clearButton = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate");
	clearButton:SetWidth(64);
	clearButton:SetHeight(20);
	clearButton:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -10, 10);
	clearButton:SetText("Clear");
	clearButton:SetScript("OnClick", function()
		BagnonSets["Banknon"].groups = {};
		editor.selectedIndex = nil;
		Banknon_RefreshAfterGroupingChange();
	end);

	Banknon.groupEditor = editor;
end

function Banknon_ToggleGroupingEditor()
	if(not Banknon.groupEditor) then
		Banknon_CreateGroupingEditor();
	end

	if(Banknon.groupEditor:IsShown() ) then
		Banknon.groupEditor:Hide();
	else
		Banknon.groupEditor:Show();
		Banknon_UpdateEditorList();
	end
end

--[[ Bank Slots functions ]]--

--Show/Hide the bag frame
function Banknon_ToggleSlots()
	if( not BanknonBags:IsShown() ) then
		BanknonBags:Show();
		BagnonSets["Banknon"].bagsShown = 1;
		this:SetText(BAGNON_HIDEBAGS);
	else
		BanknonBags:Hide();
		BagnonSets["Banknon"].bagsShown = nil;
		this:SetText(BAGNON_SHOWBAGS);
	end

	Banknon_UpdatePurchaseButtonVis(not BagnonSets["Banknon"].bagsShown);
	Banknon_ApplyGroupingLayout();
end

function Banknon_UpdateSlotCost()
	local cost = GetBankSlotCost( GetNumBankSlots() );
	if( GetMoney() >= cost ) then
		SetMoneyFrameColor("BanknonCost", 1.0, 1.0, 1.0);
	else
		SetMoneyFrameColor("BanknonCost", 1.0, 0.1, 0.1)
	end
	MoneyFrame_Update("BanknonCost", cost);

	Banknon_UpdatePurchaseButtonVis();
end

--yes, magic numbers are bad
function Banknon_UpdatePurchaseButtonVis(hide)
	if( BanknonBags:IsVisible() or hide) then
		local _, full = GetNumBankSlots();
		if( not full and bgn_atBank and (Banknon.player and Banknon.player == UnitName("player") ) and not hide ) then
			BanknonPurchase:Show();
			BanknonCost:Show();
			BanknonBags:SetHeight(72);
		else
			BanknonPurchase:Hide();
			BanknonCost:Hide();
			BanknonBags:SetHeight(46);
		end
	end
	BagnonFrame_TrimToSize(Banknon);
	Banknon_ApplyGroupingLayout();
end
