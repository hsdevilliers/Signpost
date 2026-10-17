-- Local stand-in for busted, for machines without a Lua toolchain (CI runs real busted): describe/it/before_each/
-- after_each/setup/teardown/pending with luassert's assert, spy, stub and mock. Spec files are passed as arguments.
-- Run: python tools/lua.py test   (sets package.path to the luassert copy in .venv/lua)
assert = require("luassert")
spy = require("luassert.spy")
stub = require("luassert.stub")
mock = require("luassert.mock")

local function newBlock(name, parent)
	return { name = name, parent = parent, children = {}, before = {}, after = {}, setup = {}, teardown = {} }
end

local root = newBlock("", nil)
local current = root

function describe(name, fn)
	local block = newBlock(name, current)
	current.children[#current.children + 1] = block
	current = block
	fn()
	current = block.parent
end
context = describe

function it(name, fn)
	current.children[#current.children + 1] = { name = name, fn = fn }
end

function pending(name)
	current.children[#current.children + 1] = { name = name, pending = true }
end

function before_each(fn)
	table.insert(current.before, fn)
end

function after_each(fn)
	table.insert(current.after, fn)
end

function setup(fn)
	table.insert(current.setup, fn)
end
lazy_setup = setup

function teardown(fn)
	table.insert(current.teardown, fn)
end
lazy_teardown = teardown

local results = { passed = 0, failed = {}, pending = 0 }

local function fullName(block, name)
	local parts = { name }
	while block and block.name ~= "" do
		table.insert(parts, 1, block.name)
		block = block.parent
	end
	return table.concat(parts, " ")
end

local function chain(block)
	local blocks = {}
	while block do
		table.insert(blocks, 1, block)
		block = block.parent
	end
	return blocks
end

local function traceback(err)
	return debug.traceback(tostring(err), 2)
end

local function runTest(block, test)
	local ok, err = true, nil
	local blocks = chain(block)
	for _, b in ipairs(blocks) do
		for _, fn in ipairs(b.before) do
			if ok then
				ok, err = xpcall(fn, traceback)
			end
		end
	end
	if ok then
		ok, err = xpcall(test.fn, traceback)
	end
	for i = #blocks, 1, -1 do
		for _, fn in ipairs(blocks[i].after) do
			local afterOk, afterErr = xpcall(fn, traceback)
			if ok and not afterOk then
				ok, err = afterOk, afterErr
			end
		end
	end
	if ok then
		results.passed = results.passed + 1
		io.write("+")
	else
		results.failed[#results.failed + 1] = { name = fullName(block, test.name), err = err }
		io.write("-")
	end
end

local function runBlock(block)
	for _, fn in ipairs(block.setup) do
		fn()
	end
	for _, child in ipairs(block.children) do
		if child.children then
			runBlock(child)
		elseif child.pending then
			results.pending = results.pending + 1
			io.write(".")
		else
			runTest(block, child)
		end
	end
	for _, fn in ipairs(block.teardown) do
		fn()
	end
end

for _, path in ipairs(arg) do
	-- Like busted, run each spec file in its own environment: its global assignments stay out of _G.
	local chunk = setfenv(assert(loadfile(path)), setmetatable({}, { __index = _G }))
	local fileBlock = newBlock(path, root)
	root.children[#root.children + 1] = fileBlock
	current = fileBlock
	chunk()
	current = root
end

runBlock(root)
io.write("\n")
for _, failure in ipairs(results.failed) do
	io.write("\nFAILED: ", failure.name, "\n", tostring(failure.err), "\n")
end
io.write(string.format("\n%d successes / %d failures / %d pending\n", results.passed, #results.failed, results.pending))
os.exit(#results.failed == 0 and 0 or 1)
