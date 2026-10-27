# AgentPad Studio — Design and Development

[简体中文](DESIGN.zh-CN.md) | English

This document describes the native macOS application and its interface to the
AgentPad13 `codex_oai` firmware. For app selection and configuration steps, see
the [README](README.md).

## Architecture

Studio is a SwiftUI application targeting macOS 13+, built with Swift 5.9 or later.
It has no third-party runtime dependency, helper process or configuration daemon.

| Component | Responsibility |
|---|---|
| `Sources/AgentPadCore/` | Action catalogs, layer configuration, profile validation, HID framing, response decoding and Input layer-name parsing |
| `Sources/AgentPadStudio/PadModel.swift` | Device state, drafts, capability gates, save/readback flow and layer labels |
| `Sources/AgentPadStudio/HIDTransport.swift` | IOKit discovery, nonexclusive connections, request IDs and timeouts |
| `Sources/AgentPadStudio/HardwareRenderView.swift` | CAD-based SceneKit view, key selection, accessibility and legends |
| `Sources/AgentPadStudio/RenderValidation.swift` | Offscreen rendering and picking checks without USB access |
| `Tests/AgentPadCoreTests/` | Core contracts and Swift requests against the actual C firmware engine |

The repository's GPL-2.0-or-later source is the application implementation.
Hardware meshes have a separate CERN-OHL-W-2.0 provenance described below.

## State and save behavior

The model keeps a local draft and a device baseline. Connecting or reading
replaces the draft. Disconnecting retains it but clears the baseline; a new read
is required before saving again. Offline editing, import and export are available.

Saving bindings writes the OAI map and configured layer records, then reads them
back and compares them with the intended values. Acknowledgement alone is not
success. LED power/brightness uses a separate save and readback flow. A failed or
ambiguous write requires a fresh read before further saves.

Layer records are written sequentially, not as one Studio transaction. A failure
partway through can leave some layers saved. Studio checks the remote layer count
before saving to avoid overwriting a layer-count change made by another tool.

The default four layers are CODEX, FN, NAV and MEDIA. Firmware v001C supports up
to sixteen layers. Studio reads the configured count and creates matching editing
entries; imported profiles or a factory draft can change the count when saved.
Editing a layer does not activate it on the device.

### Profile formats

- Format 1 stores the legacy CODEX map.
- Format 2 stores the CODEX map, 4–16 layer records and global LED settings.
- Import and factory reset affect the draft. Bindings and LED settings are
  applied through their respective save controls.
- Layer names are read from the device's Input file. Renaming is performed in
  Input; Studio's profile format does not contain layer names.

## USB transport

Studio matches VID/PID `303A:8360`, usage page/usage `FF00:61`, and opens the
Raw HID interface nonexclusively. This is an experimental compatibility identity;
verify the selected device when multiple matching devices are attached.
The interface is separate from ordinary Vial firmware configuration.

Each report is 64 bytes: report ID `6`, channel `2`, a payload length, up to
61 JSON bytes, then zero padding. Replies can span reports and end in CRLF.
Firmware accepts request IDs `0...998`; Studio rotates through `700...998` and
matches replies to the pending ID. Notifications do not satisfy configuration
requests. A request timeout clears pending state and response decoding state.

Nonexclusive access is not protocol-level client isolation. Interleaved fragments
or matching IDs from another app can interfere with a request. Configure
sequentially and reread after switching tools. Studio does not send the
`v.oai.rgbcfg` / `v.oai.thstatus` readiness handshake or replace task colors.

If macOS denies HID access, follow its USB accessory or Input Monitoring prompt
and reopen the application. Studio does not require Accessibility access.

### Firmware capability gates

| USB device version | Studio capability |
|---|---|
| Earlier than `0x0013` | CODEX configuration |
| `0x0013` | CODEX plus global LED power/brightness |
| `0x0014` | Four-layer configuration and indicator colors |
| `0x0018` | Native CODEX overrides and the expanded action catalog |
| `0x001C` | Dynamic 4–16-layer configuration and the Input file adapter |

## Configuration APIs and persistence

| API | Purpose |
|---|---|
| `v.oai.keymap.get/set` | Legacy OAI map on `l:0` |
| `v.agentpad.cfg.info` | Read `{n,max}` or set the configured count with `{n:4...16}` |
| `v.agentpad.cfg.get/set` | Read/write a layer with `{l,m}` |
| `v.agentpad.led.get/set` | Persist global LED power and percentage brightness |
| `fs.readbin` | Read existing Input metadata for custom layer names |

The OAI map has 15 hexadecimal digits; its factory value is `123456789abecd1`.
Only the first 13 positions are editable physical keys. Position 13 is the fixed
encoder slot; position 14 is a legacy slot without a physical input. Ordinary
editing and import preserve these slots; a factory draft restores their defaults.

A layer's `m` is 32 hexadecimal characters: thirteen action-ID bytes followed by
three indicator RGB bytes. `l` is an index from zero to the configured count minus
one. A zero CODEX override uses the OAI map. Native and Codex actions share the
catalog in `native_actions.def` and `LayerConfiguration.swift`.

The v001C compact record starts at logical EEPROM address 192 and fits in the
existing 4 KiB logical area. It stores maps, layer count, names, IDs, OS metadata
and colors, with an integrity checksum. Existing CODEX, global LED and joystick
calibration records retain their areas. The old 112–178 four-layer record and
an earlier Input record can be migrated. Settings take effect immediately and
are restored on restart. Press-time bindings are cached so release still matches
the original action after a layer or configuration change.

TP5 advances through the configured layers. The default joystick mode cycles
left/right with wraparound and requires recentering between steps. FN's `JS_MODE`
can select arrows, scrolling or gamepad operation. Encoder behavior remains fixed.
Global LED power and brightness also scale layer indicators; task colors remain
owned by the OAI renderer. QMK RGB effect keys do not necessarily appear as
background effects while that renderer owns the LEDs.

### Input file bridge and layer names

The adapter exposes a shared `keymap.json` through `fs.list`, `fs.readbin` and
`fs.writebin`, with SHA-1 values for Input's post-save verification. Uploads are
staged and validated before publication. The complete file limit is 16 KiB;
uploads use at most 3072 raw bytes per block. Layer/profile name literals are
limited to 127 JSON bytes, including quotes and Unicode escapes.

Exact uploaded bytes remain in RAM for immediate checksum/readback agreement.
After restart, the file is regenerated from compact persistent state. Bindings,
layer count, names, IDs, OS metadata and colors survive; serialization and the
resulting checksum can change. Studio changes also invalidate the cached file.
Unsupported macros, smart actions, multiple profiles and control reassignment
are rejected. `host.focused_app` accepts context without switching profiles.

Studio 1.3.2 reads the file in 192-byte chunks using the existing firmware API.
`InputLayerNameReader` bounds the file size, checks progress and a consistent
reported size, then validates the layer count. Layer array order defines the
physical layer index; Input IDs may be noncontiguous. Unicode names are decoded
after assembling all bytes, so a chunk can split a UTF-8 sequence. Empty names
fall back to CODEX/FN/NAV/MEDIA or `LAYER N`. Names are displayed in the picker,
current-layer heading, indicator controls and help text.

The adapter's app evidence and detailed scope are recorded in the
[Input compatibility report](../docs/input-compatibility.zh-CN.md).

### Microphone compatibility

The legacy map digit `e` selects combined microphone mode and emits ACT10.
Digit `f` selects separate microphone mode and emits ACT11. Digit `b` is protected
ACCEPT; the MICROPHONE compatibility action bypasses that confirmation branch.
Neither microphone action supplies a native voice-shortcut fallback before the
OAI handshake. HID connection alone does not establish voice readiness.

A historical investigation on 2026-10-26 observed USB firmware `0x0012`, an ACT11
binding at SW12/K11, and successful `v.oai.rgbcfg` / `v.oai.thstatus` responses.
Static inspection of that client found ACT11 ignored when
`separateMicrophoneKeys=false`, with ACT10 handling combined microphone input.
This identifies a compatibility condition, not the sole proven cause of every
voice problem; the user's current setting and real recording/permission behavior
were not verified by that investigation.

Firmware `0x0013` and later use combined mode in the factory map. The exact former
factory map `123456789abfcd1` migrates to `123456789abecd1`; arbitrary custom maps
containing `f` are preserved. Studio labels the two microphone modes separately.
Separate mode requires the corresponding client setting and voice-action binding.

Historical evidence, retained from the former microphone report:

- Inspected artifact: `/Applications/ChatGPT.app/Contents/Resources/app.asar`.
- SHA-256: `130145706a912db74e4d260ad7538f10f1e05e88af955f9afba42cdf01e64606`.
- Selected JavaScript: `webview/assets/codex-micro-bridge-a2956a34f88d.js`,
  `codex-micro-layout-46c1317ad24a.js`, and SDK notification keys.
- REA evidence: `ev_dcdd28acfe0485a2106e03c290fe2eae94d352fdf7bc7d509db16563da78a87a`.
- Selected JavaScript was inspected statically. Unselected native dependencies
  with ASAR metadata discrepancies were not used to establish event routing.

## CAD view, assets and legends

SceneKit renders the repository's actual case, band, plate, keycaps, encoder knob
and joystick meshes using Metal. Presentation adds materials, environment lighting
and contact shadows. The view follows the system's light/dark appearance without
changing system settings. Selected caps are highlighted; accessibility exposes
SW1–SW13 controls.

Switch centers come from `release/hardware/pcb/v5_8.kicad_pcb` in millimeters.
The encoder is upper-left, the joystick upper-right, SW1–SW12 form a 3×4 matrix,
and SW13 is the lower 2U key with TP5 to its left. Encoder placement uses the
mechanical shaft center, not footprint pin A. `generate-layout.py --check` compares
the generated UI coordinates against the PCB.

Meshes are copied unchanged from `configurator/build/out/meshes/`. Source designs
live in `release/hardware/case/v2/` and the keycap design described by
`configurator/build/out/positions.json`.

| Asset | Placement |
|---|---|
| `tray.glb` | v2 tray, baked into the board frame |
| `band_w5.4.glb` | v2 5.4 mm band, baked into the board frame |
| `plate.glb` | v2 plate, baked into the board frame |
| `cap_dish_1u_17p5.glb` | 17.5 mm 1U cap, local origin at PCB switch centers, Y = 11.6 mm |
| `cap_dish_2u_stab_17p5.glb` | Stabilized 2U cap in the same frame |
| `knob_A.glb` | Knob A at the RE1 shaft axis |
| `stick_cap_topper_12_restricted.glb` | Restricted 12 mm topper at JS1 |

Units are millimeters; Y is up and Z follows the PCB's downward Y coordinate.
Only presentation materials change; source vertices are unchanged. Legends,
fastener approximations and TP5's visual disk are presentation geometry.
These assets are CERN-OHL-W-2.0 hardware design data, separate from GPL-2.0-or-later
application code. The copied resource folder retains a distribution
[NOTICE](Sources/AgentPadStudio/Resources/Models/NOTICE.txt).

Studio 1.3.1 fixed the Input rendering crash: native `KV_*` / `KI_*` action IDs
were incorrectly used as indices into a 16-entry legacy title table.
`PadAction.keycapTitle` now uses compact labels only for matching legacy entries
and uses each native action's own title otherwise. Tests cover the entire native
catalog and unknown future IDs; offscreen rendering includes Codex overlays,
direct layer selection and momentary layer bindings.

## Build and validation

Run commands from the repository root. An Xcode or command-line toolchain with
Swift 5.9+ is required to build:

```sh
macos/scripts/build-app.sh
open 'macos/dist/AgentPad Studio.app'
```

The script checks PCB layout data, builds Release for the current Mac architecture,
copies the application resources and applies an ad-hoc signature. The output is
`macos/dist/AgentPad Studio.app`. Developer ID signing and notarization are separate
distribution steps; the existing release ZIP is an Apple Silicon build.

Offline demo, with no USB discovery or connection:

```sh
open 'macos/dist/AgentPad Studio.app' --args --demo
```

Tests and offscreen validation:

```sh
swift test --package-path macos
python3 -m unittest discover -s firmware/tests/codex_oai -p 'test_*.py'
python3 macos/scripts/generate-layout.py --check
'macos/dist/AgentPad Studio.app/Contents/MacOS/AgentPadStudio' --render-previews /tmp/agentpad-previews
```

Swift tests cover maps, reserved slots, profiles, lighting, HID fragmentation and
response assembly. They compile the real C protocol engine and send Swift-generated
requests through it, including dynamic-layer persistence. Name tests cover sixteen
layers, Unicode/emoji, chunk boundaries, refreshes and invalid responses.

The renderer checks CAD resources, both system appearances, extended action legends
and all thirteen picking targets without opening a window or accessing USB.
Offscreen rendering uses AppKit/SceneKit and requires an appropriate macOS graphics
environment. Normal application operation needs neither Python nor a browser.

These checks do not establish real-device IOKit/USB behavior, reconnect handling,
physical power-loss persistence, voice readiness or arbitrary concurrent-client
safety. Manual acceptance includes read → edit → verified save → physical key test
→ reconnect/readback → observation with Codex running. No build or test command
above flashes the device. Physical firmware work is documented in the
[runbook](../docs/codex-oai-physical-runbook.md).

## Source references

- [Core models and wire format](Sources/AgentPadCore/Keymap.swift)
- [Layer records and action catalog](Sources/AgentPadCore/LayerConfiguration.swift)
- [Layer-name reader](Sources/AgentPadCore/InputLayerNames.swift)
- [Firmware interface](../firmware/loudest_micro/keymaps/codex_oai/codex_oai.h)
- [Firmware implementation](../firmware/loudest_micro/keymaps/codex_oai/codex_oai.c)
- [QMK key behavior](../firmware/loudest_micro/keymaps/codex_oai/keymap.c)

Application license: GPL-2.0-or-later. Mesh license: CERN-OHL-W-2.0.
