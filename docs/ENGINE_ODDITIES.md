# Engine Oddities in Custom Godot 3 Builds

Games sometimes ship modified or forked Godot 3.6 engine builds. 
Constructs that stock Godot handles fine can crash natively on these builds.
This document catalogs each known build, the oddities observed on it, and the solution the GodotAP downpatch takes for each.

## Games

| Game | Build/Fork |
|------|------------|
| [Y2ROLL](#y2roll) | Godot 3.6 fork (`v3.6.stable.custom_build.43952fe13`) |
| *(future games: add a row here and a section below)* ||

## Shared Oddities

Rules treated as unsafe across multiple builds. 
Each is tagged with the game section(s) where it was confirmed.
Fixes are applied unconditionally unless noted otherwise (casus).

### Casus

For solutions that are needed for one or more game builds but are not universal to Godot 3's stock engine, the below toggles have been added to coalesce GodotAP to these certain rare and restricting environments.

|Casus Toggle|Description|Games|
|-|-|-|
|DISABLE_BITWISE_OPERATIONS|Replaces usage of bitwise operators and diverts to other math functions. Needed builds that crash brom performing bit math.|[Y2ROLL](#y2roll)|

## Y2ROLL

### Build

- Exact engine ID: **`Godot Engine v3.6.stable.custom_build.43952fe13`**.
  - Fork status: private / closed-source. 
  - GDRE export log: `Detected Engine Version: 3.6.0`, `Detected Bytecode Revision: 3.5.0-stable (a7aad78)`
- Godot Mod Loader (v6.3.0) self setup fails. Build ignores `override.cfg` and `res://` filesystem.
- `WebSocketClient` module present.

### Oddities

| # | Construct | Behavior | Solution |
|---|---|---|---|
| 1 | `for i in n:` with `n == 0` | Native fault | `for i in range(n):` for all bare-int loops. |
| 2 | `s[i]` char indexing | Native fault | `s.substr(i, 1)` for char indexing.|
| 3 | `&`, `<<`, `>>` operators | Native fault | `casus["DISABLE_BITWISE_OPERATIONS"] = true` disables bitwise operators in favor of division/modulo arithmetic.|
