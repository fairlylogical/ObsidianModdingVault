---
title: Rogue Trader Head to WotR - Porting Guide
game: "Pathfinder: Wrath of the Righteous"
game_version: 2.7
unity_version: 2020.3.48f1
created: 2026-11-23
tags:
  - pathfinder-wotr
  - rogue-trader
  - modding
  - equipment-entity
  - character-creation
---

# Rogue Trader Head to WotR - Porting Guide

How to port a custom **Rogue Trader head** (a mod that adds a face option in character creation) to Pathfinder WotR. It was worked out on the user's RT `MorganFayMod`. It builds on [[Custom Race Head - Creation Guide]] (face list patch) and [[Custom EquipmentEntity - Creation Guide]] (environment, template, build, EE cloning, atlas rects). Read those first.

> [!warning] Status (2026-11-23)
> - **Works in game**: the new face appears in CC for female humans, and the RT mesh and textures render on the WotR character. Hair is hidden, and the face does not pivot wrongly on the head bone.
> - **Unsolved: the neck.** Morgan's neck is shown but **still overlaps the vanilla female body neck** (see section 8).
> - Not tested: helmets and armor collars, other races in the shared list, removing the mod from a save.

## 1. Files

| What | Where |
|---|---|
| RT source mod | `C:\Users\fairl\source\repos\RTModifications\MorganFayMod` |
| WotR project (template copy) | `D:\Pathfingder_Mods\MorganFayWotr` |
| Mod (name `MorganFay`) | `Assets/Modifications/MorganFay/` (`MorganFay.asset`, `Scripts/MorganFay.cs`, `Scripts/Ids.cs`, `Content/`) |
| Converter | `Tools/convert_head.py` (glb + tga to `.bytes` + tga; plain Python) |
| Body neck reference | `Tools/extract_body_neck.py` produces `Tools/body_neck_ref.json` (needs UnityPy) |
| Asset IDs | `Tools/make_ids.py` writes `Scripts/Ids.cs` from the Content `.meta` GUIDs |
| Build script | `Assets/Editor/BuildMod.cs` (this mod's texture rules, see section 4) |
| New head EE GUID | `7fda053b336c5d69955034a6f95fbeec`, **never change it** (saves store it) |

## 2. What an RT head mod contains, and what carries over

RT `MorganFayMod`:
- `Content/EE_MorganFayHead.asset`: an **authored EE asset**, one BodyPart (RT `m_Type: 128`), with `RendererPrefab` = `morganfay.glb` (imported by a glTF ScriptedImporter), material `Character_Diffuse_Cutout`, and textures `head_d/n/m.tga`. `head_orange.tga` is unused.
- `Blueprints/HumanRace.jbp_patch`: `FemaleOptions.Heads` gets `InsertLast` of the EE.
- `Blueprints/CharGenRoot.jbp_patch` (`FemaleDontUnequip`), `Biomancy_IronArm_Buff.jbp_patch`, and a Harmony patch on `PartUnitViewSettings.Instantiate`: **RT only, dropped**.

In WotR:

| RT | WotR |
|---|---|
| Authored EE asset | **Hollow** in the WotR template (Assembly-CSharp MonoScripts do not bind). Clone the vanilla `EE_Head01_F_HM` (`971d4ec9ff97af447b415c8eb4c5b0b5`) at runtime and register it under a new GUID |
| `.jbp_patch` on HumanRace | Harmony postfix on the `CustomizationOptions.Heads` getter (DLC-filtered cache, see the Race Head guide) |
| `.glb` model | No glTF importer in the template (Unity 2020.3, no package). Convert to a `.bytes` TextAsset and build the Mesh at runtime |
| tga textures | Copy them, but import the normal map differently and convert the mask (section 4) |

## 3. Rig and mesh: RT and WotR are nearly identical

Measured on `morganfay.glb` (exported from Blender, root nodes `Global` > `UMA_Male_Rig.007` > `HB_Head01Bottom_F_HM` > mesh `00head`. It was evidently derived from WotR's own head asset):
- **Same bone names** as WotR: `Pelvis, Spine_1..3, Neck, Head, Head_ADJ, Jaw_Scale, Skull_Scale, Face_Scale, L/R_eye, L/R_eyebrow, L/R_eyelish_top/bottom, Neck_ADJ, Spine_3_ADJ, R_Clavicle_ADJ`... (plus `Head_helmet_ADJ`, `Position`, unweighted).
- **Rest positions match within ~1 cm** (inverse bind matrices vs WotR bind poses): Pelvis 0.9595, Neck_ADJ (0, 1.4382, -0.0447), and Head_ADJ (0, 1.5167, -0.0316) are identical. The face is slightly bigger and further forward in RT (eyes at z 0.067 vs 0.056, y 1.586 vs 1.582).
- **glTF to Unity**: mirror X and flip the triangle winding. glTF `L_*` is at +X, Unity/WotR `L_*` at -X (character's left = -X). UV: `v_unity = 1 - v_gltf`.
- **UVs already sit in WotR's Head atlas rect** (0, 1628, 685, 420 of 2048): u 0-0.334, v 0.795-1.0. No UV work is needed.
- One mesh: 3642 verts, 4866 tris. It holds **face, ears, lashes, eyelids, hair (to y 1.80, z -0.17 at the back) and a neck down to y 1.356**. Eyeballs are not included (RT eyes are separate).
- Weighted bones: Head_ADJ, Skull/Jaw_Scale, Neck_ADJ, eyelash/eyebrow bones, a few L/R_eye verts, Spine_3_ADJ (102), R_Clavicle_ADJ (53).

Vanilla WotR female human head `EE_Head01_F_HM` (Layer 0): parts `Head` (HD_Head01_F_HM, 717 v, y ~1.50-1.69), `HeadBottom` (HB_Head01Bottom_F_HM, 170 v, y 1.46-1.58), `Eyes` (64), `Ears`, `Lashes`. The Head renderer's bones are `Head_ADJ, Jaw_Scale, Skull_Scale, Face_Scale, L/R_eyelish_top/bottom, L/R_eyebrow, Neck_ADJ, Pelvis` (root Pelvis). Eyes use `L_eye, R_eye`.

### Converter (`Tools/convert_head.py`)
1. Reads the glb (positions, normals, UV0, JOINTS_0/WEIGHTS_0, inverse bind matrices).
2. Moves each vertex by the weighted difference between the WotR and RT rest positions of its bones (`v += Σ w_b (P_wotr(b) - P_rt(b))`), so eyelids and face land on the WotR eye and face bones and fit the vanilla eyeballs.
3. Remaps `L/R_eye` to `L/R_eyelish_top` (not on the donor Head renderer).
4. Neck reweighting and split (section 8).
5. Writes `MorganFay_Head.bytes`, format **MFH3**: bone names (+ a row-major bind pose for bones the donor lacks), then named parts (`Head`, `NeckTorso`), each with verts, normals, uv, 4 bone indices + 4 weights, and triangles.
6. Copies `head_d/n.tga` and converts `head_m.tga`.

Its printout checks: UV range vs the Head rect, the L_eyelish_top verts' mean x must be **negative**, and the neck weights per height band.

### Runtime (`MorganFay.cs`)
- `BlueprintsCache.Init` postfix: `Instantiate(donor EE)`, `Register` in `ResourcesLibrary.s_LoadedResources` (HandleCounter 1), then customize.
- Each mesh part is built **on a clone of the donor Head RendererPrefab**: instantiate it, disable its renderers (keep the object active), and replace `smr.sharedMesh`. Bind poses come from the donor mesh, so bone names and poses are WotR's. **No Blender or FBX import is needed**, which avoids handedness, scale and bind-pose problems.
- Bones not on the donor renderer (Spine_3_ADJ, L/R_Clavicle_ADJ) get a **placeholder child Transform** with that name plus the **vanilla body bind pose** (from `body_neck_ref.json`, written into the .bytes). `Character.EnsureBones` matches bones **by name** and takes bind poses from the part's mesh. Verified sound: inverting those poses gives Spine_3_ADJ (0, 1.2239, -0.0055), Clavicles (±0.0336, 1.3815, -0.0186), the same as the RT rig.
- Head part textures are replaced by **one** new `CharacterTextureDescription` (D/N/M). This drops the vanilla lips overlay, the base skin texture and `UseDefaultMask1` (the skin ramp), so the CC skin colour does not tint the face.
- Removed parts: `HeadBottom | Ears | Lashes`. `Eyes` is kept (vanilla eyeballs, eye colour ramp still works).
- `ee.HideBodyParts |= Hair | Brows`: the RT mesh has its own hair. Hair EEs and brows EEs are Layer 50. Brows would be wrong anyway: `Eyebrows[headIndex]` is out of range or mismatched for an appended head.
- `ee.OtherVariantGuid = null` (low-res variant, editor only).
- Face list: `Heads` getter postfix on lists whose first head is `971d4ec9...`. This list is **shared** by Human, HumanThin, Sarcorian, DLC5 Android, Succubus and AscendingSuccubus female.

Expected log (`grep -n -F -e "[MorganFay]" GameLogFull.txt`):
```
Head mesh verts=3542 min=(-0.120, 1.356, -0.169) max=(0.136, 1.804, 0.125) bones=15 (...,Spine_3_ADJ,L_Clavicle_ADJ,R_Clavicle_ADJ)
NeckTorso mesh verts=177 min=(-0.099, 1.364, -0.132) max=(0.094, 1.469, 0.046) bones=15
EE_Head_MorganFay_F_HM Layer=1 Hide=Brows, Hair
  Head mesh=MorganFay_Head tex=MorganFay_Head_D:684x420
  Eyes mesh=EY_Eyes_F_HM ...
  NeckTorso mesh=MorganFay_NeckTorso tex=MorganFay_Clear:780x420
added to face list, count=13
```

## 4. Textures: RT vs WotR

Measured with UnityPy on `ee_head01_f_hm` (vanilla) and the RT tga files (all 684x420, 32-bit, bottom-left origin):

| Map | WotR vanilla head | RT head | Port |
|---|---|---|---|
| Diffuse `_D` | DXT5, sRGB, 688x420 grey (tinted by skin ramp) | colored | copy; DXT5 sRGB |
| Normal `_N` | DXT5, **linear**, avg RGBA (255,124,124,127) = **already DXT5nm-packed** (R=1, G=y, A=x) | avg RGBA (239,127,127,126): **same packing** | import as **Default, linear, DXT5**. **NOT `NormalMap`**: Unity would repack R as x and break it. (The generic EE guide's `_N` to NormalMap rule is wrong for pre-packed maps) |
| Mask `_M` | DXT5, linear, avg (188, 0, 0, 148): R and A used | avg (202, 141, 0, 255): G used, A full | **converted**: R kept, G=0, B=0, A=148. RT G would probably act as another channel (emission-like?) in WotR. A=148 is the vanilla head average. A guess: verify the look |

RT imported everything as Default + sRGB (RT's shader or colour space differs). Do not copy those import settings.

`BuildMod.Import` rules in this project: `_N`, `_M`, `_S` are linear, all Default type, DXT5, no mips, max 2048, alpha from input.

## 5. Procedure (repeat for another RT head)

```bash
source ~/wotr_env.sh || exit 1
P=/d/Pathfingder_Mods/MorganFayWotr      # or a fresh template copy (delete UlrikaMod)
M=$P/Assets/Modifications/MorganFay
# 0. once: body neck reference (UnityPy in a venv)
python -I $P/Tools/extract_body_neck.py "$WOTR_GAME/Bundles" $P/Tools/body_neck_ref.json
# 1. convert
python -I $P/Tools/convert_head.py <RT mod>/Content $M/Content
# 2. import (creates .meta), then IDs
"$WOTR_UNITY" -batchmode -nographics -quit -projectPath "$(cd $P && pwd -W)" -executeMethod BuildMod.Import -modName MorganFay -logFile import.log
python -I $P/Tools/make_ids.py $M
# 3. build
"$WOTR_UNITY" -batchmode -nographics -projectPath "$(cd $P && pwd -W)" -executeMethod BuildMod.Build -modName MorganFay -logFile build.log
grep -E "BUILDMOD|error CS" $P/build.log
# 4. install (game closed!): copy Build/Mods/MorganFay/MorganFay/ to $WOTR_MODS/MorganFay/,
#    add "MorganFay" to EnabledModifications + ActiveModifications
```

For a new head: new mod name, new EE GUID, and check the RT bone list and weights (converter exits on unknown weighted bones). Check the donor's sex and race: male = `EE_Head01_M_HM` `4eea3ef5...`, and its first-head id for the getter patch.

Gotchas hit:
- The env vars do not survive between shell calls: `source ~/wotr_env.sh` in every command.
- Do not reinstall while `Wrath.exe` runs (`tasklist | grep -i wrath`).
- Bash heredocs containing C# with `'` broke under the rtk hook: write patch scripts to files.
- `grep` with `\(` or `|` patterns through the rtk hook fails. Use `/usr/bin/grep -F` or the Grep tool.
- UnityPy (1.25): SkinnedMeshRenderers are on **child** GameObjects of the EE RendererPrefab, so walk `Transform.m_Children`. Vertex and weight data come via `UnityPy.helpers.MeshHandler(mesh).process()` (`m_Vertices`, `m_BoneWeights`, `m_BoneIndices`). Bind poses are `mesh.m_BindPose[i].eRC` (row, col). EE MonoBehaviours read fine with `read_typetree()`.

## 6. Game code facts used (decompiled Assembly-CSharp)

- `Character.UpdateCharacter`: EEs ordered by `Layer` (stable LINQ `orderby`, ties keep list order). **One mesh per BodyPartType: the last (highest layer) wins**. `HideBodyParts` of all *other* EEs is OR-ed and removes those types.
- `Character.AddBodyParts` reads `bodyPart.Textures[0]`: **a part must have at least one texture** (empty list throws). A null source texture logs "Missing texture in ... body part" and skips the part.
- Overlays: the winning part's textures plus higher-layer EEs' textures of that type are painted into that **type's** atlas rect. Lower layers only paint with `ShowLowerMaterials`.
- `Character.EnsureBones`: maps part bones by **name** through the character's bone dictionary. A bone whose name is unknown **stops mapping all following bones** (`break`). Bind poses come from `bodyPart.SkinnedRenderer.sharedMesh.bindposes`. Identical poses for the same name are merged, different ones are added as a second entry.
- `EquipmentEntity.OtherVariantGuid` / `IsLowresVariant`: not used by game code.
- BodyPartType values: Brows 0x4, Eyes 0x40, Head 0x800, Lashes 0x8000, HeadBottom 0x20000000, Ears 0x40000000, Hair 0x800000000, Torso 0x2000000, NeckTorso 0x2000000000.
- Layers: body `EE_Body01_F_HM` 0, vanilla heads 0, hair 50, brows 50, armor ~200.

## 7. Neck: what was done

1. **Problem 1 (fixed): the head pivoted at the neck.** The RT neck is ~60% Neck_ADJ / 40% Head_ADJ all the way to its base (y 1.36). In WotR the vertical neck is not part of the head: vanilla head parts stop at ~1.46. The **body** carries it: `EE_Body01_F_HM` part NeckTorso `N2_NeckBase_F_Any` (89 v, y 1.399-1.503), plus Torso `TS_TorsoBase_F_Any` (282 v, y 1.028-1.442).

   Vanilla body neck weights by height:

   | y | weights |
   |---|---|
   | 1.40 | Spine_3 0.81, clavicles 0.07 each, Neck 0.06 |
   | 1.42-1.44 | Spine_3 ~0.35, Neck 0.26-0.40, clavicles 0.12-0.20 |
   | 1.46-1.50 | Neck ~0.64, Head 0.13-0.35 |

   Fix in the converter: vertices of **neck skin** get the body's weights (inverse-distance blend of the 4 nearest body verts, restricted to Neck/Head/Spine_3/Clavicles). The blend is full below y 1.44 and fades out by 1.48, full within 8 cm of the neck axis (x=0, z=-0.035) and fading out by 10 cm. Hair hanging behind (r > 9 cm, near-black in the diffuse; skin is ~RGB 95,60,58) keeps the head weights. Result: base Spine_3 0.67 / clavicles / Head 0.06, middle Neck 0.43 / Head 0.17. The user confirmed in game that the swap works.
2. **Problem 2 (partly): the vanilla neck covered hers.** Our EE had no HeadBottom. The covering mesh was the body's. Fix: triangles fully below y 1.47 and within 10 cm of the axis form a separate **NeckTorso** part (177 v, y 1.364-1.469). Border verts are duplicated with identical data. The EE is raised to **Layer 1** so it beats the body's NeckTorso (Layer 0), while clothing necks (higher layers) still replace it. The part paints a 780x420 **transparent** runtime texture (it needs one, see section 6). Its UVs sample the Head rect, which the Head part paints. Result in game: **Morgan's neck shows, but it still overlaps the vanilla female neck.**

## 8. Remaining to solve: neck overlap

> [!todo] Morgan's neck still overlaps the vanilla female human neck (2026-11-23)

Hypotheses, not verified:
- **The body Torso mesh includes the lower neck.** `TS_TorsoBase_F_Any` reaches y 1.442, and Morgan's neck goes down to 1.356, so her neck intersects the torso's neck stump (Torso cannot be hidden without hiding the whole chest). Check: render or compare Torso verts at y 1.38-1.44 against Morgan's neck radius. Possible fixes: shrink or trim Morgan's neck to start at ~1.44 (cut the converter's NeckTorso below the torso top and close the seam). Or fit her neck verts to the body's neck surface (radial projection onto the vanilla neck radius at each height), so the two coincide instead of intersecting.
- **The body NeckTorso still wins.** If the layer change did not take effect for the body EE (for example the body EE is not in `m_EquipmentEntities`, or another EE with NeckTorso exists, such as class clothing or underwear), the vanilla neck is still drawn. Check: log at runtime which EE supplies NeckTorso (Harmony postfix on `Character.UpdateCharacter`, or dump `Character.EquipmentEntities` with Layer and part types for the main character). Test with "show class equipment" off and naked.
- **The vanilla HeadBottom comes back** from another EE with a HeadBottom part (helmets or hoods can have HeadBottom overlays). Check in the same dump.
- **Size mismatch.** The vanilla neck radius is ~5-6 cm, while Morgan's skin sits at r ~5-7 cm with an RT-shaped throat, so one surface pokes through the other. The radial fit above would address it.

Suggested next step: add a debug dump of the resolved parts (`Character` dictionary after `UpdateCharacter`: type, EE name, Layer, mesh name) for the main character. That tells which neck mesh is drawn before choosing a fix.

Other open points:
- **Skin colour seam** at the neck base and shoulders: the face has no skin ramp. Options: tint the body to match, or re-enable a ramp with a proper colour mask.
- **Mask channels** (G zeroed, A=148) are a guess; compare the look with vanilla heads.
- **Helmets**: the hair is in the Head mesh, so it does not hide under helmets.
- **Shared face list**: the head also appears for HumanThin, Sarcorian, Android and Succubus female.
- **Save safety** when removing the mod: untested.
