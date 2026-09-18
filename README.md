# Issue Reporter Lock

Keeps WoW Forever's beta feedback UI pieces where you put them, instead of
resetting to Blizzard's default position on every login or `/reload`:

- The "Bug" icon (tooltip: "Issue Reporter")
- The Issue Reporter button
- A minimap icon that lets you reset both saved positions with a left-click

## Usage

Drag either piece to where you want it. The addon remembers the position
and reapplies it automatically on every future login/reload. Left-click the
minimap icon to clear both saved positions and go back to Blizzard's
defaults.

## Notes

This addon works by matching Blizzard's internal `Blizzard_PTRFeedback`
implementation (an undocumented global name and UI text), not a public API.
It's built for WoW Forever beta (interface 16001) and may stop working if
Blizzard changes that UI in a future patch.
