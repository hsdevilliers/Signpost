-- PLANNED: the thorough alt 1 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-01-mulgore",
	[[
#chapter 1-11 Mulgore
step
  .goto 1412,43.89,76.66
  .accept 752 -- A Humble Task
  .goto 1412,44.47,77.5
  .accept 747 -- The Hunt Begins
step
  .goto 1412,49.27,77.46
  .complete 747 -- The Hunt Begins
step
  .goto 1412,48.77,80.92
  .turnin 752 -- A Humble Task
  .accept 753 -- A Humble Task
step
  .goto 1412,48.91,81.17
  .complete 753 -- A Humble Task
step
  .goto 1412,44.47,77.5
  .turnin 747 -- The Hunt Begins
  .accept 750 -- The Hunt Continues
  .accept 3094 .class DRUID -- Verdant Note
  .goto 1412,43.89,76.66
  .turnin 753 -- A Humble Task
  .accept 755 -- Rites of the Earthmother
  .goto 1412,44.65,76.55
  .turnin 3094 .class DRUID -- Verdant Note
step
  .goto 1412,42.13,87.31
  .complete 750 -- The Hunt Continues
step
  .goto 1412,42.54,90.13
  .turnin 755 -- Rites of the Earthmother
  .accept 757 -- Rite of Strength
  .accept 95805 -- Grace of An'she and Mu'sha
step
  .goto 1412,56.61,88.7
  .turnin 95805 -- Grace of An'she and Mu'sha
step
  .goto 1412,57.21,81.85
  .complete 757 -- Rite of Strength
step
  .goto 1412,43.89,76.66
  .turnin 757 -- Rite of Strength
  .accept 763 -- Rites of the Earthmother
  .level 4
  .accept 96659 -- The Adventurer
  .goto 1412,44.47,77.5
  .turnin 750 -- The Hunt Continues
step
  .goto 1412,46.13,67.4
  .turnin 96659 -- The Adventurer
  .accept 96605 -- The Great Outdoors
step
  .goto 1412,46.21,67.31
  .complete 96605 -- The Great Outdoors
step
  .goto 1412,46.13,67.4
  .turnin 96605 -- The Great Outdoors
  .accept 96661 -- Camping 101: Cooking
  .goto 1412,47.52,63.58
  .accept 748 -- Poison Water
  .goto 1412,47.67,62.68
  .accept 761 -- Swoop Hunting
  .goto 1412,46.67,63.38
  .turnin 763 -- Rites of the Earthmother
  .accept 767 -- Rite of Vision
step
  .goto 1412,46.88,61.19
  .turnin 767 -- Rite of Vision
  .goto 1412,44.92,61.67
  .complete 96661,1 -- Camping 101: Cooking
  .turnin 96661 -- Camping 101: Cooking
step
  .goto 1412,40.57,58.81
  .complete 748 -- Poison Water
  .complete 761 -- Swoop Hunting
step
  .goto 1412,47.28,57.63
  .level 5
  .accept 99411 -- Kyle's Gone Missing!
  .goto 1412,47.67,62.68
  .turnin 761 -- Swoop Hunting
  .goto 1412,47.52,63.58
  .turnin 748 -- Poison Water
  .accept 754 -- Winterhoof Cleansing
  .complete 754,1 -- Winterhoof Cleansing
  .note Winterhoof Cleansing: HARDCORE event: enemies may come at you here; be healed and buffed first, and come back later if unsure
  .turnin 754 -- Winterhoof Cleansing
  .accept 756 -- Thunderhorn Totem
step
  .goto 1412,54.76,64.27
  .accept 749 -- The Ravaged Caravan
step
  .goto 1412,51.87,53.37
  .turnin 749 -- The Ravaged Caravan
  .accept 751 -- The Ravaged Caravan
step
  .goto 1412,50.93,50.24
  .complete 756 -- Thunderhorn Totem
step
  .goto 1412,47.52,63.58
  .turnin 756 -- Thunderhorn Totem
  .accept 758 -- Thunderhorn Cleansing
  .complete 758,1 -- Thunderhorn Cleansing
  .note Thunderhorn Cleansing: HARDCORE event: enemies may come at you here; be healed and buffed first, and come back later if unsure
  .turnin 758 -- Thunderhorn Cleansing
  .goto 1412,46.67,63.38
  .accept 745 -- Sharing the Land
  .goto 1412,46.68,63.83
  .accept 99079 -- Longwalker Malah
step
  .goto 1412,46.28,62.34
  .complete 99411 -- Kyle's Gone Missing!
step
  .goto 1412,46.23,60.8
  .accept 766 -- Mazzranache
  .goto 1412,47.28,57.63
  .turnin 99411 -- Kyle's Gone Missing!
step
  .goto 1412,49.07,48.71
  .complete 766 -- Mazzranache
step
  .goto 1412,57.62,63.18
  .turnin 99079 -- Longwalker Malah
  .accept 99081 -- Grim Tidings
  .goto 1412,54.76,64.27
  .turnin 751 -- The Ravaged Caravan
  .accept 764 -- The Venture Co.
step
  .goto 1412,47.52,63.58
  .accept 759 -- Wildmane Totem
  .goto 1412,46.68,63.83
  .turnin 99081 -- Grim Tidings
  .accept 99101 -- Our Ancient Enemy
  .goto 1412,46.23,60.8
  .turnin 766 -- Mazzranache
  .goto 1412,46.67,63.38
  .turnin 99101 -- Our Ancient Enemy
step
  .goto 1412,34.91,64.24
  .complete 745 -- Sharing the Land
step
  .goto 1412,33.13,65.92
  .accept 98430 -- The Longwalkers
step
  .goto 1412,37.19,64.62
  .complete 98430 -- The Longwalkers
step
  .goto 1412,46.67,63.38
  .turnin 745 -- Sharing the Land
  .goto 1412,46.03,63.44
  .level 10
  .accept 861 -- The Hunter's Way
  .goto 1412,47.48,62.95
  .accept 5926 .class DRUID -- Heeding the Call
step
  .goto 1412,60.63,48.8
  .complete 764 -- The Venture Co.
step
  .goto 1412,56.98,34.55
  .accept 833 -- A Sacred Burial
step
  .goto 1412,57.96,30.92
  .complete 833 -- A Sacred Burial
step
  .goto 1412,56.98,34.55
  .turnin 833 -- A Sacred Burial
step
  .goto 1412,53.15,32.46
  .complete 861 -- The Hunter's Way
step
  .goto 1412,45.33,36.52
  .complete 759 -- Wildmane Totem
step
  .todo "Walk from Mulgore to Thunder Bluff: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Thunder Bluff."
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,61.54,80.92
  .turnin 861 -- The Hunter's Way
  .goto 1456,60.3,51.68
  .turnin 98430 -- The Longwalkers
step
  .goto 1456,47.0,49.83 >> Go to the flight master
  .fp 1456,Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 5926 .class DRUID -- Heeding the Call
  .accept 5922 .class DRUID -- Moonglade
  .note Moonglade is a long walk from here. VERIFY(beta): Classic's druid learns Teleport: Moonglade at level 10, and this guide does not assume that Forever does; the way back (hearthstone, or a flight master at Nighthaven) is unconfirmed too.
step
  .todo "Walk from Thunder Bluff to Mulgore: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Mulgore."
  .zone 1412 >> Go to Mulgore
step
  .goto 1412,47.52,63.58
  .turnin 759 -- Wildmane Totem
  .accept 760 -- Wildmane Cleansing
  .complete 760,1 -- Wildmane Cleansing
  .note Wildmane Cleansing: HARDCORE event: enemies may come at you here; be healed and buffed first, and come back later if unsure
  .turnin 760 -- Wildmane Cleansing
  .accept 98435 -- Thunderhorn's Report
step
  .goto 1412,54.76,64.27
  .turnin 764 -- The Venture Co.
  .accept 765 -- Supervisor Fizsprocket
step
  .goto 1412,61.19,49.32
  .complete 765 -- Supervisor Fizsprocket
step
  .goto 1412,54.76,64.27
  .turnin 765 -- Supervisor Fizsprocket
step
  .todo "Walk from Mulgore to Thunder Bluff: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Thunder Bluff."
  .zone 1456 >> Go to Thunder Bluff
]]
)
