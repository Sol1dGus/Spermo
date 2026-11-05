-- Headless integration test for Spermo
local genetics = require("src.engine.genetics")
local session = require("src.engine.session")
local cards = require("src.engine.cards")
local combat = require("src.engine.combat")

print("--- 1. Testing genetics & oocyte creation ---")
local sperm = genetics.create_random_specimen("SPERM-TEST", "sperm")
assert(sperm.unit_type == "sperm", "sperm.unit_type should be sperm")
assert(sperm.gender == "male", "sperm.gender should be male")
print("Sperm created:", sperm.name, sperm.class_title, "HP:", sperm.phenotype.max_hp)

local oocyte = genetics.create_random_oocyte("OVUM-TEST")
assert(oocyte.unit_type == "oocyte", "oocyte.unit_type should be oocyte")
assert(oocyte.gender == "female", "oocyte.gender should be female")
assert(oocyte.phenotype.max_hp >= 40, "oocyte max_hp should be >= 40")
print("Oocyte created:", oocyte.name, oocyte.class_title, "HP:", oocyte.phenotype.max_hp)

print("--- 2. Testing Mewgenics breeding between Sperm and Oocyte ---")
local child = genetics.breed(sperm, oocyte)
assert(child ~= nil, "child should not be nil")
print("Child born:", child.name, "Unit type:", child.unit_type, "Gender:", child.gender, "Class:", child.class_title)

print("--- 3. Testing session & squad formation (up to 4 units) ---")
session.new_game()
assert(#session.data.colony == 3, "Colony should have 3 starter units")
print("Starter colony size:", #session.data.colony)
for i, unit in ipairs(session.data.colony) do
    print("  Unit " .. i .. ":", unit.name, unit.unit_type, unit.gender)
end

-- Add up to 4 units
local u1 = session.data.colony[1]
local u2 = session.data.colony[2]
local u3 = session.data.colony[3]
local u4 = genetics.create_random_specimen("SPERM-DELTA")
table.insert(session.data.colony, u4)

session.add_to_squad(u2.id)
session.add_to_squad(u3.id)
session.add_to_squad(u4.id)

local squad = session.get_squad()
print("Squad count:", #squad)
assert(#squad == 4, "Squad should have 4 units")

print("--- 4. Testing Squad Combat (4 heroes vs Enemy) ---")
local battle = combat.new(squad, "neutrophil")
assert(#battle.heroes == 4, "Combat should have 4 heroes on board")
print("Combat initialized with 4 heroes. Hand size:", #battle.hand, "ATP:", battle.atp)

for i, cv in ipairs(battle.hand) do
    print("  Card " .. i .. ":", cv.data.name, "Cost:", cv.data.cost, "Category:", cv.data.category, "Owner:", cv.owner and cv.owner.name)
end

-- Play a card if affordable
if #battle.hand > 0 and battle.atp >= battle.hand[1].data.cost then
    local card_played = battle.hand[1]
    local ok = battle:play_card(card_played)
    print("Played card " .. card_played.data.name .. ":", ok, "Remaining ATP:", battle.atp, "Enemy HP:", battle.enemy.hp)
end

-- Test summon ally with taunt and enemy attack to verify fix
battle:summon_ally({ id = "test_lacto", name = "Test Ally", hp = 10, max_hp = 10, taunt = true })
print("Summoned taunt ally. Testing enemy attack on ally...")
battle:end_turn()
print("After turn ended with ally target. Phase:", battle.phase, "Turn:", battle.turn, "ATP:", battle.atp)

print("--- 5. Testing Cryo freeze & unfreeze mechanics ---")
local col_count_before = #session.data.colony
session.data.biomass = 100
local ok_freeze = session.freeze_specimen(1)
assert(ok_freeze, "Should freeze successfully")
assert(#session.data.cryo_vault == 1, "Cryo vault should have 1 specimen")
assert(#session.data.colony == col_count_before - 1, "Colony should have 1 less")
print("Specimen frozen successfully.")

local ok_unfreeze = session.unfreeze_specimen(1)
assert(ok_unfreeze, "Should unfreeze successfully")
assert(#session.data.cryo_vault == 0, "Cryo vault should be empty")
assert(#session.data.colony == col_count_before, "Colony should be restored")
print("Specimen unfrozen successfully.")

print(">>> ALL TESTS PASSED SUCCESSFULLY! <<<")
love.event.quit(0)
