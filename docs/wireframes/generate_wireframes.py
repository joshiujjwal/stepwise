#!/usr/bin/env python3
"""Generate .excalidraw wireframe scenes for the Agentic Micro-Task Coordinator.

Run:  python3 generate_wireframes.py
Open: excalidraw.com -> Menu -> Open, or the VS Code "Excalidraw" extension.
Re-run any time after editing this file to regenerate the scenes.
"""
import json
import os
import random
import time

NOW = int(time.time() * 1000)
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# ---- palette ---------------------------------------------------------------
INK = "#1e1e1e"
GRAY = "#868e96"
LIGHT = "#f8f9fa"
TRACK = "#e9ecef"
BLUE = "#a5d8ff"
GREEN = "#b2f2bb"
YELLOW = "#ffec99"
RED = "#ffc9c9"
PURPLE = "#d0bfff"
TEAL = "#96f2d7"
ORANGE = "#ffd8a8"

STATE_COLOR = {
    "todo": TRACK,
    "in_progress": BLUE,
    "awaiting_approval": YELLOW,
    "done": GREEN,
    "blocked": RED,
    "re-tasked": PURPLE,
}


def _id():
    return "%016x" % random.randint(0, 2 ** 64)


def _seed():
    return random.randint(1, 2 ** 31)


def estw(s, fs):
    return max(8, int(len(s) * fs * 0.55))


def base(t, x, y, w, h, stroke=INK, bg="transparent", fill="solid",
         sw=1, rough=1, roundness=None, opacity=100, style="solid"):
    return {
        "id": _id(), "type": t, "x": x, "y": y, "width": w, "height": h,
        "angle": 0, "strokeColor": stroke, "backgroundColor": bg,
        "fillStyle": fill, "strokeWidth": sw, "strokeStyle": style,
        "roughness": rough, "opacity": opacity, "groupIds": [], "frameId": None,
        "roundness": roundness, "seed": _seed(), "version": 1,
        "versionNonce": _seed(), "isDeleted": False, "boundElements": [],
        "updated": NOW, "link": None, "locked": False,
    }


def rect(x, y, w, h, bg="transparent", stroke=INK, rounded=True, sw=1,
         fill="solid", rough=1, style="solid", opacity=100):
    el = base("rectangle", x, y, w, h, stroke=stroke, bg=bg, fill=fill, sw=sw,
              rough=rough, opacity=opacity, style=style,
              roundness={"type": 3} if rounded else None)
    return el


def ellipse(x, y, w, h, bg="transparent", stroke=INK, sw=1, fill="solid"):
    return base("ellipse", x, y, w, h, stroke=stroke, bg=bg, fill=fill, sw=sw)


def diamond(x, y, w, h, bg="transparent", stroke=INK):
    return base("diamond", x, y, w, h, stroke=stroke, bg=bg)


def text(x, y, s, fs=16, color=INK, align="left", w=None, family=2):
    width = w if w is not None else estw(s, fs)
    el = base("text", x, y, width, int(fs * 1.25), stroke=color)
    el.update({
        "text": s, "fontSize": fs, "fontFamily": family, "textAlign": align,
        "verticalAlign": "top", "containerId": None, "originalText": s,
        "lineHeight": 1.25, "baseline": int(fs * 0.9),
    })
    return el


def ctext(cx, cy, s, fs=16, color=INK, family=2):
    w = estw(s, fs)
    return text(int(cx - w / 2), int(cy - fs * 0.62), s, fs, color, "center", w=w, family=family)


def line(x1, y1, x2, y2, arrow=True, color=INK, sw=1, style="solid", bend=None):
    pts = [[0, 0]]
    if bend is not None:
        pts.append([bend[0] - x1, bend[1] - y1])
    pts.append([x2 - x1, y2 - y1])
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    el = base("arrow", x1, y1, max(1, max(xs) - min(xs)), max(1, max(ys) - min(ys)),
              stroke=color, sw=sw, style=style)
    el.update({
        "points": pts, "lastCommittedPoint": None,
        "startBinding": None, "endBinding": None,
        "startArrowhead": None, "endArrowhead": "arrow" if arrow else None,
    })
    return el


def chip(x, y, label, active=False, color=BLUE):
    w = estw(label, 14) + 26
    h = 30
    out = [rect(x, y, w, h, bg=color if active else "transparent", rounded=True,
                stroke=INK if active else GRAY)]
    out.append(ctext(x + w / 2, y + h / 2, label, 14, INK if active else GRAY))
    return out, w


def badge(x, y, label, color, fs=12):
    w = estw(label, fs) + 18
    h = int(fs * 1.7)
    return [rect(x, y, w, h, bg=color, rounded=True, stroke="transparent", fill="solid"),
            ctext(x + w / 2, y + h / 2, label, fs, INK)], w


def button(x, y, label, w=None, color=LIGHT):
    w = w or estw(label, 13) + 24
    h = 30
    return [rect(x, y, w, h, bg=color, rounded=True, stroke=GRAY),
            ctext(x + w / 2, y + h / 2, label, 13, INK)], w


def label_bg(cx, cy, s, fs=12, color=INK):
    w = estw(s, fs) + 10
    return [rect(int(cx - w / 2), int(cy - fs * 0.9), w, int(fs * 1.8),
                 bg="#ffffff", stroke="transparent", rounded=False),
            ctext(cx, cy, s, fs, color)]


def frame(w, h, title):
    return [rect(0, 0, w, h, bg="#ffffff", stroke=INK, rounded=True, sw=2)]


def write(name, els):
    scene = {
        "type": "excalidraw", "version": 2, "source": "idea2proj",
        "elements": els,
        "appState": {"gridSize": None, "viewBackgroundColor": "#ffffff"},
        "files": {},
    }
    p = os.path.join(OUT_DIR, name)
    with open(p, "w") as f:
        json.dump(scene, f, indent=2)
    return p


# ===========================================================================
# Scene 1 — Do Next (home)
# ===========================================================================
def scene_do_next():
    e = frame(1120, 780, "Do Next")
    e.append(text(24, 22, "Coordinator", 22))
    x = 770
    for lbl, act in [("Do Next", True), ("Ideas", False), ("Trends", False)]:
        c, w = chip(x, 22, lbl, active=act)
        e += c
        x += w + 10
    e.append(text(24, 92, "What can you do right now?", 18))
    e.append(text(24, 130, "Time I have:", 13, GRAY))
    x = 140
    for lbl, act in [("All", True), ("15 min", False), ("30 min", False),
                     ("45 min", False), ("60+", False)]:
        c, w = chip(x, 124, lbl, active=act, color=TEAL)
        e += c
        x += w + 8
    e.append(text(24, 166, "Your next 3 suggested steps · order is only a suggestion — start any of them",
                  12, GRAY))

    cards = [
        ("1", "Gather all tax documents", "tax · File my 2025 taxes", "30 min", "todo", "0 / 1", None),
        ("2", "Pick a tax tool or preparer", "tax · File my 2025 taxes", "15 min", "in_progress", "0 / 2", "06:12"),
        ("3", "Book dentist appointment", "errand · Health admin", "15 min", "todo", "0 / 1", None),
    ]
    y = 196
    for order, title_s, tag, dur, st, crit, timer in cards:
        e.append(rect(24, y, 1072, 156, bg=LIGHT, rounded=True, stroke=TRACK))
        e.append(ellipse(44, y + 20, 34, 34, bg="#ffffff", stroke=INK))
        e.append(ctext(44 + 17, y + 20 + 17, order, 16))
        e.append(text(96, y + 22, title_s, 18))
        b, _ = badge(96, y + 56, tag, PURPLE)
        e += b
        b, _ = badge(1096 - 90, y + 22, dur, BLUE)
        e += b
        b, _ = badge(1096 - 130, y + 56, st.replace("_", " "), STATE_COLOR[st])
        e += b
        e.append(text(820, y + 26, "acceptance " + crit, 12, GRAY))
        if timer:
            e.append(text(820, y + 56, "timer " + timer, 12, INK))
        bx = 96
        for lbl in ["Start", "Timer", "Break it down", "I'm stuck"]:
            bb, bw = button(bx, y + 108, lbl)
            e += bb
            bx += bw + 10
        y += 172
    return e


# ===========================================================================
# Scene 2 — Idea progress
# ===========================================================================
def scene_idea_progress():
    e = frame(1120, 1180, "Idea progress")
    e.append(text(24, 22, "←  Ideas", 14, GRAY))
    e.append(text(24, 52, "File my 2025 taxes", 24))
    b, w = badge(360, 58, "tax", PURPLE, fs=13)
    e += b
    b, w2 = badge(360 + w + 8, 58, "active", BLUE, fs=13)
    e += b
    e.append(text(24, 98, "Step 3 of 8  ·  38% complete", 14, INK))
    e.append(rect(24, 124, 760, 16, bg=TRACK, rounded=True, stroke="transparent"))
    e.append(rect(24, 124, int(760 * 0.38), 16, bg=GREEN, rounded=True, stroke="transparent"))
    e.append(text(24, 150, "Order is a suggestion — you can do any available task first.", 12, GRAY))

    rows = [
        (1, "done", "Gather W-2 / 1099 forms", "30 min", "✓ 2/2", False),
        (2, "done", "Choose tax software", "15 min", "✓ 1/1", False),
        (3, "in_progress", "Enter income details", "45 min", "0/2 · timer 06:12", True),
        (4, "awaiting_approval", "Enter deductions", "30 min", "verify: paste confirmation", False),
        (5, "todo", "Review the return", "20 min", "0/1", False),
        (6, "blocked", "Find last year's AGI", "10 min", "stuck: can't locate 2024 return", False),
        (7, "todo", "Submit the return", "15 min", "0/1", False),
        (8, "todo", "Save the confirmation", "10 min", "0/1", False),
    ]
    y = 184
    for order, st, title_s, dur, meta, expand in rows:
        h = 56
        e.append(rect(24, y, 1072, h, bg="#ffffff", rounded=True, stroke=TRACK))
        e.append(ctext(52, y + h / 2, str(order), 15, GRAY))
        b, bw = badge(74, y + 16, st.replace("_", " "), STATE_COLOR[st], fs=12)
        e += b
        e.append(text(250, y + 18, title_s, 16))
        b, _ = badge(820, y + 14, dur, BLUE, fs=12)
        e += b
        e.append(text(620, y + 20, meta, 12, GRAY))
        y += h + 10
        if expand:
            ph = 188
            e.append(rect(60, y, 1036, ph, bg=LIGHT, rounded=True, stroke=TRACK, style="dashed"))
            e.append(text(80, y + 14, "Definition of done", 13, GRAY))
            e.append(rect(80, y + 40, 22, 22, bg=GREEN, rounded=True, stroke=INK))
            e.append(ctext(80 + 11, y + 40 + 11, "✓", 14))
            e.append(text(112, y + 42, "All W-2 wages entered  (checkbox)", 14))
            e.append(rect(80, y + 74, 22, 22, bg="#ffffff", rounded=True, stroke=INK))
            e.append(text(112, y + 76, "1099 income entered  (url evidence)", 14))
            e.append(rect(420, y + 72, 360, 26, bg="#ffffff", rounded=True, stroke=GRAY))
            e.append(text(430, y + 76, "https://…  paste link to filed copy", 12, GRAY))
            bx = 80
            for lbl, col in [("Submit for approval", BLUE), ("Timer 06:12", LIGHT),
                             ("Break this down", PURPLE), ("I'm stuck", RED)]:
                bb, bw = button(bx, y + 120, lbl, color=col)
                e += bb
                bx += bw + 10
            y += ph + 12
        if st == "blocked":
            e.append(text(90, y, "> re-tasked into smaller steps:", 12, PURPLE))
            y += 24
            for ctitle, cdur in [("Search email for the 2024 PDF", "10 min"),
                                 ("Check IRS online account for AGI", "15 min")]:
                e.append(rect(90, y, 1006, 44, bg="#fbf6ff", rounded=True, stroke=PURPLE))
                b, bw = badge(108, y + 11, "todo", TRACK, fs=12)
                e += b
                e.append(text(250, y + 13, ctitle, 15))
                b, _ = badge(980, y + 10, cdur, BLUE, fs=12)
                e += b
                y += 52
            y += 6
    return e


# ===========================================================================
# Scene 3 — Trends dashboard
# ===========================================================================
def scene_trends():
    e = frame(1120, 820, "Trends")
    e.append(text(24, 22, "Trends", 22))
    e.append(text(24, 58, "Last 30 days · personal productivity", 13, GRAY))

    def card(cx, cy, cw, ch, title_s):
        e.append(rect(cx, cy, cw, ch, bg=LIGHT, rounded=True, stroke=TRACK))
        e.append(text(cx + 18, cy + 14, title_s, 15))

    gap = 24
    cw = (1120 - 24 * 2 - gap * 2) // 3
    ch = 220
    x0, y0 = 24, 92
    card(x0, y0, cw, ch, "Throughput — tasks done / day")
    bars = [3, 5, 2, 6, 4, 7, 5]
    bx = x0 + 24
    for v in bars:
        bh = v * 18
        e.append(rect(bx, y0 + ch - 30 - bh, 26, bh, bg=BLUE, rounded=True, stroke="transparent"))
        bx += 40

    card(x0 + cw + gap, y0, cw, ch, "Current streak")
    e.append(ctext(x0 + cw + gap + cw / 2, y0 + ch / 2, "6 days", 34))

    card(x0 + 2 * (cw + gap), y0, cw, ch, "Completion rate")
    cxx = x0 + 2 * (cw + gap) + cw / 2
    e.append(ellipse(cxx - 55, y0 + 70, 110, 110, bg=TRACK, stroke="transparent"))
    e.append(ellipse(cxx - 38, y0 + 87, 76, 76, bg="#ffffff", stroke="transparent"))
    e.append(ctext(cxx, y0 + 125, "72%", 26))

    y1 = y0 + ch + gap
    card(x0, y1, cw, ch, "Estimate vs actual")
    pairs = [("Docs", 30, 38), ("Tool", 15, 9), ("Income", 45, 52)]
    bx = x0 + 30
    for lbl, est, act in pairs:
        e.append(rect(bx, y1 + ch - 30 - int(est * 2.4), 22, int(est * 2.4), bg=TRACK, rounded=True, stroke="transparent"))
        e.append(rect(bx + 26, y1 + ch - 30 - int(act * 2.4), 22, int(act * 2.4), bg=ORANGE, rounded=True, stroke="transparent"))
        e.append(ctext(bx + 24, y1 + ch - 16, lbl, 11, GRAY))
        bx += 100
    e += badge(x0 + cw - 150, y1 + 12, "est", TRACK)[0]
    e += badge(x0 + cw - 95, y1 + 12, "actual", ORANGE)[0]

    card(x0 + cw + gap, y1, cw, ch, "Where you get stuck")
    fr = [("blocked", 4, RED), ("re-tasked", 7, PURPLE), ("rejected", 2, YELLOW)]
    bx = x0 + cw + gap + 30
    for lbl, v, col in fr:
        bh = v * 18
        e.append(rect(bx, y1 + ch - 34 - bh, 40, bh, bg=col, rounded=True, stroke="transparent"))
        e.append(ctext(bx + 20, y1 + ch - 18, lbl, 11, GRAY))
        bx += 95

    card(x0 + 2 * (cw + gap), y1, cw, ch, "Focused time / idea (min)")
    times = [("Taxes", 120), ("Trip", 60), ("Health", 35)]
    by = y1 + 50
    for lbl, v in times:
        e.append(text(x0 + 2 * (cw + gap) + 20, by, lbl, 12))
        e.append(rect(x0 + 2 * (cw + gap) + 90, by, int(v * 1.6), 18, bg=TEAL, rounded=True, stroke="transparent"))
        e.append(text(x0 + 2 * (cw + gap) + 96 + int(v * 1.6), by, str(v), 11, GRAY))
        by += 44
    return e


# ===========================================================================
# Scene 4 — Micro-task state machine
# ===========================================================================
def scene_state_machine():
    e = [text(40, 24, "Micro-task lifecycle (v1)", 22)]

    def node(x, y, key, label=None):
        w, h = 190, 70
        e.append(rect(x, y, w, h, bg=STATE_COLOR[key], rounded=True, stroke=INK, sw=2))
        e.append(ctext(x + w / 2, y + h / 2, label or key, 16))
        return (x, y, w, h)

    todo = node(60, 170, "todo")
    inprog = node(360, 170, "in_progress")
    await_ = node(660, 170, "awaiting_approval", "awaiting approval")
    done = node(960, 170, "done")
    blocked = node(360, 380, "blocked")
    retask = node(660, 380, "re-tasked")
    child = node(960, 380, "todo", "todo (children)")

    def edge(a, b, lbl, color=INK, style="solid"):
        ax = a[0] + a[2]
        ay = a[1] + a[3] / 2
        bx = b[0]
        by = b[1] + b[3] / 2
        e.append(line(ax, ay, bx, by, color=color, style=style))
        e.extend(label_bg((ax + bx) / 2, ay - 14, lbl, 12, color))

    edge(todo, inprog, "start")
    edge(inprog, await_, "submit + evidence")
    edge(await_, done, "confirm  ✓ all criteria")
    e.append(line(await_[0] + 20, await_[1] + await_[3], inprog[0] + inprog[2] - 20, inprog[1] + inprog[3],
                  color=GRAY, style="dashed", bend=(await_[0] - 40, await_[1] + await_[3] + 60)))
    e.extend(label_bg((await_[0] + inprog[0]) / 2 + 60, await_[1] + await_[3] + 58, "reject (criteria not met)", 12, GRAY))
    e.append(line(inprog[0] + inprog[2] / 2, inprog[1] + inprog[3], blocked[0] + blocked[2] / 2, blocked[1], color=RED))
    e.extend(label_bg(inprog[0] + inprog[2] / 2 + 78, (inprog[1] + inprog[3] + blocked[1]) / 2, "I'm stuck (+reason)", 12, INK))
    e.append(line(inprog[0] + inprog[2] - 30, inprog[1] + inprog[3], retask[0] + 30, retask[1], color=PURPLE, style="dashed"))
    e.extend(label_bg(retask[0] - 40, retask[1] - 28, "break this down (any task)", 12, PURPLE))
    edge(blocked, retask, "decompose")
    edge(retask, child, "spawns finer tasks")

    ny = 500
    e.append(rect(60, ny, 1090, 70, bg=LIGHT, rounded=True, stroke=TRACK))
    e.append(text(80, ny + 14, "Idea status (derived from its leaf tasks):", 14))
    e.append(text(80, ny + 40,
                  "planning  →  active  →  stalled (≥1 blocked leaf)  →  done (all leaf tasks done)", 14, GRAY))

    ly = 600
    e.append(text(60, ly, "Legend:", 13, GRAY))
    lx = 130
    for key in ["todo", "in_progress", "awaiting_approval", "done", "blocked", "re-tasked"]:
        b, w = badge(lx, ly - 4, key.replace("_", " "), STATE_COLOR[key], fs=12)
        e += b
        lx += w + 12
    return e


def scene_calendar():
    W, H = 390, 772
    e = frame(W, H, "Calendar")
    e.append(text(20, 16, "Coordinator", 16))
    c, w = chip(20, 44, "Idea")
    e += c
    c2, w2 = chip(20 + w + 8, 44, "Execute", active=True)
    e += c2
    # view toggle: List | Calendar (segmented)
    e.append(rect(20, 82, 150, 30, bg=LIGHT, stroke=GRAY, rounded=True))
    e.append(rect(95, 82, 75, 30, bg=BLUE, stroke=INK, rounded=True))
    e.append(ctext(57, 97, "List", 13, GRAY))
    e.append(ctext(132, 97, "Calendar", 13))
    # duration filter
    e.append(text(20, 124, "Fits in:", 12, GRAY))
    x = 84
    for lbl, act in [("15", False), ("30", False), ("45", True), ("60+", False)]:
        c, w = chip(x, 118, lbl, active=act, color=TEAL)
        e += c
        x += w + 6
    # day timeline
    top, pxmin, x_lbl, x0, x1 = 170, 1.2, 16, 66, 366
    for i, lbl in enumerate(["9 AM", "10", "11", "12 PM", "1 PM", "2", "3"]):
        y = top + i * 72
        e.append(text(x_lbl, y - 7, lbl, 11, GRAY))
        e.append(line(x0, y, x1, y, arrow=False, color=TRACK))

    def block(hour, minute, dur, title, state):
        y = top + ((hour - 9) * 60 + minute) * pxmin
        h = dur * pxmin
        e.append(rect(x0 + 4, y, x1 - x0 - 8, h, bg=STATE_COLOR[state], rounded=True, stroke=INK))
        e.append(text(x0 + 14, y + 4, title, 12))
        e.append(text(x1 - 52, y + 4, "%dm" % dur, 11, GRAY))

    block(9, 0, 30, "Gather tax documents", "todo")
    block(10, 0, 15, "Pick a tax tool", "todo")
    block(11, 0, 15, "Book dentist", "todo")
    block(13, 0, 45, "Enter income details", "in_progress")
    # now line
    ny = top + ((11 - 9) * 60 + 30) * pxmin
    e.append(line(x0, ny, x1, ny, arrow=False, color="#fa5252"))
    e += label_bg(x0 + 22, ny, "now", 10, "#fa5252")
    # unscheduled tray
    e.append(rect(20, 694, 350, 56, bg=LIGHT, stroke=GRAY, rounded=True, style="dashed"))
    e.append(text(34, 704, "Unscheduled (2) — drag onto your day", 12, GRAY))
    b, _ = badge(34, 724, "Review return · 20m", TRACK)
    e += b
    b, _ = badge(220, 724, "Submit return · 15m", TRACK)
    e += b
    return e


def scene_idea():
    e = []

    def bubble(x, y, w, lines, user=False, color=None, fs=13):
        col = color or (BLUE if user else LIGHT)
        h = 16 + len(lines) * int(fs * 1.5)
        e.append(rect(x, y, w, h, bg=col, rounded=True, stroke=(INK if user else GRAY)))
        ty = y + 9
        for ln in lines:
            e.append(text(x + 12, ty, ln, fs))
            ty += int(fs * 1.5)
        return h

    def phone(ox, mode):
        nonlocal e
        e.append(rect(ox, 0, 390, 720, bg="#ffffff", stroke=INK, rounded=True, sw=2))
        e.append(text(ox + 20, 16, "Coordinator", 16))
        c, w = chip(ox + 20, 44, "Idea", active=True)
        e += c
        c2, _ = chip(ox + 20 + w + 8, 44, "Execute")
        e += c2
        if mode == "capture":
            e.append(text(ox + 20, 90, "Describe a goal in your own words", 13, GRAY))
            e.append(rect(ox + 20, 116, 350, 300, bg=LIGHT, rounded=True, stroke=GRAY))
            e.append(text(ox + 34, 134, "Help me file my 2025 taxes for", 15))
            e.append(text(ox + 34, 160, "the first time", 15))
            e.append(line(ox + 150, 157, ox + 150, 179, arrow=False, color=INK, sw=2))
            e += label_bg(ox + 270, 198, "typing indicator", 11, GRAY)
            e.append(line(ox + 250, 190, ox + 158, 172, color=GRAY))
            e.append(text(ox + 20, 434, "I'll ask 1–2 quick questions, then propose", 12, GRAY))
            e.append(text(ox + 20, 454, "a step-by-step plan you can confirm.", 12, GRAY))
            bb, bw = button(ox + 200, 644, "Start planning →", color=BLUE)
            e += bb
        else:
            e.append(text(ox + 20, 90, "A quick back-and-forth, then a plan", 13, GRAY))
            y = 120
            y += bubble(ox + 120, y, 250, ["Help me file my 2025 taxes"], user=True) + 10
            y += bubble(ox + 20, y, 300, ["Quick Q: filing yourself online,", "or with a preparer?"]) + 10
            y += bubble(ox + 190, y, 180, ["Myself, online"], user=True) + 10
            y += bubble(ox + 20, y, 330, ["Here's an 8-step plan:",
                                          "1. Gather W-2 / 1099 — 30m",
                                          "2. Pick tax software — 15m",
                                          "3. Enter income — 45m",
                                          "4. Enter deductions — 30m",
                                          "   + 4 more steps"]) + 12
            bb, bw = button(ox + 20, y, "Confirm plan", color=GREEN)
            e += bb
            bb2, _ = button(ox + 20 + bw + 10, y, "Revise", color=LIGHT)
            e += bb2
            y += 44
            e.append(rect(ox + 20, y + 6, 70, 30, bg=LIGHT, rounded=True, stroke=GRAY))
            for i in range(3):
                e.append(ellipse(ox + 32 + i * 18, y + 17, 8, 8, bg=GRAY, stroke="transparent"))

    phone(0, "capture")
    phone(450, "plan")
    e.append(text(90, -40, "1 · Capture (typing indicator)", 14, GRAY))
    e.append(text(540, -40, "2 · Clarify, then confirm the plan", 14, GRAY))
    return e


def translate(els, dx, dy):
    for el in els:
        el["x"] += dx
        el["y"] += dy
    return els


def bbox(els):
    xs = [el["x"] for el in els]
    ys = [el["y"] for el in els]
    xe = [el["x"] + el.get("width", 0) for el in els]
    ye = [el["y"] + el.get("height", 0) for el in els]
    return min(xs), min(ys), max(xe), max(ye)


def place(els, px, py):
    minx, miny, maxx, maxy = bbox(els)
    translate(els, px - minx, py - miny)
    return (px, py, maxx - minx, maxy - miny)


def scene_flow_board():
    out = []
    idea = scene_idea(); pi = place(idea, 0, 0)
    elist = scene_do_next(); pl = place(elist, 1120, 40)
    ecal = scene_calendar(); pc = place(ecal, 2440, 40)
    state = scene_state_machine(); ps = place(state, 0, 1060)
    prog = scene_idea_progress(); pp = place(prog, 1320, 1060)
    trends = scene_trends(); pt = place(trends, 2640, 1060)
    out += idea + elist + ecal + state + prog + trends
    out.append(text(0, -120, "User Flow — Idea → Execute (v1)", 30))

    def flow(x1, y1, x2, y2, lbl, color=INK, style="solid"):
        out.append(line(x1, y1, x2, y2, color=color, sw=2, style=style))
        out.extend(label_bg((x1 + x2) / 2, (y1 + y2) / 2 - 12, lbl, 15, color))

    flow(pi[0] + pi[2], pi[1] + 380, pl[0], pl[1] + 360, "Confirm plan →", color="#2f9e44")
    flow(pl[0] + pl[2], pl[1] + 300, pc[0], pc[1] + 300, "List ⇄ Calendar")
    flow(pl[0] + pl[2] / 2, pl[1] + pl[3], pp[0] + pp[2] / 2, pp[1], "Tap a task → progress")
    flow(pl[0] + pl[2] - 120, pl[1] + 70, pt[0] + 260, pt[1], "Trends tab", color=GRAY, style="dashed")
    out.append(text(ps[0], ps[1] - 44, "Reference — every micro-task follows this lifecycle", 16, GRAY))
    return out


def main():
    scenes = {
        "1-do-next.excalidraw": scene_do_next(),
        "2-idea-progress.excalidraw": scene_idea_progress(),
        "3-trends.excalidraw": scene_trends(),
        "4-state-machine.excalidraw": scene_state_machine(),
        "5-calendar-day.excalidraw": scene_calendar(),
        "6-idea-capture.excalidraw": scene_idea(),
        "7-flow-board.excalidraw": scene_flow_board(),
    }
    for name, els in scenes.items():
        p = write(name, els)
        print("wrote", p, "(%d elements)" % len(els))


if __name__ == "__main__":
    main()
