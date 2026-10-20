local ADDON_NAME, ns = ...

-- The class quest chains are the hunter-only quests of the data pack's QuestieDB layer (a Classic Era baseline). The
-- quest IDs and levels are facts from there; each chain's races are the races whose chain it is. Forever's own
-- additions (new weapon-upgrade chains, trainer-offered lines: docs/CLASS-QUESTS.md) are not in that source, and
-- neither are the trainer spells; both come from in-game learning (Core/Learn.lua). The level-60 bow chain is left out.
-- VERIFY(beta): the level-10 pet chain may differ in Forever (a taming rod on three beasts, then Tame Beast).
-- `.tame` and `.ammo` directives are not written: the pet chain is plain quest objectives; ammunition is not routed.
ns.Classes:Register("HUNTER", {
	-- { [level] = { spellIDs } }: no spell IDs without a source; `.train class` stays empty until Learn records them.
	trainerSpells = {},
	classQuests = {
		{ id = "etched-note-troll", name = "Etched Tablet", level = 1, quests = { 3082 }, races = { "Troll" } },
		{ id = "etched-note-orc", name = "Etched Parchment", level = 1, quests = { 3087 }, races = { "Orc" } },
		{ id = "etched-note-tauren", name = "Etched Note", level = 1, quests = { 3092 }, races = { "Tauren" } },
		{
			id = "hunters-path",
			name = "The Hunter's Path / Taming the Beast",
			level = 10,
			-- three starting quests, one of which is taken: 6068, 6069 and 6070
			quests = { 6068, 6069, 6070, 6062, 6083, 6082, 6081 },
			races = { "Orc", "Troll" },
		},
		{
			id = "hunters-path-tauren",
			name = "The Hunter's Path / Taming the Beast",
			level = 10,
			quests = { 6065, 6066, 6067, 6061, 6087, 6088, 6089 },
			races = { "Tauren" },
		},
		{ id = "hunters-charm", name = "The Hunter's Charm", level = 52, quests = { 8151, 8153, 8231, 8232 } },
	},
})
