# MAVEN Thermal Control Subsystem (TCS)

MAVEN TCS design: a hybrid distributed system of passive elements (MLI,
radiators, thermo-optical paint) and active heater zones that keep all units
within their survival/operational limits across the extreme Martian
environment. Full architecture and calculations are in
[`maven-reverse-engineering-report.pdf`](../../maven-reverse-engineering-report.pdf).

## Key results

### Architecture

The TCS relies on MLI blankets on the bus and tanks, passive radiator panels
with thermo-optical coating, and seven independently thermostatted Kapton
heater strips. There is no fluid loop or louver mechanism. Payload thermal
management is localised: the IUVS uses dedicated radiators, SOW/MAG booms are
passively insulated, and the MAG sensor relies on a small heater. The
distribution wiring is kept inside the insulated bus.

### External environment

| Quantity | Value |
|---|---|
| Solar flux (perihelion / aphelion / mean) | 718.07 / 490.34 / 604.21 W/m² |
| Albedo factor | 0.15 → q_alb = 98.78 (nominal) / 100.19 (DD) W/m² |
| Mars IR (ε = 0.8, T ≈ 219.6 K) | 96.72 (nominal) / 98.10 (DD) W/m² |
| Internal dissipation (cold / hot) | 41.65 W (eclipse) / 58.8 W (DD) |

### Reverse sizing (single-node)

A single-node steady-state balance gives an upper-bound sizing of the passive
system: hot case (DD + sunlit perihelion) → required radiator area
`A_rad = 10.32 m²` (ε_rad = 0.85); cold case (eclipse at apoapsis) → heater
demand 2308.03 W, 2885.04 W with 25% margin.

### Active control (per-unit heater sizing)

Seven units are actively controlled. Each heater is sized on the cold case at
its set-point `T_set = T_min + 15 K` and verified against the hot case.

| Unit | T_min [°C] | T_max [°C] | T_eq,cold [°C] | T_eq,hot [°C] | Q_htr [W] |
|---|---|---|---|---|---|
| Batteries | −20 | +40 | −26.2 | +15.0 | 5.53 |
| N₂H₄ tanks | +10 | +40 | −118.3 | −44.5 | 93.36 |
| PCU | −20 | +50 | −20.6 | +16.2 | 3.14 |
| TWTA | −30 | +65 | −116.1 | +25.2 | 27.57 |
| Star tracker | −30 | +60 | −116.1 | +6.5 | 7.36 |
| Reaction wheel | −30 | +70 | −78.4 | −16.6 | 7.19 |
| MAG sensor | −55 | +95 | −78.4 | −23.0 | 1.44 |
| **Total** | | | | | **145.58** |

### Power budget

| Component | Qty | P [W] | DMM | w/ DMM [W] |
|---|---|---|---|---|
| Kapton heater strips | 7 | 145.58 | 5% | 152.86 |
| Thermostat controllers | 7 | 3.50 | 10% | 3.85 |
| Subtotal | | 149.08 | | 156.71 |
| Subsystem margin (20%) | | | | 31.34 |
| **Total TCS power** | | | | **188.06** |

### Mass budget

| Component | Qty | Mass [kg] | DMM | Remarks |
|---|---|---|---|---|
| MLI blankets (bus + tanks) | 1 | 2.700 | 20% | ρ ≈ 0.5 kg/m² |
| Passive radiator panels | 1 | 2.500 | 20% | Al honeycomb, ~100 W/m² |
| Kapton heater strips | 7 | 0.350 | 5% | 5 W/cm² |
| Thermostat controllers | 7 | 1.050 | 10% | heritage |
| Thermal straps (battery zone) | 2 | 0.200 | 10% | Cu braid |
| Thermo-optical paint (radiators) | 1 | 0.025 | 20% | OSR coating |
| Subtotal | | 6.825 | | |
| Subsystem margin (20%) | | 1.365 | | |
| **Total TCS mass** | | **8.190** | | |

### Data budget

20 housekeeping channels (7 unit temperatures, 4 bus panel temperatures,
2 MAG sensor temperatures, 7 heater ON/OFF status flags), 16 bit, sampled at
1/60 Hz over the 4.6 h orbit (276 samples/channel): 88.32 kbit/orbit,
132.48 kbit/orbit with 50% margin.

## Thermal sizing scripts (MATLAB)

Both scripts use the single-node steady-state thermal balance adopted in the
report, so the computed heater total reproduces the report value within
rounding of the unit thermal properties.

- **`maven_tcs_units_controlled.m`** — per-unit heater sizing: loads the unit
  thermal parameters (`tcs-unit-limits.csv`), evaluates each unit at the cold
  case set-point `T_set = T_min + 15 K`, classifies the control need
  (heater / insulation), checks the hot case equilibrium and writes
  `data/tcs-a-results-units.csv` (plus a `tcs-a-workspace.mat` for Script B).
- **`maven_tcs_budgets.m`** — subsystem budgets from Script A outputs:
  peak cold-case power budget (heater strips + thermostats, DMM and 20%
  subsystem margin), mass budget (DMM per component, 20% subsystem margin on
  the raw subtotal) and the housekeeping data budget. Writes
  `data/tcs-b-power.csv`, `data/tcs-b-mass.csv`, `data/tcs-b-data.csv`.

## STK correlation

The thermal cases are correlated to the EPS deep-dip campaign window
**11–23 Feb 2015** (scenario `stk/maven-stk-scenario`):

- **Hot case**: Deep Dip + sunlit phase near perihelion — Deep Dip mode power
  (761 W) provides the internal dissipation; perihelion solar flux 718.07 W/m²
  (AU 1.407–1.418 in the window).
- **Cold case**: eclipse at apoapsis — eclipse flag of the EPS standalone
  time-series (1,872 of 17,426 samples, 10.7%); eclipse-mode dissipation
  41.65 W (Eclipse 600 W / Safe Mode 456 W modes).
- **Pointing**: the attitude schedule drives the science/comm/Sun-pointed
  modes; the heater zones follow the unit set-points regardless of attitude.

## Folder contents

```
tcs/
├── matlab/   # maven_tcs_units_controlled.m, maven_tcs_budgets.m
└── data/     # tcs-unit-limits.csv (input); tcs-a-results-units.csv,
              # tcs-b-power.csv, tcs-b-mass.csv, tcs-b-data.csv (generated)
```

## Reproducibility

- **MATLAB R2026a**: run the pipeline in order from `matlab/`

  ```matlab
  run('maven_tcs_units_controlled.m');   % → data/tcs-a-results-units.csv
  run('maven_tcs_budgets.m');            % → data/tcs-b-*.csv
  ```

  Expected key outputs: heater total ≈ 145.6 W, TCS power ≈ 188.1 W,
  mass 8.190 kg, data 132.48 kbit/orbit.

- **STK 13**: the hot/cold cases map onto the deep-dip campaign window in the
  scenario under `eps/stk/maven-stk-scenario`; no dedicated TCS exports are
  required.
