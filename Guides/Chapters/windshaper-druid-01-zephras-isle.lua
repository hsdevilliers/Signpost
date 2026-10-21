-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-01-zephras-isle",
	[[
#chapter 1-11 Zephras Isle
step
  .goto 2521,42.82,23.37
  .accept 92460 -- Coming of Age
  .goto 2521,42.05,23.49
  .turnin 92460 -- Coming of Age
  .accept 92461 -- Harmony in Balance
step
  .goto 2521,45.22,25.13
  .complete 92461 -- Harmony in Balance
step
  .goto 2521,43.68,24.1
  .level 2
  .accept 92474 -- Falling With Style
  .todo "Falling With Style: objective 1 has no position in the pack"
  .complete 92474,1 -- Falling With Style
step
  .goto 2521,43.77,24.09
  .accept 94414 -- The Anchors of Zephras
  .complete 94414,1 -- The Anchors of Zephras
  .turnin 94414 -- The Anchors of Zephras
  .goto 2521,42.05,23.49
  .turnin 92461 -- Harmony in Balance
  .turnin 92474 -- Falling With Style
  .accept 92464 -- Elemental Unrest
  .accept 92485 .class DRUID -- A Student of Nature
  .goto 2521,41.66,23.33
  .turnin 92485 .class DRUID -- A Student of Nature
  .goto 2521,47.25,21.98
  .turnin 92464 -- Elemental Unrest
  .accept 92465 -- Agitators
step
  .goto 2521,47.2,19.81
  .complete 92465 -- Agitators
step
  .goto 2521,47.25,21.98
  .turnin 92465 -- Agitators
  .level 3
  .accept 92469 -- Return to Rorian
  .goto 2521,43.37,23.98
  .accept 93552 -- Harvesting Windstones
step
  .goto 2521,43.82,25.43
  .complete 93552 -- Harvesting Windstones
step
  .goto 2521,43.37,23.98
  .turnin 93552 -- Harvesting Windstones
  .goto 2521,42.05,23.49
  .turnin 92469 -- Return to Rorian
  .level 4
  .accept 92471 -- Aetheen of the Gales
  .goto 2521,42.76,23.66
  .turnin 92471 -- Aetheen of the Gales
  .accept 92470 -- Foul Matriarch
step
  .goto 2521,36.27,24.87
  .complete 92470 -- Foul Matriarch
step
  .goto 2521,42.76,23.66
  .turnin 92470 -- Foul Matriarch
  .accept 92472 -- The Next Step
  .accept 96638 -- The Adventurer
step
  .goto 2521,41.66,44.8
  .turnin 96638 -- The Adventurer
  .goto 2521,43.51,44.77
  .accept 92595 -- The Windshapers
  .complete 92595,1 -- The Windshapers
  .turnin 92595 -- The Windshapers
  .accept 94411 -- Meddlesome Mages
  .goto 2521,45.67,45.5
  .turnin 92472 -- The Next Step
  .accept 92514 -- Welcome to Shen'dar Village
step
  .goto 2521,43.25,43.88
  .complete 92514 -- Welcome to Shen'dar Village
step
  .goto 2521,45.67,45.5
  .turnin 92514 -- Welcome to Shen'dar Village
  .accept 92517 -- The Criminal Element
  .goto 2521,43.85,43.85
  .accept 92553 -- Restocking the Larders
  .goto 2521,44.46,44.96
  .accept 93319 -- Pilfered Windstones
  .goto 2521,44.68,44.53
  .accept 92515 -- The Problem With Prideclaws
step
  .goto 2521,39.49,43.34
  .complete 92553 -- Restocking the Larders
  .complete 92515 -- The Problem With Prideclaws
step
  .goto 2521,43.85,43.85
  .turnin 92553 -- Restocking the Larders
  .goto 2521,44.68,44.53
  .turnin 92515 -- The Problem With Prideclaws
step
  .goto 2521,45.95,39.53
  .complete 94411 -- Meddlesome Mages
  .complete 92517,1 -- The Criminal Element
  .complete 93319 -- Pilfered Windstones
step
  .goto 2521,50.62,34.27
  .complete 92517,2 -- The Criminal Element
step
  .goto 2521,44.46,44.96
  .turnin 93319 -- Pilfered Windstones
  .goto 2521,45.67,45.5
  .turnin 92517 -- The Criminal Element
  .level 5
  .accept 93036 -- Infiltrating the Cult
  .goto 2521,43.51,44.77
  .turnin 94411 -- Meddlesome Mages
  .goto 2521,43.38,45.82
  .accept 93318 -- WANTED: Vulgara the Insatiable
  .goto 2521,44.88,45.53
  .turnin 93036 -- Infiltrating the Cult
  .accept 92529 -- Falaath Village
step
  .goto 2521,42.66,52.8
  .complete 93318 -- WANTED: Vulgara the Insatiable
step
  .goto 2521,45.24,45.18
  .turnin 93318 -- WANTED: Vulgara the Insatiable
step
  .goto 2521,46.89,56.23
  .turnin 92529 -- Falaath Village
step
  .goto 2521,60.55,73.06
  .accept 93317 -- Crab Season
  .goto 2521,62.08,73.17
  .accept 92679 -- Blood Tithe
  .complete 92679,2 -- Blood Tithe
step
  .goto 2521,46.7,81.95
  .complete 92679,1 -- Blood Tithe
  .turnin 92679 -- Blood Tithe
  .accept 92682 -- Make Yourself Useful
  .accept 92684 -- Ornery Ornery Galestriders
  .goto 2521,48.65,78.42
  .accept 92698 -- What Is My Purpose?
step
  .goto 2521,46.6,78.99
  .complete 92682 -- Make Yourself Useful
step
  .goto 2521,46.7,81.95
  .turnin 92682 -- Make Yourself Useful
  .turnin 92698 -- What Is My Purpose?
step
  .goto 2521,50.21,82.72
  .complete 92684 -- Ornery Ornery Galestriders
step
  .goto 2521,46.7,81.95
  .turnin 92684 -- Ornery Ornery Galestriders
step
  .goto 2521,52.55,74.91
  .complete 93317 -- Crab Season
step
  .goto 2521,60.55,73.06
  .turnin 93317 -- Crab Season
  .goto 2521,63.99,75.08
  .level 8
  .accept 94484 -- Unnerving Silence
  .level 10
  .accept 94006 .class DRUID -- The Great Ursera Spirit
step
  .goto 2521,69.81,61.71
  .turnin 94006 .class DRUID -- The Great Ursera Spirit
  .accept 94638 .class DRUID -- Strength and Mercy
  .note VERIFY(beta): the Bear Form trial; the data only says to kill Ur'endra (near 54,65). Go in at full health with your buffs up and leave if it goes badly: the Tauren Bear Form test (Lunaclaw) kills careless players.
step
  .goto 2521,56.81,61.11
  .accept 98512 -- Al'Aketh Assassins
step
  .goto 2521,55.62,60.41
  .complete 98512 -- Al'Aketh Assassins
step
  .goto 2521,56.81,61.11
  .turnin 98512 -- Al'Aketh Assassins
step
  .goto 2521,53.66,65.02
  .complete 94638 .class DRUID -- Strength and Mercy
step
  .goto 2521,69.81,61.71
  .turnin 94638 .class DRUID -- Strength and Mercy
step
  .goto 2521,61.72,39.22
  .turnin 94484 -- Unnerving Silence
  .accept 94486 -- Feathers for Binding
  .accept 94487 -- Unwanted and Unworthy
step
  .goto 2521,61.44,37.14
  .complete 94486 -- Feathers for Binding
step
  .goto 2521,61.72,39.22
  .turnin 94486 -- Feathers for Binding
  .accept 94485 -- Tears of the Lady
step
  .goto 2521,60.8,38.7
  .complete 94485 -- Tears of the Lady
step
  .goto 2521,61.72,39.22
  .turnin 94485 -- Tears of the Lady
step
  .goto 2521,62.93,37.58
  .complete 94487 -- Unwanted and Unworthy
step
  .goto 2521,61.72,39.22
  .turnin 94487 -- Unwanted and Unworthy
  .accept 94488 -- The Ties That Bind
  .accept 94489 -- The Wounds of Betrayal
step
  .goto 2521,65.53,36.32
  .complete 94488 -- The Ties That Bind
  .complete 94489 -- The Wounds of Betrayal
step
  .goto 2521,61.72,39.22
  .turnin 94488 -- The Ties That Bind
  .turnin 94489 -- The Wounds of Betrayal
step
  .todo "travel from Zephras Isle to Mulgore: the travel graph has no route yet"
  .zone 1412 >> Go to Mulgore
]]
)
