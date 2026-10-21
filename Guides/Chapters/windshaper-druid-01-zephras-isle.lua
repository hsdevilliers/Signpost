-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-01-zephras-isle",
	[[
#chapter 1-15 Zephras Isle
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
  .goto 2521,42.41,25.17
  .accept 92473 -- Aggressive Encroachment
step
  .goto 2521,40.34,26.26
  .complete 92473 -- Aggressive Encroachment
step
  .goto 2521,42.41,25.17
  .turnin 92473 -- Aggressive Encroachment
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
  .goto 2521,44.46,44.96
  .accept 93319 -- Pilfered Windstones
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
  .goto 2521,44.88,45.53
  .turnin 93036 -- Infiltrating the Cult
  .accept 92529 -- Falaath Village
step
  .goto 2521,46.89,56.23
  .turnin 92529 -- Falaath Village
  .accept 92528 -- Among the Faithful
step
  .goto 2521,48.84,53.93
  .complete 92528 -- Among the Faithful
step
  .goto 2521,45.67,45.5
  .turnin 92528 -- Among the Faithful
  .accept 92550 -- Havoc in the Highlands
  .accept 93926 -- The Western Watch
  .goto 2521,45.24,45.18
  .accept 92551 -- Stolen Supplies
step
  .goto 2521,42.35,62.02
  .complete 93926,1 -- The Western Watch
  .turnin 93926 -- The Western Watch
  .accept 93927 -- A Last Request
step
  .goto 2521,42.37,62.07
  .complete 93927 -- A Last Request
step
  .goto 2521,45.67,45.5
  .turnin 93927 -- A Last Request
step
  .goto 2521,48.27,53.05
  .complete 92550 -- Havoc in the Highlands
  .complete 92551 -- Stolen Supplies
step
  .goto 2521,45.67,45.5
  .turnin 92550 -- Havoc in the Highlands
  .level 6
  .accept 92579 -- To Valanaar
  .accept 93948 -- Deliver the Signet
  .goto 2521,45.24,45.18
  .turnin 92551 -- Stolen Supplies
step
  .goto 2521,60.55,73.06
  .accept 93317 -- Crab Season
step
  .goto 2521,66.14,76.67
  .turnin 92579 -- To Valanaar
  .accept 92700 -- The Grand Skyseer
  .goto 2521,66.17,76.51
  .turnin 93948 -- Deliver the Signet
  .accept 93949 -- Bugged
step
  .goto 2521,63.91,77.09
  .complete 93949 -- Bugged
step
  .goto 2521,66.14,76.67
  .turnin 93949 -- Bugged
step
  .goto 2521,59.15,79.77
  .turnin 92700 -- The Grand Skyseer
  .accept 93735 -- The Broken Construct
  .goto 2521,58.13,78.32
  .accept 93736 -- Unwelcome Spirits
step
  .goto 2521,59.06,72.98
  .turnin 93735 -- The Broken Construct
  .accept 93737 -- The Broken Construct
  .complete 93737,1 -- The Broken Construct
step
  .goto 2521,52.55,74.91
  .complete 93317 -- Crab Season
step
  .goto 2521,43.9,75.4
  .complete 93737,4 -- The Broken Construct
step
  .goto 2521,51.9,67.1
  .complete 93737,2 -- The Broken Construct
step
  .goto 2521,53.5,50.4
  .complete 93737,3 -- The Broken Construct
step
  .goto 2521,60.55,73.06
  .turnin 93317 -- Crab Season
  .goto 2521,59.06,72.98
  .turnin 93737 -- The Broken Construct
  .accept 93738 -- The Broken Construct
step
  .goto 2521,59.15,79.77
  .turnin 93738 -- The Broken Construct
  .accept 93746 -- A Firm Response
step
  .goto 2521,59.79,57.31
  .complete 93746 -- A Firm Response
step
  .goto 2521,59.15,79.77
  .turnin 93746 -- A Firm Response
  .accept 92871 -- In Service of Zephras
  .accept 93740 -- Blood for Blood
step
  .goto 2521,63.99,75.08
  .level 8
  .accept 94484 -- Unnerving Silence
  .level 10
  .accept 94006 .class DRUID -- The Great Ursera Spirit
  .goto 2521,66.14,76.67
  .turnin 92871 -- In Service of Zephras
  .accept 93320 -- Tower Defense
step
  .goto 2521,69.65,67.07
  .turnin 93320 -- Tower Defense
  .accept 92642 -- Disrupting Logistics
  .accept 92645 -- Breaking the Breaker
  .goto 2521,69.81,61.71
  .turnin 94006 .class DRUID -- The Great Ursera Spirit
  .accept 94638 .class DRUID -- Strength and Mercy
  .note VERIFY(beta): the Bear Form trial; the data only says to kill Ur'endra (near 54,65). Go in at full health with your buffs up and leave if it goes badly: the Tauren Bear Form test (Lunaclaw) kills careless players.
step
  .goto 2521,53.66,65.02
  .complete 94638 .class DRUID -- Strength and Mercy
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
  .goto 2521,69.81,61.71
  .turnin 94638 .class DRUID -- Strength and Mercy
step
  .goto 2521,65.78,64.36
  .complete 93740 -- Blood for Blood
  .complete 92645 -- Breaking the Breaker
  .complete 92642 -- Disrupting Logistics
step
  .goto 2521,69.65,67.07
  .turnin 92642 -- Disrupting Logistics
  .turnin 92645 -- Breaking the Breaker
  .accept 92880 -- Return to Valanaar
step
  .goto 2521,66.14,76.67
  .turnin 92880 -- Return to Valanaar
  .accept 92881 -- The High Elder's Request
  .goto 2521,66.17,76.51
  .turnin 92881 -- The High Elder's Request
  .accept 92643 -- The Turncoat
step
  .goto 2521,56.16,60.59
  .complete 92643,1 -- The Turncoat
step
  .goto 2521,56.04,58.77
  .complete 92643,2 -- The Turncoat
  .turnin 92643 -- The Turncoat
  .accept 92644 -- Unfortunate News
step
  .goto 2521,61.72,39.22
  .turnin 94484 -- Unnerving Silence
  .accept 94485 -- Tears of the Lady
  .accept 94486 -- Feathers for Binding
  .accept 94487 -- Unwanted and Unworthy
step
  .goto 2521,61.44,37.14
  .complete 94486 -- Feathers for Binding
  .complete 94485 -- Tears of the Lady
step
  .goto 2521,61.72,39.22
  .turnin 94485 -- Tears of the Lady
  .turnin 94486 -- Feathers for Binding
step
  .goto 2521,66.17,76.51
  .turnin 92644 -- Unfortunate News
  .accept 94568 -- The Cult's True Plans
  .complete 94568,1 -- The Cult's True Plans
  .turnin 94568 -- The Cult's True Plans
  .accept 92640 -- Desperate Times
step
  .goto 2521,66.14,76.67
  .complete 92640,1 -- Desperate Times
step
  .goto 2521,59.15,79.77
  .turnin 93740 -- Blood for Blood
  .accept 92708 -- A Grand Adventure
  .complete 92640,2 -- Desperate Times
  .complete 92708,1 -- A Grand Adventure
  .turnin 92708 -- A Grand Adventure
step
  .goto 2521,66.04,74.41
  .accept 94896 -- Aid For The Refugees
  .accept 94897 -- The Fate of a Loved One
step
  .goto 2521,66.61,80.02
  .complete 92640,3 -- Desperate Times
step
  .goto 2521,66.14,76.67
  .turnin 92640 -- Desperate Times
  .accept 93065 -- Prepare for Battle
step
  .goto 2521,61.17,70.95
  .complete 93065,1 -- Prepare for Battle
  .turnin 93065 -- Prepare for Battle
  .accept 92947 -- Making Our Move
  .note VERIFY(beta): the finale of the island story starts here, at the Shrine of Akir (near 61,51), where the Al'Aketh guardian, spiritcaller and blademaster stand together. Pull them one at a time, and be healed and rested before The Inner Sanctum and Confront Lorthuna. This chain is the way off the island.
step
  .goto 2521,61.85,52.3
  .complete 92947,2 -- Making Our Move
  .complete 92947,1 -- Making Our Move
  .complete 92947,3 -- Making Our Move
step
  .goto 2521,63.77,50.51
  .complete 92947,4 -- Making Our Move
  .turnin 92947 -- Making Our Move
  .accept 93958 -- The Inner Sanctum
  .note VERIFY(beta): the last stop before the boss fight of Confront Lorthuna. Heal, drink, buff and rest first.
  .goto 2521,65.19,50.35
  .turnin 93958 -- The Inner Sanctum
  .accept 92646 -- Confront Lorthuna
  .note VERIFY(beta): a scripted boss fight at the Shrine of Akir. Fan guides say Rohash is summoned and Kirin Tor and Earthen Ring reinforcements arrive. Go in fully healed and buffed with your escape ready, fight beside the reinforcements, and leave if it goes badly. It is part of the chain that takes you off the island, so there is no way round it that we know of.
step
  .goto 2521,63.63,37.28
  .complete 94487 -- Unwanted and Unworthy
step
  .goto 2521,61.72,39.22
  .turnin 94487 -- Unwanted and Unworthy
  .accept 94488 -- The Ties That Bind
  .accept 94489 -- The Wounds of Betrayal
step
  .goto 2521,53.96,38.9
  .accept 93159 -- The Strange Hermit
  .complete 93159,1 -- The Strange Hermit
  .turnin 93159 -- The Strange Hermit
  .accept 93160 -- The Forest's Bounty
  .accept 93172 -- Free the Hollows
step
  .goto 2521,57.2,39.2
  .complete 93160 -- The Forest's Bounty
step
  .goto 2521,53.96,38.9
  .turnin 93160 -- The Forest's Bounty
step
  .goto 2521,57.99,33.64
  .complete 93736 -- Unwelcome Spirits
  .complete 93172 -- Free the Hollows
step
  .goto 2521,53.96,38.9
  .turnin 93172 -- Free the Hollows
step
  .goto 2521,65.53,36.32
  .complete 94488 -- The Ties That Bind
  .complete 94489 -- The Wounds of Betrayal
step
  .goto 2521,61.72,39.22
  .turnin 94488 -- The Ties That Bind
  .turnin 94489 -- The Wounds of Betrayal
step
  .goto 2521,58.4,32.7
  .complete 94896 -- Aid For The Refugees
  .complete 94897 -- The Fate of a Loved One
step
  .goto 2521,63.81,36.01
  .accept 93165 -- Mercy Falls on Deaf Ears
step
  .goto 2521,62.93,37.58
  .complete 93165 -- Mercy Falls on Deaf Ears
step
  .goto 2521,63.81,36.01
  .turnin 93165 -- Mercy Falls on Deaf Ears
step
  .goto 2521,74.87,53.02
  .complete 92646 -- Confront Lorthuna
step
  .goto 2521,66.04,74.41
  .turnin 94896 -- Aid For The Refugees
  .turnin 94897 -- The Fate of a Loved One
step
  .goto 2521,59.15,79.77
  .turnin 92646 -- Confront Lorthuna
  .accept 93836 -- The Fate of Zephras
  .goto 2521,58.13,78.32
  .turnin 93736 -- Unwelcome Spirits
step
  .goto 2521,66.17,76.51
  .complete 93836,1 -- The Fate of Zephras
  .turnin 93836 -- The Fate of Zephras
  .accept 93090 -- What Comes Next
step
  .goto 2521,59.15,79.77
  .turnin 93090 -- What Comes Next
  .accept 95349 -- The Earthen Ring
step
  .zone 1412 >> Take the airship from Valanaar's southwest dock (Zephras Isle) to Skywatcher Plateau, beside Thunder Bluff (Mulgore)
  .note Expect to wait about 7 to 8 minutes for it.
  .todo "Not verified in the game: the dock, the airship's name, the landing spot and whether you can board before the quest chain asks you to. This step is done when you arrive in Mulgore."
step
  .goto 1412,33.38,22.57
  .turnin 95349 -- The Earthen Ring
  .accept 95350 -- Welcome to Azeroth
  .goto 1412,33.41,22.59
  .accept 94911 .class DRUID -- Child of Nature
step
  .todo "Walk from Mulgore to Thunder Bluff: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Thunder Bluff."
  .zone 1456 >> Go to Thunder Bluff
]]
)
