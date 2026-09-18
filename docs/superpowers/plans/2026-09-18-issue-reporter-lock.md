# IssueReporterLock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a WoW Forever beta addon that keeps Blizzard's PTR feedback reminder dialog at the position the player last dragged it to, instead of resetting to Blizzard's default position on every login/reload.

**Architecture:** A single TOC + single Lua file. The Lua file hooks the `Show` method shared by all frame widgets, identifies the anonymous target dialog by duck-typing on its `CheckListText`/`TimerTracker` child fields, makes it movable, and persists/reapplies its position via SavedVariables.

**Tech Stack:** WoW Lua (client API, interface 16001), WoW addon TOC/SavedVariables. No build tooling, no package manager, no local Lua interpreter available on this machine — verification is manual, in-game (see Task 2).

**Spec:** `docs/2026-09-18-issue-reporter-lock-design.md`

## Global Constraints

- `## Interface: 16001` (WoW Forever beta client 1.60.1.69913, per `D:\World of Warcraft\.build.info`).
- SavedVariables table name: `IssueReporterLockDB`.
- Identify the target frame only by `self.CheckListText and self.TimerTracker` — no global frame name exists for it.
- Use `HookScript`, never `SetScript`, on the target frame so any existing Blizzard drag behavior isn't clobbered.
- No slash commands, no options UI, no support for other client versions or other PTR feedback frames (per spec's Out of scope section).

---

### Task 1: Addon skeleton and position-lock logic

**Files:**
- Create: `IssueReporterLockWowForever.toc`
- Create: `IssueReporterLock.lua`

**Interfaces:**
- Produces: a loaded addon named `IssueReporterLockWowForever` with SavedVariables `IssueReporterLockDB` (a table with keys `point`, `relativePoint`, `x`, `y`, or `nil` before the player has ever dragged the dialog).

- [ ] **Step 1: Write the TOC file**

```
## Interface: 16001
## Title: Issue Reporter Lock
## Notes: Keeps the WoW Forever PTR feedback reminder dialog at its last dragged position across login/reload.
## Author: Nix Solutions
## Version: 1.0
## SavedVariables: IssueReporterLockDB

IssueReporterLock.lua
```

- [ ] **Step 2: Write the addon logic**

```lua
local addonName = ...

local hooked = false

local function ApplySavedPosition(frame)
	local pos = IssueReporterLockDB
	if not pos then
		return
	end
	frame:ClearAllPoints()
	frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end

local function SaveCurrentPosition(frame)
	local point, _, relativePoint, x, y = frame:GetPoint()
	IssueReporterLockDB = {
		point = point,
		relativePoint = relativePoint,
		x = x,
		y = y,
	}
end

local function SetupFrame(frame)
	if frame.issueReporterLockSetup then
		return
	end
	frame.issueReporterLockSetup = true

	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")

	frame:HookScript("OnDragStart", function(self)
		self:StartMoving()
	end)

	frame:HookScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SaveCurrentPosition(self)
	end)
end

local function OnAnyFrameShow(self)
	if not (self.CheckListText and self.TimerTracker) then
		return
	end

	SetupFrame(self)
	ApplySavedPosition(self)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
	if hooked then
		return
	end
	hooked = true
	hooksecurefunc(getmetatable(UIParent).__index, "Show", OnAnyFrameShow)
end)
```

- [ ] **Step 3: Manual syntax check**

There is no local Lua interpreter on this machine (confirmed: `lua`, `lua5.1`,
`luac`, `luacheck` are all absent). Re-read both files line by line, checking
for: balanced `end`/`then`/`function` keywords, matching parentheses, and
correct WoW API call signatures (`CreateFrame`, `RegisterEvent`,
`hooksecurefunc`, `GetPoint`, `SetPoint`). Real syntax verification happens in
Task 2 by loading the addon in-game and checking for Lua errors.

- [ ] **Step 4: Commit**

```bash
git add "IssueReporterLockWowForever.toc" "IssueReporterLock.lua"
git commit -m "feat: add issue reporter position lock addon"
```

(Skip this step if the user has indicated, as with GCDAddon, that this
project directory should not be committed to the parent repo.)

---

### Task 2: Install and verify in-game

**Files:**
- Create (junction, not a git-tracked file): `D:\World of Warcraft\_classic_beta_\Interface\AddOns\IssueReporterLockWowForever` → `D:\NixSol\AI Projects\IssueReporterLockWowForever`

**Interfaces:**
- Consumes: the addon files from Task 1.

- [ ] **Step 1: Create the live-sync junction**

```powershell
New-Item -ItemType Junction -Path "D:\World of Warcraft\_classic_beta_\Interface\AddOns\IssueReporterLockWowForever" -Target "D:\NixSol\AI Projects\IssueReporterLockWowForever"
```

This follows the same pattern already used for ChatCopyPaste, Spy, and
APIProbe on this machine.

- [ ] **Step 2: Load-time verification (user, in-game)**

Log into WoW Forever beta, open the AddOns list, and confirm
"Issue Reporter Lock" is listed and enabled with no load errors (check
`/console scriptErrors 1` or a Lua error addon if any errors appear).

- [ ] **Step 3: Behavioral verification (user, in-game)**

Wait for the PTR feedback reminder dialog to appear, drag it to a new
screen position, then `/reload`. Confirm the dialog reopens at the dragged
position rather than Blizzard's default. Report back pass/fail — this
addon's core behavior is unverified until confirmed live, per the "Verify
live API claims" rule for this project (browser/game verification can't be
performed by the assistant directly).

- [ ] **Step 4: Report result**

No commit needed for this task (junction + manual testing only). If
verification fails, capture the exact symptom (error text, or the position
not sticking) to feed back into Task 1's implementation.
