# --- front-matter:toml ---
model = "ACC_Main.slx"
component = "ACC_Main/ProximitySensor"
[inputs]
LeadPresent = "LeadPresent"
Distance = "Distance"
[outputs]
ProximityLevel = "ProximityLevel"
# --- end front-matter ---

Feature: Front proximity sensor beeps/flashes proportionally to distance to the lead vehicle
  Covers PBI-21 (proximity sensor). Mirrors the real front collision-warning sensor: the
  closer the obstacle, the higher ProximityLevel climbs (drives beep rate/flash intensity in
  the animation), ramping up through the EmergencyBrake_Module trigger point (8m) rather than
  being disconnected from it.

Scenario: PBI-21 - Closing distance below the emergency threshold saturates proximity level
  When the gap to the lead vehicle collapses toward the emergency-brake trigger distance, the
  sensor must ramp up to (near) maximum intensity.
  Given inputs
    * LeadPresent = const(1)
    * Distance = step(50 -> 2 @ 1s)
  When simulate for 2s in Normal mode
  Then outputs
    * Saturated: ProximityLevel == [0.95 .. 1.0] when t > 1s

Scenario: Safe far distance keeps the sensor silent
  Beyond the far range, the sensor should not beep/flash at all.
  Given inputs
    * LeadPresent = const(1)
    * Distance = const(200)
  When simulate for 1s in Normal mode
  Then outputs
    * Silent: ProximityLevel == 0

Scenario: Mid-range distance produces a proportional (partial) proximity level
  Between the far and near range, ProximityLevel should ramp up smoothly rather than jump
  straight to 0 or 1.
  Given inputs
    * LeadPresent = const(1)
    * Distance = const(20)
  When simulate for 1s in Normal mode
  Then outputs
    * Partial: ProximityLevel == [0.4 .. 0.7]

Scenario: No lead vehicle means no proximity warning regardless of distance
  Without a tracked lead vehicle, the sensor must stay off even if Distance reads as close
  (e.g. the default no-obstacle placeholder value).
  Given inputs
    * LeadPresent = const(0)
    * Distance = const(2)
  When simulate for 1s in Normal mode
  Then outputs
    * Gated: ProximityLevel == 0
