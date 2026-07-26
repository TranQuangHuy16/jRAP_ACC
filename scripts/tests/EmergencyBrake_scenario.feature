# --- front-matter:toml ---
model = "ACC_Main.slx"
component = "ACC_Main/Model8"
[inputs]
LeadPresent = "LeadPresent"
Distance = "ActualDistance_m"
ClosingSpeed = "ClosingSpeed_kmh"
NormalThrottle = "NormalThrottle"
NormalBrake = "NormalBrake"
[outputs]
FinalThrottle = "FinalThrottle"
FinalBrake = "FinalBrake"
Active = "EmergencyBrakeActive"
# --- end front-matter ---

Feature: Emergency brake overrides normal control when collision risk is high
  Covers PBI-13 (emergency brake override) and PBI-19 (emergency brake scenario).

Scenario: PBI-19 - Closing distance below the emergency threshold triggers full brake
  When the gap to the lead vehicle collapses, the module must override normal throttle/brake with full emergency braking.
  Given inputs
    * LeadPresent = const(1)
    * Distance = step(50 -> 2 @ 1s)
    * ClosingSpeed = const(40)
    * NormalThrottle = const(0.6)
    * NormalBrake = const(0)
  When simulate for 2s in Normal mode
  Then outputs
    * Triggered: Active == 1 when t > 1s
    * ThrottleCut: FinalThrottle == 0 when t > 1s
    * FullBrake: FinalBrake > 0.8 when t > 1s

Scenario: Safe distance leaves normal throttle and brake unaffected
  With a safe following distance, the module must simply pass through the normal throttle and brake commands.
  Given inputs
    * LeadPresent = const(1)
    * Distance = const(200)
    * ClosingSpeed = const(5)
    * NormalThrottle = const(0.4)
    * NormalBrake = const(0)
  When simulate for 1s in Normal mode
  Then outputs
    * NotTriggered: Active == 0
    * ThrottlePassthrough: FinalThrottle == [0.39 .. 0.41]
