# NotedLootCouncil

NotedLootCouncil: a lightweight loot council addon for WoW

## Options

These can be found in Esc -> Interface -> AddOns -> NotedLootCouncil
Loot Options - A comma seperated string of all the loot options available to raiders
Link Loot - Links all Rare+ loot in raid chat
Debug Mode - Toggles on all debug output (dont use unless developing or errors show up)

## Commands

WIP

`/nlc` or `/nlc open` - Opens the available panels

`/nlc session <arg>`

- `start` - starts a voting session
- `end` - ends a voting session
- `reset` - resets all voting and item caches

`/nlc council <arg>`

- `add` - add a targeted player to the loot council
- `remove` - add the targeted player to the loot council
- `<no arg>` - list the players on the council

`/nlc add <item_link>` - adds the linked item to the session.

`/nlc cache` - prints out all the items in the session cache
