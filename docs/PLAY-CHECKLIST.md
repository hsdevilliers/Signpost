# Play checklist: short runs that give the guides their travel steps

Why: a guide tells you to change zone but cannot say how until the game has shown Signpost the way. Each item is a short run you
probably make anyway; do any of them, in any session, in any order. They go by how many travel steps of the three routes (Troll
Hunter, Tauren Druid, Skyborne Druid) they fix, most first (the number in brackets; it moves when the routes are planned again).
Signpost keeps positions and the names of places, and four small things about you: your skill next to each recipe you open, whether
you already know a service a trainer offers, how long a boat or zeppelin ride took, and your faction. No names, no chat, no gold
(docs/SHARING-DATA.md has the whole list). `/signpost contribute` shows whether recording is on (a development build always records).

## First session after launch: the Troll Hunter (about 10 minutes, then the borders below if you like)

Only the Troll Hunter is being tested (HARDCORE comes later; the two druid guides wait). Make a fresh Troll Hunter, tick "Help improve the guides", and look at:
1. `/signpost status` first: it shows the client's Interface number (if it is not 16001, say so before anything else: docs/GAME-UPDATES.md) and whether any Lua error was caught.
2. The first step where you start: does it list everything offered at the starting camp, with a pin for each, and does it fit on the step card? (A stop can hold more than ten lines;
   the Journal shows all of it.) Is there anything offered there that it did not list?
3. After the first kills: does the guide tell you to hand in before you leave, and are quests that are given at the same place taken in one visit?
4. Find my place at login (the launcher menu): does it put you at step 1 on a new character?
5. Does the quest tracker follow the current step? Do the done marks tick?
6. Anything that felt like a wrong instruction: note the step and what the game did instead (`/signpost report` if you have the words).
When you stop: `/signpost probe`, then `/reload`, and tell Claude; it reads the save with `tools/read_savedvars.py` and reports what the game really did.

## Run across these borders, there and back (a minute each; keep running, you need not stop)
1. Mulgore <-> Thunder Bluff: up into Thunder Bluff and down again (27)
2. Tirisfal Glades <-> Undercity: into the Undercity by its main entrance and out again (23)
3. The Barrens <-> Stonetalon Mountains: the road from the Crossroads to Sun Rock Retreat (22)
4. The Barrens <-> Mulgore: the road west from Camp Taurajo into Mulgore (21)
5. Tirisfal Glades <-> Silverpine Forest: the road south to The Sepulcher (18)
6. The Barrens <-> Ashenvale: the road from the Crossroads to Ashenvale (16)
7. Durotar <-> Orgrimmar: out of the gate and back in (9)
8. Durotar <-> The Barrens: the road from Razor Hill to the Crossroads (9)
9. Silverpine Forest <-> Hillsbrad Foothills: the road east from The Sepulcher (8)
10. Orgrimmar <-> The Barrens: the Barrens road out of Orgrimmar (5); The Barrens <-> Thousand Needles: south from Camp Taurajo (4)

## Ride (this fills a gap nothing else can)
11. The Orgrimmar zeppelin to the Undercity and back (7). Type `/signpost ride zeppelin` before you board. For any other boat or
    zeppelin type `/signpost ride boat` or `/signpost ride zeppelin` first, so that Signpost knows which it was.

## While you are there anyway
- Open the flight map at each flight master you pass: it records where the flight master stands.
- Talk to the innkeeper of each town; if you were going to make it your home, do. It records where the inn is and its name.

## The druids
- Moonglade: how a druid gets there and back is not in the data, and the guide says not to walk (from Classic memory the road overland is for
  levels 48 and up). Go once by the spell, the hearthstone or a flight path if you have one, and note which with `/signpost report`.
- Skyborne: when the island story sends you off, ride the airship from Valanaar's southwest dock to Mulgore (type `/signpost ride zeppelin`
  first), then `/signpost learned`: it should say 1 ride. Note what the airship is called and how long you waited.

## Check it and hand it on
`/signpost learned` counts what has been recorded (rides, innkeepers, NPCs, flight nodes, zone crossings). `/reload` writes it to disk.
Then close the game and run `tools\share_savedvars.ps1` (your friend: `share_savedvars.cmd`), or do the usual copy. The tools read it
with `python tools/import_savedvars.py --merge-learned`; the guides planned after that show the real way.
