#!/usr/bin/env python3
"""
Layout previews of the office, from a scene dump (entry_scene_dump.luau).

This is NOT Roblox's renderer: parts are ray-cast as boxes (balls as
spheres), lighting is a rough Lambert + distance falloff with no shadows,
materials are flat colours. It exists to catch spatial mistakes when Studio
isn't available -- props floating, overlapping, blocking a doorway, facing the
wall, rooms left unlit -- not to judge the final look.

  python3 render_scene.py scene.txt out_dir
Writes plan.png (top-down, floor to 11.5 studs) and a few perspective shots.
Requires numpy and pillow.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def load(path):
    parts, lights = [], []
    for line in Path(path).read_text().splitlines():
        f = line.split("|")
        if f[0] == "PART":
            comps = [float(v) for v in f[6].split(",")]
            pos = np.array(comps[0:3])
            rot = np.array(comps[3:12]).reshape(3, 3)  # rows r0.., columns = axes
            parts.append({
                "path": f[1],
                "shape": f[2],
                "size": np.array([float(f[3]), float(f[4]), float(f[5])]),
                "pos": pos,
                "rot": rot,
                "color": np.array([int(v) for v in f[7].split(",")]) / 255.0,
                "transparency": float(f[8]),
                "material": f[9],
                "interactable": f[10] == "true",
            })
        elif f[0] == "LIGHT":
            axes = [float(v) for v in f[9].split(",")]
            lights.append({
                "kind": f[1],
                "pos": np.array([float(f[2]), float(f[3]), float(f[4])]),
                "color": np.array([int(v) for v in f[5].split(",")]) / 255.0,
                "brightness": float(f[6]),
                "range": float(f[7]),
                "face": f[8],
                "right": np.array(axes[0:3]),
                "up": np.array(axes[3:6]),
                "look": np.array(axes[6:9]),
            })
    return parts, lights


def face_dir(light):
    face = light["face"]
    return {
        "Top": light["up"],
        "Bottom": -light["up"],
        "Front": light["look"],
        "Back": -light["look"],
        "Right": light["right"],
        "Left": -light["right"],
    }.get(face)


def plan(parts, lights, out, scale=16):
    xmin, xmax, zmin, zmax = -31, 31, -25, 25
    w, h = int((xmax - xmin) * scale), int((zmax - zmin) * scale)
    img = Image.new("RGB", (w, h), (10, 10, 12))
    draw = ImageDraw.Draw(img, "RGBA")

    def px(x, z):
        return ((x - xmin) * scale, (z - zmin) * scale)

    visible = []
    for p in parts:
        if "Skyline" in p["path"] or "Backdrop" in p["path"]:
            continue
        half = p["size"] / 2
        corners = []
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    corners.append(p["pos"] + p["rot"] @ (half * np.array([sx, sy, sz])))
        corners = np.array(corners)
        top = corners[:, 1].max()
        if corners[:, 1].min() > 10.5:
            continue
        visible.append((min(top, 11.5), corners, p))
    visible.sort(key=lambda v: v[0])
    for top, corners, p in visible:
        pts = [px(c[0], c[2]) for c in corners]
        # Convex hull of the projected corners.
        pts = sorted(set(pts))
        def cross(o, a, b):
            return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
        lower, upper = [], []
        for q in pts:
            while len(lower) >= 2 and cross(lower[-2], lower[-1], q) <= 0:
                lower.pop()
            lower.append(q)
        for q in reversed(pts):
            while len(upper) >= 2 and cross(upper[-2], upper[-1], q) <= 0:
                upper.pop()
            upper.append(q)
        hull = lower[:-1] + upper[:-1]
        shade = 0.55 + 0.45 * min(max(top / 8, 0), 1)
        col = tuple(int(c * 255 * shade) for c in p["color"]) + (int(255 * (1 - p["transparency"])),)
        if len(hull) >= 3:
            draw.polygon(hull, fill=col, outline=(0, 0, 0, 90) if top > 0.2 else None)
        if p["interactable"]:
            c = p["pos"]
            x, z = px(c[0], c[2])
            draw.ellipse([x - 5, z - 5, x + 5, z + 5], outline=(255, 60, 60, 255), width=2)
    for l in lights:
        x, z = px(l["pos"][0], l["pos"][2])
        r = 4 + l["brightness"] * 3
        draw.ellipse([x - r, z - r, x + r, z + r], outline=(255, 230, 120, 255), width=2)
    # Grid every 10 studs with labels.
    for gx in range(-30, 31, 10):
        x, _ = px(gx, 0)
        draw.line([(x, 0), (x, h)], fill=(80, 120, 200, 70))
        draw.text((x + 2, 2), str(gx), fill=(120, 160, 230, 255))
    for gz in range(-20, 21, 10):
        _, z = px(0, gz)
        draw.line([(0, z), (w, z)], fill=(80, 120, 200, 70))
        draw.text((2, z + 2), str(gz), fill=(120, 160, 230, 255))
    img.save(out)


def render(parts, lights, eye, target, out, width=640, height=360, fov=70):
    eye, target = np.array(eye, float), np.array(target, float)
    forward = target - eye
    forward /= np.linalg.norm(forward)
    right = np.cross(forward, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    aspect = width / height
    t = math.tan(math.radians(fov) / 2)
    ys, xs = np.mgrid[0:height, 0:width]
    u = (2 * (xs + 0.5) / width - 1) * t * aspect
    v = (1 - 2 * (ys + 0.5) / height) * t
    dirs = forward[None, None, :] + u[..., None] * right + v[..., None] * up
    dirs /= np.linalg.norm(dirs, axis=-1, keepdims=True)
    d = dirs.reshape(-1, 3)
    n_rays = d.shape[0]
    best_t = np.full(n_rays, np.inf)
    best_col = np.zeros((n_rays, 3))
    best_n = np.zeros((n_rays, 3))
    best_emissive = np.zeros(n_rays, bool)
    best_alpha = np.ones(n_rays)
    for p in parts:
        if p["transparency"] >= 0.3:
            continue
        rel = p["pos"] - eye
        dist = np.linalg.norm(rel)
        if dist > 140:
            continue
        rot = p["rot"]
        half = p["size"] / 2
        o = rot.T @ (eye - p["pos"])
        dl = d @ rot  # ray directions in local space
        if p["shape"] == "Ball":
            r = half.min()
            b = dl @ o
            c = o @ o - r * r
            disc = b * b - c
            hit = disc >= 0
            tt = np.where(hit, -b - np.sqrt(np.maximum(disc, 0)), np.inf)
            tt = np.where(tt > 0.05, tt, np.inf)
            local_hit = o[None, :] + dl * tt[:, None]
            normal_local = local_hit / max(r, 1e-6)
        else:
            with np.errstate(divide="ignore", invalid="ignore"):
                inv = 1.0 / dl
                t1 = (-half - o) * inv
                t2 = (half - o) * inv
            tmin = np.nanmax(np.minimum(t1, t2), axis=1)
            tmax = np.nanmin(np.maximum(t1, t2), axis=1)
            hit = (tmax >= tmin) & (tmax > 0.05)
            tt = np.where(hit, np.where(tmin > 0.05, tmin, tmax), np.inf)
            local_hit = o[None, :] + dl * np.where(np.isfinite(tt), tt, 0)[:, None]
            rel_hit = local_hit / np.maximum(half, 1e-6)
            axis = np.argmax(np.abs(rel_hit), axis=1)
            normal_local = np.zeros_like(rel_hit)
            normal_local[np.arange(n_rays), axis] = np.sign(rel_hit[np.arange(n_rays), axis])
        closer = tt < best_t
        if not closer.any():
            continue
        best_t = np.where(closer, tt, best_t)
        best_col[closer] = p["color"]
        best_n[closer] = (normal_local[closer] @ rot.T)
        best_emissive[closer] = p["material"] == "Neon"
        best_alpha[closer] = 1 - p["transparency"]
    hitmask = np.isfinite(best_t)
    points = eye[None, :] + d * np.where(hitmask, best_t, 0)[:, None]
    light_acc = np.full((n_rays, 3), 0.16)  # ambient
    for l in lights:
        to = l["pos"][None, :] - points
        dist = np.linalg.norm(to, axis=1)
        ldir = to / np.maximum(dist, 1e-6)[:, None]
        lam = np.clip(np.sum(ldir * best_n, axis=1), 0, 1)
        att = np.clip(1 - dist / max(l["range"], 1e-3), 0, 1) ** 2
        fd = face_dir(l)
        if fd is not None and l["kind"] in ("SpotLight", "SurfaceLight"):
            cone = np.sum(-ldir * fd[None, :], axis=1)
            att *= np.clip(cone * 1.5, 0, 1)
        light_acc += (lam * att * l["brightness"] * 1.4)[:, None] * l["color"][None, :]
    col = best_col * light_acc
    col = np.where(best_emissive[:, None], best_col * 1.2, col)
    col = np.where(hitmask[:, None], col, np.array([0.03, 0.04, 0.07]))
    col = np.clip(col, 0, 1) ** (1 / 2.2)
    Image.fromarray((col.reshape(height, width, 3) * 255).astype(np.uint8)).save(out)


if __name__ == "__main__":
    scene, out_dir = sys.argv[1], Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    parts, lights = load(scene)
    plan(parts, lights, out_dir / "plan.png")
    shots = {
        "spawn_view": ((18, 5.2, 12), (19, 4, 2)),
        "daniel_office": ((-19.2, 6.2, -3.2), (-25, 2.5, -9)),
        "meeting_room": ((13.5, 6.5, -8.5), (23, 3, -17)),
        "lobby": ((14, 6, 9), (26, 3.5, 20)),
        "corridor_mara": ((-2, 5.8, -7), (-4, 4.5, -24)),
        "open_plan": ((-8, 7, 5), (-24, 2, 18)),
        "kitchenette": ((-5, 5.5, -16), (-13, 3, -20)),
    }
    for name, (eye, target) in shots.items():
        render(parts, lights, eye, target, out_dir / f"{name}.png")
    print("rendered", len(parts), "parts,", len(lights), "lights ->", out_dir)
