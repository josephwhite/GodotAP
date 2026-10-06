# GodotAP downpatch-3.6.0 Hooks

Scripts/tooling/CI to help with developing GodotAP for Godot 3.6.

## Files
- `pre-commit-relativize.ps1` - Enforce relative paths for ext_resource
- `pre-commit-gdtoolkit.ps1` - GDScript linting

## Notes
- Should include branch name check parameters.
    - CI states branch names must start with `downpatch-3.6.0`.
- Can be ran directly or as pre-commit.
- `gdformat` is an AST pretty-printer that can discard author line breaks and wrapping.
