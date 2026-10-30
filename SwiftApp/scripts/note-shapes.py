#!/usr/bin/env python3
"""Writes App/Assets.xcassets/note-<shape>.imageset for every note shape: an SVG template image,
kept as vectors, so SwiftUI can tint and scale it.

The paths are the web app's clip paths, in a 0-1 box: the <clipPath>s near the end of
src/index.html, and the polygon() / circle() values in src/scss/_note-shapes.scss. The names
match NoteShape's raw values in ElisaKit/Sources/ElisaKit/NoteDisplay.swift. Run it again only
if a shape changes; the imagesets are committed.
"""
import json
import re
from pathlib import Path

ASSETS = Path(__file__).resolve().parents[1] / "App" / "Assets.xcassets"


def path(d):
    return f'<path d="{d}"/>'


def explicit_arcs(d):
    """Rewrites a relative m/a/z path as absolute M/A/Z with every arc flag its own number.
    Apple's CoreSVG mis-parses compact flags like "0 00-.4761.475", which drew the moon as a half disc."""
    num = r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"
    pos, out, cx, cy, sx, sy = 0, [], 0.0, 0.0, 0.0, 0.0

    def read(pattern):
        nonlocal pos
        m = re.compile(r"[\s,]*(" + pattern + ")").match(d, pos)
        if not m:
            return None
        pos = m.end()
        return m.group(1)

    cmd = None
    while True:
        m = re.compile(r"\s*([a-zA-Z])").match(d, pos)
        if m:
            cmd, pos = m.group(1), m.end()
        elif not re.compile(r"[\s,]*" + num).match(d, pos):
            break
        if cmd == "z":
            out.append("Z")
            cx, cy = sx, sy
        elif cmd == "m":
            x, y = float(read(num)), float(read(num))
            cx, cy = cx + x, cy + y
            sx, sy = cx, cy
            out.append(f"M {cx:.5f} {cy:.5f}")
            cmd = "l"
        elif cmd == "a":
            rx, ry, rot = float(read(num)), float(read(num)), float(read(num))
            large, sweep = read("[01]"), read("[01]")
            x, y = float(read(num)), float(read(num))
            cx, cy = cx + x, cy + y
            out.append(f"A {rx:g} {ry:g} {rot:g} {large} {sweep} {cx:.5f} {cy:.5f}")
        else:
            raise ValueError(f"unsupported command {cmd!r}")
    return " ".join(out)


def polygon(points):
    """CSS polygon() percentages, e.g. "50% 0%, 100% 38%" → an SVG path in the 0-1 box."""
    pairs = [p.split() for p in points.split(",")]
    coords = [f"{float(x.rstrip('%')) / 100:g} {float(y.rstrip('%')) / 100:g}" for x, y in pairs]
    return path("M" + " L".join(coords) + " Z")


SHAPES = {
    "circle": '<circle cx=".5" cy=".5" r=".5"/>',
    "triangle": path("m.8192 1q.2338-0 .1293-.2028l-.3476-.6741q-.1046-.2028-.2091 0l-.3476.6741q-.1046.2028.1293.2028z"),
    "triangle-down": path("m.1808 0q-.2338 0-.1293.2028l.3476.6741q.1046.2028.2091 0l.3476-.6741q.1046-.2028-.1293-.2028z"),
    "moon": path(explicit_arcs("m.5011.025a.4761.475 0 00-.4761.475.4761.475 0 00.4761.475.4761.475 0 00.4739-.4449.3187.318 0 01-.1276.027.3187.318 0 01-.3187-.318.3187.318 0 01.074-.2031.4761.475 0 00-.1016-.0111z")),
    "moon-flipped": path(explicit_arcs("m.025.4989a.4761.475 270 00.475.4761.4761.475 270 00.475-.4761.4761.475 270 00-.4449-.4739.3187.318 270 01.027.1276.3187.318 270 01-.318.3187.3187.318 270 01-.2031-.074.4761.475 270 00-.0111.1016z")),
    "heart": path("m 0.27446288,0.02497801 c -0.13778724,0 -0.24945956,0.12061671 -0.24945956,0.26932511 0,0.30247927 0.28243446,0.38179115 0.47499467,0.68067485 0.18220613,-0.2969646 0.47500535,-0.38796757 0.47500535,-0.68067485 0,-0.1487084 -0.1117578,-0.26932511 -0.24945955,-0.26932511 -0.0998009,0 -0.18570023,0.06363921 -0.2255458,0.15530394 -0.0395357,-0.09143312 -0.12536021,-0.15530394 -0.22527867,-0.15530394 z"),
    "heart-down": path("m0.27446 0.97542c-0.13779 0-0.24946-0.12062-0.24946-0.26933 0-0.30248 0.28243-0.38179 0.47499-0.68067 0.18221 0.29696 0.47501 0.38797 0.47501 0.68067 0 0.14871-0.11176 0.26933-0.24946 0.26933-0.099801 0-0.1857-0.063639-0.22555-0.1553-0.039536 0.091433-0.12536 0.1553-0.22528 0.1553z"),
    "pentagon": polygon("50% 0%, 100% 38%, 82% 100%, 18% 100%, 0% 38%"),
    "hexagon": polygon("50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%"),
    "octagon": polygon("30% 0%, 70% 0%, 100% 30%, 100% 70%, 70% 100%, 30% 100%, 0% 70%, 0% 30%"),
    "rounded-square": path("m0.16833 0.025 0.66323 6.9e-5c0.07945 1e-5 0.1434 0.06033 0.14336 0.13529l7.1e-5 0.67938c9e-6 0.07492-0.06394 0.13523-0.14334 0.13526l-0.66323-7e-5c-0.07945-9e-6 -0.1434-0.06033-0.14336-0.13529l-7e-5 -0.67938c-9e-6 -0.07492 0.06394-0.13523 0.14333-0.13526z"),
    "rounded-diamond": path("m0.57829 0.058879 0.36256 0.36263c0.04343 0.04344 0.04541 0.11139 0.0044 0.15236l-0.37145 0.37153c-0.04096 0.04097-0.1089 0.03899-0.15232-0.0044l-0.36256-0.36263c-0.04343-0.04344-0.04541-0.11139-0.0044-0.15236l0.37145-0.37153c0.04096-0.04097 0.1089-0.03899 0.15232 0.004399z"),
    "teardrop": path("M 0.975,0.64658972 C 0.975,0.82786247 0.76208656,0.975 0.50003926,0.975 0.23775109,0.975 0.02026146,0.82782823 0.02507851,0.64658972 0.03134067,0.40346614 0.29266543,0.30443291 0.50003926,0.025 0.72017826,0.29527426 0.975,0.46529985 0.975,0.64658972 Z"),
    "trapezoid": polygon("20% 0%, 80% 0%, 100% 100%, 0% 100%"),
    "trapezoid-down": polygon("0% 0%, 100% 0%, 80% 100%, 20% 100%"),
    "star": path("m1 0.75-0.33401-0.0010179-0.16599 0.25102-0.16599-0.25102-0.33401 0.0010179 0.16802-0.25-0.16802-0.25 0.33401 0.0010179 0.16599-0.25102 0.16599 0.25102 0.33401-0.0010179-0.16802 0.25z"),
    "clover": path("m0.29492 0a0.29492 0.28702 0 0 0-0.29492 0.28702 0.29492 0.28702 0 0 0 0.09774 0.21298 0.29492 0.28702 0 0 0-0.09774 0.21298 0.29492 0.28702 0 0 0 0.29492 0.28702 0.29492 0.28702 0 0 0 0.20508-0.0817 0.29492 0.28702 0 0 0 0.20509 0.0817 0.29492 0.28702 0 0 0 0.29491-0.28702 0.29492 0.28702 0 0 0-0.09722-0.21298 0.29492 0.28702 0 0 0 0.09722-0.21298 0.29492 0.28702 0 0 0-0.29491-0.28702 0.29492 0.28702 0 0 0-0.20463 0.0813 0.29492 0.28702 0 0 0-0.20554-0.0813z"),
    "clover-rotated": path("m0.5 3.6997e-5a0.24116 0.24129 0 0 0-0.24116 0.24129 0.24116 0.24129 0 0 0 9.9936e-4 0.018179 0.24116 0.24129 0 0 0-0.018688-7.9594e-4 0.24116 0.24129 0 0 0-0.24116 0.24129 0.24116 0.24129 0 0 0 0.24116 0.2413 0.24116 0.24129 0 0 0 0.018688-0.0012999 0.24116 0.24129 0 0 0-9.9936e-4 0.018709 0.24116 0.24129 0 0 0 0.24116 0.2413 0.24116 0.24129 0 0 0 0.24116-0.2413 0.24116 0.24129 0 0 0-9.9936e-4 -0.018709 0.24116 0.24129 0 0 0 0.018688 0.0013 0.24116 0.24129 0 0 0 0.24116-0.2413 0.24116 0.24129 0 0 0-0.24116-0.24129 0.24116 0.24129 0 0 0-0.018688 0.0012999 0.24116 0.24129 0 0 0 9.9936e-4 -0.018719 0.24116 0.24129 0 0 0-0.24116-0.24129z"),
}

for name, body in SHAPES.items():
    folder = ASSETS / f"note-{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    # 100 x 100 points drawn from the 0-1 box the web app's paths use.
    (folder / f"note-{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 1 1">{body}</svg>\n'
    )
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"note-{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
    }, indent=2) + "\n")

print(f"{len(SHAPES)} imagesets in {ASSETS}")
