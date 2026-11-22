#!/usr/bin/env bash
# Environment for the Pathfinder WOTR modding notes.
# Usage:  source ~/wotr_env.sh          (core variables)
#         source ~/wotr_env.sh mesh     (also checks AssetStudio and Blender)
# Edit the values below, or set the variables beforehand: existing values win.

# ---- EDIT ME ---------------------------------------------------------------
: "${WOTR_GAME:=/d/Games/Steam/steamapps/common/Pathfinder Second Adventure}"
: "${WOTR_TEMPLATE:=/d/Pathfingder_Mods/WrathModificationTemplate}"
: "${WOTR_UNITY:=/c/Program Files/Unity/Hub/Editor/2020.3.48f1/Editor/Unity.exe}"
: "${WOTR_MODS:=$HOME/AppData/LocalLow/Owlcat Games/Pathfinder Wrath Of The Righteous/Modifications}"
: "${WOTR_ASSETSTUDIO:=/d/Apps/AssetStudio.net6.v0.16.47}"
: "${WOTR_BLENDER:=/d/Games/Steam/steamapps/common/Blender/blender.exe}"
# ----------------------------------------------------------------------------

export WOTR_GAME WOTR_TEMPLATE WOTR_UNITY WOTR_MODS WOTR_ASSETSTUDIO WOTR_BLENDER

need() { # name, kind (f = file, d = folder)
  local v="${!1}"
  if [ -z "$v" ]; then echo "FATAL: env var $1 is not set" >&2; return 1; fi
  if [ "$2" = f ] && [ ! -f "$v" ]; then echo "FATAL: $1=$v is not a file" >&2; return 1; fi
  if [ "$2" = d ] && [ ! -d "$v" ]; then echo "FATAL: $1=$v is not a folder" >&2; return 1; fi
}

need WOTR_GAME d && need WOTR_TEMPLATE d && need WOTR_UNITY f && need WOTR_MODS d || { return 1 2>/dev/null || exit 1; }
if [ "$1" = mesh ]; then
  need WOTR_ASSETSTUDIO d && need WOTR_BLENDER f || { return 1 2>/dev/null || exit 1; }
fi
