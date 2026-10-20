local ADDON_NAME, ns = ...

-- The class quest chains are the druid-only quests of the data pack's QuestieDB layer (Classic's chains: the quest IDs
-- and levels are facts from there; each chain's races are the races whose chain it is). Forever's own additions are not
-- in that source yet, and neither are the trainer spells; both come from in-game learning (Core/Learn.lua).
-- VERIFY(beta): Forever may have reworked the early forms (Bear Form at 10, Aquatic Form at 16, Cat and Travel Form),
-- so every chain here is unconfirmed until a druid has done it; the level-60 set and reputation chains are not listed.
ns.Classes:Register("DRUID", {
	-- { [level] = { spellIDs } }: no spell IDs without a source; `.train class` stays empty until Learn records them.
	trainerSpells = {},
	classQuests = {
		{ id = "verdant-note", name = "Verdant Note", level = 1, quests = { 3094 }, races = { "Tauren" } },
		{
			id = "moonglade",
			name = "Moonglade (Bear Form)",
			level = 10,
			-- three starting points, one of which is taken: 5926 (Mulgore), 5927 (Mulgore) and 5928 (Thunder Bluff)
			quests = { 5926, 5927, 5928, 5922, 5930, 5932, 6002 },
			races = { "Tauren" },
		},
		{
			id = "lessons-anew",
			name = "Lessons Anew",
			level = 14,
			quests = { 6126, 6127, 6128, 6129, 6130 },
			races = { "Tauren" },
		},
		{ id = "aquatic-form", name = "Aquatic Form", level = 16, quests = { 26, 28, 30, 31 }, races = { "Tauren" } },
		-- Forever's own chain (not in the Classic baseline, so no IDs yet; the lint wants a `.todo` naming it in the guide):
		-- "The Great Cat Spirit" x3, "Blessings of the Great Cat Spirit", "To Thunder Bluff"; docs/CLASS-QUESTS.md
		{ id = "cat-form", name = "Cat Form", level = 20, quests = {}, pending = true },
		{ id = "torwa-pathfinder", name = "Torwa Pathfinder", level = 52, quests = { 9063, 9052, 9051, 9053 } },
	},
})
