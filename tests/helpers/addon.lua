-- Loads Signpost's own files (Libs/ skipped) in TOC order into a fresh namespace on a freshly installed mock client.
local wowMock = dofile("tests/wow_mock.lua")

local M = {}

-- The real global table, which the addon and the mock use. busted runs each spec file in its own environment, so a
-- spec's plain global assignments never reach the addon: specs set client globals through addon.G.
M.G = _G

function M.files()
	local files = {}
	for line in io.lines("Signpost.toc") do
		line = line:gsub("\r$", "")
		-- The shipped guides and chapters are content, not engine: a spec registers the guides it needs
		-- (tests/shipped_guides_spec.lua loads the real ones), so the real route never picks a test player's guide.
		local content = line:find("^Guides\\") and not line:find("^Guides\\Travel\\")
		if line ~= "" and not line:find("^#") and not line:find("^Libs\\") and not content then
			files[#files + 1] = (line:gsub("\\", "/"))
		end
	end
	return files
end

-- opts.before(mock): runs after the mock is installed and before any addon file loads (e.g. to set a data pack).
-- opts.extra: files not in the TOC yet, loaded after the TOC files in the given order; a file the TOC already lists
-- is not loaded twice, so specs keep working once the module joins the TOC.
-- opts.login == false: stop after loading the files, before ADDON_LOADED and PLAYER_LOGIN.
function M.load(opts)
	opts = opts or {}
	local mock = wowMock.install()
	if opts.before then
		opts.before(mock)
	end
	local ns = {}
	local files, listed = M.files(), {}
	for _, path in ipairs(files) do
		listed[path] = true
	end
	for _, path in ipairs(opts.extra or {}) do
		if not listed[path] then
			files[#files + 1] = path
			listed[path] = true
		end
	end
	for _, path in ipairs(files) do
		local chunk = assert(loadfile(path))
		chunk("Signpost", ns)
	end
	if opts.login ~= false then
		mock.fire("ADDON_LOADED", "Signpost")
		mock.fire("PLAYER_LOGIN")
	end
	return ns, mock
end

return M
