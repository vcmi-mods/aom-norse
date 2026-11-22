-- Favor: the hero specialty style shared by all Age of Mythology towns (Norse version, adapted from the Atlantean aomFavor.lua).
-- Set up as a COMBAT_EVENT_TRIGGER in the hero specialty (inherited by the whole army), addInfo:
--   creatures  the hero's specialty creatures (identifiers of every form)
--   patron     patron minor god (for the minor blessing)
--   god        major god of the hero class: "thor", "odin", "loki", "freyr" (for the god power)
-- val = Favor gained at the start of each round.
-- Norse Favor is earned by fighting (as Norse players gain favor in battle in the original game): if any of our stacks acted last round, this round gains 1 more.
--
-- Favor is counted per side: the script fires once per unit, so two hidden counters tell whether this side was already settled this round -
--   AOM_NOR_FAVOR_SEEN  rounds this unit has seen; AOM_NOR_FAVOR_TICK  round this side has been settled up to.
-- Favor and the tiers already reached are stored on every unit of this side that has the script, so nothing is lost when a unit dies; the Favor value is visible on every non-war-machine stack
-- (earlier only on the specialty creatures, so it was invisible without them). War machines do not get this script (limiter in the specialty).
-- Battle log: one line per round "Favor N, next tier at M" (stops once all three tiers are reached); when a blessing fires, the concrete effect of the patron or major god is written.
--
-- Three blessing tiers (once each per battle, automatic, same for players and AI), thresholds 2, 4 and 7 as for the Atlanteans:
--   tier 1  Divinity: specialty creatures ignore 15% of the target's Defense for 2 rounds
--   tier 2  minor blessing: by patron
--   tier 3  god power: by god
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local FAVOR, SEEN, TICK, TIER, DIVINE, FOUGHT = "AOM_NOR_FAVOR", "AOM_NOR_FAVOR_SEEN", "AOM_NOR_FAVOR_TICK", "AOM_NOR_FAVOR_TIER", "AOM_NOR_DIVINITY", "AOM_NOR_FAVOR_FOUGHT"
local FAVOR_FX = "aom/nor/fx/hxFavor.json"      -- original hero_birth: golden light pillars fall and gather into a glow
local THRESHOLD = { 2, 4, 7 }
local PATRON_LOG = { forseti = 21, tyr = 22, freyja = 23, hel = 24, angrboda = 25, ullr = 26, vidar = 27, sigurd = 28 }
local GOD_LOG = { thor = 31, odin = 32, loki = 33, freyr = 34 }

local function real(server) return not server.describeChanges or server:describeChanges() end
local function showAnim(server, ...)
	if not real(server) then return end
	server:showBattleAnimation(...)
end
-- war machines and the Battering Ram show no Favor and are never blessing targets
local function isSiege(u) return u:hasBonuses({ type = "SIEGE_WEAPON" }) or u:getCreature():getJsonKey():match("aomNorRam$") ~= nil end
local function setValue(server, battle, unit, bonusType, value, hidden)
	local old = unit:getBonuses({ type = bonusType })
	if old:size() > 0 then server:removeUnitBonuses(battle, unit, old) end
	if value > 0 then
		server:addUnitBonus(battle, unit, {
			type       = bonusType,
			sourceType = ENUM.BonusSource.other,
			val        = value,
			valueType  = ENUM.BonusValueType.baseNumber,
			duration   = ENUM.BonusDuration.oneBattle,
			hidden     = hidden
		}, false)
	end
end

local function shortKey(unit)
	local key = unit:getCreature():getJsonKey()
	key = key:match("([^:]+)$") or key
	-- kad shrunk and downgraded copies (kadMini_aom_norse_<creature> etc.) count as the original creature
	return key:match("^kad%a+_aom_norse_(.+)$") or key
end

function Script:isFavored(unit)
	local key = shortKey(unit)
	for _, id in ipairs(self.creatures or {}) do
		if id == key then return true end
	end
	return false
end

--- all living units of this side that carry this script
local function sideUnits(battle, unit)
	local side = unit:getSide()
	return battle:getUnitsIf(function(u)
		return u:isAlive() and u:getSide() == side and u:getBonusesValue({ type = SEEN }) > 0
	end)
end

local function sideMax(units, bonusType)
	local best = 0
	for _, u in ipairs(units) do
		best = math.max(best, u:getBonusesValue({ type = bonusType }))
	end
	return best
end

local function buff(server, battle, u, bonus)      -- [town_design2]
	bonus.sourceType = ENUM.BonusSource.other
	bonus.valueType = bonus.valueType or ENUM.BonusValueType.additiveValue
	server:addUnitBonus(battle, u, bonus, false)
end

local function living(u)
	return not u:hasBonuses({ type = "NON_LIVING" }) and not u:hasBonuses({ type = "MECHANICAL" }) and not u:hasBonuses({ type = "UNDEAD" }) and not u:hasBonuses({ type = "SIEGE_WEAPON" })
end

local function healPct(server, battle, list, pct)
	local healed = {}
	for _, u in ipairs(list) do
		if living(u) then
			local missing = u:getMaxHealth() - u:getFirstHPleft()
			local amount = math.min(missing, math.ceil(u:getMaxHealth() * pct / 100))
			if amount > 0 then server:healUnit(battle, u, amount, ENUM.HealLevel.heal, ENUM.HealPower.permanent) healed[#healed + 1] = { unit = u } end
		end
	end
	if #healed > 0 then showAnim(server, battle, healed, "C06SPW", "CURE", 1.0, true) end
end

function Script:grant(server, battle, units, tier, favor)
	local favored = {}
	for _, u in ipairs(units) do
		if self:isFavored(u) then favored[#favored + 1] = u end
	end
	if #units == 0 then return end
	local wholeArmy = tier == 3 or (tier == 2 and self.patron == "freyja")
	-- specialty creatures absent: the two specialty-only tiers go to our stack with the highest total health (as for the Atlanteans)
	if #favored == 0 and not wholeArmy then
		local best, bestHp
		for _, u in ipairs(units) do
			if not isSiege(u) then
				local hp = (u:getCount() - 1) * u:getMaxHealth() + u:getFirstHPleft()
				if not best or hp > bestHp then best, bestHp = u, hp end
			end
		end
		if not best then return end
		favored[1] = best
	end
	local targets = {}
	for _, u in ipairs(favored) do targets[#targets + 1] = { unit = u } end
	local side = units[1]:getSide()
	local function enemies() return battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() ~= side end) end

	if tier == 1 then
		for _, u in ipairs(favored) do
			buff(server, battle, u, { type = "ENEMY_DEFENCE_REDUCTION", val = 15, duration = ENUM.BonusDuration.nTurns, turns = 2, hidden = true })
			buff(server, battle, u, { type = DIVINE, val = 1, valueType = ENUM.BonusValueType.baseNumber, duration = ENUM.BonusDuration.nTurns, turns = 2 })
		end
		showAnim(server, battle, targets, FAVOR_FX, "BLESS", 1.0, true)
	elseif tier == 2 then
		local p = self.patron
		if p == "forseti" then          -- Forseti, Healing Spring: the (first) specialty stack is healed to full
			for _, u in ipairs(favored) do
				local missing = u:getMaxHealth() - u:getFirstHPleft()
				if missing > 0 then server:healUnit(battle, u, missing, ENUM.HealLevel.heal, ENUM.HealPower.permanent) end
			end
			showAnim(server, battle, targets, "C06SPW", "CURE", 1.0, true)
		elseif p == "tyr" then          -- Tyr, Valor of the War God: Attack +6 for 2 rounds
			for _, u in ipairs(favored) do buff(server, battle, u, { type = "PRIMARY_SKILL", subtype = "attack", val = 6, duration = ENUM.BonusDuration.nTurns, turns = 2, hidden = true }) end
			showAnim(server, battle, targets, FAVOR_FX, "BLESS", 1.0, true)
		elseif p == "freyja" then       -- Freyja, Tears of the Goddess: all our living units regain 20% health
			healPct(server, battle, units, 20)
		elseif p == "hel" then          -- Hel, Might of the Queen of the Dead: damage +25% for 2 rounds
			for _, u in ipairs(favored) do buff(server, battle, u, { type = "PERCENTAGE_DAMAGE_BOOST", subtype = "damageTypeAll", val = 25, duration = ENUM.BonusDuration.nTurns, turns = 2, hidden = true }) end
			showAnim(server, battle, targets, FAVOR_FX, "BLESS", 1.0, true)
		elseif p == "angrboda" then     -- Angrboda, Shelter of the Giant Mother: damage taken this round -50%
			for _, u in ipairs(favored) do buff(server, battle, u, { type = "GENERAL_DAMAGE_REDUCTION", subtype = "damageTypeAll", val = 50, duration = ENUM.BonusDuration.nTurns, turns = 1, hidden = true }) end
			showAnim(server, battle, targets, FAVOR_FX, "BLESS", 1.0, true)
		elseif p == "ullr" then         -- Ullr, Eye of the Hunter: ranged damage +30% for 2 rounds
			for _, u in ipairs(favored) do buff(server, battle, u, { type = "PERCENTAGE_DAMAGE_BOOST", subtype = "damageTypeRanged", val = 30, duration = ENUM.BonusDuration.nTurns, turns = 2, hidden = true }) end
			showAnim(server, battle, targets, FAVOR_FX, "BLESS", 1.0, true)
		elseif p == "vidar" then        -- Vidar, Silent Vengeance: Attack and Defense +4 for 2 rounds
			for _, u in ipairs(favored) do
				buff(server, battle, u, { type = "PRIMARY_SKILL", subtype = "attack", val = 4, duration = ENUM.BonusDuration.nTurns, turns = 2, hidden = true })
				buff(server, battle, u, { type = "PRIMARY_SKILL", subtype = "defence", val = 4, duration = ENUM.BonusDuration.nTurns, turns = 2, hidden = true })
			end
			showAnim(server, battle, targets, FAVOR_FX, "BLESS", 1.0, true)
		elseif p == "sigurd" then       -- Sigurd, Dragonslayer's Valor: one extra attack this round
			for _, u in ipairs(favored) do buff(server, battle, u, { type = "ADDITIONAL_ATTACK", val = 1, duration = ENUM.BonusDuration.nTurns, turns = 1, hidden = true }) end
			showAnim(server, battle, targets, FAVOR_FX, "BLESS", 1.0, true)
		else
			return
		end
	else
		local g = self.god
		if g == "thor" then             -- Thunderous Dread: all enemies Defense -4 for 2 rounds
			for _, e in ipairs(enemies()) do buff(server, battle, e, { type = "PRIMARY_SKILL", subtype = "defence", val = -4, duration = ENUM.BonusDuration.nTurns, turns = 2 }) end
		elseif g == "odin" then         -- Raven Omen: our whole army Morale +1 and Attack +2 for 2 rounds
			for _, u in ipairs(units) do
				buff(server, battle, u, { type = "MORALE", val = 1, duration = ENUM.BonusDuration.nTurns, turns = 2 })
				buff(server, battle, u, { type = "PRIMARY_SKILL", subtype = "attack", val = 2, duration = ENUM.BonusDuration.nTurns, turns = 2 })
			end
		elseif g == "loki" then         -- Trickery: all enemies Attack -3 for 2 rounds
			for _, e in ipairs(enemies()) do buff(server, battle, e, { type = "PRIMARY_SKILL", subtype = "attack", val = -3, duration = ENUM.BonusDuration.nTurns, turns = 2 }) end
		elseif g == "freyr" then        -- Abundance: all our living units regain 30% health
			healPct(server, battle, units, 30)
		else
			return
		end
	end
	server:refreshBattleUnits(battle)
	if not real(server) then return end
	local key = tier == 1 and 1 or (tier == 2 and PATRON_LOG[self.patron] or GOD_LOG[self.god])
	if key == nil then return end
	local who = favored[1]
	local log = { append = { "core.bonus." .. FAVOR .. ".description." .. key }, replaceNumbers = { favor } }
	if who and (tier == 1 or (tier == 2 and key ~= 23)) then
		log.replaceStrings = { who:getCreature():getNameTextID(who:getCount()) }
	end
	server:appendLog(battle, log)
end

-- one of our stacks acted: remember it, +1 Favor next round
function Script:onAfterAttack(server, battle, unit, other, payload)
	if unit:getBonusesValue({ type = SEEN }) <= 0 then return end
	for _, u in ipairs(sideUnits(battle, unit)) do setValue(server, battle, u, FOUGHT, 1, true) end
end

function Script:onBattleStart(server, battle, unit, other)
	setValue(server, battle, unit, SEEN, 1, true)
end

function Script:onRoundStart(server, battle, unit, other)
	if not unit:isAlive() then return end

	local seen = unit:getBonusesValue({ type = SEEN }) + 1
	setValue(server, battle, unit, SEEN, seen, true)

	local units = sideUnits(battle, unit)
	if sideMax(units, TICK) >= seen then return end

	-- Prayer (for a future Norse commander, like the Atlantean Chief Oracle): gain AOM_NOR_FAVOR_PRAY more each round
	local side = unit:getSide()
	local pray = sideMax(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side end), "AOM_NOR_FAVOR_PRAY")
	local fought = sideMax(units, FOUGHT)
	local favor = sideMax(units, FAVOR) + (self.val or 1) + pray + fought
	local tier  = sideMax(units, TIER)
	local reached = tier
	for i, need in ipairs(THRESHOLD) do
		if favor >= need then reached = math.max(reached, i) end
	end

	for _, u in ipairs(units) do
		setValue(server, battle, u, TICK, seen, true)
		setValue(server, battle, u, FAVOR, favor, isSiege(u))
		setValue(server, battle, u, TIER, reached, true)
		setValue(server, battle, u, FOUGHT, 0, true)
	end

	for t = tier + 1, reached do
		self:grant(server, battle, units, t, favor)
	end
	if reached < #THRESHOLD and real(server) then
		server:appendLog(battle, { append = { "core.bonus." .. FAVOR .. ".description.9" }, replaceNumbers = { favor, THRESHOLD[reached + 1] } })
	end
end

return Script
