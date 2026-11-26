---
title: Custom Head from External Model - Dhampir Male Guide
game: "Pathfinder: Wrath of the Righteous"
game_version: 2.7
unity_version: 2020.3.48f1
created: 2026-11-23
tags:
  - pathfinder-wotr
  - modding
  - equipment-entity
  - character-creation
  - dhampir
---

# Custom Head from External Model - Dhampir Male Guide

How a head from **another game (XPS model "Veron")** was turned into a brand-new **Dhampir male** face option in character creation (CC). Builds on [[Custom Race Head - Creation Guide]] (face list patch), [[Rogue Trader Head to WotR - Porting Guide]] (runtime mesh from `.bytes`, MFH3 format, donor renderer clone) and [[Custom EquipmentEntity - Creation Guide]] (environment, template, build, atlas rects).

> [!info] Status (2026-11-23)
> - **Works in game**: "Face 7" for Dhampir male shows Veron's face, eyes, teeth and hair with the **bald** haircut.
> - **Hair texture smeared over the face with any other haircut**. Cause found (section 8). Fix (Layer 51 + overlay filter) **built but not yet installed/tested**: the first in-game test still ran the Layer 0 build (log: `EE_Head_Veron_M_DH Layer=0`).
> - 2026-11-24: neck edge snapped onto the vanilla HeadBottom ring (section 5, "Neck ring snap"), built and installed, **not yet checked in game**.
> - 2026-11-24 23:48: rebuilt from `aligned_more_chiseled.glb` (Blender glb export of the whole scene: Veron mesh skinned on 4 XPS armatures + vanilla meshes). Only the Veron mesh was re-exported headless: `"$WOTR_BLENDER" -b --python exp.py` (factory scene, import glb, select `24_Veron-Head_1_16_16.001`, `blender_export_head.main(out=...)`) -> `veron_more_chiseled_export.glb`, then `Tools/convert_head.py` (generic converter). Neck ring snap residual 0.000 mm, Head min y 1.557. Installed, **not yet checked in game**. Backups in `D:\Pathfingder_Mods\VeronHead_backups` (never inside `Assets/`, Unity would bundle them).
> - Not tested: helmets, armor, fat/thin presets, blinking, removing the mod from a save.

> [!warning] Hair alpha bug in this project's `Tools/convert_head.py` (found 2026-11-25)
> It opens the diffuse with `.convert("RGB")`, so every written `_D` is fully opaque. Harmless for Veron (solid hair ribbons, no alpha), but a model with **alpha hair cards** loses its cut-out. Fixed copy: `D:\Pathfingder_Mods\projects\SquallHumanWotr\Tools\convert_head.py` (RGBA, plus `--ref`, `--hair-rigid`, per-vertex part groups, Head crop). Use that one for new heads. Details: [[Custom Head from Blender Scene - Squall Human Male Guide]] section 8 and [[Custom EquipmentEntity - Creation Guide]] section 8.

## 1. Files

| What | Where |
|---|---|
| Source model (aligned in Blender on the vanilla male human head) | `D:\Pathfingder_Mods\3d\veron\aligned.glb` (+ `both.blend`) |
| Source textures (512x512, already painted by the user) | `veron_head_d.png`, `veron_head_n.png` (same folder; also embedded in the glb) |
| WotR project (template copy) | `D:\Pathfingder_Mods\projects\VeronDhampirWotr` |
| Mod (name `VeronHead`) | `Assets/Modifications/VeronHead/` (`VeronHead.asset`, `Scripts/VeronHead.cs`, `Scripts/Ids.cs`, `Content/`) |
| Vanilla reference dump | `Tools/extract_ee.py` (UnityPy) -> `Tools/ref/head_m_dh.json`, `Tools/ref/body_m_dh.json` |
| Converter | `Tools/convert_veron.py` (needs numpy + Pillow, plain Python) + `Tools/glbread.py` |
| IDs | `Tools/make_ids.py` (namespace `VeronHeadMod`) |
| New head EE GUID | `3c9e1f7a5b2d4e8f9a0b6c1d2e3f4a5b`, **never change it** |

UnityPy lives in a venv (not in the system Python): `C:\Users\fairl\AppData\Local\Temp\claude\f64846b628464693\28f72d8c-4ea0-4286-8878-1f66b284666f\scratchpad\venv\Scripts\python.exe` (scratch folder: may disappear; recreate with `python -m venv venv && venv/Scripts/pip install UnityPy`).

## 2. Dhampir specifics (vs the Human notes)

Read from `blueprints.zip` (`Races/DhampirRace.jbp`, AssetId `64e8b7d5f1ae91d45bbf1e56a3fdff01`):

- Dhampir has **its own head EEs**: male `ee_head01_m_dh.ee` = `10d1ba990b1b9994ab75793188323178` (first of 6), `ee_head02afro_m_dh`, ... `ee_head06_m_dh`. Female first head `fa221031116367e42bade4a48bfbdf81`.
- `EE_Head01_M_DH` uses **the same meshes as the human head** (`HD_Head01_M_HM`, `HB_Head01Bottom_M_HM`, `EY_Eyes_M_HM`, `EA_Ears_M_HM`, `LS_Lashes_M_HM`); only textures/ramps differ (diffuse is grey 122, tinted by the skin ramp). So a model aligned on the human male head fits the Dhampir donor.
- Body: KEE `KEE_Body_Dhampir` (`9999a4f314ec7b44d97c0895055bef12`), male EE `d697db67...` = `ee_body01_m_dh.ee`. Presets (`Dhampir_Standard_VisualPreset*`) use the **Human** skeletons.
- **Trap: the Dhampir male (and female) face list is identical to Fetchling's.** Matching on the first head GUID (the Race Head guide's method) would add the face to Fetchling too. Fix: in the `Heads` getter postfix, compare the instance:
  ```csharp
  var race = ResourcesLibrary.TryGetBlueprint<BlueprintRace>(DhampirRaceId);
  if (race == null || !ReferenceEquals(race.MaleOptions, __instance)) return;
  ```
  Looked up **at call time** (the menu uses `dollState.Race.MaleOptions`, see `CharGenAppearancePhaseVM.GetHeadsList`). Proven in game: log `added to Dhampir male face list, count=6` (the 6-head blueprint list is DLC-filtered to 5, +1).
- Shared-list check for other races: dump the first head of every `Races/*.jbp` (script in the Race Head guide). Groups found: Human/HumanThin/Sarcorian/Android/Succubus/AscendingSuccubus; Dhampir/Fetchling; HalfElf/Bralani; Erinyes/SuccubusIncubus; Halfling/SarcorianChild; WormThatWalks/Zombies; Ghoul/GhoulSmall.

## 3. What the source model looked like (analyse before converting)

Do this for every new model; most decisions below follow from it.

- **One skinned mesh**, 2993 verts, **47 connected components**: face shell (766 v, includes ears, mouth cavity), 2 eyeballs (91 v each), 2 teeth rows, ~40 **hair cards** (solid ribbons, no alpha).
- **Skeleton is stale**: the user moved the mesh in Blender, not the XPS armature. Inverse bind matrices put the eyes at y 1.83 while the mesh eyes are at 1.69. **XPS rest positions are useless** -> weights must be rebuilt (section 4). Only the *names* of the XPS weights are informative (eyelid, eyebrow, eyeball, hair, teeth).
- **UVs have a UDIM offset of -16** (range -16..-15). Subtract `floor(min)`.
- Texture is a single 512x512 sheet: face upside down at top, eyeball, mouth patch, hair strip (rows ~372-466), teeth at bottom left.
- Face shell stops at **y 1.567**, like the vanilla `HeadBottom` (1.557). Below that, only hair. So the **vanilla body neck can stay** (unlike Morgan Fay, see Rogue Trader guide section 8).
- Eye centres: Veron (±0.0283, 1.6906, 0.0844) vs vanilla male (±0.0343, 1.6923, 0.0823): 6 mm closer together, fine.
- Normal map: plain RGB tangent map, **DirectX convention** (green down). Measured with a curl test (below); the same test on the vanilla map says OpenGL, which validates it.

Analysis snippets used (all with `glbread.load`): node/mesh/skin listing, per-component bounds + UV centroid + dominant XPS bone, a UV-wireframe-over-texture PNG (very useful to see islands).

Curl test for normal-map convention (`n` = RGB normal as -1..1, image rows top-down):
```python
a = -nx/nz; b = ny/nz
curl = lambda a, b: np.abs(np.diff(b, axis=1)[:-1, :] - np.diff(a, axis=0)[:, :-1]).mean()
# curl(a, b) smaller -> OpenGL (Unity); curl(a, -b) smaller -> DirectX (flip G)
```
For a vanilla WotR `_N` (packed), use `nx = A`, `ny = G`.

## 4. Vanilla reference dump (`Tools/extract_ee.py`)

```bash
source ~/wotr_env.sh || exit 1
V=<venv>/Scripts/python.exe ; G=$(cygpath -m "$WOTR_GAME")
$V -I Tools/extract_ee.py "$G/Bundles" ee_head01_m_dh.ee Tools/ref/head_m_dh.json
$V -I Tools/extract_ee.py "$G/Bundles" ee_body01_m_dh.ee Tools/ref/body_m_dh.json
```
Dumps every skinned part: verts (Unity space), normals, uv, weights **by bone name**, bind poses (row-major), triangles, texture refs. Note: `EY_Eyes_M_HM` has **no bone weights** in the mesh (rigid on its single bone): handle `m_BoneWeights is None`. Texture refs are external (`m_FileID 1`): load the bundle together with `Bundles/equipment` to read them.

Male donor facts:
- Head renderer bones: `Head_ADJ, Jaw_Scale, Skull_Scale, Face_Scale, L/R_eyelish_top/bottom, L/R_eyebrow, Pelvis`. **No `Neck_ADJ`** (the female Head renderer has it; on male it is only on HeadBottom).
- Rest positions (from bind poses): Head_ADJ (0, 1.6184, -0.0363), Neck_ADJ (0, 1.5257, -0.0517), L_eye (-0.0343, 1.6923, 0.0823), eyelid bones at the eye centre.
- Male body neck `N2_NeckBase_M_Any` y 1.497-1.612, torso `TS_TorsoBase_M_Any` up to 1.555.
- Vanilla head textures: D 684x420 (grey, ramp-tinted), **N 688x420**, M 684x420 (R mean 173 on the face, A 176; eyes brighter in R).

## 5. Converter (`Tools/convert_veron.py`)

```bash
python -I Tools/convert_veron.py /d/Pathfingder_Mods/3d/veron Assets/Modifications/VeronHead/Content
```

1. **glTF -> Unity**: mirror X, flip winding; UV minus UDIM offset.
2. **Classify connected components** (union-find on triangles + welded positions) by dominant XPS bone and UV centroid: `eye_L/eye_R` (XPS eyeball bones; XPS "left" lands at -X after the mirror = WotR `L_`), `teeth` (XPS `tee_*`), `hair` (UV centroid v > 0.70 = hair strip), else `face`.
3. **Weights**
   - face/teeth: inverse-distance blend of the **4 nearest vanilla vertices** of Head + HeadBottom + Ears (`1/(d+3mm)^2`). Lid and brow bones coming from this transfer are moved to `Face_Scale` (otherwise neighbouring skin would blink). Then the **XPS semantic weights** are added: XPS eyelid upper/lower, eyebrow (per side) -> `L/R_eyelish_top/bottom`, `L/R_eyebrow`, with the XPS weight fraction.
   - eyeballs: `L_eye` / `R_eye` = 1 (not on the donor Head renderer: extra bones, pose from the Eyes mesh).
   - hair: height blend, y >= 1.60 Head_ADJ, 1.60-1.50 Head -> Neck_ADJ, 1.50-1.42 Neck -> Spine_3_ADJ.
   - top 4, normalised.
4. **Push out of the vanilla body** (N2 neck + torso triangles above y 1.38, normals = mean vertex normals): closest point on triangle; if inside or within 3 mm, push to 3 mm outside. The hair on the back sat **up to 32 mm inside the male trapezius** (model made for a slimmer body); pushing single vertices kinks the strands, so the push is spread: each vertex takes the max of Gaussian-attenuated pushes (sigma 2 cm) of same-kind vertices, 3 passes. Result: 161 -> 0.2 mm residual.
5. **Parts and atlas UVs** (rects from the EE guide, origin bottom-left, base 2048):
   - `Head` (face + eyes + teeth): whole 512 sheet into the Head rect (0, 1628, 685, 420): `u = u*685/2048`, `v = (1628 + (1-v)*420)/2048`.
   - `Hair`: the hair strip crop (pixels 80,372 - 498,466 of the sheet) into the **Hair rect** (1465, 1060, 584, 512).
6. **`.bytes` (MFH3)**: bone list = donor Head renderer bones + extras (`L_eye, Neck_ADJ, R_eye, Spine_3_ADJ`) each with its vanilla bind pose (row-major, from the json), then parts `Head` (1006 v) and `Hair` (1987 v).
7. **Textures** (PNG is fine, `BuildMod.Import` handles it):
   - `VeronHead_Head_D/N/M.png` 684x420, `VeronHead_Hair_D/N/M.png` 584x512 (Lanczos resize, non-uniform).
   - Normal: resized as vectors and renormalised, **G flipped** (DirectX -> OpenGL), packed like WotR: `R=255, G=y, B=y, A=x`. Import as Default/linear (suffix `_N`, rule from the RT guide), not NormalMap.
   - Mask: R=173, A=176 (vanilla face means), G=B=0; eyeball area R=210. Channel meaning still unknown (R looks like gloss: eyes and lips bright; A like AO).

**Re-sculpted shape (2026-11-23, `aligned_chiseled.glb`)**: the user re-sculpted the face in Blender and exported only the mesh: same index buffer and UVs as `aligned.glb`, **no skin/skeleton**, and the mesh node carries a **translation** (0, -0.137, -0.015) that must be applied (raw positions are 14 cm off; with it, 181 verts moved > 0.5 mm, max 7.4 mm). Third converter argument: `python -I Tools/convert_veron.py <veron> <Content> aligned_chiseled.glb` takes positions/normals from it and keeps `aligned.glb` for the XPS weights (classification, lids). The converter checks topology/UVs match. Asset file names are unchanged, so GUIDs/`Ids.cs` stay the same; the installed build now uses the chiseled shape (previous install backed up to `Modifications/../VeronHead_prev_backup`).

**Neck fit (`NECK_FIT = True`, `fit_neck`)**: in game, a gap showed at the neck because Veron's neck is thinner than the vanilla one: 8-15 mm on the sides and throat between his lower edge (y 1.57 front -> 1.62 back) and the jaw (~1.66), so his edge sat ~13 mm inside the top of the body neck `N2`. Fix, run after classification and **before** the weight transfer: each face vertex gets a horizontal ray from the neck axis (x 0, z -0.053 = centre of the N2 top ring) and is moved along it onto the vanilla **HeadBottom** surface (nearest hit within 25 mm, only steep vertices/triangles |ny| < 0.6). Weight: 1 below y 1.63, fading to 0 at 1.67 (jaw). In the front sector (+-40 deg) only the throat (radius < 90 mm, y < 1.605) gets a target, and the weight fades to 0 between 90 and 125 mm. Without this fade, the smoothing dragged the chin underside 15 mm forward. Vertices without a target are filled by 15 Jacobi passes over welded neighbours (target vertices stay fixed). Normals get the change of the geometric normal. Result: the lower edge lies on HeadBottom within 0-3 mm all around; chin/mouth move <= 1 mm. Diagnostics used: radial slice tables (per 15 deg, per cm of height) of HB / N2 / Veron, and open-edge radius vs HB/N2 ray hits.

**Neck ring snap (2026-11-24, `NECK_RING = True`, `snap_neck_ring`)**: runs right after `fit_neck`. The user picked in `both.blend` Veron's lower face edge (18 verts, Blender idx 2879-2941, glb-welded mesh = 2959 verts vs 2993 in the glb) and the vanilla HeadBottom bottom ring (Blender idx = Unity dump idx). Both rings are stored in **`Tools/ref/neck_rings.json`** in Unity coords (Blender world (x,y,z) -> Unity (-x, z, -y)); the converter finds the glb verts by position (< 0.2 mm, seam duplicates included).
- The vanilla ring has only **16 unique positions**: the two halves are split at x=0 (0/40 and 16/55 are pairs), and **17/56 are not on the ring** (34 mm up the back seam): excluded.
- 18 vs 16 verts: matched per side by the **same arc-length fraction** from front (x=0) to back (x=0), linear interpolation on the vanilla polyline. Moves up to 25 mm (sides: 16 mm outward, 19 mm down; Veron's edge sat higher than the vanilla one).
- The move is spread over welded face neighbours within 35 mm of the ring (Jacobi/harmonic, 300 passes, fixed 0 beyond): 65 verts moved, no triangle flipped, bottom band stretched up to 2.6x, median 0.7 mm off the HeadBottom surface.
- Ring verts get the **interpolated vanilla ring weights** (Neck_ADJ 0.9-1.0, Head_ADJ...) so the seam deforms like the body; they are **excluded from the push-out** (otherwise up to 3 mm would undo the snap).
- Result: residual 0.000 mm, Head part min y 1.557 (= vanilla HB). Visual check: the converted Head part exported as OBJ and loaded into `both.blend` (collection `converter_check`). Previous install backed up to `Modifications/../VeronHead_beforeNeckRing_backup`; `convert_veron.py.bak3` = converter before this step.

Printout checks: vertex kinds, push passes, per-part bounds and UV ranges (Head u 0-0.333 v 0.798-0.999, Hair u 0.717-0.999 v 0.525-0.760), bone weight totals, `L_eyelish_top mean x` must be negative.

## 6. Runtime (`VeronHead.cs`)

Same skeleton as `MorganFay.cs` (RT guide section 3), differences:
- Donor `EE_Head01_M_DH` (`10d1ba99...`), cloned in a `BlueprintsCache.Init` postfix, registered, then customised.
- Head part: new mesh + **one** texture description (no ramp, so the CC skin colour does not tint the face; it still tints body and neck: pick a pale tone).
- **New `Hair` BodyPart** in the same EE (mesh built on another donor-renderer clone, donor head material, hair textures). Helmets that hide Hair should hide it too (untested).
- Removed: `HeadBottom | Ears | Lashes | Eyes` (Veron has its own). `HideBodyParts |= Hair | Brows` (the appended head has no matching eyebrows anyway).
- Heads getter: Dhampir instance check (section 2).
- Fix for the smear (section 8): `ee.Layer = 51` and a prefix on `Character.MergeOverlays`.

Expected log (`grep -n -F "[VeronHead]" "$WOTR_MODS/../GameLogFull.txt"`):
```
Head mesh verts=1006 min=(-0.082, 1.567, -0.075) max=(0.082, 1.780, 0.128) bones=15 (...,L_eye,Neck_ADJ,R_eye,Spine_3_ADJ)
Hair mesh verts=1987 min=(-0.127, 1.378, -0.169) max=(0.128, 1.814, 0.109) bones=15
EE_Head_Veron_M_DH Layer=51 Hide=Brows, Hair      (Layer=0 = old build without the fix)
added to Dhampir male face list, count=6
dropped N foreign Head overlay(s)                  (only with the fix, when an overlay was filtered)
```

## 7. Procedure (repeat for another model)

```bash
source ~/wotr_env.sh || exit 1
P=/d/Pathfingder_Mods/projects/<NewProject>
# 0. project: copy $WOTR_TEMPLATE (Assets, Packages, ProjectSettings, Library), delete Assets/Modifications/UlrikaMod(.meta),
#    copy Assets/Editor/BuildMod.cs from MorganFayWotr; create Assets/Modifications/<Mod>/{Blueprints,Content,Localization,Scripts},
#    Localization/enGB.json {"strings":[]}, Scripts/<Mod>.Scripts.asmdef, <Mod>.asset (m_Script guid 99c27a98d022a8b499d4a50de5012fad),
#    and a PLACEHOLDER Scripts/Ids.cs (empty dictionary) so the first import compiles.
# 1. In Blender: align the model on the vanilla head of the target race/sex (exported/heads/*.obj from extract_head_obj.py), export glb.
# 2. Analyse the glb (section 3): components, UV offset, skeleton validity, normal convention, where the skin ends.
# 3. Reference dump of the donor head + body (section 4).
# 4. Convert (adapt classification thresholds, rect mapping, normal flip):
python -I $P/Tools/convert_veron.py <model folder> $P/Assets/Modifications/<Mod>/Content
# 5. Import, IDs, build:
cd $P && "$WOTR_UNITY" -batchmode -nographics -quit -projectPath "$(pwd -W)" -executeMethod BuildMod.Import -modName <Mod> -logFile import.log
python -I Tools/make_ids.py Assets/Modifications/<Mod>
"$WOTR_UNITY" -batchmode -nographics -projectPath "$(pwd -W)" -executeMethod BuildMod.Build -modName <Mod> -logFile build.log
grep -E "BUILDMOD|error CS" build.log
# 6. Install ONLY with the game closed (tasklist | grep -i wrath): copy Build/Mods/<Mod>/<Mod>/ to $WOTR_MODS/<Mod>/,
#    add <Mod> to EnabledModifications + ActiveModifications. Check the log, and check "Layer=" to be sure the new build runs.
```

For a new head: new mod name, new EE GUID, donor of the right race and sex, race GUID in the getter.

## 8. Atlas overlay conflict (hair texture smeared on the face)

Symptom: fine with the bald haircut, any other haircut paints pieces of texture over the face. Same family of problem as in Rogue Trader.

Code (`Character.UpdateCharacter`, decompiled): for every winning part type, the overlay list gets the winner's textures, then **the textures of every EE with a higher `Layer` that has a part of that type** (`EEHasType`), regardless of `HideBodyParts` and **even for mesh-less parts**. Lower layers are added only if the winner has `ShowLowerMaterials`. Then `MergeOverlays(m_OverlayBodyParts)` paints them into the type's atlas rect (also called later for the delayed merge).

Scan of all 3137 `ee_*.ee` bundles (UnityPy, script `scan_head_overlays.py`: EEs with parts of Head-rect types):
- **Every Dhampir male haircut except bald** = `Hair` mesh + **mesh-less `Head` texture** (hairline drawn for the vanilla face UVs), **Layer 50**. Slick/Trim are only the Head texture. ~290 haircut/beard EEs (Layer <= 50) do this.
- **294 armors at Layer 200** (chainmail coifs etc.) carry mesh-less `Head`/`HeadBottom` textures.
- `EE_SkinMythicAeon_M/F_Any`, Layer 55, mesh-less Head texture.
- Brows EEs: Brows mesh only (own rect), harmless.

Fix (built, **not yet verified**):
1. `ee.Layer = 51`: above haircuts/beards (50), below 100 (dropped by "forced naked").
2. Harmony prefix on `Character.MergeOverlays(List<BodyPart>)`: if the list contains Veron's Head part (recognised by its diffuse texture object, robust to EE copies) and no other Head part with a mesh, remove every other `Head`-type entry. If another Head mesh wins (full helmet), nothing is touched. Side effect: the Mythic Aeon skin no longer changes the face.

Other overlay sources that still apply: higher-layer EEs with a *mesh* Head part win anyway; types sharing the Head rect (`HeadBottom`, `Ears`, `Neck`, `Teeth`, `Nose`) are only painted when some EE supplies a winning mesh of that type.

> [!note] User remark
> With a normal haircut, that hair would replace the custom hair in a vanilla setup anyway; the smear is not critical. Worth finishing the test once the fixed build is installed.

## 9. Open points

- Verify the section 8 fix in game (haircut, chainmail with "show class equipment" off).
- **Warpaint / scars** in CC paint vanilla-layout textures into the Head rect: probably garbage on this face. Check their layer; the MergeOverlays filter may already drop them.
- Blinking: lids are driven by vanilla lid bones whose pivot is ~3 mm from Veron's eye centre.
- Mask channel meanings (R, A) are guesses.
- Long hair clips through armor collars and cloaks; hair follows Neck/Spine_3 only at the bottom.
- Fat/thin presets (different skeletons): untested.
- Removing the mod from a save that uses the head: untested, assume unsafe.

## 10. Game code used

- `Kingmaker.UI.MVVM._VM.CharGen.Phases.Appearance/CharGenAppearancePhaseVM.GetHeadsList`: `dollState.Race.MaleOptions.Heads`.
- `Kingmaker.Blueprints.CharGen/CustomizationOptions`: DLC-filtered `Heads` cache.
- `Kingmaker.Visual.CharacterSystem/Character.cs`: `UpdateCharacter` (lines ~1241-1394: layers, hiding, overlay list), `AddBodyParts`, `MergeOverlays`.
- Decompiled tree (from an earlier session): `C:\Users\fairl\AppData\Local\Temp\claude\f64846b628464693\04a481b2-86f8-4c8d-bf4c-68457993807c\scratchpad\dec` (scratch folder: may disappear; see Race Head guide section 6 to regenerate).
