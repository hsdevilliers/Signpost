-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-01-durotar",
	[[
#chapter 1-10 Durotar
step
  .goto 1411,43.29,68.53
  .accept 4641 -- Your Place In The World
  .goto 1411,42.06,68.33
  .turnin 4641 -- Your Place In The World
  .accept 788 -- Cutting Teeth
  .accept 97279 -- Wayward Weapons
step
  .goto 1411,43.07,64.02
  .complete 788 -- Cutting Teeth
  .complete 97279 -- Wayward Weapons
step
  .goto 1411,42.06,68.33
  .turnin 788 -- Cutting Teeth
  .accept 789 -- Sting of the Scorpid
  .accept 3082 .class HUNTER -- Etched Tablet
  .goto 1411,42.85,69.15
  .level 2
  .accept 792 .class !WARLOCK -- Vile Familiars
  .goto 1411,42.84,69.33
  .turnin 3082 .class HUNTER -- Etched Tablet
  .goto 1411,40.47,68.0
  .turnin 97279 -- Wayward Weapons
step
  .goto 1411,40.5,66.83
  .complete 789 -- Sting of the Scorpid
step
  .goto 1411,42.73,67.23
  .accept 4402 -- Galgar's Cactus Apple Surprise
  .goto 1411,42.06,68.33
  .turnin 789 -- Sting of the Scorpid
step
  .goto 1411,40.85,63.92
  .complete 4402 -- Galgar's Cactus Apple Surprise
step
  .goto 1411,40.6,62.58
  .accept 790 -- Sarkoth
step
  .goto 1411,45.19,57.3
  .complete 792 .class !WARLOCK -- Vile Familiars
step
  .goto 1411,44.63,68.65
  .level 3
  .accept 5441 -- Lazy Peons
  .goto 1411,42.85,69.15
  .turnin 792 .class !WARLOCK -- Vile Familiars
  .accept 794 -- Burning Blade Medallion
  .goto 1411,42.73,67.23
  .turnin 4402 -- Galgar's Cactus Apple Surprise
step
  .goto 1411,40.5,66.83
  .complete 790 -- Sarkoth
step
  .goto 1411,40.6,62.58
  .turnin 790 -- Sarkoth
  .accept 804 -- Sarkoth
step
  .goto 1411,42.71,52.95
  .complete 794 -- Burning Blade Medallion
  .complete 5441 -- Lazy Peons
step
  .goto 1411,42.06,68.33
  .turnin 804 -- Sarkoth
  .goto 1411,42.85,69.15
  .turnin 794 -- Burning Blade Medallion
  .accept 805 -- Report to Sen'jin Village
  .goto 1411,42.79,69.12
  .level 4
  .accept 96652 -- The Adventurer
  .goto 1411,44.63,68.65
  .turnin 5441 -- Lazy Peons
  .accept 6394 -- Thazz'ril's Pick
step
  .goto 1411,52.02,47.3
  .turnin 96652 -- The Adventurer
  .accept 96604 -- The Great Outdoors
step
  .goto 1411,52.09,47.39
  .complete 96604 -- The Great Outdoors
step
  .goto 1411,52.02,47.3
  .turnin 96604 -- The Great Outdoors
  .accept 96655 -- Camping 101: Cooking
  .goto 1411,51.13,42.63
  .accept 96825 -- This Fruit Could Bite Back
  .goto 1411,51.11,42.45
  .complete 96655,1 -- Camping 101: Cooking
  .turnin 96655 -- Camping 101: Cooking
step
  .goto 1411,49.88,40.39
  .accept 791 -- Carry Your Weight
step
  .goto 1411,56.53,50.8
  .complete 791 -- Carry Your Weight
step
  .goto 1411,49.88,40.39
  .turnin 791 -- Carry Your Weight
  .level 7 -- reach it first: kill or grind on the way
  .note Grind about 19 experience before you go on: about 1 kill of creatures near your level (an estimate)
step
  .goto 1411,46.37,22.94
  .accept 834 -- Winds in the Desert
step
  .goto 1411,49.1,22.59
  .complete 834 -- Winds in the Desert
step
  .goto 1411,46.37,22.94
  .turnin 834 -- Winds in the Desert
  .accept 835 -- Securing the Lines
step
  .goto 1411,41.54,18.6
  .accept 812 -- Need for a Cure
  .todo "Need for a Cure: objective 1 has no position in the pack"
  .complete 812,1 -- Need for a Cure
  .turnin 812 -- Need for a Cure
step
  .goto 1411,43.73,53.79
  .complete 6394 -- Thazz'ril's Pick
step
  .goto 1411,44.63,68.65
  .turnin 6394 -- Thazz'ril's Pick
step
  .goto 1411,46.3,78.64
  .accept 99123 -- Lost in the Shadows
step
  .goto 1411,51.41,79.29
  .complete 99123 -- Lost in the Shadows
step
  .goto 1411,55.28,75.49
  .accept 97223 -- Bloodtalon Matriarch
  .goto 1411,55.95,74.72
  .turnin 805 -- Report to Sen'jin Village
  .accept 823 -- Report to Orgnil
  .goto 1411,55.94,74.39
  .turnin 99123 -- Lost in the Shadows
  .accept 97225 -- Forgotten Loa Idols
  .accept 818 -- A Solvent Spirit
  .goto 1411,55.96,73.93
  .accept 96821 -- Legging It
  .accept 817 -- Practical Prey
step
  .goto 1411,65.13,72.59
  .complete 818 -- A Solvent Spirit
  .complete 97223 -- Bloodtalon Matriarch
  .complete 817 -- Practical Prey
step
  .goto 1411,65.6,83.0
  .complete 97225 -- Forgotten Loa Idols
step
  .goto 1411,55.95,74.72
  .turnin 97225 -- Forgotten Loa Idols
  .goto 1411,55.94,74.39
  .turnin 818 -- A Solvent Spirit
  .goto 1411,55.96,73.93
  .turnin 817 -- Practical Prey
  .goto 1411,55.28,75.49
  .turnin 97223 -- Bloodtalon Matriarch
step
  .goto 1411,51.78,63.39
  .complete 96821 -- Legging It
step
  .goto 1411,51.95,43.5
  .turnin 96821 -- Legging It
  .accept 837 -- Encroachment
  .goto 1411,52.24,43.15
  .turnin 823 -- Report to Orgnil
  .accept 806 -- Dark Storms
  .level 9
  .accept 99048 -- A Missing Hand
step
  .goto 1411,50.33,49.07
  .complete 837,1 -- Encroachment
step
  .goto 1411,58.6,45.6
  .turnin 99048 -- A Missing Hand
  .accept 99049 -- Threat from Below
step
  .goto 1411,58.85,44.35
  .complete 99049 -- Threat from Below
step
  .goto 1411,52.24,43.15
  .turnin 99049 -- Threat from Below
  .accept 99051 -- Threat from Below
step
  .goto 1411,58.58,28.56
  .complete 99051 -- Threat from Below
step
  .goto 1411,52.24,43.15
  .turnin 99051 -- Threat from Below
  .level 10
  .accept 99052 -- Threat from Below
  .goto 1411,50.84,43.59
  .accept 840 -- Conscript of the Horde
step
  .goto 1411,43.24,40.5
  .complete 837,4 -- Encroachment
  .complete 837,3 -- Encroachment
step
  .goto 1411,44.03,50.33
  .complete 837,2 -- Encroachment
step
  .goto 1411,42.84,69.33
  .accept 6068 .class HUNTER -- The Hunter's Path
step
  .goto 1411,46.8,49.0
  .complete 96825 -- This Fruit Could Bite Back
step
  .goto 1411,51.11,42.45
  .turnin 96825 -- This Fruit Could Bite Back
step
  .goto 1411,51.85,43.49
  .turnin 6068 .class HUNTER -- The Hunter's Path
  .accept 6062 .class HUNTER -- Taming the Beast
  .todo "Taming the Beast: the pack has no objective for it; read what it asks in the quest log"
  .turnin 6062 .class HUNTER -- Taming the Beast
  .accept 6083 .class HUNTER -- Taming the Beast
  .todo "Taming the Beast: the pack has no objective for it; read what it asks in the quest log"
  .turnin 6083 .class HUNTER -- Taming the Beast
  .accept 6082 .class HUNTER -- Taming the Beast
  .todo "Taming the Beast: the pack has no objective for it; read what it asks in the quest log"
  .turnin 6082 .class HUNTER -- Taming the Beast
  .accept 6081 .class HUNTER -- Training the Beast
step
  .goto 1411,51.95,43.5
  .turnin 837 -- Encroachment
step
  .goto 1411,54.07,27.33
  .complete 835,1 -- Securing the Lines
step
  .todo "Walk from Durotar to Orgrimmar: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Orgrimmar."
  .zone 1454 >> Go to Orgrimmar
]]
)
