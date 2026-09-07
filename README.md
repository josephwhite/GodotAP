# GodotAP for Godot 3

A Godot 3.6 port of [GodotAP](https://github.com/EmilyV99/GodotAP) for inegrating with [Archipelago](https://archipelago.gg).

## Changes from Upstream
- Downported to Godot 3.6. Ideally can support other Godot 3.x versions.
- Preloads and ext_resource references are folder-relative
    - Allows `godot_ap/` folder installs at any depth (`res://godot_ap/`, `res://addons/godot_ap/`, `res://mods-unpacked/<ModID>/godot_ap/` etc.).
    - See [upstream's equivalent PR](https://github.com/EmilyV99/GodotAP/pull/16).
- Casus: A generic set of toggles to handle [quirks by game/engine builds](./docs/ENGINE_ODDITIES.md).

## CommonClient / Built in Support
Just like upstream, this version of GodotAP also works for custom games with bultin in Archipelago support or a text client. See the [upstream readme for more info](docs\UPSTREAM_README.md).

## In a Godot Mod Loader mod

- Copy the whole `godot_ap/` folder into your mod under `<ModID>/godot_ap/`. Everything resolves relative to the module, so it needs no absolute `res://` references.
- Add `godot_ap/autoloads/archipelago.tscn` as an AutoLoad (or `add_child` it from your mod's `_init`/`_ready`).

### Example

**mod_main.gd**
```gdscript
const MOD_ID = "JohnGodot3-ArchipelagoRandomizer"

func _ready():
  # Let's say godot_ap is in the root of our mod folder
  var ap_scene_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID + "/godot_ap/autoloads/archipelago.tscn")
  var ap_scene = load(ap_scene_path)
  var ap_node = ap_scene.instance()
  ap_node.name = "Archipelago"
  # Enable casus toggles
  ap_node.casus["DISABLE_BITWISE_OPERATIONS"] = true
  get_tree().root.add_child(ap_node)
  if ap_node.is_inside_tree():
    ap_node.AP_GAME_NAME = "My Game Name"
```
