# Sharing what Signpost recorded (for contributors)

Signpost can learn where NPCs, quest givers, flight masters, innkeepers, trainers, vendors and zone borders are, and where boats
and zeppelins dock, while you play, what trainers teach and charge, and the recipes in your profession windows, so the guides get
better. It is **your choice** and **nothing is sent by the addon**: the data stays in a file on your computer until you copy it.

## 1. Say yes in the game

The first time you log in, a window "Help improve Signpost" opens. Tick **Record this while I play** and press **Done**. You can
change it any time with `/signpost contribute` (or `/signpost contribute off`). Without the tick, nothing is recorded.

Recorded: IDs, the names of NPCs, objects, flight nodes and places (the game's own zone texts at a dock), and map positions; for a
boat or zeppelin ride the two docks, how long it took and your faction; at a trainer, the names of what it teaches, the
trainer's prices, the level and skill each needs and whether you already know it; in a profession window, the recipes (name, the item
they make, the reagents) and how hard each was at your skill (orange, yellow, green or grey) with that skill value. To learn a
profession's colours, open its window now and then as your skill goes up. So the four things about you are: your skill next to
each recipe, whether you know a trainer's service, how long a ride took and your faction. Not recorded: chat, your name, your
character's or pet's name, your gold, anything about other players (another player's or the guild's profession window is never
read). The file also holds Signpost's settings and error log.

## 2. Hand the file over (Windows)

1. Log out of the game, or close it, so the latest data is written.
2. Double-click `share_savedvars.cmd` (from the `tools` folder of the Signpost repository, or the copy you were sent). It copies
   `Signpost.lua` from your game folder into the shared folder named in `destination.txt` next to it and prints what it copied.
   - No `destination.txt`? Create it with one line: the shared folder's path.
   - World of Warcraft installed somewhere unusual? Run `powershell -ExecutionPolicy Bypass -File share_savedvars.ps1 -Dest "<shared folder>" -WowRoot "<World of Warcraft folder>"`.
3. That is all. Run it again after a later session; copies are timestamped and never overwrite each other.

Only the account-wide file is copied. The per-character file (which has your character's name and realm in its path) is not.

## For the maintainers

The shared folder holds one subfolder per contributor (a stable anonymous code) with timestamped copies,
`<id>\Signpost-<game folder>-<date time>.lua`. `python tools/import_savedvars.py --merge-learned --contributions <shared folder>`
folds them all in: each contributor's copies are one source, oldest first, so importing again or importing a later copy never
double-counts, and the learned layer accumulates across imports (`layers/learned-sources.json`), so earlier data is never dropped.
Trainer services and recipes are filed under their profession (`professions[skillLine].services` and `.recipes`, the schema is in
`Data/Schema.lua`): the newest reading of a service or of a recipe's field wins, the difficulty observations of every contributor
are added together, and what the other layers hold of the same profession stays.
