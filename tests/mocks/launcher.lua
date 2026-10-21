-- What UI/Launcher.lua talks to besides the engine, for tests/launcher_spec.lua and the Journal's settings specs:
--   * LibDataBroker-1.1 and LibDBIcon-1.0 on the fake LibStub of tests/mocks/context.lua, shaped after the copy in
--     Libs/LibDBIcon-1.0 (minor 57): Register refuses an object without an icon and a second registration, Hide and
--     Show only act on the button (the saved `hide` flag is the caller's), Lock sets db.lock = true and Unlock clears
--     it to nil;
--   * the client's Menu system: MenuUtil.CreateContextMenu(owner, generator) runs the generator on a root description
--     that records what it adds (CreateTitle, CreateButton, CreateCheckbox, CreateDivider) and lets a spec click it;
--   * GameTooltip and LibDBIcon's own tooltip, the AddOn Compartment frame and the modifier-key functions.
--
--   local client = launcherMock.install(G.LibStub)   -- in addon.load's `before`, after contextMock.install
--   client.click("Signpost", "RightButton")          -- what LibDBIcon does when the button is clicked
--   launcherMock.uninstall()                          -- in after_each
local M = {}

-- Globals defined here that tests/wow_mock.lua does not clear on install.
local OWN = {
	"MenuUtil",
	"GameTooltip",
	"AddonCompartmentFrame",
	"IsShiftKeyDown",
	"IsControlKeyDown",
	"IsAltKeyDown",
}

-- The Key Bindings labels the addon sets (BINDING_HEADER_*, BINDING_NAME_*; tests/wow_mock.lua clears the compartment's
-- functions). Cleared at install, so that a spec sees what its own load defined and not what an earlier test left.
local function clearBindingLabels()
	for name in pairs(_G) do
		if type(name) == "string" and name:find("^BINDING_") then
			_G[name] = nil
		end
	end
end

local function newTooltip()
	local tip = { lines = {}, shown = false }
	function tip.SetOwner(self, owner, anchor)
		self.owner, self.anchor, self.lines, self.shown = owner, anchor, {}, false
	end
	function tip.AddLine(self, text, r, g, b, wrap)
		self.lines[#self.lines + 1] = { text = text, r = r, g = g, b = b, wrap = wrap }
	end
	function tip.Show(self)
		self.shown = true
	end
	function tip.Hide(self)
		self.shown, self.owner = false, nil
	end
	function tip.IsOwned(self, frame)
		return self.owner == frame
	end
	-- The lines' texts, in order.
	function tip.texts(self)
		local out = {}
		for i, line in ipairs(self.lines) do
			out[i] = line.text
		end
		return out
	end
	return tip
end

-- A root description as the Menu system hands to a generator: every call is recorded in order as an entry that a spec
-- can read (kind, text) and use (entry.click(), entry.selected()).
local function newRoot(menu)
	local root = { entries = {} }
	local function add(entry)
		root.entries[#root.entries + 1] = entry
		return entry
	end
	function root.CreateTitle(_, text)
		return add({ kind = "title", text = text })
	end
	function root.CreateDivider()
		return add({ kind = "divider" })
	end
	function root.CreateButton(_, text, callback, data)
		local entry = { kind = "button", text = text }
		function entry.click()
			return callback(data, { buttonName = "LeftButton" }, menu)
		end
		return add(entry)
	end
	function root.CreateCheckbox(_, text, isSelected, onSelect, data)
		local entry = { kind = "checkbox", text = text }
		function entry.selected()
			return isSelected(data)
		end
		function entry.click()
			return onSelect(data, { buttonName = "LeftButton" }, menu)
		end
		return add(entry)
	end
	-- The texts of the entries in order, a divider as "-".
	function root.layout()
		local out = {}
		for i, entry in ipairs(root.entries) do
			out[i] = entry.kind == "divider" and "-" or entry.text
		end
		return out
	end
	-- The entry with this text.
	function root.entry(text)
		for _, entry in ipairs(root.entries) do
			if entry.text == text then
				return entry
			end
		end
	end
	return root
end

function M.uninstall()
	for _, name in ipairs(OWN) do
		_G[name] = nil
	end
end

-- opts.noMenu: the client has no Menu system; opts.noLibs: LibDataBroker and LibDBIcon are not there;
-- opts.noCompartment: no AddonCompartmentFrame.
function M.install(libStub, opts)
	opts = opts or {}
	M.uninstall()
	clearBindingLabels()
	local client = {
		shift = false,
		ctrl = false,
		alt = false,
		menus = {}, -- every context menu opened: { owner, root }
		objects = {}, -- the data objects LibDataBroker made, by name
		buttons = {}, -- the LibDBIcon buttons, by name: { object, db, frame, hidden, locked }
		calls = {}, -- LibDBIcon calls that changed a button, as { "Hide", "Signpost" }
		tooltip = newTooltip(), -- LibDBIcon's own tooltip
		gameTooltip = newTooltip(),
	}

	local function button(name)
		return client.buttons[name]
	end

	function IsShiftKeyDown()
		return client.shift
	end
	function IsControlKeyDown()
		return client.ctrl
	end
	function IsAltKeyDown()
		return client.alt
	end
	GameTooltip = client.gameTooltip
	if not opts.noCompartment then
		AddonCompartmentFrame = { name = "AddonCompartmentFrame" }
		client.compartment = AddonCompartmentFrame
	end

	if not opts.noMenu then
		MenuUtil = {
			CreateContextMenu = function(owner, generator)
				local menu = { owner = owner }
				menu.root = newRoot(menu)
				generator(owner, menu.root)
				client.menus[#client.menus + 1] = menu
				return menu
			end,
		}
	end

	if not opts.noLibs then
		local broker = {}
		function broker.NewDataObject(_, name, object)
			if client.objects[name] then
				return nil
			end
			client.objects[name] = object
			return object
		end

		local icon = {}
		function icon.Register(_, name, object, db)
			if not object.icon then
				error("Can't register LDB objects without icons set!")
			end
			if button(name) then
				error("LibDBIcon-1.0: Object '" .. name .. "' is already registered.")
			end
			client.buttons[name] = {
				object = object,
				db = db,
				frame = { name = "LibDBIcon10_" .. name },
				hidden = db ~= nil and db.hide == true,
				locked = db ~= nil and db.lock == true,
			}
		end
		function icon.IsRegistered(_, name)
			return button(name) ~= nil
		end
		function icon.Hide(_, name)
			client.calls[#client.calls + 1] = { "Hide", name }
			if button(name) then
				button(name).hidden = true
			end
		end
		function icon.Show(_, name)
			client.calls[#client.calls + 1] = { "Show", name }
			if button(name) then
				button(name).hidden = false
			end
		end
		function icon.Lock(_, name)
			client.calls[#client.calls + 1] = { "Lock", name }
			local b = button(name)
			if b then
				b.locked = true
				if b.db then
					b.db.lock = true
				end
			end
		end
		function icon.Unlock(_, name)
			client.calls[#client.calls + 1] = { "Unlock", name }
			local b = button(name)
			if b then
				b.locked = false
				if b.db then
					b.db.lock = nil
				end
			end
		end
		libStub.libs["LibDataBroker-1.1"] = broker
		libStub.libs["LibDBIcon-1.0"] = icon
	end

	-- A click on a LibDBIcon button: the library hands the button's frame and the mouse button to the object's OnClick.
	function client.click(name, mouseButton)
		local b = button(name)
		b.object.OnClick(b.frame, mouseButton)
	end

	-- Hovering a LibDBIcon button: its own tooltip, owned by the button, filled by the object, then shown.
	function client.hover(name)
		local b = button(name)
		client.tooltip:SetOwner(b.frame, "ANCHOR_NONE")
		b.object.OnTooltipShow(client.tooltip)
		client.tooltip:Show()
	end

	-- The last menu opened.
	function client.lastMenu()
		return client.menus[#client.menus]
	end

	return client
end

return M
