---
title: Custom Head from Blender Scene - Squall Human Male Guide
game: "Pathfinder: Wrath of the Righteous"
game_version: 2.7
unity_version: 2020.3.48f1
created: 2026-11-25
tags:
  - pathfinder-wotr
  - modding
  - equipment-entity
  - character-creation
  - human
---

# Custom Head from Blender Scene - Squall Human Male Guide

How the visible head parts of a Blender scene (model "ps2021", folder `squall`) became an extra **Human male** face in character creation (CC), with the custom neck snapped onto the vanilla neck. Same pipeline as [[Custom Head from External Model - Dhampir Male Guide]] (generic converter, MFH3 `.bytes`, donor renderer clone), retargeted to the Human male. See also [[Custom Race Head - Creation Guide]], [[Custom EquipmentEntity - Creation Guide]] and [[Neck Edge Alignment - Source to Target Mesh]].

> [!info] Status (2026-11-25)
> - Built (`BUILDMOD result=Success`) and **installed**, enabled in `EnabledModifications` + `ActiveModifications` (settings backed up as `OwlcatModificationManagerSettings.json.bak_squall`).
> - First in-game test: **hair fully opaque** (no cut-out). Cause: the converter dropped the diffuse alpha. Fixed and installed together with the facelift rebuild (sections 8, 9); **the fixed hair is not yet checked in game.**
> - Neck ring residual 0.000 mm, Head part min y 1.557 (= vanilla HeadBottom). Checked in Blender (`converter_check` collection, hidden): no folds.
> - Not tested: helmets, blinking, fat/thin presets, removing the mod from a save.

## 1. Files

| What | Where |
|---|---|
| Blender scene (custom parts aligned on the vanilla male human head) | `D:\Pathfingder_Mods\3d\squall\both.blend` |
| Blender export (glb + textures) | `D:\Pathfingder_Mods\3d\squall\export\` (`squall_head.glb`, `ps2021_C01.png`, `ps2021_N01.png`) |
| WotR project (template copy) | `D:\Pathfingder_Mods\projects\SquallHumanWotr` |
| Mod (name `SquallHead`) | `Assets/Modifications/SquallHead/` (`SquallHead.asset`, `Scripts/SquallHead.cs`, `Scripts/Ids.cs`, `Content/`) |
| Converter | `Tools/convert_head.py` (copy of the Veron generic converter, patched, see section 4) |
| Vanilla reference dumps | `Tools/ref/head_m_hm.json`, `Tools/ref/body_m_hm.json` (`extract_ee.py` on `ee_head01_m_hm.ee`, `ee_body01_m_hm.ee`) |
| Neck ring | `Tools/ref/neck_rings.json` (copied from Veron; "vanilla" = HeadBottom ring, same mesh for Human) |
| Visual check meshes | `Tools/check_Head.obj`, `Tools/check_Hair.obj` |
| New head EE GUID | `5ea72d3a10424b70a9071883e372991a`, **never change it** |

## 2. The source scene

- Objects used = the **visible** ones: `ps2021_skin` (face shell with ears and mouth, 1061 v), `ps2021_eye` (both eyeballs, 82 v), `ps2021_hair` (4553 v, cards with alpha). `ps2021_matsu` (lashes) was hidden: **left out**.
- Vanilla reference objects in the scene (hidden): `Head_HD_Head01_M_HM`, `HeadBottom_HB_Head01Bottom_M_HM`, `Eyes_EY_Eyes_M_HM`, `Ears_EA_Ears_M_HM`, `Lashes_LS_Lashes_M_HM`. HeadBottom indices = Unity dump indices.
- The ps2021 objects carry a transform (scale 99.2, translation y -0.033): export bakes world positions.
- No vertex groups, no armature binding (4 unrelated armatures in the scene).
- Skin open loops: a clean **16-vert neck loop** (Blender z 1.546-1.606) vs vanilla HB ring (1.557-1.612), and a 24-vert scalp opening (z 1.65-1.77, covered by hair, ignored by the converter because it is above `eye_y - 0.05`).
- Eye centres: (±0.0314, 1.6917, 0.0835) vs vanilla (±0.0343, 1.6923, 0.0862): fine.
- Texture sheet `ps2021_C01` 1024x1024 (packed in the .blend, RGBA), normal `ps2021_N01` 2048x2048 (packed). Layout (glTF UV, v top-down): face + eyes in u 0-0.5, v 0-0.5; hair in u 0-0.5, v 0.5-1; **right half unused**.
- Hair alpha: ~51% of hair texels < 128. Vanilla `HH_Hair03LongCurly_M_HM_D` has 45% < 128 on the same material, so the character shader cuts hair out. The alpha must reach `Hair_D`: the first build lost it (section 8).
- Normal map curl test: GL 0.131 vs DX 0.136, slightly OpenGL: `--normal-y gl`.

## 3. Export from Blender (MCP, no change to the user's objects)

Temporary copies of the three objects, each vertex tagged with a float attribute `_vg_<PART>` (`FACE` for skin, `HAIR` for hair, `EYE_L` if Blender x > 0 else `EYE_R`: Blender +x = Unity -x = character's left), then:

```python
bpy.ops.export_scene.gltf(filepath=OUT + "/squall_head.glb", use_selection=True, export_format="GLB",
    export_attributes=True, export_skins=False, export_animations=False, export_morph=False,
    export_apply=False, export_image_format="NONE")
```
Copies deleted afterwards. Packed images saved with `im.copy()` + `filepath_raw` + `save()`.

**Why explicit part groups**: the hair (4553 v) is bigger than the face, so shape classification ("largest piece = face") would call the hair the face.

## 4. Converter changes (vs Veron `convert_head.py`)

1. `--ref m_hm` (default): reads `ref/head_<ref>.json` / `body_<ref>.json` (Human male instead of Dhampir). Pitfall hit: `TOOLS / "ref/head_%s.json" % REF` fails (operator precedence), parenthesise the string.
2. `--hair-rigid`: hair weights = `Head_ADJ` 1.0 and hair is **excluded from the body push-out** (user request: keep the hair as modelled, fully on the head main bone).
3. **Per-vertex part group wins** in `classify`: skin and hair share positions where they touch, so the position weld merged them into one connected piece and the hair majority swallowed the face ("no face piece found"). Now a vertex with its own part group (> 0.5) keeps it.
4. **Head texture crop**: the Head rect gets only the sheet area used by face + eyes (`head_box`, like the hair crop) instead of the whole sheet (≈2x resolution here). Eye mask box is mapped into the crop.
5. Head diffuse made **opaque** (alpha 255): alpha in `_D` is coverage over lower layers.
6. **Diffuse read as RGBA** (was `.convert("RGB")`, which made every `_D` opaque): the hair crop keeps the sheet's alpha for the cut-out. Added after the first in-game test (section 8).

`Assets/Editor/BuildMod.cs` (project copy) also differs from Veron's: `alphaIsTransparency = true` on non-linear, non-icon textures (section 8).

Command:
```bash
P=/d/Pathfingder_Mods/projects/SquallHumanWotr; E=/d/Pathfingder_Mods/3d/squall/export
python -I $P/Tools/convert_head.py $E/squall_head.glb $E/ps2021_C01.png $E/ps2021_N01.png \
  $P/Assets/Modifications/SquallHead/Content --name SquallHead --normal-y gl --ref m_hm --hair-rigid
```

Printout (2026-11-25):
```
pieces: 28 (28 by vertex group), vertex kinds {eye_L 41, eye_R 41, face 1073, hair 4553}
neck ring: lowest open loop of the face, 16 verts, mean y 1.578
neck fit: 35 verts with a HeadBottom target, 99 moved, radial shift -3.0 .. 23.8 mm
neck ring snap: 17 ring verts (16 positions), 42 verts moved, ring move max 27.1 mm, residual 0.000 mm
push-out: 2 verts, max 0.2 mm
part Head verts 1155 tris 1610 min [-0.089 1.557 -0.076] max [0.089 1.768 0.13] uv u 0.002-0.333 v 0.796-0.999
part Hair verts 4553 tris 3834 min [-0.129 1.578 -0.102] max [0.129 1.824 0.145] uv u 0.715-0.999 v 0.518-0.766
bones Head_ADJ .. Pelvis + L_eye, Neck_ADJ, R_eye
L_eyelish_top mean x -0.0268 (negative OK), lids from vanilla transfer
sheet 1024x1024, head crop (1,3,511,506), hair crop (0,510,514,1024)
```

## 5. Neck alignment

Done automatically by the converter (see [[Neck Edge Alignment - Source to Target Mesh]]): lowest open face loop found -> `fit_neck` (radial fit of the neck wall onto vanilla HeadBottom) -> `snap_neck_ring` (arc-length match onto the 16-position vanilla ring, harmonic spread within 35 mm) -> ring verts get the vanilla ring weights (Neck_ADJ ~0.9-1.0) and are excluded from push-out.

Visual check: `.bytes` parts read back to OBJ (Unity -> Blender: (-x, -z, y), winding flipped), loaded in collection `converter_check`; object colours, compared with the vanilla HB and with the original `ps2021_skin`. The ledge at the back of the neck is in the **original** mesh (covered by hair), not created by the converter.

## 6. Runtime (`SquallHead.cs`)

Copy of `VeronHead.cs` with:
- Donor `EE_Head01_M_HM` = `4eea3ef5f2e01474ba5b03fe28324ad3`, EE name `EE_Head_Squall_M_HM`.
- Face list: `Heads` getter postfix, list must start with the donor **and** be `ReferenceEquals(HumanRace.MaleOptions, __instance)`. The Human male list is shared with HumanThin/Sarcorian/Android/Succubus/AscendingSuccubus; the instance check keeps the face Human-only.
- **HumanRace AssetId is `0a5d473ead98b0646b94495af250fdc4`** (read from `blueprints.zip` `Races/HumanRace.jbp`, 12 male heads). The [[Custom Race Head - Creation Guide]] used to say `d1d114f5...` (wrong); corrected there on 2026-11-25.
- Removed parts `HeadBottom | Ears | Lashes | Eyes`; `HideBodyParts |= Hair | Brows`; `Layer = 51`; `MergeOverlays` prefix dropping foreign Head overlays (same as Veron section 8).
- Hair = separate `Hair` BodyPart on a donor renderer clone, donor head material.

## 7. Build and install

```bash
source ~/wotr_env.sh || exit 1; P=/d/Pathfingder_Mods/projects/SquallHumanWotr; cd $P
"$WOTR_UNITY" -batchmode -nographics -quit -projectPath "$(pwd -W)" -executeMethod BuildMod.Import -modName SquallHead -logFile import.log
python -I Tools/make_ids.py Assets/Modifications/SquallHead      # namespace patched to SquallHeadMod
"$WOTR_UNITY" -batchmode -nographics -projectPath "$(pwd -W)" -executeMethod BuildMod.Build -modName SquallHead -logFile build.log
/usr/bin/grep -F -e BUILDMOD -e "error CS" build.log
# game closed (tasklist | grep -i wrath): copy Build/Mods/SquallHead/SquallHead -> $WOTR_MODS/SquallHead, enable
```
Project setup: template copy (`Assets Packages ProjectSettings Library`, 1.2 GB, run in background), `UlrikaMod` deleted, `BuildMod.cs` from VeronDhampirWotr, placeholder `Ids.cs` before the first import.

Expected log (`grep -n -F "[SquallHead]" "$WOTR_MODS/../GameLogFull.txt"`):
```
Head mesh verts=1155 min=(-0.089, 1.557, -0.076) max=(0.089, 1.768, 0.130) bones=14
Hair mesh verts=4553 min=(-0.129, 1.578, -0.102) max=(0.129, 1.824, 0.145) bones=14
EE_Head_Squall_M_HM Layer=51 Hide=Brows, Hair
added to Human male face list, count=...
```
The placeholder `CustomHead` mod is still enabled and also appends a face to the Human male list: Squall should be **Face 13** (Face 12 without CustomHead).

## 8. Fix: hair without transparency (2026-11-25)

Symptom in game: hair cards fully opaque (no cut-out).

- **Not the material.** WotR merges all parts into one mesh with ONE atlas material (`Character.UpdateCharacter`: `new Material(first overlay part's Material)`; per-part materials are otherwise ignored). Vanilla body, head and hair (`ee_body01_m_hm`, `ee_head01_m_hm`, `ee_hair03longcurly_m_hm`) all use `Character_Diffuse_Cutout`: `_ALPHATEST_ON`, `CUTOUT_ON`, `_Cutoff 0.3`, `_CullMode 0` (double-sided), queue 2450, `TransparentCutout`: **identical** to the RT `PsylockeMod/Content/Character_Diffuse_Cutout.mat`.
- The atlas keeps diffuse alpha (`CharacterAtlas`: cleared to alpha 0, parts blended in, DXT5).
- **Cause: the converter dropped the alpha.** `convert_head.py` opened the diffuse with `.convert("RGB")`, so `SquallHead_Hair_D.png` had alpha 255 everywhere (source sheet: hair texels ~51% < 128; Psylocke `psylocke_hair_d.tga`: 54% < 0.3). Veron's hair was solid, so it never showed.
- Fix: diffuse opened as RGBA (Head_D is still forced opaque); new Hair_D: 35.5% of texels below 0.3. `BuildMod.Import` now sets `alphaIsTransparency = true` on non-linear, non-icon textures (Psylocke's hair meta has it: dilates colour into cut texels, no dark fringes). Mesh `.bytes` unchanged (same md5).
- Rebuilt OK, but the game was running: **not installed then**. The fix went in with the facelift install (section 9).
- Check after any rebuild: `SquallHead_Hair_D.png` must have alpha below 77 (0.3) on ~35% of texels; `SquallHead_Head_D.png` must be 100% alpha 255.

## 9. Regenerate after editing in Blender (2026-11-25, `both_facelift.blend`)

User re-sculpted the face and darkened the hair in `D:\Pathfingder_Mods\3d\squall\both_facelift.blend` (hair colour baked into the packed `ps2021_C01`; `ps2021_C01_orig` kept in the file). Steps:
1. Move the old export aside (`export` -> `export_prev`), re-export exactly as in section 3 (same three visible objects, same part attributes).
2. Diff vs the previous export: 5709 verts (was 5708, glTF split), face edit = 236 verts around eyes/brows (y 1.668-1.739), max 6.1 mm; hair and eyes unchanged; sheet changes only in the hair quadrant (mean RGB 74,39,14 -> 55,32,16), alpha identical.
3. Same converter command (section 4). Neck ring residual 0.000 mm, Head min y 1.557, Head 1156 v.
4. Build, back up the installed mod (`SquallHead_backups/installed_before_facelift`), reinstall. Old Content in `SquallHead_backups/content_before_facelift`.

This install is also the first one with the hair-alpha fix (section 8).

**Second facelift (2026-11-25, same .blend, unsaved edits exported live):** face texture edited (backups `ps2021_C01_precrease`, `ps2021_C01_prestubble` packed in the .blend) and face re-sculpted. Exports are now versioned: `export_v1` (original), `export_v2` (first facelift), `export` (current). Diff vs v2: 5711 verts; 120 face verts moved (nose bridge / inner brows, y 1.676-1.714), max 3.5 mm; hair and eyes unchanged; `C01` changed on 6% of texels, all inside the face quadrant; N01 and alpha unchanged. Converter output identical at the neck (residual 0.000 mm, min y 1.557), Head 1158 v; Hair_D alpha < 0.3 on 35.5%, Head_D opaque. Built and installed; backups `SquallHead_backups/content_before_facelift2` and `installed_before_facelift2`.

**Hair texture edit (2026-11-26):** hair strands repainted in `ps2021_C01` (backup `ps2021_C01_prestrands` packed in the .blend). Previous export kept as `export_v3`. Diff: mesh and UVs identical, only the hair quadrant changed (7.2% of its texels, colour only, mean RGB 55,32,16 -> 53,31,16), alpha and N01 unchanged. After conversion only `SquallHead_Hair_D.png` changed (`.bytes` and `Head_D` byte-identical); Hair_D alpha < 0.3 still 35.5%. Built and installed; backups `content_before_hairtex`, `installed_before_hairtex`.

## 10. Open points

- Check in game: neck seam (sides, head turn), hair cut-out, face texture, skin tone match at the neck (no ramp on the face; pick a matching CC skin tone).
- Blinking: lids use vanilla lid bones, eye centres ~3 mm off.
- Hair is rigid on `Head_ADJ`: long strands at the back do not follow the neck.
- Helmets, fat/thin presets, save safety on removal: untested.
- Lashes (`ps2021_matsu`) not included; add as another FACE-tagged object if wanted.
