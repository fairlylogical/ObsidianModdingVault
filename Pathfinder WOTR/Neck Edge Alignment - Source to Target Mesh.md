---
title: Neck Edge Alignment - Source to Target Mesh
game: "Pathfinder: Wrath of the Righteous"
created: 2026-11-24
tags:
  - pathfinder-wotr
  - modding
  - mesh
  - blender
  - neck-seam
---

# Neck Edge Alignment - Source to Target Mesh

How to make the open lower edge (neck) of a custom head mesh sit **exactly** on the neck edge of a vanilla mesh, given two lists of vertex indices picked in Blender. First used for Veron (see [[Custom Head from External Model - Dhampir Male Guide]], section 5 "Neck ring snap"). Code: `D:\Pathfingder_Mods\projects\VeronDhampirWotr\Tools\convert_veron.py` (`ring_indices`, `half_rings`, `arclen`, `snap_neck_ring`).

**Terms used here**
- **Source mesh**: the mesh that gets modified (the custom head, e.g. Veron's face shell).
- **Target mesh**: the reference that stays as is (the vanilla `HeadBottom`, whose lower edge meets the vanilla body neck).
- Source edge and target edge: the two vertex lists.

> [!warning] Naming
> In the first Veron session the words were used the other way round (Veron = "target", vanilla = "source"). Before starting, confirm which mesh gets modified.

> [!info] Status (2026-11-24)
> Geometry checked in Blender (no folds, edge residual 0 mm). **Not yet checked in game.**

## 1. Get the two vertex lists from Blender

The user selects the edge vertices in Edit Mode on each mesh. Read them through the Blender MCP (`execute_blender_code`):

```python
import bpy, bmesh
o = bpy.context.active_object
bm = bmesh.from_edit_mesh(o.data) if o.mode == 'EDIT' else None
vs = bm.verts if bm else o.data.vertices
print(o.name, [v.index for v in vs if v.select])
```

When the selection is gone (object left Edit Mode, user selected something else), keep the index list and read positions by index. Use **world** positions (`o.matrix_world @ v.co`), on the evaluated mesh if there are modifiers (`o.evaluated_get(depsgraph).to_mesh()`).

## 2. Check what was selected (do not trust the lists blindly)

For each list, print per vertex: world position, whether it is on a **boundary** edge, and which other selected vertices it is linked to:

```python
bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
s = set(ids)
for i in ids:
    v = bm.verts[i]
    print(i, any(e.is_boundary for e in v.link_edges),
          [e.other_vert(v).index for e in v.link_edges if e.other_vert(v).index in s])
```

What this found on Veron / vanilla:
- **Source (Veron)**: 18 verts, one closed boundary loop: OK.
- **Target (vanilla HeadBottom)**: 20 picks, but only **16 unique positions**. The mesh halves are split at x = 0, so the front and back centre vertices exist twice (0/40, 16/55). Two more picks (17/56) were also "boundary" only because of that split: they sit 34 mm **up the back seam**, not on the neck edge. **Excluded.**
- Rule: dedupe by position (round to 1e-5), drop points that are far off the ring height trend, and say so to the user.
- Counts do not need to match (18 vs 16 here): matching is by arc length, not by index.

## 3. Save both edges in game coordinates

Write a small json (`Tools/ref/neck_rings.json`) so the converter can redo the step on every rebuild without Blender:
- Coordinates in **Unity space**: Blender world (x, y, z) -> Unity (-x, z, -y) (glTF Y-up + the converter's X mirror). Check one point against the Unity dump (`Tools/ref/head_m_dh.json`) before going on.
- Keep the Blender indices next to each position (useful for debugging). For the target, the indices of the vanilla objects in `both.blend` were **identical to the Unity dump indices**, which also gives the vanilla bone weights directly.
- The source indices are **not** usable as glb indices: Blender's glTF import welds vertices (2959 in Blender vs 2993 in the glb). The converter finds the glb vertices **by position** (< 0.2 mm), seam duplicates included.

## 4. Match the edges (arc length per side)

1. Split each closed ring into two halves, each ordered **front centre -> back centre** (front = point with the smallest |angle| around the neck axis, back = the largest; angle = `atan2(x, z - mean z)`).
2. For each half, compute the normalised arc length `s` (0 at front, 1 at back).
3. Each source vertex goes to the point of the target half-polyline at the **same `s`** (linear interpolation between the two surrounding target vertices). Also interpolate the target vertices' **bone weights** with the same factor.

```python
def arclen(P):
    s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))]
    return s / s[-1]
# per half: j = segment containing s on the target, f = fraction in it
target = VP[j] * (1 - f) + VP[j + 1] * f
```

Why arc length rather than angle or nearest point: it keeps the spacing even, it is symmetric left/right, front maps to front and back to back, and it works with different vertex counts. Nearest-point would bunch vertices; angle-only breaks when the two rings have different shapes.

Print the table (source idx, s, from, to, distance) and check it is **symmetric** on both sides. Veron: 8-25 mm moves (sides: 16 mm outward, 19 mm down).

## 5. Spread the move (no kink)

Moving only the edge vertices would create a step one row up. So:
- Build the welded vertex graph of the **source face kind only** (do not drag hair, eyes, teeth).
- Fixed values: edge vertices = their full displacement; vertices farther than **R = 35 mm** from the edge = 0 (they are not in the region).
- Region vertices: harmonic interpolation (Jacobi, 300 passes: each vertex = mean displacement of its neighbours).
- Apply, then update normals with the change of the geometric vertex normal (`n += g1 - g0`, renormalise).

Order in the converter: classification -> `fit_neck` (radial fit of the neck wall onto the target surface) -> **ring snap** -> weight transfer -> push-out of the body.

## 6. Protect the edge in later steps

- **Weights**: edge vertices take the **interpolated target edge weights** (vanilla: Neck_ADJ 0.9-1.0, a little Head_ADJ/Jaw_Scale) instead of the generic k-nearest transfer, so the seam deforms exactly like the body neck.
- **Push-out** (moves vertices that sit inside the body by up to 3 mm): skip edge vertices both as candidates and as receivers of the spread push, or it undoes the snap.

## 7. Checks

Numbers (converter printout):
- edge residual after everything = **0.000 mm**; lowest y of the Head part = lowest y of the target (1.557).
- triangles of the moved region: **no normal flip** (dot of old and new face normals > 0), area ratio (Veron: 0.97-2.64, the bottom band stretches).
- distance of moved vertices to the target surface (Veron: median 0.7 mm).

Visual (Blender MCP):
- Export the converted part as OBJ (Unity -> Blender: (-x, -z, y), flip winding back), load it into a `converter_check` collection.
- Object colours (`shading.color_type = 'OBJECT'`), source and target overlaid, then the source alone, `look` with `angles` from below/side/back. Hide the other meshes first and restore them after (and do not save the user's .blend without asking).

Then build, install with the game closed, and check the seam in game (sides of the neck, turning the head).

## 8. Reuse checklist

1. User selects both edges in Edit Mode; read indices and world positions.
2. Check topology (boundary, linked), dedupe, drop off-ring points; tell the user what was dropped.
3. Save both rings (game coords + indices) to json; check one point against the dump.
4. Converter: find source verts by position, arc-length match per half, harmonic spread (face only, R ~ 35 mm), edge weights from the target, edge excluded from push-out.
5. Check residual / flips / surface distance, then look at it in Blender.
6. Back up the installed mod, build, install, test in game.
