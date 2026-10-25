#!/usr/bin/env python3
"""Generate deterministic hand-soldering maps from the v5.8 fab package."""

from __future__ import annotations

import csv
import html
import json
import math
import re
import subprocess
import tempfile
from pathlib import Path


def write_clean_text(path: Path, content: str) -> None:
    normalized = "\n".join(line.rstrip() for line in content.splitlines())
    path.write_text(normalized + "\n", encoding="utf-8")


ROOT = Path(__file__).resolve().parents[4]
PCB_DIR = ROOT / "release/hardware/pcb"
FAB_DIR = PCB_DIR / "fabpack_out_v5_8"
MANIFEST = FAB_DIR / "build_manifest.json"
BOARD = PCB_DIR / "v5_8.kicad_pcb"
OUT = Path(__file__).resolve().parent
KICAD_CLI = Path("/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli")

BOARD_W = 84.1756
BOARD_H = 99.9998
FONT = "PingFang SC, Noto Sans CJK SC, Helvetica, Arial, sans-serif"
DISPLAY = "DIN Alternate, Avenir Next Condensed, PingFang SC, sans-serif"
MONO = "SFMono-Regular, Menlo, Consolas, monospace"

COLORS = {
    "S1": "#2563EB",
    "S2": "#0F766E",
    "S3": "#EA580C",
    "S4": "#7C3AED",
    "S5": "#0891B2",
    "S6": "#D97706",
    "S7": "#0E7490",
    "S8": "#65A30D",
    "S9": "#B91C1C",
    "S10": "#BE185D",
    "SX": "#6B7280",
}

STAGE_LABELS = {
    "S1": "S1  底层固定 R/C/FB",
    "S2": "S2  USB / 电源入口",
    "S3": "S3  MCU / Flash / 晶振",
    "S4": "S4  灯控 / 触摸 IC",
    "S5": "S5  侧灯去耦 C40-C49",
    "S6": "S6  每键 LED1-LED14",
    "S7": "S7  侧灯 LED15-LED24",
    "S8": "S8  BOOT / RESET",
    "S9": "S9  热插拔座 SW1-SW13",
    "S10": "S10 翻面后的顶面 THT",
    "SX": "DNP 禁止安装",
}


def esc(value: object) -> str:
    return html.escape(str(value), quote=True)


def ref_number(ref: str) -> int:
    match = re.search(r"(\d+)$", ref)
    return int(match.group(1)) if match else -1


def stage_for(ref: str) -> str:
    if ref in {"C25", "D1", "J2"}:
        return "SX"
    if ref in {"F1", "J1", "U3", "U4"}:
        return "S2"
    if ref in {"U1", "U2", "Y1"}:
        return "S3"
    if ref in {"U5", "U6"}:
        return "S4"
    if ref in {f"C{i}" for i in range(40, 50)}:
        return "S5"
    if ref.startswith("LED") and 1 <= ref_number(ref) <= 14:
        return "S6"
    if ref.startswith("LED") and 15 <= ref_number(ref) <= 24:
        return "S7"
    if ref in {"SW14", "SW15"}:
        return "S8"
    if ref.startswith("SW") and 1 <= ref_number(ref) <= 13:
        return "S9"
    if ref in {"RE1", "JS1", "TP5"}:
        return "S10"
    return "S1"


def load_bom() -> tuple[dict[str, dict[str, str]], dict[str, dict[str, str]]]:
    parsed: dict[str, dict[str, dict[str, str]]] = {}
    for sku in ("opaque", "translucent"):
        refs: dict[str, dict[str, str]] = {}
        with (FAB_DIR / "assembly" / f"bom_{sku}.csv").open(newline="") as handle:
            for row in csv.DictReader(handle):
                for ref in (part.strip() for part in row["References"].split(",")):
                    refs[ref] = row
        parsed[sku] = refs
    return parsed["opaque"], parsed["translucent"]


def load_footprints() -> dict[str, dict]:
    data = json.loads(MANIFEST.read_text())
    return data["board"]["footprints"]


def load_pad1_positions() -> dict[str, tuple[float, float]]:
    """Return board-coordinate positions for the first pad named '1'."""
    source = BOARD.read_text()
    positions: dict[str, tuple[float, float]] = {}
    cursor = 0
    while True:
        start = source.find("(footprint ", cursor)
        if start < 0:
            break
        depth = 0
        in_string = False
        escaped = False
        end = None
        for index in range(start, len(source)):
            char = source[index]
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
            else:
                if char == '"':
                    in_string = True
                elif char == "(":
                    depth += 1
                elif char == ")":
                    depth -= 1
                    if depth == 0:
                        end = index + 1
                        break
        if end is None:
            break
        block = source[start:end]
        cursor = end
        ref_match = re.search(r'\(property "Reference" "([^"]+)"', block)
        at_match = re.search(
            r'\n\t\t\(at\s+(-?\d+(?:\.\d+)?)\s+'
            r'(-?\d+(?:\.\d+)?)(?:\s+(-?\d+(?:\.\d+)?))?\)',
            block,
        )
        pad_match = re.search(
            r'\(pad "1" [^\n]+\n\s*\(at\s+(-?\d+(?:\.\d+)?)\s+'
            r'(-?\d+(?:\.\d+)?)',
            block,
        )
        if not (ref_match and at_match and pad_match):
            continue
        origin_x, origin_y = float(at_match.group(1)), float(at_match.group(2))
        rotation = math.radians(float(at_match.group(3) or 0))
        local_x, local_y = float(pad_match.group(1)), float(pad_match.group(2))
        global_x = origin_x + local_x * math.cos(rotation) - local_y * math.sin(rotation)
        global_y = origin_y + local_x * math.sin(rotation) + local_y * math.cos(rotation)
        positions[ref_match.group(1)] = (global_x, global_y)
    return positions


def method_for(ref: str) -> str:
    if ref in {"C25", "D1", "J2"}:
        return "不安装"
    if ref == "U1":
        return "锡膏 + 热风（中心焊盘也必须回流）"
    if ref in {"U2", "U3", "U4", "U5", "U6", "J1"}:
        return "锡膏/助焊剂 + 热风，或拖焊"
    if ref == "Y1":
        return "烙铁点焊四角焊盘 / 热风"
    if ref.startswith("LED"):
        return "烙铁逐脚焊或低风速热风"
    if ref.startswith("SW") and ref_number(ref) <= 13:
        return "烙铁，先对角固定两脚"
    if ref in {"SW14", "SW15"}:
        return "烙铁，四脚对角固定"
    if ref in {"RE1", "JS1"}:
        return "烙铁（THT）"
    return "烙铁逐件焊 / 热风"


def polarity_for(ref: str) -> str:
    if ref in {"C25", "D1", "J2"}:
        return "不安装"
    if ref in {"U1", "U2", "U3", "U4", "U5", "U6", "Y1"}:
        return "有方向：对齐 pin 1 圆点/缺角"
    if ref.startswith("LED"):
        return "有方向：pin 1 / DIN 标记必须对齐"
    if ref == "J1":
        return "有方向：按丝印外框，不可镜像安装"
    if ref.startswith("SW") and ref_number(ref) <= 13:
        return "有方向：按底面丝印，CPL 为 180°"
    if ref == "JS1":
        return "有方向：本板按 180° 安装位置"
    if ref == "RE1":
        return "有方向：按丝印外框与 A/B/C 脚位"
    return "无极性/按焊盘方向"


def note_for(ref: str, opaque: dict[str, dict[str, str]], translucent: dict[str, dict[str, str]]) -> str:
    if ref in translucent and translucent[ref]["Populate"] == "DNP":
        return "透明版同样禁止安装"
    if ref == "TP5":
        return "仅接电极式触摸面板时选装弹簧/导线；空白或普通打印板不焊"
    if ref.startswith("LED") and 1 <= ref_number(ref) <= 14:
        return "反装 LED；pin 1 错会导致整串不亮"
    if ref.startswith("SW") and 1 <= ref_number(ref) <= 13:
        return "MX 热插拔座；实际 MX 轴体不焊"
    if ref in {"SW14", "SW15"}:
        return "不要改用 J 引脚版本"
    if ref == "U1":
        return "56 脚 0.4 mm pitch，中心散热焊盘要少量锡膏"
    if ref == "C25":
        return "触摸灵敏度调校位，默认不装"
    if ref == "D1":
        return "USBLC6 已覆盖 D+/D- ESD，默认不装"
    if ref == "J2":
        return "扩展排针位，默认不装"
    return "值/封装按本行执行"


def write_checklist(
    opaque: dict[str, dict[str, str]],
    translucent: dict[str, dict[str, str]],
    footprints: dict[str, dict],
) -> None:
    rows: list[dict[str, str]] = []
    refs = sorted(
        set(opaque) | set(translucent),
        key=lambda ref: (stage_for(ref), ref.rstrip("0123456789"), ref_number(ref)),
    )
    for ref in refs:
        source = translucent[ref]
        footprint = footprints[ref]
        if translucent[ref]["Populate"] == "DNP":
            config = "禁止安装"
        else:
            config = "透明版安装"
        rows.append(
            {
                "阶段": stage_for(ref),
                "参考位号": ref,
                "数量": "1",
                "值/型号": source["Value"],
                "MPN": source["MPN"],
                "封装": source["Footprint"],
                "面": "顶面 F.Cu" if footprint["layer"] == "F.Cu" else "底面 B.Cu",
                "CPL_X_mm": f"{footprint['x_mm']:.4f}",
                "CPL_Y_mm": f"{footprint['y_mm']:.4f}",
                "角度_deg": f"{footprint['rot_deg']:.1f}",
                "配置": config,
                "焊接方式": method_for(ref),
                "方向/极性": polarity_for(ref),
                "说明": note_for(ref, opaque, translucent),
            }
        )

    rows.append(
        {
            "阶段": "S10",
            "参考位号": "TP5_CONTACT",
            "数量": "0-1",
            "值/型号": "用户选弹簧/导线",
            "MPN": "-",
            "封装": "TP5 Ø4.0 mm 焊盘",
            "面": "顶面 F.Cu",
            "CPL_X_mm": "13.5250",
            "CPL_Y_mm": "88.8500",
            "角度_deg": "-",
            "配置": "选装",
            "焊接方式": "烙铁",
            "方向/极性": "无极性",
            "说明": "仅电极式触摸面板需要；普通打印板留空",
        }
    )
    rows.append(
        {
            "阶段": "机械",
            "参考位号": "STAB1",
            "数量": "0-1",
            "值/型号": "2U 卫星轴",
            "MPN": "-",
            "封装": "STAB_MX_2u",
            "面": "顶面",
            "CPL_X_mm": "42.1000",
            "CPL_Y_mm": "88.8500",
            "角度_deg": "0",
            "配置": "选装",
            "焊接方式": "不焊",
            "方向/极性": "-",
            "说明": "装入定位板/2U 键帽系统，PCB 上只有 NPTH 让位孔",
        }
    )

    with (OUT / "agentpad13-v5_8-placement-checklist.zh-CN.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_web_data() -> None:
    checklist = OUT / "agentpad13-v5_8-placement-checklist.zh-CN.csv"
    with checklist.open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    payload = json.dumps(rows, ensure_ascii=False, indent=2)
    write_clean_text(
        OUT / "web-data.js",
        "/* Generated from agentpad13-v5_8-placement-checklist.zh-CN.csv. */\n"
        f"window.AGENTPAD_PLACEMENTS = {payload};\n",
    )


def kicad_svg(layer: str, mirror: bool) -> str:
    temp = Path(tempfile.mkdtemp(prefix="agentpad13-map-"))
    suffix = "bottom" if mirror else "top"
    target = temp / f"{suffix}.svg"
    command = [
        str(KICAD_CLI),
        "pcb",
        "export",
        "svg",
        str(BOARD),
        "--output",
        str(target),
        "--layers",
        layer,
        "--page-size-mode",
        "2",
        "--exclude-drawing-sheet",
        "--mode-single",
        "--black-and-white",
    ]
    if mirror:
        command.append("--mirror")
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
    source = target.read_text()
    start = source.index("<svg")
    root_end = source.index(">", start) + 1
    end = source.rindex("</svg>")
    inner = source[root_end:end]
    inner = re.sub(r"<title>.*?</title>", "", inner, flags=re.DOTALL)
    inner = re.sub(r"<desc>.*?</desc>", "", inner, flags=re.DOTALL)
    return inner


def base_group(
    inner: str,
    *,
    x: float,
    y: float,
    scale: float,
    crop_x: float = 0,
    crop_y: float = 0,
    opacity: float = 0.28,
) -> str:
    return (
        f'<g transform="translate({x:.3f} {y:.3f}) scale({scale}) '
        f'translate({-crop_x:.5f} {-crop_y:.5f})" opacity="{opacity}">{inner}</g>'
    )


def board_background(
    *,
    x: float,
    y: float,
    scale: float,
    width: float = BOARD_W,
    height: float = BOARD_H,
) -> str:
    return (
        f'<rect x="{x:.2f}" y="{y:.2f}" width="{width * scale:.2f}" '
        f'height="{height * scale:.2f}" rx="14" fill="#FBF8F1" '
        'stroke="#D6D3CA" stroke-width="2"/>'
    )


def point(
    fp: dict,
    *,
    x: float,
    y: float,
    scale: float,
    crop_x: float = 0,
    crop_y: float = 0,
    mirror: bool = True,
) -> tuple[float, float]:
    board_x = BOARD_W - fp["x_mm"] if mirror else fp["x_mm"]
    return x + (board_x - crop_x) * scale, y + (fp["y_mm"] - crop_y) * scale


def marker(
    px: float,
    py: float,
    color: str,
    *,
    radius: float = 7,
    label: str | None = None,
    font_size: float = 10,
    text_color: str = "#FFFFFF",
) -> str:
    parts = [
        f'<circle cx="{px:.2f}" cy="{py:.2f}" r="{radius:.2f}" fill="{color}" '
        'stroke="#FFFFFF" stroke-width="1.8"/>'
    ]
    if label:
        parts.append(
            f'<text x="{px:.2f}" y="{py + font_size * 0.34:.2f}" '
            f'text-anchor="middle" font-family="{MONO}" font-size="{font_size}" '
            f'font-weight="700" fill="{text_color}">{esc(label)}</text>'
        )
    return "".join(parts)


def text(
    x: float,
    y: float,
    value: object,
    *,
    size: float = 18,
    color: str = "#17202A",
    weight: int = 400,
    family: str = FONT,
    anchor: str = "start",
    extra: str = "",
) -> str:
    return (
        f'<text x="{x:.2f}" y="{y:.2f}" font-family="{family}" '
        f'font-size="{size}" font-weight="{weight}" fill="{color}" '
        f'text-anchor="{anchor}" {extra}>{esc(value)}</text>'
    )


def title_block(
    title: str,
    subtitle: str,
    *,
    width: float,
    color: str = "#17202A",
) -> str:
    return (
        f'<rect x="0" y="0" width="{width}" height="112" fill="{color}"/>'
        + text(42, 53, title, size=34, color="#FFFFFF", weight=800)
        + text(42, 88, subtitle, size=18, color="#E5E7EB", weight=500)
    )


def overview_svg(footprints: dict[str, dict]) -> str:
    canvas_w, canvas_h = 2000.0, 2000.0
    board_x, board_y, scale = 130.0, 155.0, 16.2
    inner = kicad_svg("B.SilkS,Edge.Cuts", True)
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{canvas_w}" height="{canvas_h}" '
        f'viewBox="0 0 {canvas_w} {canvas_h}">',
        '<rect width="100%" height="100%" fill="#E9E5DB"/>',
        title_block(
            "AgentPad13 v5.8 手焊总览",
            "透明侧发光版，共 111 件。底面朝上，USB-C 在上方。",
            width=canvas_w,
        ),
        board_background(x=board_x, y=board_y, scale=scale),
        base_group(inner, x=board_x, y=board_y, scale=scale, opacity=0.26),
    ]

    # Board orientation.
    parts.append(
        text(
            board_x + 22,
            board_y - 16,
            "USB-C / BOOT / RESET 端",
            size=18,
            color="#374151",
            weight=700,
        )
    )
    parts.append(
        text(
            board_x + 22,
            board_y + BOARD_H * scale + 28,
            "2U / LED13 / TP5 端",
            size=18,
            color="#374151",
            weight=700,
        )
    )

    refs = [
        ref
        for ref in footprints
        if ref not in {"STAB1"} and not ref.startswith(("FID", "TP")) and re.match(r"^[A-Z]", ref)
    ]
    for ref in refs:
        fp = footprints[ref]
        stage = stage_for(ref)
        color = COLORS[stage]
        px, py = point(fp, x=board_x, y=board_y, scale=scale)
        if stage == "SX":
            parts.append(
                f'<path d="M {px - 6:.1f} {py - 6:.1f} L {px + 6:.1f} {py + 6:.1f} '
                f'M {px + 6:.1f} {py - 6:.1f} L {px - 6:.1f} {py + 6:.1f}" '
                'stroke="#6B7280" stroke-width="3" stroke-linecap="round"/>'
            )
        else:
            radius = 5.0 if stage in {"S1", "S5", "S6", "S7"} else 7.0
            parts.append(
                f'<circle cx="{px:.2f}" cy="{py:.2f}" r="{radius:.2f}" fill="{color}" '
                'fill-opacity="0.82" stroke="#FFFFFF" stroke-width="1.3"/>'
            )

    # Legend.
    legend_x, legend_y = 1500, 150
    parts.append(text(legend_x, legend_y, "颜色 = 焊接阶段", size=27, weight=800))
    stage_counts = {
        "S1": "51 件：固定 R/C/FB",
        "S2": "4 件：F1 J1 U3 U4",
        "S3": "3 件：U1 U2 Y1",
        "S4": "2 件：U5 U6",
        "S5": "10 件：C40–C49",
        "S6": "14 件：LED1–LED14",
        "S7": "10 件：LED15–LED24",
        "S8": "2 件：SW14, SW15",
        "S9": "13 件：SW1–SW13",
        "S10": "2 件：RE1, JS1（翻到顶面）",
        "SX": "3 件：C25, D1, J2 均不装",
    }
    for index, key in enumerate(["S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10", "SX"]):
        y = legend_y + 54 + index * 58
        parts.append(
            f'<rect x="{legend_x}" y="{y - 22}" width="42" height="34" rx="7" '
            f'fill="{COLORS[key]}"/>'
        )
        parts.append(
            text(
                legend_x + 21,
                y + 2,
                key,
                size=13,
                color="#FFFFFF",
                weight=800,
                family=MONO,
                anchor="middle",
            )
        )
        parts.append(text(legend_x + 58, y + 1, stage_counts[key], size=17, weight=650))

    parts.append(
        '<rect x="130" y="1818" width="1740" height="142" rx="12" fill="#FFFFFF" '
        'stroke="#B8B3A8" stroke-width="2"/>'
    )
    parts.append(
        text(158, 1855, "关键规则", size=23, weight=800, color="#B91C1C")
        + text(
            158,
            1888,
            "R/C/FB → USB/电源验 3.3 V → U1/U2/Y1 → U5/U6 → 侧灯电容 → 主灯 → 侧灯 → 轻触键 → 热插拔座 → 翻面焊 THT。",
            size=18,
            weight=650,
        )
        + text(
            158,
            1923,
            "DNP：C25 / D1 / J2 不装。TP5 仅电极式面板选装。STAB1 是机械卫星轴，不在 PCB 上焊接。",
            size=18,
        )
    )
    parts.append(
        text(
            1850,
            1775,
            "底面视图（从 B.Cu 看）",
            size=17,
            color="#4B5563",
            weight=700,
            anchor="end",
        )
    )
    parts.append("</svg>")
    return "".join(parts)


def upper_detail_svg(
    footprints: dict[str, dict],
    opaque: dict[str, dict[str, str]],
    translucent: dict[str, dict[str, str]],
    pad1_positions: dict[str, tuple[float, float]],
) -> str:
    canvas_w, canvas_h = 2200.0, 1700.0
    crop_y = 0.0
    board_x, board_y, scale = 80.0, 135.0, 24.0
    inner = kicad_svg("B.SilkS,Edge.Cuts", True)
    selected = sorted(
        [
            ref
            for ref, fp in footprints.items()
            if 0 <= fp["y_mm"] <= 28
            and ref in opaque
            and fp["layer"] == "B.Cu"
            and ref not in {"STAB1"}
        ],
        key=lambda ref: (stage_for(ref), ref.rstrip("0123456789"), ref_number(ref)),
    )
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{canvas_w}" height="{canvas_h}" '
        f'viewBox="0 0 {canvas_w} {canvas_h}">',
        '<defs><clipPath id="upper-board-clip">'
        f'<rect x="{board_x}" y="{board_y}" width="{BOARD_W * scale}" height="{28 * scale}"/>'
        "</clipPath></defs>",
        '<rect width="100%" height="100%" fill="#E9E5DB"/>',
        title_block(
            "底面放大：USB / 电源 / MCU / Flash",
            "按图中数字到下方清单取件；白色小圈 1 = 实际 pad 1。区域 y=0–28 mm。",
            width=canvas_w,
        ),
        f'<g clip-path="url(#upper-board-clip)">'
        + board_background(x=board_x, y=board_y, scale=scale, height=28)
        + base_group(
            inner,
            x=board_x,
            y=board_y,
            scale=scale,
            crop_y=crop_y,
            opacity=0.22,
        )
        + "</g>",
    ]

    for index, ref in enumerate(selected, start=1):
        fp = footprints[ref]
        px, py = point(fp, x=board_x, y=board_y, scale=scale, crop_y=crop_y)
        stage = stage_for(ref)
        parts.append(marker(px, py, COLORS[stage], radius=11, label=str(index), font_size=10))

    for ref in ["U1", "U2", "U3", "U4", "J1", "Y1"]:
        if ref not in pad1_positions:
            continue
        gx, gy = pad1_positions[ref]
        px, py = point(
            {"x_mm": gx, "y_mm": gy},
            x=board_x,
            y=board_y,
            scale=scale,
            crop_y=crop_y,
        )
        parts.append(
            f'<circle cx="{px:.1f}" cy="{py:.1f}" r="9" fill="#FFFFFF" '
            'stroke="#111827" stroke-width="2"/>'
        )
        parts.append(
            text(px, py + 4, "1", size=10, color="#111827", weight=900, family=MONO, anchor="middle")
        )

    legend_top = 880.0
    parts.append(text(80, legend_top - 24, "位号对照", size=26, weight=800))
    columns = 3
    rows_per_column = (len(selected) + columns - 1) // columns
    column_width = 680.0
    for index, ref in enumerate(selected, start=1):
        column = (index - 1) // rows_per_column
        row = (index - 1) % rows_per_column
        x = 80 + column * column_width
        y = legend_top + 22 + row * 40
        row_data = opaque.get(ref) or translucent.get(ref)
        display_values = {
            "12MHz ABM8-272-T3": "12 MHz 晶振",
            "2-axis tilt joystick": "YA13 摇杆",
            "EC11 encoder+push": "EC11 编码器",
        }
        value = display_values.get(row_data["Value"], row_data["Value"])
        parts.append(marker(x + 12, y - 7, COLORS[stage_for(ref)], radius=12, label=str(index), font_size=10))
        parts.append(text(x + 34, y, ref, size=18, weight=800, family=MONO))
        parts.append(text(x + 116, y, value, size=15, color="#374151"))

    parts.append(
        '<rect x="80" y="1570" width="2040" height="82" rx="10" fill="#FFF7ED" '
        'stroke="#F97316" stroke-width="2"/>'
    )
    parts.append(
        text(
            105,
            1603,
            "先只装 S1 固定被动件 → 再装 F1/J1/U3/U4，并用限流电源确认 +5 V 与 +3.3 V 无短路。",
            size=18,
            weight=700,
            color="#9A3412",
        )
        + text(
            105,
            1633,
            "电源确认后才焊 U1、U2、Y1。U1 为 QFN-56/0.4 mm pitch，中心焊盘不能漏焊或堆锡。",
            size=18,
            color="#9A3412",
        )
    )
    parts.append("</svg>")
    return "".join(parts)


def matrix_detail_svg(
    footprints: dict[str, dict],
    translucent: dict[str, dict[str, str]],
    pad1_positions: dict[str, tuple[float, float]],
) -> str:
    canvas_w, canvas_h = 2200.0, 2050.0
    board_x, board_y, scale = 120.0, 135.0, 17.2
    inner = kicad_svg("B.SilkS,Edge.Cuts", True)
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{canvas_w}" height="{canvas_h}" '
        f'viewBox="0 0 {canvas_w} {canvas_h}">',
        '<rect width="100%" height="100%" fill="#E9E5DB"/>',
        title_block(
            "底面放大：13 个热插拔座 + 24 颗灯",
            "底面朝上，USB 在上方。SW1–SW13 是座子；实际轴体最后直接插入，不焊。",
            width=canvas_w,
        ),
        board_background(x=board_x, y=board_y, scale=scale),
        base_group(inner, x=board_x, y=board_y, scale=scale, opacity=0.22),
    ]

    # Hot-swap sockets.
    for index in range(1, 14):
        ref = f"SW{index}"
        fp = footprints[ref]
        px, py = point(fp, x=board_x, y=board_y, scale=scale)
        label_dx = -13 if ref in {"SW5", "SW6", "SW7", "SW8"} else 13
        parts.append(
            f'<circle cx="{px:.1f}" cy="{py:.1f}" r="17" fill="none" '
            f'stroke="{COLORS["S9"]}" stroke-width="4"/>'
        )
        parts.append(
            f'<rect x="{px + label_dx - 34:.1f}" y="{py - 44:.1f}" width="68" height="27" rx="6" '
            f'fill="#FFFFFF" stroke="{COLORS["S9"]}" stroke-width="2"/>'
        )
        parts.append(
            text(
                px + label_dx,
                py - 25,
                ref,
                size=15,
                color=COLORS["S9"],
                weight=800,
                family=MONO,
                anchor="middle",
            )
        )

    # Per-key reverse LEDs.
    for index in range(1, 15):
        ref = f"LED{index}"
        fp = footprints[ref]
        px, py = point(fp, x=board_x, y=board_y, scale=scale)
        parts.append(
            f'<rect x="{px - 25:.1f}" y="{py - 12:.1f}" width="50" height="24" rx="6" '
            f'fill="{COLORS["S6"]}" fill-opacity="0.9"/>'
        )
        parts.append(
            text(
                px,
                py + 5,
                ref,
                size=13,
                color="#FFFFFF",
                weight=800,
                family=MONO,
                anchor="middle",
            )
        )
        if ref in pad1_positions:
            gx, gy = pad1_positions[ref]
            pin_x, pin_y = point(
                {"x_mm": gx, "y_mm": gy},
                x=board_x,
                y=board_y,
                scale=scale,
            )
            parts.append(
                f'<circle cx="{pin_x:.1f}" cy="{pin_y:.1f}" r="4.5" fill="#FFFFFF" '
                'stroke="#9A3412" stroke-width="2"/>'
            )

    # Optional underglow LEDs and their local capacitors.
    for index in range(15, 25):
        ref = f"LED{index}"
        fp = footprints[ref]
        px, py = point(fp, x=board_x, y=board_y, scale=scale)
        parts.append(
            f'<circle cx="{px:.1f}" cy="{py:.1f}" r="12" fill="{COLORS["S7"]}" '
            'stroke="#FFFFFF" stroke-width="2"/>'
        )
        parts.append(
            text(
                px,
                py + 4,
                str(index),
                size=10,
                color="#FFFFFF",
                weight=800,
                family=MONO,
                anchor="middle",
            )
        )
    for index in range(40, 50):
        ref = f"C{index}"
        fp = footprints[ref]
        px, py = point(fp, x=board_x, y=board_y, scale=scale)
        parts.append(
            f'<rect x="{px - 8:.1f}" y="{py - 6:.1f}" width="16" height="12" rx="2" '
            f'fill="#FFFFFF" stroke="{COLORS["S5"]}" stroke-width="3"/>'
        )
        parts.append(
            text(
                px + 11,
                py + 4,
                str(index),
                size=9,
                color="#155E75",
                weight=800,
                family=MONO,
            )
        )

    # Side panel.
    panel_x = 1585
    parts.append(
        f'<rect x="{panel_x}" y="150" width="540" height="1640" rx="16" fill="#FBF8F1" '
        'stroke="#C7C2B7" stroke-width="2"/>'
    )
    parts.append(text(panel_x + 30, 205, "底面行列", size=28, weight=800))
    rows = [
        ("第一排", "SW4  SW3  SW2  SW1", "LED4  LED3  LED2  LED1"),
        ("第二排", "SW8  SW7  SW6  SW5", "LED8  LED7  LED6  LED5"),
        ("第三排", "SW12 SW11 SW10 SW9", "LED12 LED11 LED10 LED9"),
        ("最下排", "SW13", "LED13"),
    ]
    for index, (row_name, switches, leds) in enumerate(rows):
        y = 258 + index * 155
        parts.append(text(panel_x + 30, y, row_name, size=20, weight=800, color="#374151"))
        parts.append(text(panel_x + 30, y + 38, switches, size=19, weight=800, family=MONO, color=COLORS["S9"]))
        parts.append(text(panel_x + 30, y + 74, leds, size=19, weight=800, family=MONO, color=COLORS["S6"]))

    parts.append(
        f'<rect x="{panel_x + 28}" y="900" width="484" height="252" rx="12" fill="#ECFEFF" '
        f'stroke="{COLORS["S7"]}" stroke-width="3"/>'
    )
    parts.append(text(panel_x + 50, 940, "透明版完整灯链", size=21, weight=800, color="#155E75"))
    parts.append(text(panel_x + 50, 980, "LED15–LED24：10 颗侧发光灯", size=17))
    parts.append(text(panel_x + 50, 1010, "C40–C49：10 颗 100 nF 去耦", size=17))
    parts.append(text(panel_x + 50, 1040, "先焊 10 颗电容，再焊侧面灯。", size=17))
    parts.append(text(panel_x + 50, 1070, "两颗侧面灯按设计朝外：", size=17, weight=700))
    parts.append(text(panel_x + 50, 1100, "LED15 / LED16；不要自行转回。", size=17, color="#B45309", weight=800))

    parts.append(
        f'<rect x="{panel_x + 28}" y="1190" width="484" height="290" rx="12" fill="#FEF2F2" '
        f'stroke="{COLORS["S9"]}" stroke-width="3"/>'
    )
    parts.append(text(panel_x + 50, 1230, "LED 方向", size=21, weight=800, color="#991B1B"))
    parts.append(text(panel_x + 50, 1270, "橙色框里的白圈 = 实际 pad 1。", size=17, weight=700))
    parts.append(text(panel_x + 50, 1300, "所有 LED 的 pin 1 / DIN 都按丝印。", size=17))
    parts.append(text(panel_x + 50, 1330, "一颗反装就会让后面的灯整串不亮。", size=17))
    parts.append(text(panel_x + 50, 1370, "热插拔座：先只焊一只脚，", size=17, weight=700))
    parts.append(text(panel_x + 50, 1400, "确认座体平贴后再焊另一端。", size=17, weight=700))
    parts.append(text(panel_x + 50, 1450, "虚线并非封装；红色圆环是 SW 中心。", size=15, color="#6B7280"))

    parts.append(
        text(
            board_x + BOARD_W * scale - 4,
            board_y + BOARD_H * scale + 35,
            "底面视图（从 B.Cu 看）",
            size=17,
            color="#4B5563",
            weight=700,
            anchor="end",
        )
    )
    parts.append("</svg>")
    return "".join(parts)


def top_detail_svg(footprints: dict[str, dict]) -> str:
    canvas_w, canvas_h = 1800.0, 1850.0
    board_x, board_y, scale = 115.0, 145.0, 12.2
    inner = kicad_svg("F.SilkS,Edge.Cuts", False)
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{canvas_w}" height="{canvas_h}" '
        f'viewBox="0 0 {canvas_w} {canvas_h}">',
        '<rect width="100%" height="100%" fill="#E9E5DB"/>',
        title_block(
            "顶面：最后焊接 2–3 个直插件",
            "完成全部底面 SMD、清洁并检查后，再翻面焊 RE1 与 JS1；TP5 只在触摸面板需要时处理。",
            width=canvas_w,
        ),
        board_background(x=board_x, y=board_y, scale=scale),
        base_group(inner, x=board_x, y=board_y, scale=scale, opacity=0.3),
    ]

    callouts = {
        "RE1": ("S10-1  EC11 编码器", 340, 255),
        "JS1": ("S10-2  YA13 摇杆", 710, 255),
        "TP5": ("选装  Ø4.0 mm TP5", 310, 1435),
        "STAB1": ("机械件：不焊", 700, 1500),
    }
    for ref, (label, lx, ly) in callouts.items():
        fp = footprints[ref]
        px, py = point(fp, x=board_x, y=board_y, scale=scale, mirror=False)
        color = COLORS["S10"] if ref in {"RE1", "JS1"} else "#6B7280"
        parts.append(
            f'<path d="M {px:.1f} {py:.1f} L {lx - 18:.1f} {ly - 6:.1f}" '
            f'stroke="{color}" stroke-width="3" stroke-dasharray="7 6" fill="none"/>'
        )
        parts.append(marker(px, py, color, radius=9))
        parts.append(
            f'<rect x="{lx - 15:.1f}" y="{ly - 31:.1f}" width="330" height="48" rx="9" '
            f'fill="#FFFFFF" stroke="{color}" stroke-width="3"/>'
        )
        parts.append(text(lx + 5, ly, label, size=20, color=color, weight=800))

    panel_x = 1200
    parts.append(
        f'<rect x="{panel_x}" y="650" width="560" height="610" rx="16" fill="#FBF8F1" '
        'stroke="#C7C2B7" stroke-width="2"/>'
    )
    parts.append(text(panel_x + 28, 700, "顶面 THT 数量", size=27, weight=800))
    checklist = [
        ("RE1", "1 个 EC11 编码器", "7 个 THT 焊点"),
        ("JS1", "1 个 YA13 摇杆", "10 个 THT 焊点"),
        ("TP5", "0–1 个弹簧/导线", "1 个可选焊盘"),
        ("STAB1", "0–1 个 2U 卫星轴", "不焊，只穿过定位板"),
    ]
    for index, (ref, label, detail) in enumerate(checklist):
        y = 755 + index * 105
        color = COLORS["S10"] if ref in {"RE1", "JS1"} else "#4B5563"
        parts.append(marker(panel_x + 45, y - 7, color, radius=16, label=ref[:1], font_size=12))
        parts.append(text(panel_x + 75, y, label, size=19, weight=800))
        parts.append(text(panel_x + 75, y + 27, detail, size=16, color="#4B5563"))

    parts.append(
        '<rect x="115" y="1670" width="1570" height="95" rx="12" fill="#FEF2F2" '
        'stroke="#BE185D" stroke-width="3"/>'
    )
    parts.append(
        text(145, 1707, "安装前先干插一次", size=21, weight=800, color="#9D174D")
        + text(
            145,
            1738,
            "RE1 / JS1 先对好外框，焊两个对角脚，确认垂直、贴平和摇杆行程后再焊完全部机械脚与信号脚。",
            size=17,
        )
    )
    parts.append("</svg>")
    return "".join(parts)


STAGE_GUIDE_DATA = {
    "S1": {
        "title": "底层固定 R / C / FB",
        "subtitle": "LOW PROFILE",
        "groups": [
            ("30 × 100 nF 0402", "C1-C10, C13, C20-C24, C26-C39"),
            ("4 × 1 uF 0402", "C11, C12, C14, C15"),
            ("2 × 10 uF 0805", "C16, C17"),
            ("2 × 15 pF C0G", "C18, C19"),
            ("2 × 5.1 kΩ", "R1, R2"),
            ("2 × 27 Ω", "R3, R4"),
            ("4 × 1 kΩ", "R5, R6, R11, R12"),
            ("1 × 10 kΩ", "R7"),
            ("2 × 4.7 kΩ", "R8, R9"),
            ("1 × 0 Ω", "R10"),
            ("1 × 600 Ω 磁珠", "FB1"),
        ],
        "check": "先焊低矮被动件；不要装 C25。",
    },
    "S2": {
        "title": "USB / 电源入口",
        "subtitle": "POWER CHECKPOINT",
        "groups": [
            ("1 × AP2112K-3.3", "U3 · SOT-23-5"),
            ("1 × USBLC6-2SC6", "U4 · SOT-23-6"),
            ("1 × 750 mA 保险丝", "F1 · 1812"),
            ("1 × USB-C 16P", "J1 · TYPE-C-31-M-12"),
        ],
        "check": "装 U1 前先限流上电，确认 U3 输出 3.3 V。",
    },
    "S3": {
        "title": "MCU / Flash / 晶振",
        "subtitle": "FINE PITCH",
        "groups": [
            ("1 × RP2040", "U1 · QFN-56 0.4 mm"),
            ("1 × 16 MB Flash", "U2 · W25Q128JVSIQ"),
            ("1 × 12 MHz 晶振", "Y1 · ABM8-272-T3"),
        ],
        "check": "U1 中心焊盘必须回流，四边不能连锡。",
    },
    "S4": {
        "title": "灯控 / 触摸 IC",
        "subtitle": "SOT-23-6",
        "groups": [
            ("1 × SN74LVC1T45", "U5 · LED 电平转换"),
            ("1 × TTP223-BA6", "U6 · 触摸控制"),
            ("复核 R10 = 0 Ω", "已在 S1 安装"),
        ],
        "check": "U5/U6 对齐 pin 1，六脚之间不能桥连。",
    },
    "S5": {
        "title": "侧灯去耦 C40-C49",
        "subtitle": "UNDERGLOW DECOUPLING",
        "groups": [
            ("10 × 100 nF 0402", "C40-C49"),
            ("先焊电容", "再焊 LED15-LED24"),
            ("透明版固定安装", "每个侧灯都有独立去耦"),
        ],
        "check": "10 颗电容全部平贴，不要与侧灯焊盘短路。",
    },
    "S6": {
        "title": "每键 LED1-LED14",
        "subtitle": "REVERSE MOUNT RGB",
        "groups": [
            ("14 × SK6812MINI-E", "LED1-LED14"),
            ("第一排", "LED1-LED4"),
            ("第二排", "LED5-LED8"),
            ("第三排", "LED9-LED12"),
            ("2U / 指示位", "LED13, LED14"),
        ],
        "check": "每颗都是反装件，pin 1 白圈必须对齐。",
    },
    "S7": {
        "title": "侧灯 LED15-LED24",
        "subtitle": "EDGE-FIRING RGB",
        "groups": [
            ("10 × SK6812-SIDE", "LED15-LED24"),
            ("上边", "LED15, LED16"),
            ("右边", "LED17-LED19"),
            ("下边", "LED20, LED21"),
            ("左边", "LED22-LED24"),
        ],
        "check": "LED15/LED16 朝外是设计选择，不要自行旋转。",
    },
    "S8": {
        "title": "BOOT / RESET",
        "subtitle": "TACTILE SWITCH",
        "groups": [
            ("1 × BOOT", "SW14"),
            ("1 × RESET", "SW15"),
            ("PTS645SM43SMTR92 LFS", "6.0 × 6.0 × H4.3 鸥翼脚"),
        ],
        "check": "禁止使用 J 引脚版本；四脚先对角固定。",
    },
    "S9": {
        "title": "热插拔座 SW1-SW13",
        "subtitle": "LAST BOTTOM SMD",
        "groups": [
            ("13 × MX 热插拔座", "SW1-SW13"),
            ("型号", "Kailh CPG151101S11"),
            ("安装方向", "底面朝上，按丝印与板图"),
            ("真实 MX 轴体", "不焊，最后直接插入"),
        ],
        "check": "每个座子先焊一端，确认平贴后再焊另一端。",
    },
    "S10": {
        "title": "顶面直插件",
        "subtitle": "FLIP THE BOARD",
        "groups": [
            ("1 × EC11 编码器", "RE1 · PEC11R-4215F-S0024"),
            ("1 × YA13 摇杆", "JS1 · YA13-FL7.4-B5Ka"),
            ("选装 TP5", "仅电极式触摸面板需要"),
            ("STAB1", "机械卫星轴，不焊"),
        ],
        "check": "先对角固定，确认垂直、贴平和摇杆行程后再焊完。",
    },
}


PHASE_COLORS = {
    "P1": "#2563EB",
    "P2": "#0F766E",
    "P3": "#EA580C",
    "P4": "#7C3AED",
    "P5": "#0891B2",
    "P6": "#B91C1C",
    "P7": "#BE185D",
}


STEP_GUIDE_DATA = [
    {
        "number": "01",
        "phase": "P1",
        "phase_title": "被动件",
        "title": "30 × 100 nF 固定去耦",
        "subtitle": "0402 X7R",
        "value": "100 nF 0402 X7R",
        "package": "0402 / C_0402_1005Metric",
        "refs": [
            *(f"C{i}" for i in range(1, 11)),
            "C13",
            *(f"C{i}" for i in range(20, 25)),
            *(f"C{i}" for i in range(26, 40)),
        ],
        "ref_display": "C1-C10, C13, C20-C24, C26-C39",
        "summary": "先在底面完成 30 颗固定 100 nF 去耦电容。",
        "instructions": [
            "按 C1-C10、C13、C20-C24、C26-C39 逐一核对位号。",
            "每颗先固定一端，确认无立碑和偏移后再焊另一端。",
            "本步不要混入 C40-C49；它们属于透明版侧灯步骤。"
        ],
        "method": "烙铁逐件焊 / 低风速热风",
        "check": "30 颗全部安装，C25 不在此步。",
        "side": "bottom",
    },
    {
        "number": "02",
        "phase": "P1",
        "phase_title": "被动件",
        "title": "4 × 1 uF",
        "subtitle": "0402 X5R",
        "value": "1 uF 0402 X5R",
        "package": "0402 / C_0402_1005Metric",
        "refs": ["C11", "C12", "C14", "C15"],
        "summary": "焊接稳压器与 LDO 输入输出的 4 颗 1 uF 电容。",
        "instructions": [
            "先焊 C14、C15，再焊 C11、C12。",
            "逐颗确认焊盘没有桥连。",
            "不要与 100 nF 或 10 uF 电容混袋。"
        ],
        "method": "烙铁逐件焊 / 低风速热风",
        "check": "4 颗均为 1 uF，不得用 100 nF 替代。",
        "side": "bottom",
    },
    {
        "number": "03",
        "phase": "P1",
        "phase_title": "被动件",
        "title": "2 × 10 uF 大容量",
        "subtitle": "0805 X5R",
        "value": "10 uF 0805 X5R",
        "package": "0805 / C_0805_2012Metric",
        "refs": ["C16", "C17"],
        "summary": "安装 +5 V 与 +3V3 的 2 颗大容量储能电容。",
        "instructions": [
            "先给一个焊盘上锡，放平元件后焊另一端。",
            "确认底部没有立碑或翘起。",
            "这两颗比 0402 高，后面避免再被热风反复吹。"
        ],
        "method": "烙铁逐件焊 / 热风",
        "check": "C16、C17 均为 10 uF 0805。",
        "side": "bottom",
    },
    {
        "number": "04",
        "phase": "P1",
        "phase_title": "被动件",
        "title": "2 × 15 pF 晶振负载",
        "subtitle": "0402 C0G",
        "value": "15 pF 0402 C0G",
        "package": "0402 / C_0402_1005Metric",
        "refs": ["C18", "C19"],
        "summary": "安装 12 MHz 晶振的两颗负载电容。",
        "instructions": [
            "只使用 15 pF C0G，不要用 100 nF 替代。",
            "分别安装 C18、C19。",
            "焊完确认没有与晶振焊盘短路。"
        ],
        "method": "烙铁逐件焊 / 热风",
        "check": "容值和温度特性必须正确。",
        "side": "bottom",
    },
    {
        "number": "05",
        "phase": "P1",
        "phase_title": "被动件",
        "title": "2 × 5.1 kΩ",
        "subtitle": "USB-C CC",
        "value": "5.1 kΩ 1% 0402",
        "package": "0402 / R_0402_1005Metric",
        "refs": ["R1", "R2"],
        "summary": "焊接 USB-C 两颗 CC 下拉电阻。",
        "instructions": [
            "R1、R2 都是 5.1 kΩ。",
            "确认没有与 4.7 kΩ 电阻混袋。",
            "逐颗固定两端，避免立碑。"
        ],
        "method": "烙铁逐件焊",
        "check": "R1、R2 均为 5.1 kΩ。",
        "side": "bottom",
    },
    {
        "number": "06",
        "phase": "P1",
        "phase_title": "被动件",
        "title": "2 × 27 Ω",
        "subtitle": "USB D+/D-",
        "value": "27 Ω 0402",
        "package": "0402 / R_0402_1005Metric",
        "refs": ["R3", "R4"],
        "summary": "焊接 USB D+/D- 两颗串联电阻。",
        "instructions": [
            "R3、R4 都是 27 Ω。",
            "焊完用放大镜检查 USB 数据线焊盘。",
            "不要用 0 Ω 或 1 kΩ 替代。"
        ],
        "method": "烙铁逐件焊",
        "check": "R3、R4 均为 27 Ω。",
        "side": "bottom",
    },
    {
        "number": "07",
        "phase": "P1",
        "phase_title": "被动件",
        "title": "4 × 1 kΩ",
        "subtitle": "RC / BOOT",
        "value": "1 kΩ 0402",
        "package": "0402 / R_0402_1005Metric",
        "refs": ["R5", "R6", "R11", "R12"],
        "summary": "焊接晶振、BOOTSEL 和摇杆 RC 的 4 颗 1 kΩ。",
        "instructions": [
            "按 R5、R6、R11、R12 逐颗核对。",
            "不要与 10 kΩ、4.7 kΩ 混装。",
            "每颗确认电阻体完全贴平。"
        ],
        "method": "烙铁逐件焊",
        "check": "4 颗全部为 1 kΩ。",
        "side": "bottom",
    },
    {
        "number": "08",
        "phase": "P1",
        "phase_title": "被动件",
        "title": "1 × 10 kΩ",
        "subtitle": "RUN PULL-UP",
        "value": "10 kΩ 0402",
        "package": "0402 / R_0402_1005Metric",
        "refs": ["R7"],
        "summary": "安装 RP2040 RUN 引脚的 10 kΩ 上拉电阻。",
        "instructions": [
            "只安装 R7。",
            "确认阻值为 10 kΩ。",
            "焊完检查两端焊盘无桥连。"
        ],
        "method": "烙铁",
        "check": "R7 = 10 kΩ。",
        "side": "bottom",
    },
    {
        "number": "09",
        "phase": "P1",
        "phase_title": "被动件",
        "title": "2 × 4.7 kΩ",
        "subtitle": "I2C PULL-UP",
        "value": "4.7 kΩ 0402",
        "package": "0402 / R_0402_1005Metric",
        "refs": ["R8", "R9"],
        "summary": "安装 I2C SDA/SCL 的两颗 4.7 kΩ 上拉。",
        "instructions": [
            "R8、R9 都是 4.7 kΩ。",
            "不要与 5.1 kΩ 混袋。",
            "逐颗确认焊端完整。"
        ],
        "method": "烙铁逐件焊",
        "check": "R8、R9 均为 4.7 kΩ。",
        "side": "bottom",
    },
    {
        "number": "10",
        "phase": "P1",
        "phase_title": "被动件",
        "title": "1 × 0 Ω",
        "subtitle": "TOUCH AHLB STRAP",
        "value": "0 Ω 0402",
        "package": "0402 / R_0402_1005Metric",
        "refs": ["R10"],
        "summary": "安装触摸 AHLB 配置的 0 Ω 跳线。",
        "instructions": [
            "只安装 R10。",
            "确认没有装成普通电阻。",
            "R10 决定触摸高有效配置，不能漏装。"
        ],
        "method": "烙铁",
        "check": "R10 = 0 Ω。",
        "side": "bottom",
    },
    {
        "number": "11",
        "phase": "P1",
        "phase_title": "被动件",
        "title": "1 × 600 Ω 磁珠",
        "subtitle": "ADC_AVDD FILTER",
        "value": "600 Ω @ 100 MHz",
        "package": "0402 / L_0402_1005Metric",
        "refs": ["FB1"],
        "summary": "安装 ADC_AVDD 电源滤波磁珠。",
        "instructions": [
            "只安装 FB1。",
            "磁珠外形像电阻，不能混入 R 袋。",
            "确认焊盘两端无桥连。"
        ],
        "method": "烙铁 / 热风",
        "check": "FB1 = 600 Ω @ 100 MHz。",
        "side": "bottom",
    },
    {
        "number": "12",
        "phase": "P2",
        "phase_title": "电源",
        "title": "1 × AP2112K-3.3",
        "subtitle": "3.3 V LDO",
        "value": "AP2112K-3.3",
        "package": "SOT-23-5",
        "refs": ["U3"],
        "summary": "先安装 3.3 V LDO，为后续电源测试做准备。",
        "instructions": [
            "对齐 U3 pin 1。",
            "先固定一只脚，确认芯片平贴后焊完。",
            "检查 5 只脚之间没有锡桥。"
        ],
        "method": "锡膏 / 助焊剂 + 热风",
        "check": "方向、pin 1 和脚间连锡。",
        "side": "bottom",
    },
    {
        "number": "13",
        "phase": "P2",
        "phase_title": "电源",
        "title": "1 × USBLC6-2SC6",
        "subtitle": "USB ESD ARRAY",
        "value": "USBLC6-2SC6",
        "package": "SOT-23-6",
        "refs": ["U4"],
        "summary": "安装 USB D+/D- ESD 保护阵列。",
        "instructions": [
            "对齐 U4 pin 1。",
            "先固定对角脚，再焊余下四脚。",
            "重点检查 D+、D-、VBUS 相邻脚无桥连。"
        ],
        "method": "锡膏 / 助焊剂 + 热风",
        "check": "pin 1 方向和 USB 数据脚连锡。",
        "side": "bottom",
    },
    {
        "number": "14",
        "phase": "P2",
        "phase_title": "电源",
        "title": "1 × 750 mA 保险丝",
        "subtitle": "USB INPUT PROTECTION",
        "value": "MF-MSMF075/24-2",
        "package": "1812 / Fuse_1812_4532Metric",
        "refs": ["F1"],
        "summary": "安装 USB 输入自恢复保险丝。",
        "instructions": [
            "只安装 F1。",
            "1812 封装必须完全平贴。",
            "确认两端焊盘均有焊锡，不使用过多锡。"
        ],
        "method": "烙铁 / 热风",
        "check": "F1 无裂纹、无偏斜、两端可靠连接。",
        "side": "bottom",
    },
    {
        "number": "15",
        "phase": "P2",
        "phase_title": "电源",
        "title": "1 × USB-C 16P",
        "subtitle": "POWER CHECKPOINT",
        "value": "TYPE-C-31-M-12",
        "package": "USB_C_Receptacle_HRO",
        "refs": ["J1"],
        "summary": "安装 USB-C 座；完成后先验证 3.3 V，再继续主控。",
        "instructions": [
            "先固定两端壳脚，确认开口朝板外。",
            "逐脚焊 VBUS、CC、D+、D- 与 GND。",
            "限流 100 mA 上电，测量 U3 输出约 3.3 V。",
            "3.3 V 异常时停止，不要安装 U1。"
        ],
        "method": "锡膏 + 热风，壳脚可补烙铁",
        "check": "USB 无短路、3.3 V 正常后才能进入下一步。",
        "side": "bottom",
    },
    {
        "number": "16",
        "phase": "P3",
        "phase_title": "主控",
        "title": "1 × RP2040",
        "subtitle": "QFN-56 · 0.4 mm",
        "value": "RP2040",
        "package": "QFN-56 + EP 3.2 × 3.2",
        "refs": ["U1"],
        "summary": "安装本板最难的高密度主控芯片。",
        "instructions": [
            "焊盘薄涂锡膏，中心散热焊盘只放少量。",
            "严格对齐 U1 pin 1。",
            "低风速热风回流，让芯片自行回位。",
            "冷却后用助焊剂和吸锡带清理脚间连锡。"
        ],
        "method": "锡膏 + 热风（不能只靠烙铁）",
        "check": "四边无连锡、中心焊盘已回流、3.3 V 无短路。",
        "side": "bottom",
    },
    {
        "number": "17",
        "phase": "P3",
        "phase_title": "主控",
        "title": "1 × 16 MB Flash",
        "subtitle": "QSPI SOIC-8",
        "value": "W25Q128JVSIQ",
        "package": "SOIC-8 / 1.27 mm",
        "refs": ["U2"],
        "summary": "安装 RP2040 的 QSPI Flash。",
        "instructions": [
            "U2 对齐 pin 1。",
            "使用热风或逐脚拖焊。",
            "检查 8 只脚均连接且相邻脚无桥连。"
        ],
        "method": "热风 / 拖焊",
        "check": "pin 1 方向、8 脚焊接完整。",
        "side": "bottom",
    },
    {
        "number": "18",
        "phase": "P3",
        "phase_title": "主控",
        "title": "1 × 12 MHz 晶振",
        "subtitle": "4-PAD CRYSTAL",
        "value": "ABM8-272-T3",
        "package": "3225 / 4-pad",
        "refs": ["Y1"],
        "summary": "安装 RP2040 的 12 MHz 晶振。",
        "instructions": [
            "按丝印方向放正 Y1。",
            "先固定一个角，再焊其余三脚。",
            "不要歪斜或悬空。"
        ],
        "method": "烙铁点焊四角 / 热风",
        "check": "Y1 方向正确，四脚可靠连接。",
        "side": "bottom",
    },
    {
        "number": "19",
        "phase": "P4",
        "phase_title": "辅助 IC",
        "title": "1 × SN74LVC1T45",
        "subtitle": "LED LEVEL SHIFTER",
        "value": "SN74LVC1T45DBVR",
        "package": "SOT-23-6",
        "refs": ["U5"],
        "summary": "安装 LED 数据电平转换器。",
        "instructions": [
            "U5 对齐 pin 1。",
            "先固定对角脚，再焊余下四脚。",
            "检查六脚之间没有锡桥。"
        ],
        "method": "烙铁 / 热风",
        "check": "pin 1 正确，六脚无桥连。",
        "side": "bottom",
    },
    {
        "number": "20",
        "phase": "P4",
        "phase_title": "辅助 IC",
        "title": "1 × TTP223-BA6",
        "subtitle": "TOUCH CONTROLLER",
        "value": "TTP223-BA6",
        "package": "SOT-23-6",
        "refs": ["U6"],
        "summary": "安装触摸输入控制器。",
        "instructions": [
            "U6 对齐 pin 1。",
            "先固定对角脚，再焊余下四脚。",
            "复核 R10 已在第一步组中安装。"
        ],
        "method": "烙铁 / 热风",
        "check": "pin 1 正确，六脚无桥连，R10 = 0 Ω。",
        "side": "bottom",
    },
    {
        "number": "21",
        "phase": "P5",
        "phase_title": "灯光",
        "title": "10 × 100 nF 侧灯去耦",
        "subtitle": "TRANSLUCENT ONLY",
        "value": "100 nF 0402 X7R",
        "package": "0402 / C_0402_1005Metric",
        "refs": [f"C{i}" for i in range(40, 50)],
        "ref_display": "C40-C49",
        "summary": "透明版固定安装的 10 颗侧灯去耦电容。",
        "instructions": [
            "按 C40-C49 逐一安装。",
            "每颗先固定一端，再焊另一端。",
            "检查电容与侧面 LED 焊盘不短路。"
        ],
        "method": "烙铁逐件焊 / 热风",
        "check": "10 颗全部安装，不得留空。",
        "side": "bottom",
    },
    {
        "number": "22",
        "phase": "P5",
        "phase_title": "灯光",
        "title": "14 × 反装 RGB LED",
        "subtitle": "PER-KEY LED",
        "value": "SK6812MINI-E",
        "package": "LED_6028R 反装",
        "refs": [f"LED{i}" for i in range(1, 15)],
        "ref_display": "LED1-LED14",
        "summary": "安装 14 颗主灯链 LED1-LED14。",
        "instructions": [
            "每颗按板上 pin 1 / DIN 标记对齐。",
            "先固定对角两点，再焊另外两点。",
            "LED13 在 2U 轴位，LED14 是独立指示位。"
        ],
        "method": "烙铁逐脚焊 / 低风速热风",
        "check": "14 颗方向全部正确，一颗反装会导致后续整串异常。",
        "side": "bottom",
    },
    {
        "number": "23",
        "phase": "P5",
        "phase_title": "灯光",
        "title": "10 × 侧发光 RGB LED",
        "subtitle": "EDGE-FIRING LED",
        "value": "SK6812SIDE-A",
        "package": "LED_WS2812_4020",
        "refs": [f"LED{i}" for i in range(15, 25)],
        "ref_display": "LED15-LED24",
        "summary": "安装透明版四周的 10 颗侧发光 LED。",
        "instructions": [
            "上边 LED15-LED16，右边 LED17-LED19。",
            "下边 LED20-LED21，左边 LED22-LED24。",
            "LED15、LED16 按设计朝外，不要旋转。"
        ],
        "method": "烙铁逐脚焊 / 低风速热风",
        "check": "10 颗均对齐 pin 1，LED15/LED16 保持向外。",
        "side": "bottom",
    },
    {
        "number": "24",
        "phase": "P6",
        "phase_title": "按键与座",
        "title": "2 × 6 mm 轻触按键",
        "subtitle": "BOOT / RESET",
        "value": "PTS645SM43SMTR92 LFS",
        "package": "6.0 × 6.0 mm H4.3 鸥翼脚",
        "refs": ["SW14", "SW15"],
        "summary": "安装 BOOT 和 RESET 两颗同型号轻触按键。",
        "instructions": [
            "SW14 = BOOT，SW15 = RESET。",
            "先对角固定，确认按键平贴后再焊余下两脚。",
            "禁止使用 J 引脚型号。"
        ],
        "method": "烙铁，四脚对角固定",
        "check": "型号、方向和平贴度。",
        "side": "bottom",
    },
    {
        "number": "25",
        "phase": "P6",
        "phase_title": "按键与座",
        "title": "13 × MX 热插拔座",
        "subtitle": "LAST BOTTOM SMD",
        "value": "Kailh CPG151101S11",
        "package": "SW_MX_HS_CPG151101S11_1u",
        "refs": [f"SW{i}" for i in range(1, 14)],
        "ref_display": "SW1-SW13",
        "summary": "安装 13 个 MX 热插拔座；实际轴体不焊。",
        "instructions": [
            "从 SW4→SW3→SW2→SW1 开始，按排推进。",
            "每个座子先焊一端，确认平贴后再焊另一端。",
            "座内不能进锡，不要用轴体做高温夹具。"
        ],
        "method": "烙铁，先固定一端",
        "check": "13 个方向一致、平贴、座内无异物。",
        "side": "bottom",
    },
    {
        "number": "26",
        "phase": "P7",
        "phase_title": "顶面直插",
        "title": "1 × EC11 编码器",
        "subtitle": "TOP SIDE · THT",
        "value": "PEC11R-4215F-S0024",
        "package": "EC11 vertical H20",
        "refs": ["RE1"],
        "summary": "翻面后安装旋转编码器。",
        "instructions": [
            "先干插 RE1，确认 7 个焊点都能进入。",
            "只焊两个对角脚，检查垂直和贴平。",
            "确认后再焊全部信号脚与机械脚。"
        ],
        "method": "烙铁（THT）",
        "check": "轴垂直、器件贴平、A/B/C 与机械脚全部可靠。",
        "side": "top",
    },
    {
        "number": "27",
        "phase": "P7",
        "phase_title": "顶面直插",
        "title": "1 × YA13 摇杆",
        "subtitle": "TOP SIDE · THT",
        "value": "YA13-FL7.4-B5Ka",
        "package": "10-pad tilt joystick",
        "refs": ["JS1"],
        "summary": "翻面后安装两轴模拟摇杆。",
        "instructions": [
            "干插 JS1，确认 10 个焊点无应力进入。",
            "先焊两个对角脚，检查垂直和行程。",
            "确认摇杆能完整活动后焊完剩余焊点。"
        ],
        "method": "烙铁（THT）",
        "check": "10 个焊点可靠，摇杆不被结构干涉。",
        "side": "top",
    },
    {
        "number": "28",
        "phase": "P7",
        "phase_title": "顶面直插",
        "title": "TP5 触摸触点",
        "subtitle": "OPTIONAL CONTACT",
        "value": "用户选弹簧 / 导线",
        "package": "TP5 Ø4.0 mm 焊盘",
        "refs": ["TP5"],
        "summary": "只有使用电极式触摸定位板时才安装。",
        "instructions": [
            "普通打印板或空白 FR4 板不需要焊接。",
            "选择能稳定压住定位板电极的弹簧或导线。",
            "焊后确认触点不会短路到其他焊盘。"
        ],
        "method": "烙铁（选装）",
        "check": "仅电极式面板需要；其他情况留空。",
        "side": "top",
        "optional": True,
    },
]


def stage_refs(
    code: str,
    footprints: dict[str, dict],
    bom: dict[str, dict[str, str]],
) -> list[str]:
    refs = [
        ref
        for ref in footprints
        if ref in bom and stage_for(ref) == code and bom[ref]["Populate"] == "Place"
    ]
    return sorted(refs, key=lambda ref: (ref.rstrip("0123456789"), ref_number(ref)))


def footprint_mark_size(fp: dict) -> tuple[float, float]:
    footprint = fp["footprint"]
    if "SW_MX_HS" in footprint:
        width, height = 17.0, 14.0
    elif "SW_SPST" in footprint:
        width, height = 8.5, 8.5
    elif "YA13" in footprint:
        width, height = 20.0, 20.0
    elif "RotaryEncoder" in footprint:
        width, height = 20.0, 20.0
    elif "USB_C" in footprint:
        width, height = 12.0, 7.0
    elif "QFN-56" in footprint:
        width, height = 10.0, 10.0
    elif "SOIC-8" in footprint:
        width, height = 9.0, 7.0
    elif "SOT-23" in footprint:
        width, height = 5.0, 5.0
    elif "Crystal_SMD" in footprint:
        width, height = 5.2, 4.2
    elif "Fuse_1812" in footprint:
        width, height = 5.5, 3.5
    elif "LED_6028R" in footprint:
        width, height = 7.0, 7.0
    elif "LED_WS2812_4020" in footprint:
        width, height = 5.5, 3.5
    elif "TestPoint_Pad_D4" in footprint:
        width, height = 7.0, 7.0
    elif "C_0805" in footprint:
        width, height = 3.2, 2.0
    else:
        width, height = 2.6, 1.6
    if abs(float(fp["rot_deg"])) % 180 == 90:
        width, height = height, width
    return width, height


def stage_detail_svg(
    code: str,
    footprints: dict[str, dict],
    bom: dict[str, dict[str, str]],
) -> str:
    info = STAGE_GUIDE_DATA[code]
    is_top = code == "S10"
    color = COLORS[code]
    refs = stage_refs(code, footprints, bom)
    canvas_w, canvas_h = 2000.0, 2000.0
    board_x, board_y, scale = 70.0, 138.0, 17.15
    inner = kicad_svg("F.SilkS,Edge.Cuts" if is_top else "B.SilkS,Edge.Cuts", not is_top)
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{canvas_w}" height="{canvas_h}" '
        f'viewBox="0 0 {canvas_w} {canvas_h}">',
        '<rect width="100%" height="100%" fill="#E9E5DB"/>',
        title_block(
            f"{code} · {info['title']}",
            f"透明版全装 · 本步 {len(refs)} 件。{'顶面视图' if is_top else '底面视图，USB-C 在上方'}；高亮框就是本步焊接位置。",
            width=canvas_w,
            color=color,
        ),
        board_background(x=board_x, y=board_y, scale=scale),
        base_group(
            inner,
            x=board_x,
            y=board_y,
            scale=scale,
            opacity=0.25,
        ),
    ]

    label_refs = code not in {"S1"}
    for ref in refs:
        fp = footprints[ref]
        px, py = point(
            fp,
            x=board_x,
            y=board_y,
            scale=scale,
            mirror=not is_top,
        )
        width, height = footprint_mark_size(fp)
        width_px, height_px = width * scale, height * scale
        rect_x = min(
            max(board_x, px - width_px / 2),
            board_x + BOARD_W * scale - width_px,
        )
        rect_y = min(
            max(board_y, py - height_px / 2),
            board_y + BOARD_H * scale - height_px,
        )
        parts.append(
            f'<rect x="{rect_x:.1f}" y="{rect_y:.1f}" '
            f'width="{width_px:.1f}" height="{height_px:.1f}" rx="5" '
            f'fill="{color}" fill-opacity="0.20" stroke="{color}" stroke-width="4"/>'
        )
        if label_refs:
            show_value = code not in {"S1", "S6", "S9"}
            short_values = {
                "U3": "AP2112K-3.3",
                "U4": "USBLC6",
                "F1": "750mA",
                "J1": "USB-C 16P",
                "U1": "RP2040",
                "U2": "W25Q128",
                "Y1": "12MHz",
                "U5": "74LVC1T45",
                "U6": "TTP223",
                "RE1": "EC11",
                "JS1": "YA13",
            }
            label_text = ref
            if show_value:
                value = short_values.get(ref)
                if value is None:
                    raw = bom[ref]["Value"]
                    if ref.startswith("C"):
                        value = raw.split()[0]
                    elif ref.startswith("LED"):
                        value = "SK6812-SIDE"
                    else:
                        value = raw
                label_text = f"{ref} · {value}"
            label_w = max(48.0, len(label_text) * 8.0 + 18)
            label_x = rect_x + width_px + 5
            label_y = py - 14
            if label_x + label_w > board_x + BOARD_W * scale - 5:
                label_x = rect_x - label_w - 5
            label_x = max(board_x + 4, label_x)
            parts.append(
                f'<rect x="{label_x:.1f}" y="{label_y - 12:.1f}" width="{label_w:.1f}" '
                f'height="24" rx="4" fill="#FFFFFF" fill-opacity="0.96" '
                f'stroke="{color}" stroke-width="2"/>'
            )
            parts.append(
                text(
                    label_x + label_w / 2,
                    label_y + 4,
                    label_text,
                    size=11,
                    color=color,
                    weight=800,
                    family=MONO,
                    anchor="middle",
                )
            )

    panel_x = 1530.0
    parts.append(
        f'<rect x="{panel_x}" y="145" width="410" height="1720" rx="12" '
        f'fill="#FBF8F1" stroke="{color}" stroke-width="4"/>'
    )
    parts.append(
        f'<rect x="{panel_x}" y="145" width="410" height="142" rx="12" fill="{color}"/>'
    )
    parts.append(text(panel_x + 26, 194, code, size=34, color="#FFFFFF", weight=900, family=DISPLAY))
    parts.append(text(panel_x + 98, 194, info["title"], size=23, color="#FFFFFF", weight=800))
    parts.append(text(panel_x + 26, 236, info["subtitle"], size=12, color="#FFFFFF", family=MONO))
    parts.append(text(panel_x + 26, 271, f"{len(refs)} 件", size=22, color="#FFFFFF", weight=800))

    y = 345.0
    parts.append(text(panel_x + 26, y, "使用什么元件", size=18, weight=800))
    y += 35
    for label, refs_text in info["groups"]:
        parts.append(
            f'<rect x="{panel_x + 24}" y="{y - 15:.1f}" width="6" height="38" fill="{color}"/>'
        )
        parts.append(text(panel_x + 44, y, label, size=15, weight=800))
        wrapped = refs_text
        parts.append(text(panel_x + 44, y + 20, wrapped, size=12, color="#4D514B"))
        y += 76

    parts.append(
        f'<rect x="{panel_x + 24}" y="1640" width="362" height="170" rx="10" '
        f'fill="{color}" fill-opacity="0.10" stroke="{color}" stroke-width="2"/>'
    )
    parts.append(text(panel_x + 44, 1678, "本步检查", size=16, weight=800, color=color))
    check = info["check"]
    check_lines = [check[i : i + 26] for i in range(0, len(check), 26)]
    for index, line in enumerate(check_lines[:4]):
        parts.append(text(panel_x + 44, 1712 + index * 23, line, size=13, color="#363A35"))
    parts.append(
        text(
            panel_x + 24,
            1850,
            "高亮框 = 本步安装位置",
            size=12,
            color="#6B7280",
            family=MONO,
        )
    )
    parts.append("</svg>")
    return "".join(parts)


def wrap_lines(value: str, width: int) -> list[str]:
    return [value[index : index + width] for index in range(0, len(value), width)]


def step_detail_svg(
    step: dict,
    footprints: dict[str, dict],
) -> str:
    color = PHASE_COLORS[step["phase"]]
    is_top = step["side"] == "top"
    refs = step["refs"]
    canvas_w, canvas_h = 2000.0, 2000.0
    board_x, board_y, scale = 70.0, 138.0, 17.15
    inner = kicad_svg("F.SilkS,Edge.Cuts" if is_top else "B.SilkS,Edge.Cuts", not is_top)
    refs_text = step.get("ref_display", ", ".join(refs))
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{canvas_w}" height="{canvas_h}" '
        f'viewBox="0 0 {canvas_w} {canvas_h}">',
        '<rect width="100%" height="100%" fill="#E9E5DB"/>',
        title_block(
            f"STEP {step['number']} · {step['title']}",
            f"透明版全装 · {len(refs)} 件同型号元件。{'顶面视图' if is_top else '底面视图，USB-C 在上方'}；高亮框 = 本步位置。",
            width=canvas_w,
            color=color,
        ),
        board_background(x=board_x, y=board_y, scale=scale),
        base_group(
            inner,
            x=board_x,
            y=board_y,
            scale=scale,
            opacity=0.25,
        ),
    ]

    for ref in refs:
        fp = footprints[ref]
        px, py = point(
            fp,
            x=board_x,
            y=board_y,
            scale=scale,
            mirror=not is_top,
        )
        width, height = footprint_mark_size(fp)
        width_px, height_px = width * scale, height * scale
        rect_x = min(
            max(board_x, px - width_px / 2),
            board_x + BOARD_W * scale - width_px,
        )
        rect_y = min(
            max(board_y, py - height_px / 2),
            board_y + BOARD_H * scale - height_px,
        )
        parts.append(
            f'<rect x="{rect_x:.1f}" y="{rect_y:.1f}" '
            f'width="{width_px:.1f}" height="{height_px:.1f}" rx="5" '
            f'fill="{color}" fill-opacity="0.22" stroke="{color}" stroke-width="4"/>'
        )
        if len(refs) <= 14:
            label_w = max(44.0, len(ref) * 8.5 + 16)
            label_x = rect_x + width_px + 5
            if label_x + label_w > board_x + BOARD_W * scale - 5:
                label_x = rect_x - label_w - 5
            label_x = max(board_x + 4, label_x)
            parts.append(
                f'<rect x="{label_x:.1f}" y="{py - 26:.1f}" width="{label_w:.1f}" '
                f'height="24" rx="4" fill="#FFFFFF" fill-opacity="0.96" '
                f'stroke="{color}" stroke-width="2"/>'
            )
            parts.append(
                text(
                    label_x + label_w / 2,
                    py - 8,
                    ref,
                    size=11,
                    color=color,
                    weight=800,
                    family=MONO,
                    anchor="middle",
                )
            )

    panel_x = 1530.0
    parts.append(
        f'<rect x="{panel_x}" y="145" width="410" height="1720" rx="12" '
        f'fill="#FBF8F1" stroke="{color}" stroke-width="4"/>'
    )
    parts.append(
        f'<rect x="{panel_x}" y="145" width="410" height="190" rx="12" fill="{color}"/>'
    )
    parts.append(text(panel_x + 26, 195, f"STEP {step['number']}", size=18, color="#FFFFFF", weight=800, family=MONO))
    title_lines = wrap_lines(step["title"], 16)
    for index, line in enumerate(title_lines[:2]):
        parts.append(text(panel_x + 26, 232 + index * 30, line, size=25, color="#FFFFFF", weight=900))
    parts.append(text(panel_x + 26, 310, step["subtitle"], size=12, color="#FFFFFF", family=MONO))

    y = 390.0
    parts.append(text(panel_x + 26, y, "本步只焊这一种型号", size=18, weight=800, color=color))
    y += 38
    parts.append(text(panel_x + 26, y, f"{len(refs)} 件", size=26, weight=900))
    y += 45
    parts.append(text(panel_x + 26, y, "型号 / 值", size=12, color="#6B7280", family=MONO))
    for line in wrap_lines(step["value"], 25)[:3]:
        y += 25
        parts.append(text(panel_x + 26, y, line, size=16, weight=800))
    y += 38
    parts.append(text(panel_x + 26, y, "封装", size=12, color="#6B7280", family=MONO))
    for line in wrap_lines(step["package"], 25)[:3]:
        y += 23
        parts.append(text(panel_x + 26, y, line, size=14, color="#363A35"))
    y += 38
    parts.append(text(panel_x + 26, y, "参考位号", size=12, color="#6B7280", family=MONO))
    for line in wrap_lines(refs_text, 26):
        y += 22
        parts.append(text(panel_x + 26, y, line, size=12, color="#363A35", family=MONO))
    y += 42
    parts.append(text(panel_x + 26, y, "焊接方式", size=12, color="#6B7280", family=MONO))
    for line in wrap_lines(step["method"], 23)[:3]:
        y += 23
        parts.append(text(panel_x + 26, y, line, size=14, color="#363A35"))

    parts.append(
        f'<rect x="{panel_x + 24}" y="1580" width="362" height="230" rx="10" '
        f'fill="{color}" fill-opacity="0.10" stroke="{color}" stroke-width="2"/>'
    )
    parts.append(text(panel_x + 44, 1622, "本步检查", size=17, weight=800, color=color))
    for index, line in enumerate(wrap_lines(step["check"], 25)[:5]):
        parts.append(text(panel_x + 44, 1658 + index * 24, line, size=13, color="#363A35"))
    parts.append(
        text(
            panel_x + 24,
            1850,
            "高亮框 = 本步要焊的同型号元件",
            size=12,
            color="#6B7280",
            family=MONO,
        )
    )
    parts.append("</svg>")
    return "".join(parts)


def write_web_steps() -> None:
    payload = []
    for index, step in enumerate(STEP_GUIDE_DATA):
        refs = step["refs"]
        payload.append(
            {
                "id": f"step-{int(step['number']):02d}",
                "code": step["number"],
                "count": "选装 0–1 件" if step.get("optional") else f"{len(refs)} 件",
                "color": PHASE_COLORS[step["phase"]],
                "phase": step["phase"],
                "phaseTitle": step["phase_title"],
                "title": step["title"],
                "subtitle": step["subtitle"],
                "image": f"step-{int(step['number']):02d}.zh-CN.png",
                "summary": step["summary"],
                "parts": [
                    f"型号 · {step['value']}",
                    f"封装 · {step['package']}",
                    f"位号 · {step.get('ref_display', ', '.join(refs))}",
                ],
                "steps": step["instructions"],
                "checkpoint": step["check"],
                "method": step["method"],
                "side": step["side"],
                "optional": bool(step.get("optional")),
                "index": index + 1,
            }
        )
    write_clean_text(
        OUT / "web-steps.js",
        "/* Generated from the transparent-build single-type soldering steps. */\n"
        f"window.AGENTPAD_STEPS = {json.dumps(payload, ensure_ascii=False, indent=2)};\n",
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    opaque, translucent = load_bom()
    footprints = load_footprints()
    pad1_positions = load_pad1_positions()
    assert len([ref for ref in opaque if opaque[ref]["Populate"] == "Place"]) == 91
    assert len([ref for ref in translucent if translucent[ref]["Populate"] == "Place"]) == 111
    write_checklist(opaque, translucent, footprints)
    write_web_data()
    write_web_steps()
    outputs = {
        "bottom-overview.zh-CN.svg": overview_svg(footprints),
        "bottom-upper-detail.zh-CN.svg": upper_detail_svg(
            footprints,
            opaque,
            translucent,
            pad1_positions,
        ),
        "bottom-matrix-led.zh-CN.svg": matrix_detail_svg(
            footprints,
            translucent,
            pad1_positions,
        ),
        "top-tht.zh-CN.svg": top_detail_svg(footprints),
    }
    for code in STAGE_GUIDE_DATA:
        outputs[f"stage-{code.lower()}.zh-CN.svg"] = stage_detail_svg(
            code,
            footprints,
            translucent,
        )
    for step in STEP_GUIDE_DATA:
        outputs[f"step-{step['number']}.zh-CN.svg"] = step_detail_svg(step, footprints)
    for name, content in outputs.items():
        write_clean_text(OUT / name, content)
        print(f"wrote {OUT / name}")


if __name__ == "__main__":
    main()
