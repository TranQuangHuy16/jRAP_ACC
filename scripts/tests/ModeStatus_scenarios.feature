# --- front-matter:toml ---
model = "ACC_Main.slx"
component = "ACC_Main/ACC_Mode_Status"
[inputs]
Enable = "ACC_Enable"
LeadPresent = "LeadPresent"
EmergencyActive = "EmergencyBrakeActive"
Brake = "FinalBrake"
[outputs]
Mode = "ModeStatus"
# --- end front-matter ---

Feature: ACC mode status reflects the active control state
  Covers PBI-15 (mode display) and contributes to PBI-20 (system validation).
  Mode codes: 0=Off, 1=Cruising, 2=Following, 3=Braking, 4=Emergency Braking.

Scenario: ACC off reports mode 0
  Given inputs
    * Enable = const(0)
    * LeadPresent = const(0)
    * EmergencyActive = const(0)
    * Brake = const(0)
  When simulate for 1s in Normal mode
  Then outputs
    * Off: Mode == 0

Scenario: ACC on with no lead and no braking reports Cruising
  Given inputs
    * Enable = const(1)
    * LeadPresent = const(0)
    * EmergencyActive = const(0)
    * Brake = const(0)
  When simulate for 1s in Normal mode
  Then outputs
    * Cruising: Mode == 1 when t > 0.1s

Scenario: ACC on with a lead vehicle present reports Following
  Given inputs
    * Enable = const(1)
    * LeadPresent = const(1)
    * EmergencyActive = const(0)
    * Brake = const(0)
  When simulate for 1s in Normal mode
  Then outputs
    * Following: Mode == 2 when t > 0.1s

Scenario: Active braking reports Braking
  Given inputs
    * Enable = const(1)
    * LeadPresent = const(1)
    * EmergencyActive = const(0)
    * Brake = const(0.5)
  When simulate for 1s in Normal mode
  Then outputs
    * Braking: Mode == 3 when t > 0.1s

Scenario: Emergency brake active reports Emergency Braking regardless of other inputs
  Given inputs
    * Enable = const(1)
    * LeadPresent = const(1)
    * EmergencyActive = const(1)
    * Brake = const(1)
  When simulate for 1s in Normal mode
  Then outputs
    * Emergency: Mode == 4 when t > 0.1s
