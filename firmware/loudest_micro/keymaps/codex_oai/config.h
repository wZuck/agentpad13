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
#define DEVICE_VER 0x0013
#define MANUFACTURER "hirlu"
#define PRODUCT "Codex Micro Lab OAI LED"

#define RAW_USAGE_PAGE 0xFF00
#define RAW_USAGE_ID 0x61
#define RAW_EPSIZE 64
#define RAW_REPORT_ID 6

/* The CODEX layer defaults to left/right session navigation. */
#define CODEX_OAI_DEFAULT_JOYSTICK_SESSIONS
#define CODEX_OAI_JOYSTICK_ACTIVE_LAYER 0
#define CODEX_OAI_JOYSTICK_SWAP_XY
#define CODEX_OAI_SESSION_DEADZONE 40

/* K00 / physical [0,0] enters the normal QMK bootmagic-lite path. */
#define BOOTMAGIC_LITE_ROW 0
#define BOOTMAGIC_LITE_COLUMN 0

#define LOUDEST_CUSTOM_RAW_HID
#define LOUDEST_CUSTOM_RGB_STATUS
