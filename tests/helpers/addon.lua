-- Loads Signpost's own files (Libs/ skipped) in TOC order into a fresh namespace on a freshly installed mock client.
local wowMock = dofile("tests/wow_mock.lua")

local M = {}

function M.files()
	local files = {}
	for line in io.lines("Signpost.toc") do
		line = line:gsub("\r$", "")
		if line ~= "" and not line:find("^#") and not line:find("^Libs\\") then
			files[#files + 1] = (line:gsub("\\", "/"))
		end
	end
	return files
end

-- opts.before(mock): runs after the mock is installed and before any addon file loads (e.g. to set a data pack).
-- opts.login == false: stop after loading the files, before ADDON_LOADED and PLAYER_LOGIN.
function M.load(opts)
	opts = opts or {}
	local mock = wowMock.install()
	if opts.before then
		opts.before(mock)
	end
	local ns = {}
	for _, path in ipairs(M.files()) do
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
