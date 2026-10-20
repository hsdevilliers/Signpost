local ADDON_NAME, ns = ...

-- Skill line 197: from the beta client probe (C_TradeSkillUI.GetProfessionSkillLineID, FOREVER-API-NOTES "Professions").
-- The rank caps are Classic's (Apprentice 75, Journeyman 150, Expert 225, Artisan 300) until the launch client confirms them.
-- VERIFY(launch): rank caps and the rank-up thresholds.
ns.Professions:Register("tailoring", {
	skillLine = 197,
	primary = true,
	gathering = false,
	ranks = { 75, 150, 225, 300 },
})
