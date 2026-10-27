// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

/* Direct Codex Desktop OAI endpoint.  This target intentionally does not
 * expose the AgentPad13 Vial status protocol. */
#undef VENDOR_ID
#undef PRODUCT_ID
#undef DEVICE_VER
#undef MANUFACTURER
#undef PRODUCT
#undef RAW_USAGE_PAGE
#undef RAW_USAGE_ID
#undef RAW_EPSIZE
#undef RAW_REPORT_ID

#define VENDOR_ID 0x303A
#define PRODUCT_ID 0x8360
#define DEVICE_VER 0x001C
#define CODEX_PAD_CONFIGURABLE
#define MANUFACTURER "ZiyiWang"
#define PRODUCT "Codex Micro Lab OAI LED"

#define RAW_USAGE_PAGE 0xFF00
#define RAW_USAGE_ID 0x61
#define RAW_EPSIZE 64
#define RAW_REPORT_ID 6

/* Left/right cycles layers from every layer; one step per deflection. */
#define CODEX_OAI_DEFAULT_JOYSTICK_LAYERS
#define CODEX_OAI_JOYSTICK_SWAP_XY
#define CODEX_OAI_LAYER_DEADZONE 40

/* K00 / physical [0,0] enters the normal QMK bootmagic-lite path. */
#define BOOTMAGIC_LITE_ROW 0
#define BOOTMAGIC_LITE_COLUMN 0

#define LOUDEST_CUSTOM_RAW_HID
#define LOUDEST_CUSTOM_RGB_STATUS
