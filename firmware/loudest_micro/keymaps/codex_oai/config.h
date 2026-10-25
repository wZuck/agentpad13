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
#define DEVICE_VER 0x000E
#define MANUFACTURER "hirlu"
#define PRODUCT "Codex Micro Lab OAI LED"

#define RAW_USAGE_PAGE 0xFF00
#define RAW_USAGE_ID 0x61
#define RAW_EPSIZE 64
#define RAW_REPORT_ID 6

/* The joystick acts as a pointer on the CODEX layer; FN+SW1 cycles modes. */
#define CODEX_OAI_DEFAULT_JOYSTICK_MOUSE
#define CODEX_OAI_JOYSTICK_MOUSE_LAYER 0
#define CODEX_OAI_JOYSTICK_SWAP_XY
#define CODEX_OAI_MOUSE_EXTRA_DEADZONE 200

/* Keep pointer control deliberately slow enough for precise UI selection. */
#define MOUSEKEY_MOVE_DELTA 1
#define MOUSEKEY_MAX_SPEED 20
#define MOUSEKEY_INTERVAL 20

/* K00 / physical [0,0] enters the normal QMK bootmagic-lite path. */
#define BOOTMAGIC_LITE_ROW 0
#define BOOTMAGIC_LITE_COLUMN 0

#define LOUDEST_CUSTOM_RAW_HID
#define LOUDEST_CUSTOM_RGB_STATUS
