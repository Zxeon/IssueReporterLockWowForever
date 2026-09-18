local addonName = ...

local bugSetupDone = false
local buttonSetupDone = false

local function ApplySavedPosition(frame, savedTable)
	if not savedTable then
		return
	end
	frame:ClearAllPoints()
	frame:SetPoint(savedTable.point, UIParent, savedTable.relativePoint, savedTable.x, savedTable.y)
end

local function GetCurrentPositionTable(frame)
	local point, _, relativePoint, x, y = frame:GetPoint()
	return {
		point = point,
		relativePoint = relativePoint,
		x = x,
		y = y,
	}
end

local function MakeMovableAndTrackDrag(frame, getSavedTable, setSavedTable)
	if not frame:IsMovable() then
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
	end

	frame:HookScript("OnDragStart", function(self)
		self:StartMoving()
	end)

	frame:HookScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		setSavedTable(GetCurrentPositionTable(self))
	end)
end

-- The "Bug" icon (tooltip: "Issue Reporter") is a persistent, named global
-- frame that exists for the whole session once Blizzard_PTRFeedback loads.
-- It's not reliably available at PLAYER_LOGIN or via ADDON_LOADED, so it's
-- found by polling instead.
local function TryBugSetup()
	if bugSetupDone then
		return
	end
	if not Bug then
		return
	end
	bugSetupDone = true

	ApplySavedPosition(Bug, IssueReporterLockDB)
	Bug:HookScript("OnShow", function(self)
		ApplySavedPosition(self, IssueReporterLockDB)
	end)
	MakeMovableAndTrackDrag(Bug, function()
		return IssueReporterLockDB
	end, function(pos)
		IssueReporterLockDB = pos
	end)
end

local pollTicker
pollTicker = C_Timer.NewTicker(1, function()
	TryBugSetup()
	if bugSetupDone then
		pollTicker:Cancel()
	end
end)

-- The "Issue Reporter" button is a separate anonymous frame from "Bug" (no
-- GetName(), Border+Background children), identified by a FontString region
-- reading "Issue\nReporter". Like Bug, it's already shown by the time any
-- hook could install, so it's found by polling UIParent's children.
local function FrameHasIssueReporterLabel(frame)
	local ok, regions = pcall(function()
		return { frame:GetRegions() }
	end)
	if not ok then
		return false
	end
	for _, region in ipairs(regions) do
		local okType, objType = pcall(region.GetObjectType, region)
		if okType and objType == "FontString" then
			local okText, text = pcall(region.GetText, region)
			if okText and text and text:find("Issue") and text:find("Reporter") then
				return true
			end
		end
	end
	return false
end

local function FindIssueReporterButton()
	local kids = { UIParent:GetChildren() }
	for _, f in ipairs(kids) do
		if type(f) == "table" and f.Border and f.Background and not f:GetName() then
			if FrameHasIssueReporterLabel(f) then
				return f
			end
		end
	end
	return nil
end

local function TryButtonSetup()
	if buttonSetupDone then
		return
	end
	local button = FindIssueReporterButton()
	if not button then
		return
	end
	buttonSetupDone = true

	ApplySavedPosition(button, IssueReporterLockDialogDB)
	button:HookScript("OnShow", function(self)
		ApplySavedPosition(self, IssueReporterLockDialogDB)
	end)
	MakeMovableAndTrackDrag(button, function()
		return IssueReporterLockDialogDB
	end, function(pos)
		IssueReporterLockDialogDB = pos
	end)
end

local buttonPollTicker
buttonPollTicker = C_Timer.NewTicker(1, function()
	TryButtonSetup()
	if buttonSetupDone then
		buttonPollTicker:Cancel()
	end
end)

-- Minimap button: orbits the minimap's edge like a standard minimap button
-- (angle-based position, not a fixed UIParent offset), so it follows the
-- minimap if it ever moves/resizes. Click to reset both saved positions
-- back to Blizzard's default.
local minimapButton = CreateFrame("Button", "IssueReporterLockMinimapButton", Minimap)
minimapButton:SetSize(31, 31)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:RegisterForClicks("LeftButtonUp")
minimapButton:RegisterForDrag("LeftButton")
minimapButton:EnableMouse(true)

local minimapIcon = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
minimapIcon:SetSize(20, 20)
minimapIcon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)

local minimapBorder = minimapButton:CreateTexture(nil, "OVERLAY")
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapBorder:SetSize(54, 54)
minimapBorder:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)

local function UpdateMinimapButtonPosition()
	local angle = math.rad(IssueReporterLockMinimapDB and IssueReporterLockMinimapDB.angle or 215)
	local radius = (Minimap:GetWidth() / 2) + 5
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

minimapButton:SetScript("OnDragStart", function(self)
	self:SetScript("OnUpdate", function()
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		px, py = px / scale, py / scale
		local angle = math.deg(math.atan2(py - my, px - mx))
		IssueReporterLockMinimapDB = IssueReporterLockMinimapDB or {}
		IssueReporterLockMinimapDB.angle = angle
		UpdateMinimapButtonPosition()
	end)
end)

minimapButton:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
end)

UpdateMinimapButtonPosition()

minimapButton:SetScript("OnClick", function()
	IssueReporterLockDB = nil
	IssueReporterLockDialogDB = nil
	print("|cff33ff99[Issue Reporter Lock]|r Saved positions cleared. They'll reset to Blizzard's default next time they appear.")
end)

minimapButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("Issue Reporter Lock")
	GameTooltip:AddLine("Left-click: reset saved positions", 1, 1, 1)
	GameTooltip:AddLine("Drag to move this button", 1, 1, 1)
	GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)
