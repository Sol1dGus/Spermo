-- Headless integration test suite for Spermo: Eco Clinic & Bio-Salvage Simulator
local genetics = require("src.engine.genetics")
local session = require("src.engine.session")
local clinic = require("src.engine.clinic")
local salvage = require("src.engine.salvage")

print("==================================================")
print("   SPERMO CLINIC & BIO-SALVAGE INTEGRATION TESTS  ")
print("==================================================")

print("--- 1. Testing Session Initialization ---")
session.new_game()
assert(session.data ~= nil, "Session data must be initialized")
assert(session.data.funds >= 400, "Starter funds should be at least 400")
assert(session.data.reputation >= 50, "Starter reputation should be 50")
assert(#session.data.active_orders > 0, "Must generate starter client orders")
assert(#session.data.active_specimens >= 3, "Must have starter specimens in petri dish")
assert(#session.data.salvage_lots > 0, "Must generate starter salvage lots in archive")
print("✓ Session initialized. Day:", session.data.day, "Funds:", session.data.funds, "Orders:", #session.data.active_orders)

print("--- 2. Testing Clinical Order Generation & Compliance Evaluation ---")
local order = session.data.active_orders[1]
assert(order.client_name ~= nil, "Order must have client info")
assert(order.requirements ~= nil, "Order must have genetic requirements")
print("Order from:", order.client_name, "| Reward:", order.reward_money .. "₽", "| Target:", order.title)

-- Create a specimen tailored to test compliance
local test_specimen = genetics.create_random_specimen("TEST-DONOR-01", "sperm")
assert(test_specimen.phenotype.motility ~= nil, "Phenotype must have motility")
assert(test_specimen.phenotype.acrosome_potency ~= nil, "Phenotype must have acrosome potency")
assert(test_specimen.phenotype.membrane_barrier ~= nil, "Phenotype must have membrane barrier")
assert(test_specimen.phenotype.kruger_normality ~= nil, "Phenotype must have kruger normality")

local score, matches, failures = genetics.evaluate_compliance(test_specimen, order.requirements)
assert(score >= 0 and score <= 100, "Compliance score must be 0-100%")
print("✓ Compliance evaluated:", score .. "% (" .. #matches .. " matches, " .. #failures .. " violations)")

print("--- 3. Testing Bio-Salvage (Scrapyard) Lot Purchase ---")
local initial_funds = session.data.funds
local lot = session.data.salvage_lots[1]
local lot_cost = lot.cost
local lot_id = lot.id
local buy_ok, buy_msg = session.buy_salvage_lot(lot_id)
assert(buy_ok, "Salvage lot purchase should succeed: " .. tostring(buy_msg))
assert(session.data.funds == initial_funds - lot_cost, "Funds must decrease by lot cost")
assert(#session.data.unrestored_vials == 1, "Unrestored vials must increase")
print("✓ Salvage lot bought:", lot.label, "Condition:", lot.condition, "Cost:", lot_cost)

print("--- 4. Testing Centrifuge Purification & Gene Restoration ---")
local vial = session.data.unrestored_vials[1]
assert(vial.sample.is_restored == false, "Vial should initially be unrestored")
local spec_count_before = #session.data.active_specimens
local restore_ok, restored_spec = session.restore_vial(vial.id)
assert(restore_ok, "Vial restoration must succeed: " .. tostring(restored_spec))
assert(restored_spec.is_restored == true, "Restored specimen must have is_restored=true")
assert(#session.data.active_specimens == spec_count_before + 1, "Restored specimen should be added to active specimens")
print("✓ Vial restored in centrifuge! Name:", restored_spec.name, "Class:", restored_spec.class_title, "Loci ch1:", restored_spec.chromosomes.ch1)

print("--- 5. Testing ICSI (Intracytoplasmic Sperm Injection) ---")
local sperm_donor = nil
local ovum_donor = nil
for _, s in ipairs(session.data.active_specimens) do
    if s.unit_type == "sperm" and not sperm_donor then sperm_donor = s end
    if s.unit_type == "oocyte" and not ovum_donor then ovum_donor = s end
end

if not ovum_donor then
    ovum_donor = genetics.create_random_oocyte("DONOR-OVUM-A")
    table.insert(session.data.active_specimens, ovum_donor)
end

assert(sperm_donor ~= nil, "Need sperm donor")
assert(ovum_donor ~= nil, "Need ovum donor")

local embryo, icsi_err = session.perform_icsi(sperm_donor, ovum_donor)
assert(embryo ~= nil, "ICSI fertilization must produce embryo: " .. tostring(icsi_err))
assert(embryo.is_embryo == true, "Embryo flag must be set")
assert(embryo.phenotype ~= nil, "Embryo must have phenotype")
print("✓ ICSI Fertilization successful! Embryo:", embryo.name, "Acrosome:", embryo.phenotype.acrosome_potency, "Motility:", embryo.phenotype.motility)

print("--- 6. Testing Order Submission & Payout ---")
local funds_before = session.data.funds
local rep_before = session.data.reputation
-- Ensure test specimen satisfies the order requirements by adjusting if needed
test_specimen.phenotype.frequency_hz = 50
test_specimen.phenotype.kruger_normality = 90
test_specimen.phenotype.membrane_barrier = 15
test_specimen.phenotype.acrosome_potency = 20
test_specimen.freak_type = order.requirements.require_freak or nil
table.insert(session.data.active_specimens, test_specimen)

local submit_ok, earned, score_sub = session.submit_order(order.id, test_specimen)
assert(submit_ok, "Order submission should succeed: " .. tostring(earned))
assert(session.data.funds > funds_before, "Funds must increase after order payout")
print("✓ Order fulfilled! Payout awarded: +" .. earned .. "₽. Old funds:", funds_before, "New funds:", session.data.funds, "Rep:", session.data.reputation)

print("--- 7. Testing Day Advancement & Archive Refresh ---")
local day_before = session.data.day
local report = session.advance_day()
assert(session.data.day == day_before + 1, "Day must increment")
assert(#session.data.salvage_lots > 0, "New salvage lots must be generated")
assert(#session.data.active_orders > 0, "Active orders must be replenished")
print("✓ Day advance successful: Day " .. session.data.day .. ". Daily rent paid: " .. (report.rent_paid or 0) .. "₽")

print("==================================================")
print("   ALL CLINIC TESTS PASSED SUCCESSFULLY! (7/7)   ")
print("==================================================")
