#!/usr/bin/env python3
"""Render .excalidraw scenes to lightweight .svg previews (clean, non-sketchy).
This is only for previewing; the .excalidraw files are the real, editable artifacts.
"""
import glob
import json
import os
import html

OUT = os.path.dirname(os.path.abspath(__file__))
FONTS = {1: "Comic Sans MS, cursive", 2: "Helvetica, Arial, sans-serif", 3: "monospace"}


def col(c):
    return "none" if c in (None, "transparent") else c


def bounds(els):
    xs, ys, xe, ye = [], [], [], []
    for el in els:
        xs.append(el["x"]); ys.append(el["y"])
        xe.append(el["x"] + el.get("width", 0)); ye.append(el["y"] + el.get("height", 0))
    return min(xs), min(ys), max(xe), max(ye)


def render(els):
    minx, miny, maxx, maxy = bounds(els)
    pad = 24
    w = maxx - minx + pad * 2
    h = maxy - miny + pad * 2
    ox, oy = pad - minx, pad - miny
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{int(w)}" height="{int(h)}" '
           f'viewBox="0 0 {int(w)} {int(h)}" font-family="Helvetica, Arial, sans-serif">']
    out.append(f'<rect x="0" y="0" width="{int(w)}" height="{int(h)}" fill="#ffffff"/>')
    out.append('<defs><marker id="ah" markerWidth="10" markerHeight="10" refX="8" refY="3" '
               'orient="auto" markerUnits="strokeWidth"><path d="M0,0 L8,3 L0,6 z" fill="#1e1e1e"/></marker></defs>')
    for el in els:
        t = el["type"]
        x, y = el["x"] + ox, el["y"] + oy
        ww, hh = el.get("width", 0), el.get("height", 0)
        stroke = col(el.get("strokeColor"))
        bg = col(el.get("backgroundColor"))
        sw = el.get("strokeWidth", 1)
        dash = ' stroke-dasharray="6 4"' if el.get("strokeStyle") == "dashed" else ""
        if t == "rectangle":
            rx = 8 if el.get("roundness") else 0
            out.append(f'<rect x="{x:.0f}" y="{y:.0f}" width="{ww:.0f}" height="{hh:.0f}" rx="{rx}" '
                       f'fill="{bg}" stroke="{stroke}" stroke-width="{sw}"{dash}/>')
        elif t == "ellipse":
            out.append(f'<ellipse cx="{x+ww/2:.0f}" cy="{y+hh/2:.0f}" rx="{ww/2:.0f}" ry="{hh/2:.0f}" '
                       f'fill="{bg}" stroke="{stroke}" stroke-width="{sw}"/>')
        elif t == "diamond":
            pts = f"{x+ww/2:.0f},{y:.0f} {x+ww:.0f},{y+hh/2:.0f} {x+ww/2:.0f},{y+hh:.0f} {x:.0f},{y+hh/2:.0f}"
            out.append(f'<polygon points="{pts}" fill="{bg}" stroke="{stroke}" stroke-width="{sw}"/>')
        elif t == "arrow":
            pts = el.get("points", [[0, 0], [ww, hh]])
            poly = " ".join(f"{x+px:.0f},{y+py:.0f}" for px, py in pts)
            head = ' marker-end="url(#ah)"' if el.get("endArrowhead") == "arrow" else ""
            out.append(f'<polyline points="{poly}" fill="none" stroke="{stroke}" stroke-width="{sw}"{dash}{head}/>')
        elif t == "text":
            fs = el.get("fontSize", 16)
            anchor = "middle" if el.get("textAlign") == "middle" else "start"
            tx = x + (ww / 2 if anchor == "middle" else 0)
            fam = FONTS.get(el.get("fontFamily", 2), FONTS[2])
            for i, ln in enumerate(el.get("text", "").split("\n")):
                ty = y + fs * 0.92 + i * fs * 1.25
                out.append(f'<text x="{tx:.0f}" y="{ty:.0f}" font-size="{fs}" fill="{stroke}" '
                           f'text-anchor="{anchor}" font-family="{fam}">{html.escape(ln)}</text>')
    out.append("</svg>")
    return "\n".join(out)


def main():
    for f in sorted(glob.glob(os.path.join(OUT, "*.excalidraw"))):
        d = json.load(open(f))
        svg = render(d["elements"])
        p = f.replace(".excalidraw", ".svg")
        open(p, "w").write(svg)
        print("wrote", os.path.basename(p))


if __name__ == "__main__":
    main()
