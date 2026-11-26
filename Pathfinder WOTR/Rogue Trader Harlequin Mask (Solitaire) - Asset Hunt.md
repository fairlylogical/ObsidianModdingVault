---
title: Rogue Trader Harlequin Mask (Solitaire) - Asset Hunt
game: Pathfinder: Wrath of the Righteous
source_game: Warhammer 40,000 Rogue Trader
created: 2026-11-26
tags:
  - pathfinder-wotr
  - rogue-trader
  - modding
  - equipment-entity
---

# Rogue Trader Harlequin Mask (Solitaire) - Asset Hunt

How the horned harlequin mask of the RT companion **Solitaire** (internal name **Zanni**) was found in the RT bundles and extracted, and how it fits the WotR male elf head. Follows [[Rogue Trader Head to WotR - Porting Guide]], [[Custom EquipmentEntity - Creation Guide]], [[Custom Head from External Model - Dhampir Male Guide]].

> [!info] Status (2026-11-26)
> - Mask (white face plate + gold frame + 2 horns) **extracted** and checked visually in Blender (headless renders).
> - Placed on the WotR rig with the bone-delta method: fits, but the WotR elf nose pokes through (up to ~19 mm), see section 6.
> - Not ported yet. Plan: WotR equipment item, part type chosen so it does not fight the Rogue outfit hood (section 7).

## 1. The key lesson: Harlequin looks are NOT equipment entities

- Every Zanni / Solitaire unit (`HarlequinZanni_Companion`, `HarlequinZanni`, `ZanniIncognito`, `Zanni_GrandSpectacle`, `Quetza_HarlequinZanni`...) uses the **same unit prefab** `0ba028b076e7a214c882f0cd6dcecee4.unit` (root `DrukhariSolitaire`, `UMA_Male_Rig`).
- Its `Character` component has `m_SavedEquipmentEntities` = 6 **placeholder** Drukhari EEs (`EE_Body01_M_EL`, `EE_Head01_1a_M_EL`, `EE_HelmetDrukhariKabaliteArmor3_M_EL`, backpack, accessory, `EE_DrukhariKabaliteArmor2_M_EL`). **The same 6 are on every Crown World Harlequin prefab.** Following them leads to a Drukhari Kabalite crest helmet: **wrong asset** (first attempt).
- The real look is a **baked single SkinnedMeshRenderer** in the prefab: GameObject `DrukhariSolitare`, mesh `DrukhariSolitare` (7005 v, 67 bones, 1 submesh), stored in the `equipment` bundle. Material `DrukhariSolitaire_character_d` lives in a dependency bundle (`5ba501fa26570df4297ba8e578eac823.unit`); textures `DrukhariSolitaire_d/_n/_m`, 1024x1024.
- Other Harlequins work the same way: SMR `Harlequin` (CrownWorldHarlequin, prefab `6a0b9344...`), `DrukhariTroupeMaster` (`b6d7ac45...`).
- Scanning all ~2000 EEs of `equipment` by EE name and part mesh name for harlequin/solitaire/horn finds nothing: **search the unit prefab's SkinnedMeshRenderers instead**.
- The template's blueprints predate the DLC: the game pack `Bundles/blueprints-pack.bbp` has `Solitaire_DLC3` and `DLC3_Companion`; `HarlequinZanni_Companion` (AssetId `ea3a40db...`) is the Solitaire companion (portrait `Solitair.jbp` `161e1dbd...`). The bbp contains GUIDs and names as ASCII: `LC_ALL=C /usr/bin/grep -a -b -o <guid> blueprints-pack.bbp` then `dd` around the offset.

## 2. RT bundle facts

- RT install: `D:\Games\Steam\steamapps\common\Warhammer 40,000 Rogue Trader`. `Bundles/locationlist.json` (`m_Guids`/`m_Bundles`), `Bundles/dependencylist.json` (`BundleToDependencies[<bundle>]`).
- **All RT EEs are in one bundle `equipment`** (~800 MB). Its `AssetBundle.m_Container` keys are the **EE GUIDs** -> PathID.
- RT `BodyPartType` values differ from WotR (RT Head = 0x80, HeadBottom 0x10000000, Ears 0x8000000, Eyes 0x8, Lashes 0x2000000, Helmet 0x100). Translate by mesh prefix (HD_, HB_, EA_, EY_, LS_, HH_...).
- RT EE field is `m_HideBodyParts` (WotR: `HideBodyParts`).
- UnityPy 1.25: load the unit bundle **together with all its dependencies** or PPtr deref fails (`File cab-... not found`).

## 3. Skeleton comparison (bind poses)

| bone | RT Eldar male | WotR elf male | WotR human male |
|---|---|---|---|
| Pelvis | (0, 1.119, 0) | (0, 0.959, 0) | same as elf |
| Neck_ADJ | (0, 1.709, -0.052) | (0, 1.526, -0.052) | same |
| Head_ADJ | (0, 1.819, -0.033) | (0, 1.618, -0.036) | same |
| L_eye | (-0.034, 1.884, 0.062) | (-0.034, 1.692, 0.082) | same |
| Face_Scale | (0, 1.874, 0.040) | (0, 1.682, 0.065) | same |

- **WotR elf male and human male skeletons are identical.** Elf vs human does not matter for fitting.
- RT Eldar: same bone names, ~16-20 cm taller; at the head +201 mm, and face bones ~2 cm further back relative to `Head_ADJ`.
- Head width: RT Eldar 140 mm, WotR elf 131, WotR human 160. RT and WotR elf faces look clearly different (RT longer and narrower, small swept ears; WotR rounder, tall ears).
- RT male elf head texture layout is nearly identical to WotR's (688x420 vs 684x420): RT heads were derived from WotR's.

## 4. The mask pieces (in `DrukhariSolitare`)

Split by **triangle connectivity only** (a position weld merges the mask into the body). Head-weighted pieces, each a mirrored L/R pair:

| piece | verts | UV (u, v) | bones |
|---|---|---|---|
| horns | 2 x 86 | 0.30-0.40, 0.00-0.14 | Head_ADJ 1.0 |
| white face plate | 2 x 199 | 0.06-0.13, 0.03-0.13 | Head_ADJ + eyelid/brow bones (mask animates with the face) |
| gold frame | 2 x 107 | 0.05-0.13, 0.00-0.17 | Head_ADJ (+ tiny Neck_ADJ) |
| hood | 2 x 58 + 2 x 128 | 0.21-0.41, 0.35-0.98 | Head_ADJ, Spine_3_ADJ, Neck_ADJ |

Mask = horns + plate + frame = **784 v, 1244 tris**, bones `Face_Scale, Head_ADJ, L/R_eye, L/R_eye_end, L/R_eyebrow, L/R_eyelish_top/bottom, Neck_ADJ, Spine_3_ADJ`. `*_eye_end` do not exist on WotR's renderers: map to `L/R_eye`.

## 5. Files and tools

| What | Where |
|---|---|
| Tools | `D:\Pathfingder_Mods\3d\solitaire\tools\` |
| RT EE extractor (by GUID, json + obj + png) | `extract_rt_ee.py <RT Bundles> <out> <guid>...` |
| RT unit prefab SMR extractor (loads dependencies) | `extract_rt_unit_smr.py <RT Bundles> <unit guid> <out>` |
| Connected pieces (triangle-only) | `components2.py <mesh.json> <out components.json>` |
| Subset to json/obj | `subset_obj.py <mesh.json> <components.json> <out base> <ids,comma>` |
| Move onto WotR rig (bone deltas) | `mask_to_wotr.py` |
| Skeleton comparison | `compare_skel.py` |
| Renders (headless Blender, emission shading) | `render_sol.py`, `render_mask.py`, `render_mask_wotr.py` -> `..\preview\` |
| Full Solitaire mesh + textures | `D:\Pathfingder_Mods\3d\solitaire\rt_solitaire\DrukhariSolitare.{json,obj}`, `DrukhariSolitaire_{d,n,m}.png` |
| Mask only | `rt_solitaire\ZanniMask.{json,obj}`, on WotR rig `ZanniMask_wotr.obj` |
| WotR elf male reference | `wotr_ref\head01_m_el.json`, `body01_m_el.json`, `obj_el\` |
| Wrong-asset extraction (Kabalite crest helmet, kept for reference) | `rt_extract\` |

UnityPy venv: session scratchpad (recreate: `python -m venv venv && venv/Scripts/pip install UnityPy numpy Pillow`).

Pitfalls hit:
- `extract_ee.py`-style "dump every `_D` Texture2D" on WotR `ee_*.ee` + `equipment` dumps the **whole shared texture bundle**: load textures by the PathIDs referenced by the parts.
- Blender MCP was not connected: headless `"$WOTR_BLENDER" -b --factory-startup --python <script>` works. OBJ written in Blender space (Unity (x,y,z) -> (-x,-z,y), winding flipped): import with `forward_axis="Y", up_axis="Z"`.
- Principled + strong lights washed textures out to white: use **Emission** shading with `view_transform = "Standard"` to judge textures.
- In Git Bash through the rtk hook, `grep` alternations fail: use `/usr/bin/grep -E`.

## 6. Fit on the WotR elf male head

Method: `v += sum_b w_b (P_wotr(b) - P_rt(b))` (same as the MorganFay converter). Result bounds y 1.545-1.915.
- Placement right overall (`preview\mask_on_wotr_*.png`).
- **WotR nose pokes through** the face plate: up to ~19 mm (Head part). Needs a push-out of the mask (or of the face), like the converters' push-out.
- Ears behind the frame (worst 2.7 mm): hide Ears, or accept.

## 7. Next: port as a WotR item

See the slot decision in [[Rogue Trader Harlequin Mask (Solitaire) - Asset Hunt#8. Slot decision]] (filled in once checked). Plan: runtime clone of a vanilla EE, mask mesh from `.bytes` (MFH3) built on a donor renderer clone, mask textures cropped from the 1024 sheet into the part's atlas rect.

## 8. Slot decision

The mask is meant to be worn with the **WotR Rogue class outfit**, which has a hood. Checked 2026-11-26 (`tools\wotr_ee_info.py`, loads the EE bundle together with `equipment`):

- `Classes/Rogue/RogueClass.jbp`: `m_EquipmentEntities` = `KEE_Helmet_RogueClassHat` (`b6909b05...`, race dependent; elf male `ee_rogueclasshat_m_el.ee` `f7a1ddc9...`, human male `ee_rogueclasshat_m_hm.ee` `19f86105...`) + `KEE_CapeRogue` (`21d733c2...`, outfit part on Spine_3). Body: `ee_rogue_m_any.ee` + `ee_rogueaccessories_m_any.ee`.
- **The hood is a `Helmet` (0x1000) mesh part, Layer 100, `HideBodyParts` = Hair | Ears (0x840000000), ShowLowerMaterials 1.** A helmet-type mask would therefore replace the hood (an item helmet at Layer ~200 wins the Helmet type).
- Rogue outfit part types (`EE_Rogue_M_Any`, Layer 100): Skirt, UpperLegs, LowerLegs, Feet, Hands, Forearms, Belt, UpperArms, DownArms, Torso, NeckTorso, BeltBag, Spaulders, ThighBag. Accessories (Layer 300): Torso. **No Mask / MaskBottom.**
- **Beards** (CC `MaleOptions.Beards`, e.g. `ee_beard04oldmanlong_m_hm.ee`): part type **`MaskBottom` (0x20000)**, Layer 50, sometimes plus a mesh-less `Head` texture (stubble). The hood does not hide MaskBottom.
- Decision: put the harlequin mask on **`MaskBottom`** ("beard slot"), so it stacks with the Rogue hood. Atlas rect MaskBottom = (1690, 0, 358, 318): the mask texture crop (plate+frame u 0.05-0.13, horns u 0.30-0.40, v 0-0.17 of the 1024 sheet) is ~358x174 px, it fits at 1:1.
- Caveats: the Elf race has **no `Beards` list** in CC (`Races/ElvenRace.jbp` MaleOptions has only m_Heads, m_Eyebrows, m_Hair), so the option must be added (getter/field patch like the Heads one in [[Custom Race Head - Creation Guide]]). MaskBottom is not one of the "show helmet" types (Helmet, Mask, HeadBand), so it is always shown. A beard chosen in CC would be replaced by the mask (same type).
