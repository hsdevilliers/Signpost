local ADDON_NAME, ns = ...

-- The class quest chains are the druid quests of the data pack: QuestieDB's Classic baseline (the Tauren chains) and,
-- since 2026-10-20, its Forever layers (the Cat Form chain at 20 and the Windshaper Skyborne chains: quest IDs, levels
-- and races are facts from there; QuestieDB says those layers do not supply complete objectives or restrictions).
-- Trainer spells are not in either source; they come from in-game learning (Core/Learn.lua). The Windshaper's own
-- Cat Form quests ("The Great Windborne Cat Spirit" ...) are in the pack (the windshaper-cat-form chain below); a
-- Windshaper's Cure Poison and Aquatic Form quests, if it has any, are not: the Tauren chains are limited to Tauren.
-- VERIFY(beta): the forms (Bear Form at 10, Aquatic Form at 16, Cat Form at 20, Travel Form) and who learns them where
-- are unconfirmed until a druid has done them; the level-60 set and reputation chains are not listed.
ns.Classes:Register("DRUID", {
	-- { [level] = { spellIDs } }: no spell IDs without a source; `.train class` stays empty until Learn records them.
	trainerSpells = {},
	classQuests = {
		{ id = "verdant-note", name = "Verdant Note", level = 1, quests = { 3094 }, races = { "Tauren" } },
		{
			id = "student-of-nature",
			name = "A Student of Nature",
			level = 2,
			quests = { 92485 },
			races = { "Skyborne" },
		},
		{
			id = "moonglade",
			name = "Moonglade (Bear Form)",
			level = 10,
			-- three starting points, one of which is taken: 5926 (Mulgore), 5927 (Mulgore) and 5928 (Thunder Bluff)
			quests = { 5926, 5927, 5928, 5922, 5930, 5932, 6002 },
			races = { "Tauren" },
		},
		{
			id = "windshaper-bear-form",
			name = "Child of Nature, Moonglade (Bear Form, Windshaper)",
			level = 10,
			quests = { 94911, 94913, 94006, 94638 },
			races = { "Skyborne" },
		},
		{
			id = "lessons-anew",
			name = "Lessons Anew",
			level = 14,
			quests = { 6126, 6127, 6128, 6129, 6130 },
			races = { "Tauren" },
		},
		{ id = "aquatic-form", name = "Aquatic Form", level = 16, quests = { 26, 28, 30, 31 }, races = { "Tauren" } },
		{
			id = "cat-form",
			name = "Cat Form",
			level = 20,
			-- The Great Cat Spirit (Turak to Dendrite), The Great Cat Spirit (Dendrite to the Spirit), The Great Cat
			-- Spirit (the Spirit), Blessings of the Great Cat Spirit, To Thunder Bluff
			quests = { 98340, 98405, 98342, 98739, 98362 },
			races = { "Tauren" },
		},
		-- The Windshaper shares the first and last quests with the Tauren chain (98340, 98362); the Windborne ones in between
		-- (The Great Windborne Cat Spirit x2, Blessings of the Great Windborne Cat Spirit) are its own, with the Avatar of
		-- Saeyleenan.
		{
			id = "windshaper-cat-form",
			name = "Cat Form (Windshaper)",
			level = 20,
			quests = { 98340, 98341, 98404, 98738, 98362 },
			races = { "Skyborne" },
		},
		{ id = "torwa-pathfinder", name = "Torwa Pathfinder", level = 52, quests = { 9063, 9052, 9051, 9053 } },
	},
	-- Words for the travel steps tools/guide_travel.py writes in a druid's guide, by the uiMapID of the zone they go to or leave
	-- (docs/ENGINE.md). Where the way to or from such a zone would be a walk across a border, the step says these words in place
	-- of "find your own way" (a flight path or the hearthstone that the guide already has stands as it is). `to`, `back` and
	-- `unsafe` are plain words for the player, each a string or a list of lines joined with a space; no coordinate, no ID.
	-- Moonglade (1450 in the pack's maps): every Bear Form, Lessons Anew, Aquatic Form and Cat Form chain turns or ends there, and
	-- the route in the data is only a walk. VERIFY(beta): that a Forever druid has Teleport: Moonglade, where it is learned, and the
	-- way back (the hearthstone, a flight path from Nighthaven) are all unconfirmed (docs/CLASS-QUESTS.md, docs/FOREVER-API-NOTES.md,
	-- Open probes: "Teleport: Moonglade"). The way overland is from Classic memory only, and a HARDCORE druid of level 10 to 30 must
	-- never be sent along it.
	travelHints = {
		[1450] = {
			to = {
				"cast Teleport: Moonglade if you have it (VERIFY(beta): where a druid learns it),",
				"else the way is not in the data",
			},
			back = {
				"use your hearthstone or a flight path if you have one",
				"(VERIFY(beta): the way back is not in the data)",
			},
			unsafe = {
				"from Classic memory (not confirmed in Forever) the road overland runs through Felwood or Winterspring,",
				"zones for levels 48 and up, so it is not safe at your level",
			},
		},
	},
})
