# IssueReporterLock — Design

## Problem

WoW Forever beta (client `wow_classic_beta`, interface 16001) periodically shows a
PTR/beta feedback reminder dialog (`Blizzard_PTRFeedback` addon). The dialog is an
anonymous frame (no `GetName()`) parented directly to `UIParent`. Every time it
reappears — including after `/reload` or re-login — Blizzard resets it to its
default screen position, discarding wherever the player last dragged it.

## Verified facts

- Confirmed via in-game `/framestack`: the dialog's source is
  `Interface/AddOns/Blizzard_PTRFeedback/Blizzard_PTRFeedback_Frames.lua:1021`.
- The frame has no global name; framestack displayed it as `UIParent.<hash>`.
- The frame has child fields `CheckListText` and `TimerTracker` (confirmed
  visible in framestack region list), which are distinctive enough to identify
  the frame by duck-typing.
- `C_UserFeedback` exists as a global API table, exposing only `SubmitBug` and
  `SubmitSuggestion` — no positioning-related API, so it's not useful here.
- No frame with a name matching `PTRFeedback` exists in `_G`.
- Client version confirmed via `D:\World of Warcraft\.build.info`:
  `wow_classic_beta` = 1.60.1.69913 → Interface 16001 (Blizzard's
  major.minor.patch → interface-number convention).
- **Unverified / to confirm in-game:** whether the frame is already
  user-draggable out of the box, or whether this addon needs to make it
  movable itself. The design handles both cases defensively (see below).

## Approach

Since the frame has no stable global reference, hook the `Show` method shared
by all frame widgets (`hooksecurefunc(getmetatable(UIParent).__index, "Show", ...)`).
Inside the handler, identify the target frame by checking for both
`self.CheckListText` and `self.TimerTracker`. This works regardless of when or
how Blizzard creates/pools the frame, and needs no global name.

On first detection of the frame (guarded by a one-time flag stored on the
frame itself, so repeat `Show` calls don't rewire it):

- Ensure it's movable: `SetMovable(true)`, `EnableMouse(true)`,
  `RegisterForDrag("LeftButton")`.
- `HookScript` (not `SetScript`, to avoid clobbering any existing Blizzard
  drag behavior) `OnDragStart` → `self:StartMoving()`.
- `HookScript` `OnDragStop` → `self:StopMovingOrSizing()`, then persist the
  frame's current `GetPoint()` (point, relativePoint, x, y relative to
  `UIParent`) into SavedVariables.

On every `Show` (after one-time setup), if a saved position exists, reapply
it: `ClearAllPoints()` + `SetPoint(...)` from SavedVariables, overriding
whatever default point Blizzard just set. If no saved position exists yet,
Blizzard's default position is left alone.

## Files

- `IssueReporterLockWowForever.toc` — `## Interface: 16001`,
  `## SavedVariables: IssueReporterLockDB`
- `IssueReporterLock.lua` — hook logic described above (~50-60 lines)

## Out of scope

- No slash commands, no options UI, no support for other client versions.
- No handling of other Blizzard PTR feedback frames/dialogs beyond this one.

## Testing

This can't be triggered on demand — it's a periodic Blizzard reminder. Manual
test plan: install the addon, wait for the reminder to appear, drag it to a
new position, `/reload`, and confirm it reopens at the dragged position
instead of Blizzard's default. This is unverified until the user confirms it
in-game.
