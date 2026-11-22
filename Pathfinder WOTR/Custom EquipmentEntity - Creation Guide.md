---
title: Custom EquipmentEntity - Creation Guide
game: "Pathfinder: Wrath of the Righteous"
game_version: 2.7
unity_version: 2020.3.48f1
created: 2026-11-22
tags: [pathfinder-wotr, modding, equipment-entity]
---

# Custom EquipmentEntity - Creation Guide

Runbook for adding a **brand-new equipment item with its own EquipmentEntity (EE)** to Pathfinder WotR. It is written for a coding agent starting from zero: all code is included. Only the Owlcat modification template is needed, not Unity Mod Manager or VisualAdjustments2.

> [!important] The one thing to know
> **Do not author the EE as a Unity asset.** In this template it builds as an empty object. Ship models and textures in the bundle, and **create the EE at runtime by cloning a vanilla one** from the mod's script.

## 1. How far to trust this

| Claim | Evidence |
|---|---|
| New item + KEE + cloned EE + new torso texture works | **In game**, 2026-11-22 (proof mod "Proof Plate"; user confirmed, log shows load and item grant) |
| The three files in section 6, followed literally | **Headless**: followed on a clean template copy, built, then loaded through the game's own mod loader and real blueprint pack in Unity (41 checks, stand-in donor EEs). This generalized script has **not** been run in game |
| Custom mesh from Blender | **Headless only**: a skinned test cube exported from Blender 4.5 arrives at the right position, scale, winding, UVs and bind poses. **Never seen rendered in game**; the AssetStudio-to-Blender round trip is untested |
| Merge, atlas and equip rules (sections 8-10) | Read from decompiled `Assembly-CSharp.dll`, plus measurements on vanilla bundles |
| Slots other than body armor, race-dependent KEEs, `AddPart`, outfit parts | **Untested** |
| Removing the mod from a save that contains the item | **Untested**, assume it is unsafe |

Weapons are out of scope: their models do not go through EEs.

## 2. Environment

No path is hardcoded in this note. Set these environment variables once (Git Bash profile or Windows user variables). Every script and command checks them first and **exits immediately if one is missing or does not point to an existing file or folder**.

| Variable | Points to | Required by |
|---|---|---|
| `WOTR_GAME` | Game install folder (contains `blueprints.zip`, `Bundles`, `Wrath_Data`) | all |
| `WOTR_TEMPLATE` | Owlcat modification template project (`Assets`, `Packages`, `ProjectSettings`, `Library`) | all |
| `WOTR_UNITY` | `Unity.exe` of Unity 2020.3.48f1 | build |
| `WOTR_MODS` | The game's `Modifications` folder in `AppData\LocalLow\Owlcat Games\Pathfinder Wrath Of The Righteous` | install, log |
| `WOTR_ASSETSTUDIO` | AssetStudio folder (export vanilla meshes and textures) | custom meshes |
| `WOTR_BLENDER` | `blender.exe` | custom meshes |

Derived: game code `$WOTR_GAME/Wrath_Data/Managed/Assembly-CSharp.dll`, vanilla blueprints `$WOTR_GAME/blueprints.zip`, GUID-to-bundle index `$WOTR_GAME/Bundles/locationlist.json` (parallel arrays `m_Guids`, `m_Bundles`), log `$WOTR_MODS/../GameLogFull.txt`, mod settings `$WOTR_MODS/../OwlcatModificationManagerSettings.json`.

Preflight: `source ~/wotr_env.sh` at the start of every session (`WOTR_ASSETSTUDIO` and `WOTR_BLENDER` are only checked when you pass `mesh`). The full script, with default values to edit, is stored next to these notes as `wotr_env.sh`; copy it to `~/wotr_env.sh`. Its check logic:

```bash
# ~/wotr_env.sh (check logic only)
need() { # name, kind (f|d)
  local v="${!1}"
  if [ -z "$v" ]; then echo "FATAL: env var $1 is not set" >&2; return 1; fi
  if [ "$2" = f ] && [ ! -f "$v" ]; then echo "FATAL: $1=$v is not a file" >&2; return 1; fi
  if [ "$2" = d ] && [ ! -d "$v" ]; then echo "FATAL: $1=$v is not a folder" >&2; return 1; fi
}
need WOTR_GAME d && need WOTR_TEMPLATE d && need WOTR_UNITY f && need WOTR_MODS d || { return 1 2>/dev/null || exit 1; }
if [ "$1" = mesh ]; then need WOTR_ASSETSTUDIO d && need WOTR_BLENDER f || { return 1 2>/dev/null || exit 1; }; fi
```

`UlrikaMod` is a **Rogue Trader** project. Copies of it in WotR folders are not valid references.

## 3. Mental model

```text
BlueprintItemArmor (.jbp)            the item: name, icon, cost, armor type
  m_EquipmentEntity ---------------> KingmakerEquipmentEntity "KEE" (.jbp)
                                       male / female / per-race lists of EquipmentEntityLink (GUID strings)
                                         |
                                         v  ResourcesLibrary.TryGetResource<EquipmentEntity>(guid)
                                     EquipmentEntity (ScriptableObject, here created by script)
                                       Layer, HideBodyParts, ShowLowerMaterials, ramps
                                       BodyParts[]   type + skinned prefab + material + textures
                                       OutfitParts[] rigid prefab attached to a named bone
                                         |
                                         v
                                     Character merges all parts into ONE mesh and bakes
                                     three atlases: Diffuse, Normal, Masks
```

An EE link is only a GUID looked up in `ResourcesLibrary.s_LoadedResources`, then in bundles. Putting a runtime-created EE in that dictionary under a new GUID makes it a normal EE for the whole game.

## 4. The traps that make this non-obvious

1. **The template cannot bind scripts of `Assembly-CSharp.dll` and `Assembly-CSharp-firstpass.dll`.** Unity reserves those assembly names. Measured: 0/2626 and 0/365 MonoScripts bound, 100% for every other DLL. EE assets get `m_Script: {fileID: 0}` or lose all fields. (EbonsContentMod ships valid bundled EEs, so a workaround exists, but it is unknown and unnecessary.)
2. **Mod `.jbp` files are enabled before the vanilla blueprint pack opens.** `BlueprintItemArmor.OnEnableWithLibrary` then sees a null `Type` and silently never links visual and sound parameters. Call it again after `BlueprintsCache.Init`.
3. **`BlueprintsCache.Init` postfix is the right moment to create EEs**: bundles and vanilla blueprints are available, no character exists yet.
4. **Injected cache entries need `HandleCounter = 1`**, otherwise area cleanup unloads them.
5. **Preloading rejects GUIDs with no bundle location.** Postfix `BundlesLoadService.HasLocation`.
6. **A missing EE throws on equip.** `UnitEntityView.AddItemEquipment` dereferences the loaded EE without a null check. Register the clone first, customize afterwards.
7. **GUIDs end up in saves.** Never change an item, KEE or EE GUID after release. The generator derives them from the mod name, so do not rename the mod either.
8. **The stock build menu deletes the whole `Build` folder**, and every build deletes the mod's `Generated` folder. Never store anything there.
9. **Only top-level files of `Blueprints/` are scanned for direct references** such as icons. Do not use subfolders.
10. **A hand-written `.meta` with only a GUID imports PNGs as cubemaps.** Let Unity create metas, then read the GUIDs.

## 5. Procedure

Commands are for Git Bash. Work on a copy of the template unless told otherwise, and close Unity on that project.

```bash
source ~/wotr_env.sh || exit 1    # section 2: exits if any WOTR_* variable is missing
U="$WOTR_UNITY"
P="<path to template copy>"     # copy of $WOTR_TEMPLATE: needs Assets, Packages, ProjectSettings; copy Library/PackageCache to stay offline
[ -d "$P/Assets" ] || { echo "FATAL: $P is not a project"; exit 1; }
MOD=MyNewArmor                  # letters and digits only
```

1. **Save the three files of section 6**: `new_mod.py` anywhere, `BuildMod.cs` to `$P/Assets/Editor/`, and `CustomEquipment.cs` in step 4.
2. **Pick a vanilla item** that is closest in silhouette and weight class:
   ```bash
   python -I new_mod.py find fullplate
   ```
3. **Create the mod.** This makes the manifest, asmdef, item, KEE, localization and `Ids.cs`:
   ```bash
   python -I new_mod.py make "$P" $MOD "My New Armor" "Equipment/Armor/Items/Standard/FullplateStandard.jbp"
   ```
4. **Add the script and assets**: save `CustomEquipment.cs` to `$P/Assets/Modifications/$MOD/Scripts/`. Put textures and models directly in `.../Content/`. Use `Icon.png` for the icon, suffix `_N` for normal maps, `_M` for masks and `_S` for color masks.
5. **Import, then refresh the IDs.** Re-running `make` is safe: it keeps edited blueprints and localization, and only updates the icon reference and `Ids.cs`.
   ```bash
   "$U" -batchmode -nographics -quit -projectPath "$P" -executeMethod BuildMod.Import -modName $MOD -logFile import.log
   python -I new_mod.py make "$P" $MOD "My New Armor" "Equipment/Armor/Items/Standard/FullplateStandard.jbp"
   ```
6. **Edit `Customize()`** in `CustomEquipment.cs` (API in section 7), and stats in `Blueprints/<MOD>.jbp` if needed.
7. **Build.** The result is the folder `$P/Build/Mods/$MOD/$MOD/`, also zipped next to it.
   ```bash
   "$U" -batchmode -nographics -projectPath "$P" -executeMethod BuildMod.Build -modName $MOD -logFile build.log
   grep -E "BUILDMOD|error CS" build.log
   ```
8. **Install** (ask the user first): copy the folder `$P/Build/Mods/$MOD/$MOD/` to `$WOTR_MODS/$MOD/` (the zip has the same content, but command-line `unzip` exits with an error on its `/` entry), then add `"$MOD"` to `EnabledModifications` in `$WOTR_MODS/../OwlcatModificationManagerSettings.json`.
9. **Test on a throwaway save.** The item is granted once per save on area load. Turn off "show class equipment", equip it, test both genders, change area, save and reload.
10. **Read the log**: `grep -nE "\[EE\]|ApplyException|Failed loading blueprint|Textures must be the same size" "$WOTR_MODS/../GameLogFull.txt"`

## 6. Files

### File: new_mod.py

```python
"""Usage:
  python -I new_mod.py find <text>
  python -I new_mod.py make <project> <ModName> <display name> <vanilla item path in blueprints.zip>
"""
import copy, json, pathlib, re, sys, uuid, zipfile

import os


def need(var, kind):
    v = os.environ.get(var)
    if not v:
        sys.exit("FATAL: env var %s is not set" % var)
    p = pathlib.Path(v)
    if not (p.is_dir() if kind == "d" else p.is_file()):
        sys.exit("FATAL: %s=%s does not exist" % (var, v))
    return p


GAME = need("WOTR_GAME", "d")
if not (GAME / "blueprints.zip").is_file():
    sys.exit("FATAL: %s has no blueprints.zip" % GAME)
Z = zipfile.ZipFile(GAME / "blueprints.zip")


def read_bp(path):
    bp = json.loads(Z.read(path).decode("utf-8-sig"))
    bp.pop("Meta", None)
    return bp


def find(text):
    for n in Z.namelist():
        if text.lower() in n.lower() and n.endswith(".jbp"):
            if b'"m_EquipmentEntity": "!bp_' in Z.read(n):
                print(n)


def vanilla_kee(guid):
    names = sorted(Z.namelist(), key=lambda n: not n.startswith("EquipmentEntities/"))
    for n in names:
        if n.endswith(".jbp") and ('"AssetId": "%s"' % guid).encode() in Z.read(n)[:200]:
            return read_bp(n)
    sys.exit("KEE not found: " + guid)


def make(project, mod, display, base):
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9]*", mod):
        sys.exit("ModName: letters and digits only")
    project = pathlib.Path(project)
    root = project / "Assets/Modifications" / mod
    for d in ("Blueprints", "Content", "Localization", "Scripts"):
        (root / d).mkdir(parents=True, exist_ok=True)

    def gid(n): return uuid.uuid5(uuid.NAMESPACE_URL, mod + "/" + n).hex

    def write_once(path, text, guid=None):
        if not path.exists():
            path.write_text(text, encoding="utf-8")
            if guid:
                pathlib.Path(str(path) + ".meta").write_text("fileFormatVersion: 2\nguid: %s\n" % guid)

    item = read_bp(base)
    ref = item["Data"].get("m_EquipmentEntity")
    if not ref:
        sys.exit("This item inherits its visual from its type; choose one with its own m_EquipmentEntity")
    kee = vanilla_kee(ref[len("!bp_"):])

    # Every EE link in the KEE (both genders, all races) becomes a clone with its own ID.
    loc = json.loads((GAME / "Bundles/locationlist.json").read_text(encoding="utf-8-sig"))
    bundle = dict(zip(loc["m_Guids"], loc["m_Bundles"]))
    clones = {}

    def relink(link):
        donor = link.get("AssetId")
        if donor:
            stem = bundle.get(donor, donor).split("/")[-1].split(".")[0]
            clones[donor] = (gid("ee/" + donor), "EE_%s_%s" % (mod, stem))
            link["AssetId"] = clones[donor][0]

    new_kee = copy.deepcopy(kee)
    data = new_kee["Data"]
    for link in data.get("m_MaleArray", []) + data.get("m_FemaleArray", []):
        relink(link)
    for pair in data.get("m_RaceDependentArrays") or []:
        for link in pair["MaleArray"] + pair["FemaleArray"]:
            relink(link)
    new_kee["AssetId"] = gid("kee")
    write_once(root / "Blueprints" / ("KEE_%s.jbp" % mod), json.dumps(new_kee, indent=2), gid("kee"))

    item["AssetId"] = gid("item")
    item["Data"]["m_EquipmentEntity"] = "!bp_" + gid("kee")
    strings = []
    for field, text in (("m_DisplayNameText", display), ("m_DescriptionText", display + ".")):
        key = str(uuid.UUID(gid("text/" + field)))
        item["Data"][field] = {"m_Key": key, "m_OwnerString": "", "m_OwnerPropertyPath": "",
                               "m_JsonPath": "", "Shared": None}
        strings.append({"Key": key, "Value": text})
    write_once(root / "Localization/enGB.json", json.dumps({"strings": strings}, indent=2))
    item_path = root / "Blueprints" / (mod + ".jbp")
    write_once(item_path, json.dumps(item, indent=2), gid("item"))

    script_meta = (project / "Assets/Editor/Modification.cs.meta").read_text()
    script_guid = re.search(r"guid: (\w+)", script_meta).group(1)
    write_once(root / (mod + ".asset"), """%%YAML 1.1
%%TAG !u! tag:unity3d.com,2011:
--- !u!114 &11400000
MonoBehaviour:
  m_ObjectHideFlags: 0
  m_Script: {fileID: 11500000, guid: %s, type: 3}
  m_Name: %s
  Manifest:
    UniqueName: %s
    Version: 0.1
    DisplayName: %s
    Description: %s
    Author: ''
    Repository: ''
    HomePage: ''
    Dependencies: []
  Settings: {}
""" % (script_guid, mod, mod, json.dumps(display), json.dumps(display)))
    write_once(root / "Scripts" / (mod + ".Scripts.asmdef"),
               json.dumps({"name": mod + ".Scripts", "autoReferenced": False}, indent=2))

    # Content GUIDs exist once Unity has imported the files.
    assets = {}
    for meta in sorted((root / "Content").glob("*.meta")):
        assets[meta.name[:-5]] = re.search(r"guid: (\w+)", meta.read_text()).group(1)
    if "Icon.png" in assets:
        current = json.loads(item_path.read_text(encoding="utf-8"))
        current["Data"]["m_Icon"] = {"guid": assets["Icon.png"], "fileid": 21300000}
        item_path.write_text(json.dumps(current, indent=2), encoding="utf-8")

    q = json.dumps
    ees = "".join("            new[] { %s, %s, %s },\n" % (q(i), q(n), q(d)) for d, (i, n) in clones.items())
    files = "".join("            { %s, %s },\n" % (q(n), q(g)) for n, g in assets.items())
    (root / "Scripts/Ids.cs").write_text("""// Generated by new_mod.py, do not edit.
using System.Collections.Generic;

namespace CustomEquipmentMod
{
    internal static class Ids
    {
        public const string Item = %s;

        // { new EE id, new EE name, donor EE id }
        public static readonly string[][] EEs =
        {
%s        };

        public static readonly Dictionary<string, string> Assets = new Dictionary<string, string>
        {
%s        };
    }
}
""" % (q(gid("item")), ees, files), encoding="utf-8")

    print("item", gid("item"))
    for donor, (i, n) in clones.items():
        print("EE", i, n, "donor", donor)
    print("assets", list(assets))


if __name__ == "__main__":
    if sys.argv[1:2] == ["find"] and len(sys.argv) == 3:
        find(sys.argv[2])
    elif sys.argv[1:2] == ["make"] and len(sys.argv) == 6:
        make(*sys.argv[2:])
    else:
        sys.exit(__doc__)
```

### File: BuildMod.cs

```csharp
using System;
using System.IO;
using System.Linq;
using OwlcatModification.Editor.Build;
using UnityEditor;
using UnityEditor.Build.Pipeline;
using UnityEngine;

public static class BuildMod
{
    static string Name
    {
        get
        {
            var args = Environment.GetCommandLineArgs();
            return args[Array.IndexOf(args, "-modName") + 1];
        }
    }

    public static void Import()
    {
        AssetDatabase.Refresh();
        var folder = "Assets/Modifications/" + Name + "/Content";
        foreach (var path in AssetDatabase.FindAssets("", new[] { folder })
                                          .Select(AssetDatabase.GUIDToAssetPath).Distinct())
        {
            var name = Path.GetFileNameWithoutExtension(path);
            var importer = AssetImporter.GetAtPath(path);

            if (importer is TextureImporter t)
            {
                bool icon = name.StartsWith("Icon"), normal = name.EndsWith("_N");
                bool linear = normal || name.EndsWith("_M") || name.EndsWith("_S");
                t.textureShape = TextureImporterShape.Texture2D;
                t.textureType = icon ? TextureImporterType.Sprite
                              : normal ? TextureImporterType.NormalMap : TextureImporterType.Default;
                if (icon) t.spriteImportMode = SpriteImportMode.Single;
                t.npotScale = TextureImporterNPOTScale.None;
                t.mipmapEnabled = false;
                t.sRGBTexture = !linear;
                if (!icon) // vanilla equipment textures are all DXT5
                    t.SetPlatformTextureSettings(new TextureImporterPlatformSettings
                    {
                        name = "Standalone", overridden = true, maxTextureSize = 2048,
                        format = TextureImporterFormat.DXT5
                    });
                t.SaveAndReimport();
            }
            else if (importer is ModelImporter m)
            {
                m.isReadable = true;              // the character merger reads the mesh
                m.optimizeGameObjects = false;    // bones are matched by Transform name
                m.importAnimation = false;
                m.materialImportMode = ModelImporterMaterialImportMode.None;
                m.SaveAndReimport();
            }
        }
        Debug.Log("BUILDMOD import done");
    }

    public static void Build()
    {
        var code = ReturnCode.Exception;
        try
        {
            Import();
            var mod = Builder.Modifications.First(m => m.Manifest.UniqueName == Name);
            // own output folder: the builder deletes its target folder
            code = Builder.Build(mod.Manifest, mod.Settings, Path.GetDirectoryName(AssetDatabase.GetAssetPath(mod)),
                                 "Build/Mods/" + Name, null);
        }
        catch (Exception e) { Debug.LogException(e); }
        Debug.Log("BUILDMOD result=" + code);
        EditorApplication.Exit(code >= ReturnCode.Success ? 0 : 1);
    }
}
```

### File: CustomEquipment.cs

```csharp
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using HarmonyLib;
using Kingmaker;
using Kingmaker.Blueprints;
using Kingmaker.Blueprints.Items;
using Kingmaker.Blueprints.JsonSystem;
using Kingmaker.BundlesLoading;
using Kingmaker.EntitySystem;
using Kingmaker.Modding;
using Kingmaker.PubSubSystem;
using Kingmaker.Utility;
using Kingmaker.Visual.CharacterSystem;
using UnityEngine;

namespace CustomEquipmentMod
{
    internal static class CustomEquipment
    {
        static Kingmaker.Modding.OwlcatModification s_Mod;

        // ===== EDIT THIS =====
        // Runs once per cloned EE. Female EEs have "_f_" in ee.name, male ones "_m_".
        static void Customize(EquipmentEntity ee)
        {
            // Retexture(ee, "TS_FullplateKnight_D", "Torso_D.png", "Torso_N.png", "Torso_M.png");
            // ReplaceMesh(ee, BodyPartType.Torso, "Torso.fbx");
        }

        [OwlcatModificationEnterPoint]
        public static void Init(Kingmaker.Modding.OwlcatModification mod)
        {
            s_Mod = mod;
            new Harmony(mod.Manifest.UniqueName).PatchAll(Assembly.GetExecutingAssembly());
            EventBus.Subscribe(new GiveOncePerSave());
        }

        // ----- registration -----

        [HarmonyPatch(typeof(BlueprintsCache), nameof(BlueprintsCache.Init))]
        static class AfterVanillaBlueprints
        {
            static void Postfix()
            {
                // mod blueprints were enabled before the vanilla pack existed
                try { ResourcesLibrary.TryGetBlueprint<BlueprintItem>(Ids.Item).OnEnableWithLibrary(); }
                catch (Exception e) { Error("item init: " + e); }

                foreach (var def in Ids.EEs)
                {
                    try
                    {
                        var donor = ResourcesLibrary.TryGetResource<EquipmentEntity>(def[2], hold: true);
                        if (donor == null) { Error("donor not found: " + def[2]); continue; }
                        var ee = UnityEngine.Object.Instantiate(donor);
                        ee.name = def[1];
                        ee.hideFlags = HideFlags.DontUnloadUnusedAsset;
                        Register(def[0], ee);   // before customizing: a missing EE throws on equip
                        Dump(ee);
                        Customize(ee);
                    }
                    catch (Exception e) { Error(def[1] + ": " + e); }
                }
            }
        }

        [HarmonyPatch(typeof(BundlesLoadService), nameof(BundlesLoadService.HasLocation))]
        static class AllowPreload
        {
            static void Postfix(string __0, ref bool __result)
            {
                if (!__result) __result = Ids.EEs.Any(d => d[0] == __0);
            }
        }

        static void Register(string id, UnityEngine.Object resource)
        {
            var type = AccessTools.Inner(typeof(ResourcesLibrary), "LoadedResource");
            var entry = Activator.CreateInstance(type, new object[] { resource });
            AccessTools.Field(type, "RequestCounter").SetValue(entry, 1);
            AccessTools.Field(type, "HandleCounter").SetValue(entry, 1);
            ((IDictionary)AccessTools.Field(typeof(ResourcesLibrary), "s_LoadedResources").GetValue(null))[id] = entry;
        }

        // ----- editing API -----

        static void Retexture(EquipmentEntity ee, string donorDiffuseName, string diffuse,
                              string normal = null, string masks = null, string colorMask = null)
        {
            var d = Load<Texture2D>(diffuse);
            if (d == null) return;
            var n = Load<Texture2D>(normal);
            var m = Load<Texture2D>(masks);
            var s = Load<Texture2D>(colorMask);
            int hits = 0;
            // one texture is often shared by several parts (Torso + NeckTorso, Forearms + DownArms)
            foreach (var t in ee.BodyParts.SelectMany(p => p.Textures)
                .Where(t => t.DiffuseTexture != null && t.DiffuseTexture.name == donorDiffuseName))
            {
                t.ActiveTexture = t.DiffuseTexture = d;
                if (n != null) t.NormalTexture = n;
                if (m != null) t.MaskTexture = m;
                if (s != null) t.RampShadowTexture = s;
                else // the donor's color masks would repaint the new texture
                    t.UseRamp1Mask = t.UseRamp2Mask = t.UseDefaultMask1 = t.UseDefaultMask2 = t.UseShadowMask = false;
                foreach (var other in new[] { t.NormalTexture, t.MaskTexture })
                    if (other != null && (other.width != d.width || other.height != d.height))
                        Error(other.name + " must be " + d.width + "x" + d.height + " like " + d.name);
                hits++;
            }
            if (hits == 0) Error(ee.name + " has no texture " + donorDiffuseName);
        }

        // Moves the imported mesh into the game's mesh space and copies the donor's bind poses,
        // so that the importer's axes, scale and bone orientations do not matter.
        static bool ReplaceMesh(EquipmentEntity ee, BodyPartType type, string model)
        {
            var part = ee.BodyParts.FirstOrDefault(p => p.Type == type && p.RendererPrefab != null);
            if (part == null) { Error(ee.name + " has no meshed part " + type + ", use AddPart"); return false; }
            var go = PrepareModel(ee, model);
            if (go == null) return false;
            part.RendererPrefab = go;
            return true;
        }

        static bool AddPart(EquipmentEntity ee, BodyPartType type, string model,
                            string diffuse, string normal = null, string masks = null)
        {
            var go = PrepareModel(ee, model);
            var d = Load<Texture2D>(diffuse);
            if (go == null || d == null) return false;
            var texture = new CharacterTextureDescription
            {
                ActiveTexture = d, DiffuseTexture = d,
                NormalTexture = Load<Texture2D>(normal), MaskTexture = Load<Texture2D>(masks),
                DiffuseActive = true, NormalActive = true, MaskActive = true
            };
            ee.BodyParts.Add(new BodyPart
            {
                Type = type, RendererPrefab = go,
                Material = ee.BodyParts.First(p => p.Material != null).Material,
                Textures = new List<CharacterTextureDescription> { texture }
            });
            return true;
        }

        static void RemovePart(EquipmentEntity ee, BodyPartType type)
        {
            ee.BodyParts.RemoveAll(p => p.Type == type);
        }

        static GameObject PrepareModel(EquipmentEntity ee, string model)
        {
            var source = Load<GameObject>(model);
            if (source == null) return null;
            var src = source.GetComponentInChildren<SkinnedMeshRenderer>(true);
            var mesh = src != null ? src.sharedMesh : null;
            if (mesh == null) { Error(model + ": no skinned mesh"); return null; }
            if (!mesh.isReadable) { Error(model + ": Read/Write is off"); return null; }
            if (mesh.subMeshCount != 1) { Error(model + ": needs exactly one material/submesh"); return null; }
            if (mesh.uv.Length != mesh.vertexCount) { Error(model + ": no UV0"); return null; }

            var donorPoses = new Dictionary<string, Matrix4x4>();
            foreach (var r in ee.BodyParts.Select(p => p.SkinnedRenderer).Where(r => r != null && r.sharedMesh != null))
            {
                var poses = r.sharedMesh.bindposes;
                for (int i = 0; i < r.bones.Length && i < poses.Length; i++)
                    if (r.bones[i] != null) donorPoses[r.bones[i].name] = poses[i];
            }
            var unknown = src.bones.Where(b => b == null || !donorPoses.ContainsKey(b.name))
                                   .Select(b => b == null ? "<null>" : b.name).ToArray();
            if (src.bones.Length == 0 || unknown.Length > 0)
            {
                Error(model + ": bones missing from donor: " + string.Join(", ", unknown));
                return null;
            }

            var go = UnityEngine.Object.Instantiate(source, Vector3.zero, source.transform.rotation);
            go.name = source.name;
            if (Application.isPlaying) UnityEngine.Object.DontDestroyOnLoad(go);
            var smr = go.GetComponentInChildren<SkinnedMeshRenderer>();
            // keep the object active: BodyPart.SkinnedRenderer skips inactive children
            foreach (var r in go.GetComponentsInChildren<Renderer>(true)) r.enabled = false;

            var toModel = smr.transform.localToWorldMatrix;
            var toModelNormal = toModel.inverse.transpose;
            var copy = UnityEngine.Object.Instantiate(mesh);
            copy.name = mesh.name;
            copy.hideFlags = HideFlags.DontUnloadUnusedAsset;
            copy.vertices = mesh.vertices.Select(v => toModel.MultiplyPoint3x4(v)).ToArray();
            copy.normals = mesh.normals.Select(v => toModelNormal.MultiplyVector(v).normalized).ToArray();
            copy.bindposes = smr.bones.Select(b => donorPoses[b.name]).ToArray();
            copy.RecalculateTangents();
            copy.RecalculateBounds();
            smr.sharedMesh = copy;
            // the merger looks the root bone up by name and throws if the rig does not have it
            smr.rootBone = smr.bones.FirstOrDefault(b => b.name == "Pelvis") ?? smr.bones[0];
            Info(model + " min=" + copy.bounds.min + " max=" + copy.bounds.max);
            return go;
        }

        static T Load<T>(string file) where T : UnityEngine.Object
        {
            if (string.IsNullOrEmpty(file)) return null;
            string id;
            if (!Ids.Assets.TryGetValue(file, out id)) { Error(file + " not in Ids.cs, re-run new_mod.py make"); return null; }
            var asset = ResourcesLibrary.TryGetResource<T>(id, hold: true);
            if (asset == null) Error(file + " could not be loaded as " + typeof(T).Name);
            return asset;
        }

        static void Dump(EquipmentEntity ee)
        {
            Info(ee.name + " Layer=" + ee.Layer + " Hide=" + ee.HideBodyParts + " ShowLower=" + ee.ShowLowerMaterials);
            foreach (var p in ee.BodyParts)
                Info("  " + p.Type + " mesh=" + (p.RendererPrefab != null ? p.RendererPrefab.name : "-") + " tex="
                     + string.Join(",", p.Textures.Where(t => t.DiffuseTexture != null)
                           .Select(t => t.DiffuseTexture.name + ":" + t.DiffuseTexture.width + "x" + t.DiffuseTexture.height)));
        }

        static void Info(string s) { s_Mod.Logger.Log("[EE] " + s); }
        static void Error(string s) { s_Mod.Logger.Error("[EE] ERROR " + s); }

        // ----- delivery, replace with a vendor or loot patch for release -----

        class GiveOncePerSave : IAreaActivationHandler
        {
            public void OnAreaActivated()
            {
                var player = Game.Instance.Player;
                var data = player.Ensure<EntityPartKeyValueStorage>().GetStorage(s_Mod.Manifest.UniqueName);
                if (data.Get("given") != null) return;
                player.Inventory.Add(ResourcesLibrary.TryGetBlueprint<BlueprintItem>(Ids.Item));
                data["given"] = "1";
            }
        }
    }
}
```

## 7. What `Customize()` can do

| Goal | Call |
|---|---|
| New texture | `Retexture(ee, "<donor diffuse name>", diffuse, normal, masks, colorMask)` |
| New geometry on an existing part | `ReplaceMesh(ee, type, "file.fbx")` |
| Extra part | `AddPart(ee, type, "file.fbx", diffuse, normal, masks)` |
| Drop a part | `RemovePart(ee, type)` |
| Draw over or under other EEs | `ee.Layer = ...` (the fullplate donor is 200) |
| Hide parts of other EEs | `ee.HideBodyParts = BodyPartType.Ears \| BodyPartType.Skirt` |
| Let lower textures show through transparency | `ee.ShowLowerMaterials = true` |
| Rigid prop on a bone | Edit `ee.OutfitParts` (`m_Prefab`, `m_BoneName`, `m_Position`, `m_Rotation`, `m_Scale`, material) |

To learn a donor's part types and texture names, launch once with an empty `Customize()`: `Dump` logs them as `[EE]` lines.

## 8. Textures

- **Size**: the rect from section 9, rounded to a multiple of 4 (DXT). Copying the donor's size is safest.
- **Normal and masks must have exactly the diffuse's size**, otherwise `Textures must be the same size` is logged.
- **Vanilla format**: DXT5, no mips, not readable.

| Map | Color space | Content |
|---|---|---|
| `_D` diffuse | sRGB | color; alpha is coverage over lower layers |
| `_N` normal | linear | ordinary tangent-space map, imported as NormalMap (packed as DXT5nm) |
| `_M` masks | linear | material channels: R and B are used, G and A are 0 in the measured donor maps. Start from the donor's map |
| `_S` color mask | linear | `RampShadowTexture`, selects what the color ramps repaint |

- A part can stack several textures: fullplate torso = chainmail underneath + plate on top. Retexture each by name.
- A part **without a mesh** is a pure texture overlay (fullplate `HeadBottom`).
- Textures are placed by the part type they are first seen with, so never share one texture between types that have different rects.

## 9. Body part types and atlas rects

**UVs are never remapped.** Author UV0 directly in the final atlas: base 2048, origin bottom-left, `u = x / 2048`, `v = y / 2048`. Texture files are cropped to the rect, so to paint in Blender offset and scale the preview accordingly.

| Type | Value | x, y, w, h |
|---|---|---|
| Belt | `0x1` | 0, 673, 685, 380 |
| BeltBag | `0x2` | 1295, 318, 394, 200 |
| Brows | `0x4` | 1295, 193, 265, 125 |
| ChestBag | `0x8` | 1295, 803, 170, 330 |
| Cuffs | `0x10` | 1690, 443, 358, 245 |
| Cuts | `0x20` | 925, 0, 165, 378 |
| Eyes | `0x40` | 1090, 283, 205, 95 |
| ElbowCops | `0x80` | 1295, 518, 395, 285 |
| Feet | `0x100` | 310, 1053, 375, 315 |
| Forearms | `0x200` | 1465, 1798, 583, 250 |
| Hands | `0x400` | 1690, 688, 358, 375 |
| Head | `0x800` | 0, 1628, 685, 420 |
| Helmet | `0x1000` | 1465, 1060, 584, 512 |
| Horns | `0x2000` | 925, 378, 370, 295 |
| KneeCops | `0x4000` | 0, 1053, 310, 315 |
| Lashes | `0x8000` | 1090, 238, 125, 45 |
| LowerLegs | `0x10000` | 1465, 1573, 583, 225 |
| MaskBottom | `0x20000` | 1690, 0, 358, 318 |
| MaskGoggles | `0x40000` | 1690, 318, 357, 124 |
| RingLeft | `0x80000` | 1560, 256, 130, 63 |
| RingRight | `0x100000` | 1560, 193, 130, 63 |
| Skirt | `0x200000` | 0, 98, 925, 575 |
| Spaulders | `0x400000` | 685, 673, 610, 460 |
| Tail | `0x800000` | 0, 0, 925, 98 |
| ThighBag | `0x1000000` | 1465, 803, 225, 260 |
| Torso | `0x2000000` | 685, 1628, 780, 420 |
| UpperArms | `0x4000000` | 0, 1368, 685, 260 |
| UpperLegs | `0x8000000` | 685, 1133, 780, 495 |
| HeadTop, HeadBottom, Ears, Neck, Teeth | `0x10000000` to `0x100000000` (successive bits) | 0, 1628, 685, 420 |
| Mask | `0x200000000` | 1690, 0, 357, 442 |
| DownArms | `0x400000000` | none of its own, uses the Forearms texture and area |
| Hair | `0x800000000` | 1465, 1060, 584, 512 |
| HeadBand | `0x1000000000` | 1371, 50, 318, 143 |
| NeckTorso | `0x2000000000` | 685, 1628, 780, 420 |
| Nose | `0x4000000000` | 0, 1628, 685, 420 |
| Cape, Backpack, Wings | `0x8000000000` to `0x20000000000` (successive bits) | none, normally outfit parts |

`Cuts` is shared cap geometry: any part may map faces there. On 204 vanilla armor meshes, 99.6% of vertices are inside their own rect or Cuts.

## 10. Meshes

### Rules of the merger

- **One mesh per body part type** in the final character: the highest Layer wins. Split armor by type, one file per part.
- **One submesh**, **Read/Write on**, **UV0 present**.
- **Bones are matched by exact name.** An unknown bone silently breaks the mapping of all following bones.
- Transforms are ignored and bind poses are used as-is (`PrepareModel` handles both).
- The merged character has a 16-bit index buffer: stay far below 65535 vertices in total. Vanilla parts have roughly 16-620.

### Mesh space (measured on the fullplate donor)

Metres, Y up, facing +Z, feet at y=0, renderer transform identity. The character's left is -X in Unity. Every part uses the same bind pose for a given bone.

| Male part | y range | half width (x) |
|---|---|---|
| Feet | 0.00-0.11 | 0.34 |
| UpperLegs | 0.34-1.11 | 0.31 |
| Skirt | 0.09-1.11 | 0.40 |
| Torso | 1.07-1.56 | 0.20 |
| Forearms | 1.14-1.34 | 0.65 |
| UpperArms | 1.22-1.52 | 0.46 |
| Spaulders | 1.38-1.63 | 0.35 |

After loading, compare the `[EE] <file> min= max=` log line with this table.

### Blender workflow

1. Export the donor part with AssetStudio (`Bundles\ee_<name>.ee` together with `Bundles\equipment`) as FBX, and import it in Blender to get the armature, scale and a weight source.
2. Model around it: Z up, facing -Y, metres. Transfer weights from the donor mesh, max 4 bones per vertex, only bones from the list below.
3. Lay out UV0 in atlas space, one material.
4. Export the armature and that one mesh:
   ```python
   bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'ARMATURE', 'MESH'},
                            add_leaf_bones=False, bake_anim=False, apply_scale_options='FBX_SCALE_ALL')
   ```
5. Male and female bodies differ: make one model for each and choose with `ee.name.Contains("_f_")`.

### Bones of the fullplate donor

```text
Pelvis Pelvis_ADJ Stomach_ADJ Spine_1_ADJ Spine_2_ADJ Spine_3_ADJ Neck_ADJ Head_ADJ
Face_Scale Jaw_Scale Skull_Scale
L_Clavicle_ADJ L_Neck_Muscl_ADJ L_Up_arm_ADJ L_Up_Arm_Muscl_ADJ L_ForeArm_ADJ L_ForeArm_Twist_ADJ L_Hand_ADJ
L_A_ADJ L_B_ADJ
L_Up_leg_ADJ L_leg_ADJ L_Ankle_ADJ L_foot_ADJ L_toe_ADJ
L_Toe_1_01_ADJ L_Toe_1_02_ADJ L_Toe_2_01_ADJ L_Toe_2_02_ADJ L_Toe_3_01_ADJ L_Toe_3_02_ADJ
(same with R_ for the right side)
```

### How parts are resolved

- EEs are sorted by `Layer`. For each type the last one supplies the mesh. Higher-layer textures of that type are painted on top, lower ones only with `ShowLowerMaterials`.
- `HideBodyParts` of every *other* visible EE is OR-ed and removes those types.
- Layer >= 100 is dropped when the character is forced naked.
- Helmet, Mask and HeadBand follow "show helmet". Belt, bags, Cuffs, Skirt, Spaulders, rings, Cape and similar follow "show cloth".

## 11. Reference donor: Fullplate Knight

| What | ID |
|---|---|
| Item `FullplateStandard` | `559b0b6f194656c428c403a000ceee78` |
| Its KEE | `fea832fe875ad1748a97cf50166ce394` |
| Male EE | `f645de0a63343da42a4c8dfabedd431f` |
| Female EE | `6a16a0a5a76241f4d83ea827d4837e6e` |

Layer 200, ShowLowerMaterials on, hides nothing. Textures are identical for both genders.

| Part | Diffuse textures, bottom to top | Size |
|---|---|---|
| Torso, NeckTorso | `TS_ChainmailArmy_D`, `TS_FullplateKnight_D` | 780x420 |
| UpperArms | `UA_ChainmailArmy_D`, `UA_FullplateKnight_D` | 688x260, 684x260 |
| Forearms, DownArms | `FA_ChainmailArmy_D`, `FA_FullplateKnight_D` | 584x252 |
| Hands | `HN_FullplateKnight_D` | 360x376 |
| UpperLegs | `UL_FullplateKnight_D` | 780x496 |
| LowerLegs | `LL_FullplateKnight_D` | 584x224 |
| Feet | `FT_FullplateKnight_D` | 376x316 |
| Spaulders | `SP_FullplateKnight_D` | 612x460 |
| Cuffs | `CF_FullplateKnight_D` | 360x244 |
| ElbowCops | `EC_FullplateKnight_D` | 396x284 |
| KneeCops | `KC_FullplateKnight_D` | 312x316 |
| Skirt | `SK_PaddedNoble_D`, `SK_ChainskirtFullplateHoly_D`, `SK_FullplateKnight_D` | 924x576, 928x576, 924x576 |
| HeadBottom (overlay only) | `HD_ChainmailArmy_D` | 688x420 |

## 12. Troubleshooting

| Symptom | Cause |
|---|---|
| No `Apply modification: <MOD>` in the log | Not in `EnabledModifications`, or wrong folder depth |
| Item has no name | Localization key missing (`enGB.json` also serves other languages) |
| No icon | Not imported as a single Sprite, blueprint in a subfolder, or `make` not re-run after import |
| Item equips but nothing changes | "Show class equipment" is on, or the slot's visual is hidden, or a higher Layer covers it |
| NullReferenceException in `AddItemEquipment` | An EE GUID of the KEE is not registered: look for `[EE] ERROR` |
| Texture tinted wrongly | Color mask still active, or a ramp preset applies (`m_ForcedRampColorPresetIndex` in the item) |
| Part shows pieces of another texture | UVs outside the part's rect |
| Mesh mangled or collapsed | Bone names, or weights on non-deform bones |
| `KeyNotFoundException` in `BuildMesh` | Root bone name not in the game's rig |
| Part missing | No material, no texture, hidden by another EE, or lost against another part of the same type |
| Empty or null EE from a bundle | Someone authored the EE in Unity, see trap 1 |

## 13. Where to look in the game code

Decompile `Assembly-CSharp.dll` with ILSpy (or dnSpy):

- `Kingmaker.Visual.CharacterSystem`: `EquipmentEntity`, `BodyPart`, `BodyPartType`, `KingmakerEquipmentEntity`, `CharacterTextureDescription`
- `Character`: `UpdateCharacter` (layers, hiding), `BuildMesh` / `EnsureBones` (merge), `MergeOverlays` (atlases)
- `CharacterAtlas.GetMappedRect`: rects
- `Kingmaker.View.UnitEntityView`: `UpdateBodyEquipmentModel`, `AddItemEquipment`
- `Kingmaker.Blueprints.ResourcesLibrary`: cache and cleanup
- `Kingmaker.Modding.OwlcatModification`: how mods are loaded
- `Kingmaker.GameStarter`: startup order
