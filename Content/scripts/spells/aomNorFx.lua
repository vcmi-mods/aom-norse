-- Extra animations of Norse god powers (visual only, the battlefield is not changed). Effect key "1fx": after the sacrifice (0sac), before the damage.
--   "screen": animation   full-battlefield animation, placed on hex (8,10) with the full-screen technique (the blizzard of Fimbulwinter)
--   "perUnit": { "mass": "own"/"enemy", "filter": ..., "prefix": "aom/nor/fx/fw/", "known": ["creature key", ...], "fallback": animation }
--        plays a per-creature animation on each stack of one side: known creatures get prefix .. creature .. "_R" / "_L" .. ".json" (attacker facing right, defender left), others prefix .. fallback .. "_R"/"_L" (Flame Weapons: a ball of fire on the body)
local Base = require("spells/spellEffect")
local Sac = require("spells/aomNorSacCommon")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local function screenHex(battle)
	local arr = battle:getAllPossibleHexes()
	for i = 1, arr:size() do
		local h = arr:at(i)
		if h:getY() == 10 and h:getX() == 8 then return h end
	end
	return nil
end

function Script:applicableGeneral(mechanics, problem) return true end
function Script:applicableTarget(mechanics, problem, target) return true end
function Script:transformTarget(mechanics, aimPoint, spellTarget) return spellTarget end
function Script:filterTarget(mechanics, target) return target end
function Script:isValidTarget(mechanics, unit) return true end
function Script:isReceptive(mechanics, unit) return true end

function Script:apply(mechanics, server, target)
	if not server:describeChanges() then return end      -- the AI's trial runs get no animations
	local battle = mechanics:getBattle()
	if self.screen then
		local hex = screenHex(battle)
		if hex then server:showBattleAnimation(battle, { { hex = hex } }, self.screen, "", 1.0, false) end
	end
	local pu = self.perUnit
	if pu then
		local known = {}
		for _, k in ipairs(pu.known or {}) do known[k] = true end
		local groups = {}
		for _, d in ipairs(Sac.massTarget({ filter = pu.filter, isValidTarget = function() return true end, isReceptive = function() return true end }, mechanics, pu.mass or "own")) do
			local u = d.unit
			local key = Sac.shortKey(u)
			local dir = u:getSide() == ENUM.BattleSide.attacker and "_R" or "_L"
			local anim = pu.fallback and (pu.prefix .. pu.fallback .. dir .. ".json") or nil
			if known[key] then anim = pu.prefix .. key .. dir .. ".json" end
			if anim then
				groups[anim] = groups[anim] or {}
				table.insert(groups[anim], { unit = u })
			end
		end
		for anim, list in pairs(groups) do server:showBattleAnimation(battle, list, anim, "", 1.0, false) end
	end
end

return Script
