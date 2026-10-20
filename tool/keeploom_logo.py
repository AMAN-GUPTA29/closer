"""Keeploom logo geometry, shared by every generated asset.

Two rounded, slightly tilted quadrilaterals interlock: a coral one (top-left)
and a deep plum one (bottom-right). Where they overlap, an ivory "seed"
shape shows through, the moment that is kept. Coordinates are in a 100x100
box; `lib/core/widgets/keeploom_logo.dart` mirrors the same numbers.

Run:  python tool/make_icons.py
"""
import math

CORAL = (0xF5, 0x76, 0x7A)
PLUM = (0x6B, 0x3F, 0x55)
IVORY = (0xFF, 0xF7, 0xF1)
NIGHT = (0x0E, 0x08, 0x10)

# Corners (clockwise) and the corner radius of each shape.
CORAL_QUAD = [(10, 24), (54, 10), (58, 62), (16, 74)]
PLUM_QUAD = [(36, 38), (88, 30), (82, 86), (40, 90)]
RADIUS = 13
# The ivory seed inside the overlap (a rounded, leaf-like pentagon).
SEED = [(39, 42), (55, 39), (57, 56), (49, 65), (41, 60)]
SEED_RADIUS = 6


def rounded_polygon(points, radius, steps=24):
    """Polygon with circular-ish rounded corners, as a list of points."""
    out = []
    n = len(points)
    for i in range(n):
        p0, p1, p2 = points[i - 1], points[i], points[(i + 1) % n]
        v1 = (p0[0] - p1[0], p0[1] - p1[1])
        v2 = (p2[0] - p1[0], p2[1] - p1[1])
        l1, l2 = math.hypot(*v1), math.hypot(*v2)
        r = min(radius, l1 / 2.2, l2 / 2.2)
        a = (p1[0] + v1[0] / l1 * r, p1[1] + v1[1] / l1 * r)
        b = (p1[0] + v2[0] / l2 * r, p1[1] + v2[1] / l2 * r)
        for k in range(steps + 1):  # quadratic Bezier a -> p1 -> b
            t = k / steps
            x = (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * b[0]
            y = (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * b[1]
            out.append((x, y))
    return out


def svg_path(points, radius):
    """Same rounded polygon as an SVG path (quadratic corners)."""
    n = len(points)
    cmds = []
    for i in range(n):
        p0, p1, p2 = points[i - 1], points[i], points[(i + 1) % n]
        v1 = (p0[0] - p1[0], p0[1] - p1[1])
        v2 = (p2[0] - p1[0], p2[1] - p1[1])
        l1, l2 = math.hypot(*v1), math.hypot(*v2)
        r = min(radius, l1 / 2.2, l2 / 2.2)
        a = (p1[0] + v1[0] / l1 * r, p1[1] + v1[1] / l1 * r)
        b = (p1[0] + v2[0] / l2 * r, p1[1] + v2[1] / l2 * r)
        cmds.append(("M" if i == 0 else "L") + f"{a[0]:.2f} {a[1]:.2f}")
        cmds.append(f"Q{p1[0]:.2f} {p1[1]:.2f} {b[0]:.2f} {b[1]:.2f}")
    return " ".join(cmds) + " Z"


def svg(background=None):
    hexc = lambda c: "#%02X%02X%02X" % c
    bg = f'<rect width="100" height="100" fill="{hexc(background)}"/>' if background else ""
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        f"{bg}"
        f'<path d="{svg_path(CORAL_QUAD, RADIUS)}" fill="{hexc(CORAL)}"/>'
        f'<defs><clipPath id="c"><path d="{svg_path(CORAL_QUAD, RADIUS)}"/></clipPath></defs>'
        f'<path d="{svg_path(PLUM_QUAD, RADIUS)}" fill="{hexc(PLUM)}"/>'
        f'<path d="{svg_path(PLUM_QUAD, RADIUS)}" fill="#5A3348" clip-path="url(#c)"/>'
        f'<path d="{svg_path(SEED, SEED_RADIUS)}" fill="{hexc(IVORY)}"/>'
        "</svg>"
    )


def android_vector_paths():
    """Path data for the white notification silhouette (even-odd fill):
    the overlap becomes a hole and the seed sits inside it."""
    return " ".join(
        [svg_path(CORAL_QUAD, RADIUS), svg_path(PLUM_QUAD, RADIUS), svg_path(SEED, SEED_RADIUS)]
    )
