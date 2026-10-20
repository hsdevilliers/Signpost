-- Automation: vendors (PLAN §3.4). Off by default (`vendor`). On MERCHANT_SHOW during a `.buy <itemID>,<count>` step,
-- buys what is missing to reach `count` in the bags, no more than the gold above the reserve pays for and no more than
-- the vendor has. Only items the step lists; nothing else the vendor sells.
local ADDON_NAME, ns = ...
local Util = ns.Util
local Automation = ns.Automation

local Vendor = {}
Automation.Vendor = Vendor

local DEFAULT_MAX_PURCHASE = 20 -- units per BuyMerchantItem call when the client does not say

local function plain(value)
	if type(value) == "number" and not Util.IsSecret(value) and value == value then
		return value
	end
end

-- One vendor slot as { price (copper per purchase), stack (items per purchase), available (nil: unlimited),
-- purchasable, extended }. VERIFY(beta): C_MerchantFrame.GetItemInfo returns a table (retail) or the old values
-- (name, texture, price, quantity, numAvailable, isUsable...), and numAvailable is -1 for unlimited stock.
function Vendor.SlotInfo(index)
	local api = C_MerchantFrame and C_MerchantFrame.GetItemInfo
	local result = Util.Pack(Util.Call(api, index))
	local info
	if type(result[1]) == "table" then
		local t = result[1]
		info = {
			price = plain(t.price),
			stack = plain(t.stackCount),
			available = plain(t.numAvailable),
			purchasable = t.isPurchasable,
			extended = t.hasExtendedCost,
		}
	else
		info = {
			price = plain(result[3]),
			stack = plain(result[4]),
			available = plain(result[5]),
			purchasable = result[6],
			extended = result[8],
		}
	end
	info.stack = (info.stack and info.stack >= 1) and info.stack or 1
	if info.available and info.available < 0 then
		info.available = nil
	end
	return info
end

-- Purchases to make for one wanted item: how many (of `stack` items each), 0 when none.
function Vendor.Purchases(info, missing, money, reserve)
	if missing <= 0 or info.purchasable == false or info.extended == true or not info.price then
		return 0
	end
	local count = math.ceil(missing / info.stack)
	if info.available then
		count = math.min(count, info.available)
	end
	if info.price > 0 then
		count = math.min(count, math.floor(math.max(money - reserve, 0) / info.price))
	end
	return math.max(count, 0)
end

local function wantedItems()
	local wanted = {}
	for _, entry in ipairs(Automation:Directives("buy")) do
		local itemID, count = plain(entry.args.itemID), plain(entry.args.count)
		if itemID and count then
			wanted[#wanted + 1] = { itemID = itemID, count = count }
		end
	end
	return wanted
end

function Vendor:OnShow()
	if not Automation:Allowed("vendor") then
		return
	end
	local wanted = wantedItems()
	if #wanted == 0 then
		return
	end
	local money, reserve = plain(Util.Call(GetMoney)) or 0, Automation:Reserve()
	local slots = plain(Util.Call(GetMerchantNumItems)) or 0
	for _, item in ipairs(wanted) do
		local have = plain(Util.Call(C_Item and C_Item.GetItemCount, item.itemID)) or 0
		for index = 1, slots do
			if plain(Util.Call(GetMerchantItemID, index)) == item.itemID then
				local info = Vendor.SlotInfo(index)
				local purchases = Vendor.Purchases(info, item.count - have, money, reserve)
				-- VERIFY(beta): BuyMerchantItem(index, quantity) counts purchases (bundles of info.stack), up to the
				-- item's maximum per call (GetMerchantItemMaxStack).
				local chunk = plain(Util.Call(Util.Resolve("GetMerchantItemMaxStack"), index)) or DEFAULT_MAX_PURCHASE
				local left = purchases
				while left > 0 do
					local now = math.min(left, math.max(chunk, 1))
					Util.Call(BuyMerchantItem, index, now)
					left = left - now
				end
				money = money - purchases * (info.price or 0)
				break
			end
		end
	end
end

ns.Events:Register("MERCHANT_SHOW", function()
	Vendor:OnShow()
end)
