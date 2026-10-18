#!/usr/bin/env python3
"""Generates assets/lottie/daily_chest.json, the daily chest loot box animation.

Run from the repo root: python3 tool/daily_chest_lottie.py

Contract: 512x512 at 60 fps. Markers (frames):
  idle 0-120 loop, charge 120-180 loop, open 180-270 one shot, opened 270-390 loop, spent 390-392 static.
  The spent pose is held from frame 391, so show marker end (392). Frame 390 is the opened loop frame.
Dynamic fill names, all plain fills: glow (default #34D399), accent_light #B79CFF, accent_mid #8B5CF6,
accent_dark #5B3BC4. Override with ValueDelegate.color(['**', '<name>'], value: color).
Create the LottieDrawable first and assign delegates after, as the Lottie widget does.
The output is deterministic.
"""

import json
import math
import random
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "lottie" / "daily_chest.json"
SIZE, FPS, END = 512, 60, 393
MARKERS = (("idle", 0, 120), ("charge", 120, 60), ("open", 180, 90), ("opened", 270, 120), ("spent", 390, 2))
LOOPS = ((0, 120), (120, 180), (270, 390))
GROUND = (256, 364)
ROLE = {"glow": "#34D399", "accent_light": "#B79CFF", "accent_mid": "#8B5CF6", "accent_dark": "#5B3BC4"}
GRAPHITE_L, GRAPHITE_R, GRAPHITE_HI = "#3A3B45", "#24252C", "#5A5C68"
NAVY, WHITE, SHADE = "#14122B", "#FFFFFF", "#05050A"

BODY_S, BODY_C, BODY_H = 68, 9, 140
COLLAR_S, COLLAR_C = 72, 8
OPEN_S, OPEN_DEPTH = 54, 46
LID_S, LID_C, LID_TOP = 82, 10, 165
BRACKET_H, BRACKET_T = 30, 9
TINT_ACCENT, TINT_BODY = 65, 45
LID_RISE = 520
OPENING = (0, -BODY_H)

COS30 = math.cos(math.radians(30))
KAPPA = 0.5523


def iso(x, y, z):
    return ((x - y) * COS30, (x + y) * 0.5 - z)


def proj(points):
    return [iso(*p) for p in points]


def area(pts):
    return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1])) / 2


def unit(v):
    n = math.hypot(*v) or 1
    return (v[0] / n, v[1] / n)


def inflate(pts, d):
    if not d:
        return pts
    sign = 1 if area(pts) > 0 else -1
    out = []
    for k, p in enumerate(pts):
        prev, nxt = pts[k - 1], pts[(k + 1) % len(pts)]
        e1, e2 = unit((p[0] - prev[0], p[1] - prev[1])), unit((nxt[0] - p[0], nxt[1] - p[1]))
        n1, n2 = (sign * e1[1], -sign * e1[0]), (sign * e2[1], -sign * e2[0])
        m = max(1 + n1[0] * n2[0] + n1[1] * n2[1], 0.35)
        out.append((p[0] + d * (n1[0] + n2[0]) / m, p[1] + d * (n1[1] + n2[1]) / m))
    return out


def clip(subject, region):
    """Sutherland-Hodgman clip of a polygon to a convex region."""
    sign = 1 if area(region) > 0 else -1
    out = subject
    for a, b in zip(region, region[1:] + region[:1]):
        def side(p):
            return sign * ((b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]))

        src, out = out, []
        for p, q in zip(src, src[1:] + src[:1]):
            sp, sq = side(p), side(q)
            if sp >= 0:
                out.append(p)
            if (sp >= 0) != (sq >= 0):
                t = sp / (sp - sq)
                out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
        if not out:
            break
    return out


def hull(points):
    def half(seq):
        h = []
        for p in seq:
            while len(h) > 1 and (h[-1][0] - h[-2][0]) * (p[1] - h[-2][1]) - (h[-1][1] - h[-2][1]) * (p[0] - h[-2][0]) <= 0:
                h.pop()
            h.append(p)
        return h[:-1]

    pts = sorted(set(points))
    return half(pts) + half(pts[::-1])


def rounded_outline(pts, radius, steps=5):
    out = []
    for k, p in enumerate(pts):
        a, b = pts[k - 1], pts[(k + 1) % len(pts)]
        r = min(radius, math.dist(a, p) / 2, math.dist(b, p) / 2)
        d1, d2 = unit((a[0] - p[0], a[1] - p[1])), unit((b[0] - p[0], b[1] - p[1]))
        s, e = (p[0] + d1[0] * r, p[1] + d1[1] * r), (p[0] + d2[0] * r, p[1] + d2[1] * r)
        for i in range(steps + 1):
            t = i / steps
            out.append(tuple((1 - t) ** 2 * s[j] + 2 * t * (1 - t) * p[j] + t * t * e[j] for j in (0, 1)))
    return out


EASES = {"lin": None, "io": (0.37, 0, 0.63, 1), "out": (0.22, 1, 0.36, 1), "in": (0.64, 0, 0.78, 0), "launch": (0.35, 0.55, 0.7, 0.85)}


def ease_y(ease, x):
    if ease == "lin":
        return x
    x1, y1, x2, y2 = EASES[ease]
    lo, hi = 0.0, 1.0
    for _ in range(40):
        m = (lo + hi) / 2
        if 3 * (1 - m) ** 2 * m * x1 + 3 * (1 - m) * m * m * x2 + m ** 3 < x:
            lo = m
        else:
            hi = m
    m = (lo + hi) / 2
    return 3 * (1 - m) ** 2 * m * y1 + 3 * (1 - m) * m * m * y2 + m ** 3


def lerp(a, b, t):
    if isinstance(a, (list, tuple)):
        return [x + (y - x) * t for x, y in zip(a, b)]
    return a + (b - a) * t


def same(a, b):
    pairs = zip(a, b) if isinstance(a, (list, tuple)) else [(a, b)]
    return all(abs(x - y) < 1e-6 for x, y in pairs)


class Track:
    """Keys are (frame, value, ease to the next key). Later parts override earlier keys at the same frame.

    The value is held before the first key and after the last. Loop markers must start and end on the same value.
    """

    def __init__(self, *parts):
        merged = {}
        for part in parts:
            for key in part:
                merged[key[0]] = key
        self.keys = [merged[t] for t in sorted(merged)]
        for a, b in LOOPS:
            assert same(self.at(a), self.at(b)), f"loop {a}-{b} not seamless: {self.at(a)} vs {self.at(b)}"

    def at(self, t):
        keys = self.keys
        if t <= keys[0][0]:
            return keys[0][1]
        for a, b in zip(keys, keys[1:]):
            if a[0] <= t <= b[0]:
                return lerp(a[1], b[1], ease_y(a[2], (t - a[0]) / (b[0] - a[0])))
        return keys[-1][1]

    def constant(self):
        return all(k[1] == self.keys[0][1] for k in self.keys)

    def map(self, fn):
        return Track([(t, fn(v), e) for t, v, e in self.keys])


def sampled(fn, t0, t1, step):
    count = max(1, round((t1 - t0) / step))
    return [(t0 + (t1 - t0) * i / count, fn(t0 + (t1 - t0) * i / count), "lin") for i in range(count + 1)]


def swing(base, amp, k, phase, start, hi=460):
    """Eased keys on the extremes of base + amp * sin(2 pi k (t - 270) / 120 + phase), from frame start.

    The extremes repeat every 120 / k frames, so the opened loop stays seamless.
    """
    wave = lambda t: base + amp * math.sin(2 * math.pi * k * (t - 270) / 120 + phase)
    keys = [(start, wave(start), "io")]
    for m in range(-12, 13):
        t = 270 + (math.pi / 2 + m * math.pi - phase) * 120 / (2 * math.pi * k)
        if start < t <= hi:
            keys.append((t, base + amp * (-1) ** m, "io"))
    return keys


def num(v):
    return round(v, 3) if isinstance(v, float) else v


def vec(v, pad):
    if isinstance(v, (list, tuple)):
        return [num(x) for x in v] + ([100] if pad else [])
    return [num(v)]


def prop(v, pad=False):
    if isinstance(v, Track) and not v.constant():
        frames = []
        for k, (t, value, ease) in enumerate(v.keys):
            frame = {"t": round(t, 2), "s": vec(value, pad)}
            if k < len(v.keys) - 1 and ease != "lin":
                x1, y1, x2, y2 = EASES[ease]
                frame["i"], frame["o"] = {"x": x2, "y": y2}, {"x": x1, "y": y1}
            frames.append(frame)
        return {"a": 1, "k": frames}
    v = v.keys[0][1] if isinstance(v, Track) else v
    return {"a": 0, "k": vec(v, pad) if isinstance(v, (list, tuple)) else num(v)}


def transform(p=(0, 0), a=(0, 0), s=(100, 100), r=0, o=100, group=False):
    animated = isinstance(p[0], Track) or isinstance(p[1], Track)
    out = {"ty": "tr"} if group else {}
    out |= {
        "o": prop(o),
        "r": prop(r),
        "p": {"s": True, "x": prop(p[0]), "y": prop(p[1])} if animated else {"a": 0, "k": [p[0], p[1], 0]},
        "a": {"a": 0, "k": [a[0], a[1], 0]},
        "s": prop(s, pad=True),
    }
    if group:
        out |= {"sk": {"a": 0, "k": 0}, "sa": {"a": 0, "k": 0}}
    return out


def rgba(c):
    c = ROLE.get(c, c).lstrip("#")
    return [round(int(c[i : i + 2], 16) / 255, 4) for i in (0, 2, 4)] + [1]


def rnd(seq):
    return [[round(x, 2), round(y, 2)] for x, y in seq]


def path(pts, radius=0.0):
    n = len(pts)
    if radius <= 0:
        return {"ty": "sh", "ks": {"a": 0, "k": {"i": [[0, 0]] * n, "o": [[0, 0]] * n, "v": rnd(pts), "c": True}}}
    v, i, o = [], [], []
    for k, p in enumerate(pts):
        a, b = pts[k - 1], pts[(k + 1) % n]
        r = min(radius, math.dist(a, p) / 2, math.dist(b, p) / 2)
        d1, d2 = unit((a[0] - p[0], a[1] - p[1])), unit((b[0] - p[0], b[1] - p[1]))
        s, e = (p[0] + d1[0] * r, p[1] + d1[1] * r), (p[0] + d2[0] * r, p[1] + d2[1] * r)
        v += [s, e]
        i += [(0, 0), ((p[0] - e[0]) * KAPPA, (p[1] - e[1]) * KAPPA)]
        o += [((p[0] - s[0]) * KAPPA, (p[1] - s[1]) * KAPPA), (0, 0)]
    return {"ty": "sh", "ks": {"a": 0, "k": {"i": rnd(i), "o": rnd(o), "v": rnd(v), "c": True}}}


def ellipse(cx, cy, w, h):
    return {"ty": "el", "p": {"a": 0, "k": [round(cx, 2), round(cy, 2)]}, "s": {"a": 0, "k": [round(w, 2), round(h, 2)]}, "d": 1}


def fill(color, opacity=100, rule=1):
    return {"ty": "fl", "nm": color, "c": {"a": 0, "k": rgba(color)}, "o": prop(opacity), "r": rule, "bm": 0}


def shape(name, color, paths, opacity=100, rule=1, **tr):
    return {"ty": "gr", "nm": name, "it": [*paths, fill(color, opacity, rule), transform(group=True, **tr)]}


def poly(name, pts, color, opacity=100, radius=0.0, grow=0.0, **tr):
    return shape(name, color, [path(inflate(pts, grow), radius)], opacity, **tr)


def layer(ind, name, shapes=(), parent=None, ip=0, op=END, **tr):
    out = {"ddd": 0, "ind": ind, "ty": 4 if shapes else 3, "nm": name, "sr": 1, "ks": transform(**tr), "ao": 0, "ip": ip, "op": op, "st": 0, "bm": 0}
    if parent:
        out["parent"] = parent
    if shapes:
        # Lottie paints the first shape last, so shapes are authored back to front.
        out["shapes"] = list(reversed(shapes))
    return out


def falloff(steps, peak, curve=1.5):
    """(index, alpha %) of each layer in a stack whose composited alpha follows an eased falloff.

    Index 0 is the outermost layer and the composite is 0 outside it and `peak` percent inside the innermost.
    Each layer adds only the alpha that is still missing, so the steps stay thin and no edge shows. `curve` above 1
    pulls the light toward the inside. A layer that would add less than one alpha byte (0.4 %) is left out and its
    alpha goes to the next layer.
    """
    covered = 0.0
    for i in range(steps):
        u = (i + 1) / steps
        target = peak / 100 * (u * u * (3 - 2 * u)) ** curve
        alpha = 100 * (1 - (1 - target) / (1 - covered))
        if alpha < 0.4:
            continue
        covered = target
        yield i, alpha


def soft(name, color, center, big, small, steps, peak, curve=1.5, rise=False):
    """Stacked solid ellipses whose composited alpha follows `falloff`, so one colour delegate can tint them.

    The ellipses are concentric on `center`. With `rise` they share their bottom point instead, so the light fades out
    upward and its top edge is the biggest ellipse's top.
    """
    out = []
    for i, alpha in falloff(steps, peak, curve):
        w, h = (b + (s - b) * i / (steps - 1) for b, s in zip(big, small))
        out.append(shape(f"{name}_{i}", color, [ellipse(center[0], center[1] - (h / 2 if rise else 0), w, h)], opacity=alpha))
    return out


def octagon(s, c):
    return [(-s + c, -s), (s - c, -s), (s, -s + c), (s, s - c), (s - c, s), (-s + c, s), (-s, s - c), (-s, -s + c)]


class Prism:
    """The faces of a chamfered prism that face the camera, as maps from (u, z) to 3D. u runs left to right."""

    def __init__(self, s, c):
        self.span = 2 * s - 2 * c
        self.left = lambda u, z: (-s + c + u, s, z)
        self.right = lambda u, z: (s, s - c - u, z)
        self.bevel = lambda u, z: (s - c + u * c, s - u * c, z)


def strip(pt, contour, top):
    return proj([pt(contour[0][0], top), pt(contour[-1][0], top)] + [pt(u, z) for u, z in reversed(contour)])


def band(pt, contour, dz):
    return proj([pt(u, z) for u, z in contour] + [pt(u, z - dz) for u, z in reversed(contour)])


def circle(pt, uc, zc, r, n=16):
    return proj([pt(uc + r * math.cos(2 * math.pi * k / n), zc + r * math.sin(2 * math.pi * k / n)) for k in range(n)])


def star(r, pinch):
    a = r * pinch
    return [(0, -r), (a, -a), (r, 0), (a, a), (0, r), (-a, a), (-r, 0), (-a, -a)]


def glint(a3, b3, w=1.6):
    (ax, ay), (bx, by) = iso(*a3), iso(*b3)
    return [(ax, ay), (bx, by), (bx, by - w), (ax, ay - w)]


def skirt(span, far, front, cham, z_fin, z_notch):
    """Bottom contours of the left and right skirt faces: fins at the ends, a notch between."""
    left = ((0, z_fin), (far, z_fin), (far + cham, z_notch), (span - front - cham, z_notch), (span - front, z_fin), (span, z_fin))
    right = ((0, z_fin), (front, z_fin), (front + cham, z_notch), (span - far - cham, z_notch), (span - far, z_fin), (span, z_fin))
    return left, right


def skirt_parts(prefix, prism, contours, top, colors, visor):
    """(name, outline, color, options) of a notched skirt: two faces, the front bevel strip and two visor slots."""
    left_c, right_c = contours
    fin = left_c[0][1]
    out = [
        (f"{prefix}_left", strip(prism.left, left_c, top), colors[0], {}),
        (f"{prefix}_right", strip(prism.right, right_c, top), colors[1], {}),
        (f"{prefix}_front", strip(prism.bevel, ((0, fin), (1, fin)), top), colors[2], {}),
    ]
    z0, z1 = visor
    for side, pt, (a, b) in (("left", prism.left, (38, prism.span - 44)), ("right", prism.right, (44, prism.span - 38))):
        out.append((f"{prefix}_visor_{side}", proj([pt(a, z1), pt(b, z1), pt(b - 10, z0), pt(a + 10, z0)]), NAVY, {"radius": 2, "grow": 0}))
    return out


class Surfaces:
    """Shapes of one box layer plus the tint and dim overlay shapes that follow the same outlines."""

    def __init__(self):
        self.base, self.tint, self.dim = [], [], []

    def add(self, name, paths, color, rule=1, tint=TINT_ACCENT):
        self.base.append(shape(name, color, paths, rule=rule))
        self.tint.append(shape(name + "_tint", "glow", paths, opacity=tint, rule=rule))
        self.dim.append(shape(name + "_dim", SHADE, paths, rule=rule))

    def poly(self, name, pts, color, grow=0.45, radius=0.0, tint=TINT_ACCENT):
        self.add(name, [path(inflate(pts, grow), radius)], color, tint=tint)


def collar_contours():
    return skirt(Prism(COLLAR_S, COLLAR_C).span, 22, 26, 16, 100, 118)


def lid_contours():
    return skirt(Prism(LID_S, LID_C).span, 22, 26, 18, 88, 112)


def build_base():
    st = Surfaces()
    body = Prism(BODY_S, BODY_C)
    st.poly("body_left", strip(body.left, ((0, 0), (body.span, 0)), BODY_H), GRAPHITE_L, tint=TINT_BODY)
    st.poly("body_right", strip(body.right, ((0, 0), (body.span, 0)), BODY_H), GRAPHITE_R, tint=TINT_BODY)
    st.poly("body_edge", strip(body.bevel, ((0, 0), (1, 0)), BODY_H), GRAPHITE_HI, tint=TINT_BODY)
    collar = Prism(COLLAR_S, COLLAR_C)
    for name, pts, color, kw in skirt_parts("collar", collar, collar_contours(), BODY_H, ("accent_mid", "accent_dark", "accent_light"), (125, 134)):
        st.poly(name, pts, color, tint=TINT_BODY if color == NAVY else TINT_ACCENT, **kw)
    hole = proj([(x, y, BODY_H) for x, y in ((-OPEN_S, -OPEN_S), (OPEN_S, -OPEN_S), (OPEN_S, OPEN_S), (-OPEN_S, OPEN_S))])
    outer = proj([(x, y, BODY_H) for x, y in octagon(COLLAR_S, COLLAR_C)])
    st.add("rim", [path(inflate(outer, 0.3)), path(hole)], "accent_light", rule=2)
    rim = octagon(COLLAR_S, COLLAR_C)
    for k in (4, 3, 2):
        st.base.append(poly(f"rim_glint_{k}", glint((*rim[k], BODY_H), (*rim[(k + 1) % 8], BODY_H)), WHITE, opacity=45))
    return st, hole


def interior(hole):
    s, z0, z1 = OPEN_S, BODY_H, BODY_H - OPEN_DEPTH
    wall_x = clip(proj([(-s, -s, z0), (-s, s, z0), (-s, s, z1), (-s, -s, z1)]), hole)
    wall_y = clip(proj([(-s, -s, z0), (s, -s, z0), (s, -s, z1), (-s, -s, z1)]), hole)
    floor = clip(proj([(-s, -s, z1), (s, -s, z1), (s, s, z1), (-s, s, z1)]), hole)
    return [("floor", floor, "#0F1015", 92), ("wall_x", wall_x, "#1B1C23", 55), ("wall_y", wall_y, "#23242D", 70)]


def crystal(center, scale):
    """The Prism crystal as an upright badge: a kite with a light left facet and a darker right facet."""
    outline = rounded_outline([(0, -35), (33, 18), (0, 36), (-33, 18)], 5)
    place = lambda pts: [(center[0] + x * scale, center[1] + y * scale) for x, y in pts]
    return (
        place(clip(outline, [(-99, -99), (0, -99), (0, 99), (-99, 99)])),
        place(clip(outline, [(0, -99), (99, -99), (99, 99), (0, 99)])),
        place([(-1.5, -29), (0.3, -29), (-25, 14), (-27, 13)]),
    )


def build_lid():
    lid = []
    zt, zs = LID_TOP, LID_TOP - 5
    faces = Prism(LID_S, LID_C)
    for name, pts, color, kw in skirt_parts("lid", faces, lid_contours(), zs, ("accent_mid", "accent_dark", "accent_light"), (136, 152)):
        lid.append(poly(name, pts, color, **{"grow": 0.45, **kw}))

    outer, inner = octagon(LID_S, LID_C), octagon(LID_S - 6, LID_C - 1.5)
    for k, color, opacity in ((5, "accent_mid", 85), (4, "accent_light", 70), (3, "accent_light", 92), (2, "accent_mid", 85), (1, "accent_mid", 85)):
        o0, o1, i0, i1 = outer[k], outer[(k + 1) % 8], inner[k], inner[(k + 1) % 8]
        lid.append(poly(f"bevel_{k}", proj([(*o0, zs), (*o1, zs), (*i1, zt), (*i0, zt)]), color, opacity=opacity, grow=0.3))
    recess = octagon(60, 8)
    lid.append(shape("lid_top", "accent_light", [path(proj([(*p, zt) for p in inner])), path(proj([(*p, zt) for p in recess]))], rule=2))
    for k in (4, 3, 2):
        lid.append(poly(f"lid_glint_{k}", glint((*inner[k], zt), (*inner[(k + 1) % 8], zt)), WHITE, opacity=60))

    floor_z = zt - 6
    hole = proj([(*p, zt) for p in recess])
    wall_x = clip(proj([(-60, -60, zt), (-60, 60, zt), (-60, 60, floor_z), (-60, -60, floor_z)]), hole)
    wall_y = clip(proj([(-60, -60, zt), (60, -60, zt), (60, -60, floor_z), (-60, -60, floor_z)]), hole)
    lid.append(poly("recess_floor", clip(proj([(*p, floor_z) for p in recess]), hole), "#1A1838", grow=0.3))
    lid.append(poly("recess_wall_x", wall_x, "accent_dark", grow=0.3))
    lid.append(poly("recess_wall_y", wall_y, "accent_mid", grow=0.3))

    plate_s, plate_c, plate_top = 42, 7, zt + 9
    plate = Prism(plate_s, plate_c)
    flat = ((0, floor_z), (plate.span, floor_z))
    lid.append(poly("plate_left", strip(plate.left, flat, plate_top), "accent_mid", grow=0.4))
    lid.append(poly("plate_right", strip(plate.right, flat, plate_top), "accent_dark", grow=0.4))
    lid.append(poly("plate_edge", strip(plate.bevel, ((0, floor_z), (1, floor_z)), plate_top), "accent_light", grow=0.4))
    lid.append(poly("plate_top", proj([(*p, plate_top) for p in octagon(plate_s, plate_c)]), "#F6F3FF", grow=0.3))
    lid.append(poly("plate_inset", proj([(*p, plate_top) for p in octagon(33, 6)]), NAVY))
    cx, cy = iso(0, 0, plate_top)
    left_facet, right_facet, sheen = crystal((cx, cy - 9), 0.84)
    lid.append(shape("crystal_shadow", "#07061A", [ellipse(cx, cy + 12, 50, 18)], opacity=70))
    lid.append(poly("crystal_right", right_facet, "#D9DBE8"))
    lid.append(poly("crystal_left", left_facet, "#F5F5F7"))
    lid.append(poly("crystal_sheen", sheen, WHITE, opacity=60))
    return lid


def build_brackets():
    """Corner brackets at the base. Only the parts the camera can see are modelled."""
    st = Surfaces()
    s, t, h, n = BODY_S, BRACKET_T, BRACKET_H, 9
    jobs = (
        ("bracket_l", [(-s - t, s - n), (-s - t, s + t), (-s + 34, s + t), (-s + 34, s), (-s, s), (-s, s - n)],
         (("left", (-s - t, s + t), (-s + 34, s + t), "accent_mid", True), ("cap", (-s + 34, s), (-s + 34, s + t), "accent_dark", False))),
        ("bracket_r", [(s + t, -s - t), (s + t, -s + 34), (s, -s + 34), (s, -s), (s - n, -s), (s - n, -s - t)],
         (("right", (s + t, -s + 34), (s + t, -s - t), "accent_dark", True), ("cap", (s + t, -s + 34), (s, -s + 34), "accent_mid", False))),
        ("bracket_f", [(s + t, s - 44), (s + t, s + t), (s - 44, s + t), (s - 44, s), (s, s), (s, s - 44)],
         (("left", (s - 44, s + t), (s + t, s + t), "accent_mid", True), ("right", (s + t, s - 44), (s + t, s + t), "accent_dark", True))),
    )
    for name, footprint, faces in jobs:
        for tag, p0, p1, color, slotted in faces:
            st.poly(f"{name}_{tag}", proj([(*p0, h), (*p1, h), (*p1, 0), (*p0, 0)]), color)
        st.poly(f"{name}_top", proj([(*p, h) for p in footprint]), "accent_light", radius=2)
        for tag, p0, p1, color, slotted in faces:
            if slotted:
                a, b = (tuple(p0[j] + (p1[j] - p0[j]) * f for j in (0, 1)) for f in (0.14, 0.86))
                st.poly(f"{name}_{tag}_slot", proj([(*a, h - 8), (*b, h - 8), (*b, 8), (*a, 8)]), NAVY, grow=0, radius=3, tint=TINT_BODY)
                st.base.append(poly(f"{name}_{tag}_glint", glint((*p0, h), (*p1, h)), WHITE, opacity=55))
    return st


def build_slots():
    body = Prism(BODY_S, BODY_C)
    dark, lights = [], []
    for name, pt, uc in (("left", body.left, body.span - 56), ("right", body.right, 56)):
        dark.append(poly(f"slot_{name}", proj([pt(uc - 7, 98), pt(uc + 7, 98), pt(uc + 7, 20), pt(uc - 7, 20)]), "#0E0D1F", radius=5))
        lights.append(poly(f"slot_bar_{name}", proj([pt(uc - 2, 74), pt(uc + 2, 74), pt(uc + 2, 28), pt(uc - 2, 28)]), "glow", radius=1.8))
        lights.append(poly(f"slot_dot_{name}", circle(pt, uc, 87, 3.2), "glow"))
    return dark, lights


def build_shade_and_seams():
    body_sil = hull(proj([(*p, z) for p in octagon(BODY_S, BODY_C) for z in (0, BODY_H)]))
    faces = Prism(LID_S, LID_C)
    left_c, right_c = lid_contours()
    shade, seams = [], []
    for name, pt, contour in (("left", faces.left, left_c), ("right", faces.right, right_c)):
        for out, tag, dz, color, opacity in ((shade, "shade", 12, SHADE, 38), (seams, "seam", 3.4, "glow", 100)):
            outline = clip(band(pt, contour, dz), body_sil)
            if outline:
                out.append(poly(f"{tag}_{name}", outline, color, opacity=opacity))
    return shade, seams


def build_bloom():
    cx, cy = OPENING
    beam = soft("beam", "glow", (cx, cy), (118, 158), (56, 96), 24, 17, rise=True)
    halo = soft("halo", "glow", (cx, cy), (400, 260), (110, 72), 44, 35)
    core = [shape("core_halo", WHITE, [ellipse(cx, cy, 112, 64)], opacity=26), shape("core", WHITE, [ellipse(cx, cy, 70, 40)], opacity=92)]
    return beam + halo + core


def build_flash():
    """A burst of light out of the open top: a soft glow-coloured bloom with a white-hot heart, no hard edge."""
    bloom = soft("flash_glow", "glow", OPENING, (440, 340), (170, 110), 20, 80)
    heart = soft("flash_heart", WHITE, OPENING, (240, 160), (80, 52), 16, 90)
    return bloom + heart


# The lengths, and the beam's size in build_bloom, keep all light below y=24 at the worst sway, float and squash frame.
# daily_chest_asset_test.dart renders frames to check it, so the canvas edge never cuts a ray.
RAYS = ((-72, 170, 3.5), (-54, 215, 4.5), (-37, 236, 3.0), (-20, 210, 5.0), (-6, 205, 3.5), (9, 200, 4.2), (24, 208, 3.0), (40, 235, 4.6), (57, 215, 3.5), (73, 165, 4.0))


def ray_kite(theta, length, half):
    d = math.radians(theta)
    dx, dy = math.sin(d), -math.cos(d)
    shoulder, wid = length * 0.42, length * 0.42 * math.tan(math.radians(half * 1.5))
    return [(0, 0), (dx * shoulder - dy * wid, dy * shoulder + dx * wid), (dx * length, dy * length), (dx * shoulder + dy * wid, dy * shoulder - dx * wid)]


RAY_STEPS, RAY_PEAK = 7, 26


def build_rays():
    """Each ray is nested kites on one eased falloff, so it thins out to nothing at its tip instead of ending on an edge."""
    rays = []
    for n, (theta, length, half) in enumerate(RAYS):
        k, phase = 1 + n % 2, n * 1.3
        kites = []
        for i, alpha in falloff(RAY_STEPS, RAY_PEAK):
            f = 1 - 0.7 * i / (RAY_STEPS - 1)
            kites.append(poly(f"ray_{i}", ray_kite(theta, length * f, half * f ** 0.4), "glow", opacity=alpha))
        rot = Track(swing(0, 3.2, k, phase, 192))
        scale = Track([(t, [v] * 2, e) for t, v, e in swing(100, 7, k, phase + 2, 192)])
        rays.append({"ty": "gr", "nm": f"ray_group_{n}", "it": [*kites[::-1], transform(group=True, r=rot, s=scale)]})
    return rays


def build_sparkles(rng):
    cx, cy = GROUND[0] + OPENING[0], GROUND[1] + OPENING[1] + 6
    groups = []
    for n in range(12):
        angle = math.radians(-78 + 156 * (n + 0.5) / 12 + rng.uniform(-7, 7))
        dist, t0, life = rng.uniform(100, 190), 190 + rng.uniform(0, 16), rng.uniform(34, 50)
        size, spin = rng.uniform(8, 17), rng.choice((-1, 1)) * rng.uniform(40, 110)
        dx, dy, end = math.sin(angle), -math.cos(angle), t0 + life
        u = lambda t: min(max((t - t0) / life, 0), 1)
        px = lambda t: cx + dx * dist * (1 - (1 - u(t)) ** 2.2)
        py = lambda t: cy + dy * dist * (1 - (1 - u(t)) ** 2.2) + 62 * u(t) ** 2
        scale = lambda t: [100 * min(u(t) / 0.14, 1) * (1 - u(t)) ** 0.7 * (0.82 + 0.18 * math.sin(14 * u(t)))] * 2
        items = [
            path(star(size, 0.22), 0.6),
            fill("glow"),
            transform(
                group=True,
                p=(Track(sampled(px, t0, end, 6)), Track(sampled(py, t0, end, 6))),
                s=Track(sampled(scale, t0, end, 4)),
                r=Track([(t0, 0, "lin"), (end, spin, "lin")]),
                o=Track([(t0, 100, "lin"), (t0 + life * 0.65, 100, "lin"), (end, 0, "lin")]),
            ),
        ]
        groups.append({"ty": "gr", "nm": f"sparkle_{n}", "it": items})
    return groups


def build_sparks():
    groups = []
    spots = ((-76, 62, 100), (62, -76, 100), (80, 36, 108), (36, 80, 108), (-52, 82, 104), (82, -48, 104))
    for n, spot in enumerate(spots):
        x, y = iso(*spot)
        x, y = GROUND[0] + x, GROUND[1] + y
        d = unit((x - GROUND[0], y - (GROUND[1] - 100)))
        t0, life, size = 120 + (4, 14, 22, 31, 38, 44)[n], 14, 4.5 + (n % 3) * 0.8
        u = lambda t: min(max((t - t0) / life, 0), 1)
        keys = lambda fn: Track(sampled(fn, t0, t0 + life, 2), [(t0 + life + 1, fn(t0), "lin")])
        items = [
            path(star(size, 0.2)),
            fill("glow"),
            transform(
                group=True,
                p=(keys(lambda t: x + d[0] * 16 * u(t)), keys(lambda t: y + d[1] * 16 * u(t))),
                s=keys(lambda t: [100 * math.sin(math.pi * u(t))] * 2),
                r=keys(lambda t: 90 * u(t)),
            ),
        ]
        groups.append({"ty": "gr", "nm": f"spark_{n}", "it": items})
    return groups


def charge(fn):
    return sampled(lambda t: fn(t - 120), 120, 180, 1)


def build_tracks():
    env = lambda tau: 0.3 + 0.7 * math.sin(math.pi * tau / 60) ** 2
    float_y = Track(
        [(0, 6, "io"), (60, -6, "io"), (120, 6, "lin")],
        charge(lambda tau: 6 + 1.1 * env(tau) * math.sin(2 * math.pi * tau / 7.5)),
        [(180, 6, "lin"), (192, 6, "out"), (201, -12, "in"), (213, 6, "out"), (219, 2, "in"), (225, 6, "lin"), (270, 6, "io"), (330, -6, "io"), (390, 6, "lin")],
    )
    pulse = lambda hi, lo: [(270, hi, "io"), (330, lo, "io"), (390, hi, "lin")]
    off = [(391, 0, "lin")]
    lid_end = 224
    return {
        "float_y": float_y,
        "shake_x": Track(charge(lambda tau: 2.6 * env(tau) * math.sin(2 * math.pi * tau / 10)), [(180, 0, "lin")]),
        "squash_s": Track(
            charge(lambda tau: [100 - 1.7 * math.sin(2 * math.pi * tau / 15), 100 + 3.1 * math.sin(2 * math.pi * tau / 15)]),
            [(180, [100, 100], "io"), (192, [108, 88], "out"), (198, [93, 111], "io"), (206, [103.5, 96], "io"), (214, [99, 101.5], "io"), (224, [100, 100], "lin")],
        ),
        "squash_r": Track(
            charge(lambda tau: 2.4 * math.sin(2 * math.pi * tau / 20)),
            [(180, 0, "lin"), (192, 0, "io"), (198, -2.0, "io"), (207, 1.5, "io"), (216, -0.6, "io"), (226, 0, "lin")],
        ),
        "shadow_s": float_y.map(lambda y: [100 - 0.7 * (6 - y)] * 2),
        "shadow_o": float_y.map(lambda y: 100 - 1.1 * (6 - y)),
        "lid_x": Track([(194, 0, "launch"), (lid_end, 34, "lin")]),
        "lid_y": Track([(194, 0, "launch"), (lid_end, -LID_RISE, "lin")]),
        "lid_r": Track([(194, 0, "out"), (lid_end, 14, "lin")]),
        "lid_s": Track([(194, [100, 100], "out"), (lid_end, [115, 115], "lin")]),
        "bloom_o": Track([(192, 0, "out"), (206, 100, "io"), (238, 100, "io")], pulse(92, 100), off),
        "bloom_s": Track([(192, [40, 40], "out"), (214, [112, 112], "io"), (244, [100, 100], "io"), (270, [100, 100], "io"), (330, [105, 105], "io"), (390, [100, 100], "lin")]),
        "flash_o": Track([(193, 0, "out"), (198, 100, "io"), (208, 0, "lin")]),
        "flash_s": Track([(193, [60, 60], "out"), (208, [135, 135], "lin")]),
        "rays_o": Track([(193, 0, "out"), (216, 100, "io")], pulse(86, 100), off),
        "rays_r": Track(swing(0, 8, 1, 0, 192)),
        "rays_s": Track([(192, [45, 45], "out"), (232, [100, 100], "lin")]),
        "tint_o": Track([(194, 0, "io"), (236, 94, "out")], pulse(94, 100), off),
        "floor_o": Track([(192, 0, "out"), (206, 100, "io")], pulse(100, 88), off),
        "slot_o": Track(
            [(0, 100, "io"), (60, 72, "io"), (120, 100, "lin")],
            charge(lambda tau: 100 - 35 * math.sin(math.pi * tau / 10) ** 2),
            [(180, 100, "lin")],
            pulse(100, 82),
            off,
        ),
        "seam_o": Track(
            [(0, 25, "lin"), (120, 25, "lin")],
            charge(lambda tau: 25 + 75 * math.sin(math.pi * tau / 30) ** 2),
            [(180, 25, "lin"), (192, 100, "out"), (214, 0, "io")],
        ),
        "shade_o": Track([(196, 100, "io"), (206, 0, "lin")]),
        "ground_o": Track([(192, 0, "out"), (240, 100, "io")], pulse(92, 100), off),
        "dim_o": Track([(390, 0, "lin"), (391, 28, "lin")]),
    }


def build():
    tk = build_tracks()
    rng = random.Random(7)
    base, hole = build_base()
    interior_parts = interior(hole)
    brackets = build_brackets()
    slot_dark, slot_lights = build_slots()
    shade, seams = build_shade_and_seams()
    shadow = soft("shadow", SHADE, (0, 0), (340, 178), (250, 130), 10, 26)
    ground = soft("ground_glow", "glow", (0, 0), (440, 240), (220, 125), 36, 26)

    anchor = (0, -150)
    ground_xy = (GROUND[0], GROUND[1] + 10)
    layers = [
        layer(1, "sparkles", build_sparkles(rng), ip=190, op=272),
        layer(2, "sparks", build_sparks(), ip=120, op=182),
        layer(3, "lid", build_lid(), parent=21, op=226, a=anchor, p=(tk["lid_x"].map(lambda v: anchor[0] + v), tk["lid_y"].map(lambda v: anchor[1] + v)), r=tk["lid_r"], s=tk["lid_s"]),
        layer(4, "flash", build_flash(), parent=21, ip=192, op=210, a=OPENING, p=OPENING, s=tk["flash_s"], o=tk["flash_o"]),
        layer(5, "bloom", build_bloom(), parent=21, a=OPENING, p=OPENING, s=tk["bloom_s"], o=tk["bloom_o"]),
        layer(6, "rays", build_rays(), parent=21, p=OPENING, r=tk["rays_r"], s=tk["rays_s"], o=tk["rays_o"]),
        layer(7, "bracket_dim", brackets.dim, parent=21, o=tk["dim_o"]),
        layer(8, "bracket_tint", brackets.tint, parent=21, o=tk["tint_o"]),
        layer(9, "brackets", brackets.base, parent=21),
        layer(10, "seams", seams, parent=21, o=tk["seam_o"]),
        layer(11, "slot_lights", slot_lights, parent=21, o=tk["slot_o"]),
        layer(12, "slots", slot_dark, parent=21),
        layer(13, "lid_shade", shade, parent=21, o=tk["shade_o"]),
        layer(14, "interior_light", [poly(n + "_lit", pts, "glow", opacity=a, grow=0.3) for n, pts, _, a in interior_parts], parent=21, o=tk["floor_o"]),
        layer(15, "base_dim", base.dim, parent=21, o=tk["dim_o"]),
        layer(16, "base_tint", base.tint, parent=21, o=tk["tint_o"]),
        layer(17, "base", base.base + [poly(n, pts, c, grow=0.3) for n, pts, c, _ in interior_parts], parent=21),
        layer(18, "ground_glow", ground, p=ground_xy, s=tk["shadow_s"], o=tk["ground_o"]),
        layer(19, "shadow", shadow, p=ground_xy, s=tk["shadow_s"], o=tk["shadow_o"]),
        layer(20, "float_rig", p=(tk["shake_x"].map(lambda v: GROUND[0] + v), tk["float_y"].map(lambda v: GROUND[1] + v))),
        layer(21, "squash_rig", parent=20, s=tk["squash_s"], r=tk["squash_r"]),
    ]
    markers = [{"cm": name, "tm": start, "dr": dur} for name, start, dur in MARKERS]
    return {"v": "5.7.0", "fr": FPS, "ip": 0, "op": END, "w": SIZE, "h": SIZE, "nm": "daily_chest", "ddd": 0, "assets": [], "layers": layers, "markers": markers}


def main():
    data = json.dumps(build(), separators=(",", ":"))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(data)
    print(f"{OUT} {len(data) / 1024:.1f} KB")


if __name__ == "__main__":
    main()
