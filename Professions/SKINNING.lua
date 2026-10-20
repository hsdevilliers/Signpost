local ADDON_NAME, ns = ...

-- Skill line 393: the beta client's own answer (C_TradeSkillUI.GetProfessionSkillLineID; FOREVER-API-NOTES).
-- The rank caps are Classic's (75, 150, 225, 300) until the launch client confirms them.
-- VERIFY(launch): rank caps and the rank-up thresholds.
ns.Professions:Register("skinning", {
	skillLine = 393,
	primary = true,
	gathering = true,
	ranks = { 75, 150, 225, 300 },
})
