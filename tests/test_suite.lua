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

-- Add up to 4 sperm units
local u1 = session.data.colony[1]
local u2 = session.data.colony[2]
local u3 = genetics.create_random_specimen("SPERM-GAMMA", "sperm")
local u4 = genetics.create_random_specimen("SPERM-DELTA", "sperm")
table.insert(session.data.colony, u3)
table.insert(session.data.colony, u4)

session.add_to_squad(u2.id)
session.add_to_squad(u3.id)
session.add_to_squad(u4.id)

local squad = session.get_squad()
print("Squad count (only spermatozoa ♂):", #squad)
assert(#squad == 4, "Squad should have 4 sperm units")

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

print("--- 6. Testing Mutant Inbreeding Freak Cards ---")
local freak_sperm = genetics.create_random_specimen("MUTANT-HYDRA")
freak_sperm.freak_type = "freak_two_headed"
freak_sperm.phenotype = genetics.calculate_phenotype(freak_sperm)
assert(cards.DATABASE["bicephalic_bite"] ~= nil, "bicephalic_bite should exist in card DB")
local has_bicephalic = false
for _, cid in ipairs(freak_sperm.phenotype.deck) do
    if cid == "bicephalic_bite" then has_bicephalic = true end
end
assert(has_bicephalic, "Two-headed freak must contain bicephalic_bite cards in deck")
print("Freak mutation card verified:", freak_sperm.name, "contains bicephalic_bite")

-- Test play mutant card in combat
local freak_battle = combat.new({freak_sperm}, "neutrophil")
local bite_card = { data = cards.DATABASE["bicephalic_bite"], owner = freak_battle.heroes[1] }
freak_battle.atp = 10
local prev_hp = freak_battle.enemy.hp
local bite_ok = freak_battle:play_card(bite_card)
assert(bite_ok, "Playing bicephalic_bite should succeed")
assert(freak_battle.enemy.hp < prev_hp, "Enemy should take double-bite damage")
print("Mutant attack card resolved! Enemy HP before:", prev_hp, "after:", freak_battle.enemy.hp)

print("--- 7. Testing Physics Slingshot & Ricochet Combat Engine ---")
local physics_combat = require("src.engine.physics_combat")
local p_battle = physics_combat.new(squad, "neutrophil")
assert(#p_battle.heroes == 4, "Physics arena should have 4 sperm heroes")
assert(p_battle.phase == "aiming", "Initial phase should be aiming")
assert(#p_battle.enemies == 5, "Enemy formation should have leader + 3 bacteria + 1 antibody")
assert(#p_battle.vortices == 1, "Arena should feature chemotactic singularity vortex")
assert(p_battle.stamina_turns == 7, "Initial stamina turns should be 7")
print("Physics arena initialized. Formation enemies count:", #p_battle.enemies, "Vortices:", #p_battle.vortices)

-- Test aiming and slingshot launch
local hero1 = p_battle.heroes[1]
local aim_ok = p_battle:start_aiming(hero1.x, hero1.y)
assert(aim_ok, "start_aiming on hero position should succeed")
assert(p_battle.is_aiming, "is_aiming should be true")

p_battle:update_aiming(hero1.x - 80, hero1.y - 40)
p_battle:release_aim()
assert(hero1.is_flying, "Hero should be flying after release")
assert(p_battle.phase == "flying", "Phase should be flying")
assert(hero1.vx > 0, "Hero should have positive horizontal launch velocity")
print("Hero successfully launched! Initial vx:", math.floor(hero1.vx), "vy:", math.floor(hero1.vy))

-- Test mid-flight active ability trigger
local trig_ok = p_battle:trigger_mid_flight_ability()
assert(trig_ok, "Mid-flight ability should trigger successfully")
assert(hero1.ability_used, "hero.ability_used should be true")
print("Mid-flight ability triggered successfully in flight!")

-- Simulate physics steps with vortex gravity and bouncing
for step = 1, 60 do
    p_battle:update(0.016, 0, 0)
end
print("Simulated 60 physics frames. Hero position:", math.floor(hero1.x), math.floor(hero1.y), "Combo:", p_battle.combo_ricochets)

-- Test direct strike on enemy leader
local leader = p_battle.enemies[1]
local leader_hp_before = leader.hp
hero1.x = leader.x - 30
hero1.y = leader.y
hero1.vx = 400
hero1.vy = 0
p_battle:strike_enemy(hero1, leader)
assert(leader.hp < leader_hp_before, "Leader should take damage from physical strike")
print("Physical strike on enemy resolved! HP before:", leader_hp_before, "after:", leader.hp)

-- Test enemy phase and stamina reduction
p_battle:execute_enemy_phase()
assert(p_battle.stamina_turns == 6, "Stamina turns should decrement by 1 after enemy phase")
print("Enemy phase executed. Remaining stamina turns:", p_battle.stamina_turns, "pH:", p_battle.ph)

print(">>> ALL TESTS PASSED SUCCESSFULLY! <<<")
love.event.quit(0)
