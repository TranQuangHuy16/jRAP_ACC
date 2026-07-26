# --- front-matter:toml ---
model = "ACC_Main.slx"
component = "ACC_Main/SpeedArbitration"
[inputs]
DesiredSpeed = "DesiredSpeed_kmh"
LeadPresent = "LeadPresent"
LeadSpeed = "LeadSpeed_kmh"
Distance = "ActualDistance_m"
ClosingSpeed = "ClosingSpeed_kmh"
[outputs]
Effective = "EffectiveDesiredSpeed"
# --- end front-matter ---

Feature: Speed arbitration between desired speed and safe car-following speed
  Covers PBI-16 (normal cruise), PBI-17 (follow slow lead vehicle), PBI-18 (return to desired speed).

Scenario: PBI-16 - No lead vehicle keeps the driver desired speed
  With no lead vehicle present, the arbitrated speed must equal the driver-set desired speed.
  Given inputs
    * DesiredSpeed = const(80)
    * LeadPresent = const(0)
    * LeadSpeed = const(0)
    * Distance = const(1000)
    * ClosingSpeed = const(0)
  When simulate for 2s in Normal mode
  Then outputs
    * MatchesDesired: Effective == [79.9 .. 80.1]

Scenario: PBI-17 - Slow lead vehicle close ahead forces a lower target speed
  A slower lead vehicle within a tight gap must pull the arbitrated speed below the driver desired speed.
  Given inputs
    * DesiredSpeed = const(100)
    * LeadPresent = const(1)
    * LeadSpeed = const(40)
    * Distance = const(15)
    * ClosingSpeed = const(30)
  When simulate for 2s in Normal mode
  Then outputs
    * ReducedBelowDesired: Effective < 100
    * NonNegative: Effective >= 0

Scenario: PBI-18 - Lead vehicle disappearing restores desired speed
  Once the lead vehicle is gone, the arbitrated speed must snap back to the driver desired speed.
  Given inputs
    * DesiredSpeed = const(90)
    * LeadPresent = step(1 -> 0 @ 1s)
    * LeadSpeed = const(30)
    * Distance = const(10)
    * ClosingSpeed = const(20)
  When simulate for 2s in Normal mode
  Then outputs
    * RestoredDesired: Effective > 85 when t > 1s
