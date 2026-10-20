-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
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
  .goto 1411,45.67,65.76
  .complete 788 -- Cutting Teeth
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
step
  .goto 1411,40.5,66.83
  .complete 789 -- Sting of the Scorpid
step
  .goto 1411,42.73,67.23
  .accept 4402 -- Galgar's Cactus Apple Surprise
  .goto 1411,42.06,68.33
  .turnin 789 -- Sting of the Scorpid
  .goto 1411,44.63,68.65
  .level 3
  .accept 5441 -- Lazy Peons
step
  .goto 1411,43.2,71.7
  .complete 97279 -- Wayward Weapons
step
  .goto 1411,47.16,65.45
  .complete 5441 -- Lazy Peons
step
  .goto 1411,44.63,68.65
  .turnin 5441 -- Lazy Peons
  .accept 6394 -- Thazz'ril's Pick
  .goto 1411,40.47,68.0
  .turnin 97279 -- Wayward Weapons
step
  .goto 1411,45.68,63.29
  .complete 4402 -- Galgar's Cactus Apple Surprise
  .complete 792 .class !WARLOCK -- Vile Familiars
step
  .goto 1411,40.6,62.58
  .accept 790 -- Sarkoth
step
  .goto 1411,40.5,66.83
  .complete 790 -- Sarkoth
step
  .goto 1411,42.85,69.15
  .turnin 792 .class !WARLOCK -- Vile Familiars
  .accept 794 -- Burning Blade Medallion
  .goto 1411,42.73,67.23
  .turnin 4402 -- Galgar's Cactus Apple Surprise
step
  .goto 1411,40.6,62.58
  .turnin 790 -- Sarkoth
  .accept 804 -- Sarkoth
step
  .goto 1411,43.73,53.79
  .complete 6394 -- Thazz'ril's Pick
  .complete 794 -- Burning Blade Medallion
step
  .goto 1411,42.06,68.33
  .turnin 804 -- Sarkoth
  .goto 1411,42.85,69.15
  .turnin 794 -- Burning Blade Medallion
  .goto 1411,42.79,69.12
  .level 4
  .accept 96652 -- The Adventurer
  .goto 1411,44.63,68.65
  .turnin 6394 -- Thazz'ril's Pick
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
  .goto 1411,49.3,48.1
  .complete 96825 -- This Fruit Could Bite Back
step
  .goto 1411,56.53,50.8
  .complete 791 -- Carry Your Weight
step
  .goto 1411,51.11,42.45
  .turnin 96825 -- This Fruit Could Bite Back
  .goto 1411,49.88,40.39
  .turnin 791 -- Carry Your Weight
step
  .goto 1411,41.54,18.6
  .level 7
  .accept 812 -- Need for a Cure
  .todo "Need for a Cure: objective 1 has no position in the pack"
  .complete 812,1 -- Need for a Cure
  .turnin 812 -- Need for a Cure
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
  .goto 1411,51.95,43.5
  .accept 784 -- Vanquish the Betrayers
  .accept 837 -- Encroachment
  .goto 1411,53.95,42.59
  .accept 96822 -- For Honor
step
  .goto 1411,56.53,50.8
  .complete 784,2 -- Vanquish the Betrayers
  .complete 96822 -- For Honor
  .complete 784,1 -- Vanquish the Betrayers
step
  .goto 1411,59.72,58.27
  .complete 784,3 -- Vanquish the Betrayers
step
  .goto 1411,53.95,42.59
  .turnin 96822 -- For Honor
  .goto 1411,51.95,43.5
  .turnin 784 -- Vanquish the Betrayers
  .accept 825 -- From The Wreckage....
step
  .goto 1411,54.07,27.33
  .complete 835 -- Securing the Lines
step
  .goto 1411,46.37,22.94
  .turnin 835 -- Securing the Lines
step
  .goto 1411,43.1,30.24
  .level 8
  .accept 816 -- Lost But Not Forgotten
step
  .goto 1411,35.7,25.31
  .complete 816 -- Lost But Not Forgotten
step
  .goto 1411,43.1,30.24
  .turnin 816 -- Lost But Not Forgotten
step
  .goto 1411,52.24,43.15
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
  .complete 825 -- From The Wreckage....
step
  .goto 1411,52.24,43.15
  .turnin 99049 -- Threat from Below
  .accept 99051 -- Threat from Below
  .goto 1411,51.95,43.5
  .turnin 825 -- From The Wreckage....
step
  .goto 1411,58.58,28.56
  .complete 99051 -- Threat from Below
step
  .goto 1411,52.24,43.15
  .turnin 99051 -- Threat from Below
  .level 10
  .accept 99052 -- Threat from Below
step
  .goto 1411,49.18,49.09
  .complete 837,2 -- Encroachment
step
  .goto 1411,42.84,69.33
  .accept 6068 .class HUNTER -- The Hunter's Path
step
  .goto 1411,38.77,53.52
  .complete 837,4 -- Encroachment
  .complete 837,3 -- Encroachment
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
  .todo "travel from Durotar to Orgrimmar: the travel graph has no route yet"
  .zone 1454 >> Go to Orgrimmar
]]
)
