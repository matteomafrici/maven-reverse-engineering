# MAVEN On-Board Data Handling (OBDH)

OBDH design for MAVEN: the centralized command & data handling (CDH)
architecture, the store-and-forward data flow, the full data budget and the
reverse-engineered mass. Full architecture and calculations are in
[`maven-reverse-engineering-report.pdf`](../../maven-reverse-engineering-report.pdf).

## Key results

### Architecture

Centralized **CDH** (Command and Data Handling) architecture: housekeeping,
navigation and payload data are collected by the spacecraft central avionics,
packetized and routed toward the appropriate telemetry branch. Since MAVEN
does not maintain continuous high-rate Earth-pointed communications during
nominal science operations — the body-fixed HGA is used only in dedicated
sessions, while routine support runs on lower-rate links — the OBDH acts as
the logical buffer between asynchronous onboard data generation and scheduled
downlink opportunities: a **store-and-forward** architecture centered on the
CDH and its mass-memory stage.

### Components

| Component | Description |
|---|---|
| Flight computer | Radiation-hardened platform, BAE Systems **RAD750** single-board-computer class |
| Mass memory | Solid-state recorder of **SSR** class, accumulates housekeeping / navigation / science packets |
| Electra UHF | Relay transceiver — treated as an additional data source and sink of the CDH chain |

Component-level statements are kept at class level: public sources support the
RAD750/SSR technological family but do not justify exact board-part numbers or
installed memory capacity, so those claims are intentionally avoided. The
Electra relay is functionally part of the OBDH: proximity data from landed
assets pass to the central recorder, are retained and later downlinked through
the X-band system; its spacecraft-side interfaces split into a low-rate
command-and-control class and a high-rate differential data-transfer class.

### Data flow

A single spacecraft-level acquisition and redistribution chain:

- **Housekeeping** telemetry from EPS, ADCS, thermal control, propulsion and
  telecommunications is acquired by the CDH, encoded into telemetry packets
  and either forwarded directly or stored temporarily, depending on the active
  communication geometry and operational mode.
- **Science payload** data are produced independently of ground visibility,
  buffered through the onboard recorder and transmitted during subsequent
  dedicated communication windows.
- **Relay** traffic adds a further store-and-forward layer: Electra data are
  stored onboard and downlinked later; proximity commands follow the reverse
  path.

Housekeeping, science and relay traffic are therefore three concurrent
contributors to a common onboard storage and routing resource.

### Design rationale

A centralized architecture minimizes spacecraft-level complexity, simplifies
coordination among platform and payload functions and matches an operational
concept in which high-rate contacts are discrete rather than continuous. It is
also the most coherent interpretation of the public evidence for a Mars orbiter
of this generation: rad-hard processor of RAD750 class, SSR-class memory and an
Electra payload whose latency/routing constraints fit differentiated
command/control and bulk-data interfaces. The subsystem sizing is driven
primarily by **mass-memory capacity, data-routing capability and reliability**
rather than by computational throughput. This satisfies requirement
**MAV-SYS-002** (24 h of science data storage in the event of a ground-station
outage).

### Data budget

Row-level budget in [`data/obdh-data-budget.csv`](data/obdh-data-budget.csv)
(sub-system, parameter, n, data type, bit size, frequency, data rate), with
the per-subsystem totals:

| Subsystem | Data rate [bit/s] |
|---|---|
| EPS | 202.4 |
| ADCS | 10,585.6 |
| TCS | 36.0 |
| TTMTC | 382.8 |
| PS | 71.2 |
| OBDH | 136.0 |
| Payload | 10,836.0 |
| **Total** | **22,274.6** |

The report quotes a total of **22,274.6 bit/s** (row-level sum from the CSV:
22,250.0 bit/s; the small difference is a rounding in the report). A 100%
margin is applied — for packetization overhead, telemetry channels not
explicitly modeled, event-driven data and uncertainty in the reconstructed
payload operating modes — bringing the budget to **44,551.1 bit/s (~44.6 kbps)**,
well within the 271 kbps HGA downlink of the TTMTC subsystem. Payload (~49%)
and ADCS (~48%) dominate. The TX antenna selection channel is event-driven and
excluded from the continuous-rate total.

### Mass budget

| Item | Mass |
|---|---|
| OBDH (RAD750-class avionics + SSR + harness) | **9.23 kg** |

No direct literature mass is available for the MAVEN OBDH, so it is
reverse-engineered by scaling the MRO OBDH surrogate with the dry-mass ratio:

```
OBDH_MAVEN = DRY_MAVEN / DRY_MRO × OBDH_MRO = 809 / 1031 × 11.76 = 9.23 kg
```

## Folder contents

```
obdh/
├── README.md
└── data/
    └── obdh-data-budget.csv   # full row-level data budget (~53 channels)
```

## Reproducibility

- No simulation: the OBDH design is taken from the report's OBDH section.
- The data budget CSV is the full transcription of the report's
  `maven_data_budget` tables (Part I + Part II), unmodified.
- Mass follows the report's MRO dry-mass scaling formula
  (`OBDH_MAVEN = DRY_MAVEN/DRY_MRO · OBDH_MRO`, DRY_MRO = 1031 kg,
  OBDH_MRO = 11.76 kg).
