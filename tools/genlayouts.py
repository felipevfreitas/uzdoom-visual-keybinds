#!/usr/bin/env python3
"""Generates zscript/vkb/layouts.zs from UZDoom's KeyNames table.

Usage: genlayouts.py <path to c_bind.cpp> <output .zs>
"""
import re
import sys

src = open(sys.argv[1], encoding="utf-8").read()
start = src.index("const char *KeyNames[NUM_KEYS]")
block = src[start:src.index("// non-keyboard buttons", start)]
block = block.replace("#ifdef __APPLE__", "\x00APPLE").replace("#else // !__APPLE__", "\x00ELSE").replace("#endif // __APPLE__", "\x00END")
# Keep the non-Apple branch (Windows/Linux names).
block = re.sub(r"\x00APPLE.*?\x00ELSE", "", block, flags=re.S).replace("\x00END", "")
body = block[block.index("{") + 1:]
tokens = re.findall(r'nullptr|"((?:\\.|[^"\\])*)"', body)
# re.findall with one group returns '' for nullptr; rebuild properly
items = re.findall(r'(nullptr|"(?:\\.|[^"\\])*")', body)
names = {}
for code, tok in enumerate(items):
    if tok == "nullptr":
        continue
    name = tok[1:-1].replace("\\\\", "\\")
    names[name.lower()] = code
assert names["escape"] == 1 and names["a"] == 0x1E and names["uparrow"] == 0xC8, "table parse failed"
assert names["lwin"] == 0xDB and names["kp-enter"] == 0x9C

MOUSE = {"mouse1": 0x100, "mouse2": 0x101, "mouse3": 0x102, "mouse4": 0x103,
         "mouse5": 0x104, "mwheelup": 0x198, "mwheeldown": 0x199}

def code(n):
    if n is None:
        return 0
    n = n.lower()
    if n in MOUSE:
        return MOUSE[n]
    return names[n]

# Each row: list of (keyname or None for non-bindable, label, width[, height])
def row(y, x0, keys, out):
    x = x0
    for k in keys:
        if k == "gap":
            x += 0.5
            continue
        if isinstance(k, tuple) and k[0] == "skip":
            x += k[1]
            continue
        name, label, w = k[0], k[1], k[2]
        h = k[3] if len(k) > 3 else 1.0
        out.append((code(name), x, y, w, h, label, name is not None))
        x += w

def k(name, label=None, w=1.0, h=1.0):
    return (name, label if label is not None else name.upper(), w, h)

NUM_ROW = [k("`", "`"), k("1"), k("2"), k("3"), k("4"), k("5"), k("6"), k("7"), k("8"), k("9"), k("0"), k("-", "-"), k("=", "=")]
Q_ROW = [k("Q"), k("W"), k("E"), k("R"), k("T"), k("Y"), k("U"), k("I"), k("O"), k("P"), k("[", "["), k("]", "]")]
A_ROW = [k("A"), k("S"), k("D"), k("F"), k("G"), k("H"), k("J"), k("K"), k("L"), k(";", ";"), k("'", "'")]
Z_ROW = [k("Z"), k("X"), k("C"), k("V"), k("B"), k("N"), k("M"), k(",", ","), k(".", "."), k("/", "/")]

def main_block(out, y0, esc_on_grave=False):
    nums = list(NUM_ROW)
    if esc_on_grave:
        nums[0] = k("Escape", "Esc")
    row(y0, 0, nums + [k("Backspace", "Backspace", 2)], out)
    row(y0 + 1, 0, [k("Tab", "Tab", 1.5)] + Q_ROW + [k("\\", "\\", 1.5)], out)
    row(y0 + 2, 0, [k("CapsLock", "Caps", 1.75)] + A_ROW + [k("Enter", "Enter", 2.25)], out)

def layout_100():
    out = []
    row(0, 0, [k("Escape", "Esc"), ("skip", 1.0), k("F1"), k("F2"), k("F3"), k("F4"), ("skip", 0.5),
               k("F5"), k("F6"), k("F7"), k("F8"), ("skip", 0.5), k("F9"), k("F10"), k("F11"), k("F12")], out)
    row(0, 15.25, [k("SysRq", "PrtSc"), k("Scroll", "ScrLk"), k("Pause", "Pause")], out)
    y = 1.25
    main_block(out, y)
    row(y + 3, 0, [k("Shift", "Shift", 2.25)] + Z_ROW + [k("RShift", "Shift", 2.75)], out)
    row(y + 4, 0, [k("Ctrl", "Ctrl", 1.25), k("LWin", "Win", 1.25), k("Alt", "Alt", 1.25), k("Space", "Space", 6.25),
                   k("RAlt", "Alt", 1.25), k("RWin", "Win", 1.25), k("Apps", "Menu", 1.25), k("RCtrl", "Ctrl", 1.25)], out)
    # navigation cluster
    row(y, 15.25, [k("Ins", "Ins"), k("Home", "Home"), k("PgUp", "PgUp")], out)
    row(y + 1, 15.25, [k("Del", "Del"), k("End", "End"), k("PgDn", "PgDn")], out)
    row(y + 3, 16.25, [k("UpArrow", "↑")], out)
    row(y + 4, 15.25, [k("LeftArrow", "←"), k("DownArrow", "↓"), k("RightArrow", "→")], out)
    # number pad
    nx = 18.5
    row(y, nx, [k("NumLock", "Num"), k("KP/", "/"), k("KP*", "*"), k("KP-", "-")], out)
    row(y + 1, nx, [k("KP7", "7"), k("KP8", "8"), k("KP9", "9"), k("KP+", "+", 1, 2)], out)
    row(y + 2, nx, [k("KP4", "4"), k("KP5", "5"), k("KP6", "6")], out)
    row(y + 3, nx, [k("KP1", "1"), k("KP2", "2"), k("KP3", "3"), k("KP-Enter", "Enter", 1, 2)], out)
    row(y + 4, nx, [k("KP0", "0", 2), k("KP.", ".")], out)
    return out, 22.5, y + 5

def layout_75():
    out = []
    row(0, 0, [k("Escape", "Esc"), k("F1"), k("F2"), k("F3"), k("F4"), k("F5"), k("F6"), k("F7"), k("F8"),
               k("F9"), k("F10"), k("F11"), k("F12"), k("SysRq", "PrtSc"), k("Pause", "Pause"), k("Del", "Del")], out)
    y = 1.0
    main_block(out, y)
    row(y, 15, [k("Home", "Home")], out)
    row(y + 1, 15, [k("PgUp", "PgUp")], out)
    row(y + 2, 15, [k("PgDn", "PgDn")], out)
    row(y + 3, 0, [k("Shift", "Shift", 2.25)] + Z_ROW + [k("RShift", "Shift", 1.75), k("UpArrow", "↑"), k("End", "End")], out)
    row(y + 4, 0, [k("Ctrl", "Ctrl", 1.25), k("LWin", "Win", 1.25), k("Alt", "Alt", 1.25), k("Space", "Space", 6.25),
                   k("RAlt", "Alt"), (None, "Fn", 1.0), k("RCtrl", "Ctrl"),
                   k("LeftArrow", "←"), k("DownArrow", "↓"), k("RightArrow", "→")], out)
    return out, 16.0, y + 5

def layout_60():
    out = []
    y = 0.0
    main_block(out, y, esc_on_grave=True)
    row(y + 3, 0, [k("Shift", "Shift", 2.25)] + Z_ROW + [k("RShift", "Shift", 2.75)], out)
    row(y + 4, 0, [k("Ctrl", "Ctrl", 1.25), k("LWin", "Win", 1.25), k("Alt", "Alt", 1.25), k("Space", "Space", 6.25),
                   k("RAlt", "Alt", 1.25), (None, "Fn", 1.25), k("Apps", "Menu", 1.25), k("RCtrl", "Ctrl", 1.25)], out)
    return out, 15.0, y + 5

def mouse_row():
    out = []
    row(0, 0, [k("Mouse1", "$VKB_M1", 1.75), k("Mouse3", "$VKB_M3", 1.75), k("Mouse2", "$VKB_M2", 1.75),
               k("Mouse4", "$VKB_M4", 1.75), k("Mouse5", "$VKB_M5", 1.75),
               k("MWheelUp", "$VKB_WUP", 1.75), k("MWheelDown", "$VKB_WDN", 1.75)], out)
    return out, 12.25, 1.0

def emit(fn, keys, w, h):
    lines = [f"\tstatic void {fn}(VKB_Board b)", "\t{"]
    lines.append(f"\t\tb.mWidth = {w};")
    lines.append(f"\t\tb.mHeight = {h};")
    for c, x, y, kw, kh, label, bindable in keys:
        lab = "#BACKSLASH" if label == "\\" else label
        assert '"' not in lab and "\\" not in lab, lab
        lines.append(f'\t\tb.Add({c}, {x}, {y}, {kw}, {kh}, "{lab}", {"true" if bindable else "false"});')
    lines.append("\t}")
    return "\n".join(lines)

def check(keys, w, h, name):
    for c, x, y, kw, kh, label, bindable in keys:
        assert x + kw <= w + 1e-9, (name, label, x, kw, w)
        assert y + kh <= h + 1e-9, (name, label, y, kh, h)
    rects = [(x, y, x + kw, y + kh, label) for _, x, y, kw, kh, label, _ in keys]
    for i, a in enumerate(rects):
        for b in rects[i + 1:]:
            if a[0] < b[2] - 1e-9 and b[0] < a[2] - 1e-9 and a[1] < b[3] - 1e-9 and b[1] < a[3] - 1e-9:
                raise SystemExit(f"overlap in {name}: {a[4]} / {b[4]}")
    codes = [c for c, *_ , bindable in keys if bindable]
    assert len(codes) == len(set(codes)), (name, "duplicate key code")

parts = []
for fn, (keys, w, h) in (("Full", layout_100()), ("TKL75", layout_75()), ("Compact60", layout_60()), ("Mouse", mouse_row())):
    check(keys, w, h, fn)
    parts.append(emit(fn, keys, w, h))
    print(fn, len(keys), "keys", w, "x", h)

header = """//===========================================================================
//
// Visual Keybinds - keyboard layouts
//
// GENERATED by genlayouts.py from UZDoom's KeyNames table (c_bind.cpp).
// Key codes are the engine's DirectInput scan codes; positions and sizes
// are in key units (1.0 = one normal key).
//
//===========================================================================

class VKB_Layouts ui
{
"""
open(sys.argv[2], "w", encoding="utf-8").write(header + "\n\n".join(parts) + "\n}\n")
