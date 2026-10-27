# CAD model resources

These meshes are copied unchanged from `configurator/build/out/meshes/` in this repository.
Their source designs live in `release/hardware/case/v2/` and the keycap design described by
`configurator/build/out/positions.json`. They are hardware design data under CERN-OHL-W-2.0,
separate from the application's GPL-2.0-or-later source code.

- `tray.glb`: v2 tray; coordinates baked into the board frame.
- `band_w5.4.glb`: v2 5.4 mm band; coordinates baked into the board frame.
- `plate.glb`: v2 plate; coordinates baked into the board frame.
- `cap_dish_1u_17p5.glb`: 17.5 mm 1U dish cap, local origin; placed at PCB switch centres, y = 11.6 mm.
- `cap_dish_2u_stab_17p5.glb`: stabilized 2U dish cap, same frame.
- `knob_A.glb`: knob A, local origin; placed at RE1's shaft axis.
- `stick_cap_topper_12_restricted.glb`: restricted 12 mm topper; placed at JS1.

Units are millimetres. Y is up and Z follows the PCB's downward Y coordinate.
The renderer changes only presentation materials; the source vertex data is unchanged.
Legends, fastener approximations and TP5's visual disk are presentation geometry.
