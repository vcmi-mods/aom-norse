-- Settlement effect of Soul Offering: the first effect of every Norse god power (key aSac). Affects no unit; only spends Einherjar via aomNorSacCommon.consume and records the bonus.
local Base = require("spells/spellEffect")
local Sac = require("spells/aomNorSacCommon")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:applicableGeneral(mechanics, problem) return true end
function Script:applicableTarget(mechanics, problem, target) return true end
function Script:transformTarget(mechanics, aimPoint, spellTarget) return spellTarget end
function Script:filterTarget(mechanics, target) return target end
function Script:apply(mechanics, server, target) Sac.consume(mechanics, server) end

return Script
