# Friends (step 9c)

Owner (plan 1.O): friends-list skin, cross-source search, group-invite accept from friends and guild. The minimap friends tooltip is the Minimap's.

- Files: `Data.lua` (one entry shape for WoW, Battle.net, guild, recent; filter, sort, plain search, invite source), `Skin.lua` (post-hook on `FriendsFrame_UpdateFriendButton`), `Panel.lua` (docked search panel and actions), `Friends.lua` (settings, invite accept, events).
- No taint: Blizzard still builds its list; rows are only decorated. App-only friends are dimmed there and left out of the Phoenix panel.
- Invite accept: per source, both off at first install; never while queued (PUI.Queue) or in combat. Flow's `flow.acceptInvites` stands down while Friends is on.
