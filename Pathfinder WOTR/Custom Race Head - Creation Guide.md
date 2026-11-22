---
title: Custom Race Head - Creation Guide
game: "Pathfinder: Wrath of the Righteous"
game_version: 2.7
created: 2026-11-22
tags:
  - pathfinder-wotr
  - modding
  - equipment-entity
  - character-creation
---

# Custom Race Head - Creation Guide

How to add an extra **head option in character creation** to any race. Companion of [[Custom EquipmentEntity - Creation Guide]] (same template, build and install procedure, same EE-cloning trick).

> [!success] Status
> **Proven in game, 2026-11-22**: a placeholder head (clone of a helmet EE) appears as a 12th "Face" option for Human male in the CC menu. The placeholder's visual (helmet EE used as head, no eyebrows) was not inspected closely. Real head meshes and textures are untested.

## 1. Structure (same idea as Rogue Trader)

- Races are `BlueprintRace` blueprints, in `blueprints.zip` under `Races/`. Human = `Races/HumanRace.jbp`, AssetId `d1d114f539b74468b157ac69c275f266`.
- Each has `MaleOptions` and `FemaleOptions`, of type `Kingmaker.Blueprints.CharGen.CustomizationOptions`.
- Its fields `m_Heads`, `m_Eyebrows`, `m_Hair`, ... are arrays of `EquipmentEntityLink` (`{ "AssetId": "<EE guid>" }`). **A head is a plain EE, not a KEE.**
- `m_Eyebrows` is a tooltip "Must match heads 1:1": `DollState` picks `Eyebrows[indexOfHead]` and leaves eyebrows empty if the index is out of range. A head added at the end therefore has **no eyebrows** unless you also extend the eyebrows list.
- The menu list is `CharGenAppearancePhaseVM.GetHeadsList`: it iterates `options.Heads`, titles them "Face 1..N", and compares with `head.Load() == dollState.Head.Load()`.

## 2. The trap: do not append to `m_Heads`

`CustomizationOptions.Heads` is **not** `m_Heads`. It is a getter:

```csharp
public EquipmentEntityLink[] Heads =>
    m_HeadsCache ?? (m_HeadsCache = m_Heads.Where(ee => ee.Load().IsDlcAvailable()).ToArray());
```

It filters by DLC (so vanilla Human male shows 11 of the 12 blueprint heads) and caches the result.

What was tried, in order:

1. Append to `m_Heads` of the race blueprint in a `BlueprintsCache.Init` postfix: log said "added", **menu still 11 heads**.
2. Same, plus `m_HeadsCache = null`: **still 11**. The race blueprint instance is probably reloaded, or the cache is rebuilt from a different instance.
3. **Working**: Harmony **postfix on the `Heads` getter**. If the returned array belongs to the target race, append the new link and store it into `m_HeadsCache`. This does not depend on which blueprint instance is live.

How the postfix recognises the race: the first head AssetId of the returned array (Human male `4eea3ef5f2e01474ba5b03fe28324ad3`, Human female `971d4ec9ff97af447b415c8eb4c5b0b5`). To find these for another race:

```bash
python -I - <<'E'
import zipfile, json
import os, sys
g = os.environ.get("WOTR_GAME")
if not g or not os.path.isfile(g + "/blueprints.zip"):
    sys.exit("FATAL: WOTR_GAME not set or has no blueprints.zip")
z = zipfile.ZipFile(g + "/blueprints.zip")
r = json.loads(z.read("Races/HumanRace.jbp").decode("utf-8-sig"))   # change the race file
for g in ("Male", "Female"):
    print(g, [l["AssetId"] for l in r["Data"][g + "Options"]["m_Heads"]])
E
```

List the races with `Races/*.jbp` in the zip. Race-specific head lists can be shared between races, so check that the first head is unique to the race you target, or compare the whole array.

## 3. Procedure

Everything else follows [[Custom EquipmentEntity - Creation Guide]] section 5 (template copy, Unity 2020.3.48f1 batch build, install, enable). Differences:

1. **Check the environment** (`source ~/wotr_env.sh`, see section 2 of the other note; it exits if a `WOTR_*` variable is missing), then **copy the template** (`$WOTR_TEMPLATE`: `Assets`, `Packages`, `ProjectSettings`, `Library`) to a new folder, delete `Assets/Modifications/UlrikaMod` and its `.meta` (Rogue Trader project, not valid here). No need for `new_mod.py`, there is no item or KEE.
2. Create `Assets/Modifications/<Mod>/` with `Blueprints/`, `Content/`, `Localization/enGB.json` (`{"strings":[]}`), `Scripts/<Mod>.Scripts.asmdef` (`{"name":"<Mod>.Scripts","autoReferenced":false}`), the script, and the manifest asset `<Mod>.asset`. The asset is a MonoBehaviour whose `m_Script` guid is the guid in `Assets/Editor/Modification.cs.meta` (copy the format from `new_mod.py`, section 6 of the other note).
3. Put `BuildMod.cs` from the other note in `Assets/Editor/` (only `Build()` is needed when there is no Content).
4. Build, then copy `Build/Mods/<Mod>/<Mod>/` to `$WOTR_MODS/<Mod>/` and add the name to `EnabledModifications` (and `ActiveModifications`) in `$WOTR_MODS/../OwlcatModificationManagerSettings.json`. Restart the game.
5. Check the log: `grep -n -F "[Head]" "$WOTR_MODS/../GameLogFull.txt"`.

Gotchas hit in this session:
- Compile error `OwlcatModificationEnterPointAttribute not found`: the script needs `using Kingmaker.Modding;`. Also needs `using Kingmaker.ResourceLinks;` (EquipmentEntityLink) and `using Kingmaker.Blueprints.CharGen;` (CustomizationOptions).
- `Grep` on the log for `A|B` through the rtk hook can dump the whole log. Use `grep -n -F -e "[Head]"`.
- New EE GUIDs: any unique 32-hex string, **never change after release** (saves store the head).

## 4. The script (working)

Placeholder = clones of the Fullplate Evil helmet EEs (male `7a90029d7d182da42a7ba9f532cf2511`, female `6d4e9dc7c5e6a3346b7543728de9dd31`). To use a real head later, replace the donor with a vanilla head EE (e.g. Human male `ee_head01_m_hm.ee` = `4eea3ef5...`) and call `Customize`-style edits from the other note (`Retexture`, `ReplaceMesh`, with `BodyPartType.Head`, rect 0,1628,685,420).

```csharp
using System;
using System.Collections;
using System.Linq;
using System.Reflection;
using HarmonyLib;
using Kingmaker.Blueprints;
using Kingmaker.Blueprints.Classes;
using Kingmaker.Blueprints.CharGen;
using Kingmaker.Blueprints.JsonSystem;
using Kingmaker.BundlesLoading;
using Kingmaker.ResourceLinks;
using Kingmaker.Modding;
using Kingmaker.Visual.CharacterSystem;
using UnityEngine;

namespace CustomHeadMod
{
    internal static class CustomHead
    {
        static Kingmaker.Modding.OwlcatModification s_Mod;

        // { new EE id, name, donor EE id }, index 0 = male, 1 = female
        static readonly string[][] Heads =
        {
            new[] { "6f3a0c52d5e14b2f9a1c7e8b4d203a11", "EE_CustomHead_PlaceholderM", "7a90029d7d182da42a7ba9f532cf2511" },
            new[] { "b81e47c9a02d4f6c8e35d1f7a96c0b22", "EE_CustomHead_PlaceholderF", "6d4e9dc7c5e6a3346b7543728de9dd31" },
        };
        // first head of the target race's male / female Heads (Human here)
        static readonly string[] RaceFirstHeads = { "4eea3ef5f2e01474ba5b03fe28324ad3", "971d4ec9ff97af447b415c8eb4c5b0b5" };

        [OwlcatModificationEnterPoint]
        public static void Init(Kingmaker.Modding.OwlcatModification mod)
        {
            s_Mod = mod;
            new Harmony(mod.Manifest.UniqueName).PatchAll(Assembly.GetExecutingAssembly());
        }

        // Create and register the EE clones once vanilla bundles and blueprints are available.
        [HarmonyPatch(typeof(BlueprintsCache), nameof(BlueprintsCache.Init))]
        static class AfterVanillaBlueprints
        {
            static void Postfix()
            {
                foreach (var def in Heads)
                {
                    try
                    {
                        var donor = ResourcesLibrary.TryGetResource<EquipmentEntity>(def[2], hold: true);
                        if (donor == null) { Error("donor not found: " + def[2]); continue; }
                        var ee = UnityEngine.Object.Instantiate(donor);
                        ee.name = def[1];
                        ee.hideFlags = HideFlags.DontUnloadUnusedAsset;
                        Register(def[0], ee);
                        Log("registered " + def[1]);
                    }
                    catch (Exception e) { Error(e.ToString()); }
                }
            }
        }

        // The menu reads CustomizationOptions.Heads (filtered + cached), so patch the getter.
        [HarmonyPatch(typeof(CustomizationOptions), nameof(CustomizationOptions.Heads), MethodType.Getter)]
        static class HeadsGetter
        {
            static void Postfix(CustomizationOptions __instance, ref EquipmentEntityLink[] __result)
            {
                try
                {
                    if (__result == null || __result.Length == 0) return;
                    int k = Array.IndexOf(RaceFirstHeads, __result[0].AssetId);
                    if (k < 0) return;
                    string id = Heads[k][0];
                    if (__result.Any(l => l.AssetId == id)) return;
                    var link = new EquipmentEntityLink { AssetId = id };
                    __result = __result.Concat(new[] { link }).ToArray();
                    AccessTools.Field(typeof(CustomizationOptions), "m_HeadsCache").SetValue(__instance, __result);
                    Log("appended " + Heads[k][1] + " to Heads getter, count=" + __result.Length);
                }
                catch (Exception e) { Error(e.ToString()); }
            }
        }

        // Preloading rejects GUIDs without a bundle location.
        [HarmonyPatch(typeof(BundlesLoadService), nameof(BundlesLoadService.HasLocation))]
        static class AllowPreload
        {
            static void Postfix(string __0, ref bool __result)
            {
                if (!__result) __result = Heads.Any(d => d[0] == __0);
            }
        }

        // Put a runtime-created EE into the resource cache under a new GUID (HandleCounter 1 = survives cleanup).
        static void Register(string id, UnityEngine.Object resource)
        {
            var type = AccessTools.Inner(typeof(ResourcesLibrary), "LoadedResource");
            var entry = Activator.CreateInstance(type, new object[] { resource });
            AccessTools.Field(type, "RequestCounter").SetValue(entry, 1);
            AccessTools.Field(type, "HandleCounter").SetValue(entry, 1);
            ((IDictionary)AccessTools.Field(typeof(ResourcesLibrary), "s_LoadedResources").GetValue(null))[id] = entry;
        }

        static void Log(string s) { s_Mod.Logger.Log("[Head] " + s); }
        static void Error(string s) { s_Mod.Logger.Error("[Head] ERROR " + s); }
    }
}
```

The working project was a template copy named `CustomHeadMod` (mod name `CustomHead`).

## 5. Open points / next steps

- **Eyebrows**: patch the `Eyebrows` getter the same way (index must match the head's index), or the new head has none.
- **Other options tied to the head**: `Presets`/ramps are per race, not per head, so skin and hair colors should work, but this is untested with a real head.
- **Real head asset**: build the EE from a vanilla head EE clone (head EEs use `BodyPartType.Head`, with Eyes/Teeth/Ears etc. as other parts) and retexture/replace mesh per the other guide. Untested.
- **Other races / gender mix**: change `RaceFirstHeads` (one entry per option set). A shared first head between races would add the head to both.
- **Removing the mod from a save that used the head**: untested, assume unsafe.

## 6. Where to look in the game code

Decompiled with `ilspycmd` 8.2.0.7535 (`dotnet tool install ilspycmd --version 8.2.0.7535 --tool-path <dir>`, then `ilspycmd -p -o <out> Assembly-CSharp.dll`; the latest version needs a newer SDK than 9.0.301, and dnSpy.Console crashed):
- `Kingmaker.Blueprints.CharGen/CustomizationOptions.cs`
- `Kingmaker.UI.MVVM._VM.CharGen.Phases.Appearance/CharGenAppearancePhaseVM.cs` (`GetHeadsList`)
- `Kingmaker.UnitLogic.Class.LevelUp/DollState.cs` (head, eyebrows, hair selection)
- `Kingmaker.Blueprints.Classes/BlueprintRace.cs`
