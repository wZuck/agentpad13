# AgentPad Studio and Input

[简体中文](README.zh-CN.md) | English

Use AgentPad Studio and Input to configure the same AgentPad13 device. Both work
with the experimental `codex_oai` firmware; no conversion between apps is needed.

## Choose an app

| Task | AgentPad Studio 1.3.2+ | Input 1.0.2 |
|---|---|---|
| Edit key bindings | Yes, using the actual AgentPad13 3D layout | Yes, using the Codex Micro compatibility layout |
| Work with 4–16 layers | Read and edit existing layers; imports can change the layer count | Add, edit and remove extension layers beyond the four base layers |
| Rename layers | Displays names saved by Input | Edit and save layer names |
| Set layer indicator colors | Yes | Colors saved in the shared configuration are read by Studio |
| Set global LED power and brightness | Yes, with verified readback | Use Studio for these settings |
| Import/export Studio profiles | Yes | Uses its own device configuration format |
| Macros, smart actions and encoder/joystick reassignment | Unsupported | Unsupported by the AgentPad13 adapter |

Use **Studio** for everyday key and lighting configuration. Use **Input** to add
or rename layers, then return to Studio to edit them in the physical layout.

## Set up the device and apps

1. Install the experimental
   [AgentPad13 Codex/Input firmware v001C](../release/firmware/prebuilt/agentpad13_codex_oai.uf2)
   using the board's BOOTSEL workflow. This firmware supports 4–16 layers.
2. Download Studio from the [GitHub releases](https://github.com/wZuck/agentpad13/releases).
   Unzip the macOS Apple Silicon package, quit the old app and move
   `AgentPad Studio.app` into Applications. Studio requires macOS 13 or later.
3. Connect the device over USB. In Input, it appears as **Codex Micro**.
   Use the AgentPad13 UF2 above for firmware updates; Input's original-device
   firmware is for different hardware.

Studio 1.3.1 fixed a crash when rendering Input's extended actions. Version 1.3.2
also reads custom layer names. Updating Studio for these fixes does not require
clearing the device configuration or reflashing existing v001C firmware.

## Configure with AgentPad Studio

1. Click **Scan** (`扫描`), select the device, then **Connect and Read**
   (`连接并读取`). Reading replaces the local draft with the device configuration.
2. Choose a layer in **Edit Layer** (`编辑层`). Click K00–K12 in the 3D view and
   assign a native key or Codex action. All configured layers, including layers
   added in Input, are available after reading the device.
3. Set the current layer's TP5 indicator color. Black disables that layer's
   indicator.
4. Click **Save to Device** (`保存到设备`). Studio waits for acknowledgement and
   verifies the bindings by reading them back.
5. Set global LED power and brightness under **LED Lighting** (`LED 灯光`), then
   click **Apply Lighting** (`应用灯光`). This is saved separately from key edits.
6. Use **Export** (`导出`) to back up bindings, indicator colors and lighting
   settings. **Import** (`导入`) and **Load Factory Bindings** (`载入出厂键位`)
   change the draft; save bindings and apply lighting to write those changes.

Selecting an editing layer does not switch the device's active layer. Use TP5,
the joystick or assigned layer keys to change the active layer. In the default
joystick mode, left/right cycles through the configured layers; return the stick
to the center before the next step.

If a save times out, read the device again to establish its actual state before
continuing. Export an important draft before replacing it with a device read.

## Configure with Input

1. Connect to **Codex Micro** and load its configuration.
2. Edit an existing layer, or add layers 5 through 16. The four base layers are
   CODEX, FN, NAV and MEDIA; additional layers can be removed.
3. Assign letters, digits, F1–F24, modifiers, navigation/media keys, Codex actions
   or supported layer-switch keys. Save and wait for Input's verification.
4. To rename a layer, edit its name and save in Input. In Studio, click
   **Read Device** (`读取设备`) or reconnect. The layer picker, current-layer
   heading and indicator settings show the saved name, including Unicode names.
5. Switch to the new layer on the device and test its keys. Open Studio and read
   again before continuing configuration there.

Input displays a **2/4/4/3** key arrangement. Flattened in display order, these
keys correspond to AgentPad13 K00–K12; the last key is the separate 2U key. Use
Studio's 3D view to check physical positions.

The adapter supports one device profile with 4–16 layers. Macros, smart actions,
multiple profiles and changes to the fixed encoder/joystick controls are
rejected. Many multi-modifier shortcuts in Input use macros and are therefore
outside this scope. Input's blank control placeholders on new layers inherit
the device's fixed encoder and joystick behavior.

## Switch between the apps

Save in the first app, then read or reconnect in the second app before editing.
Studio and Input share the device's mappings, layer names and indicator colors;
changes persist across restarts. Prefer configuring with one app at a time:
simultaneous HID requests are not guaranteed to be isolated.

For build instructions, architecture, protocols, compatibility evidence and
validation, see [Design and development](DESIGN.md).
