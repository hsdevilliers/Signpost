# Play checklist: short runs that give the guides their travel steps

Why: a guide tells you to change zone but cannot say how until the game has shown Signpost the way. Each item is a short run you
probably make anyway; do any of them, in any session, in any order. They go by how many travel steps of the three routes (Troll
Hunter, Tauren Druid, Skyborne Druid) they fix, most first (the number in brackets; it moves when the routes are planned again).
Signpost keeps only positions and the names of places, nothing about you. `/signpost contribute` shows whether recording is on
(a development build always records).

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
- Moonglade: how a druid gets there and back is not in the data. Go once and note how (spell, walking, flight) with `/signpost report`.
- Skyborne: when the island story sends you off, ride the airship from Valanaar's southwest dock to Mulgore (type `/signpost ride zeppelin`
  first), then `/signpost learned`: it should say 1 ride. Note what the airship is called and how long you waited.

## Check it and hand it on
`/signpost learned` counts what has been recorded (rides, innkeepers, NPCs, flight nodes, zone crossings). `/reload` writes it to disk.
Then close the game and run `tools\share_savedvars.ps1` (your friend: `share_savedvars.cmd`), or do the usual copy. The tools read it
with `python tools/import_savedvars.py --merge-learned`; the guides planned after that show the real way.
