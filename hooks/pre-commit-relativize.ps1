<#
    .SYNOPSIS
    Pre-commit that rewrites forced-absolute godot_ap .tscn/.tres
    [ext_resource] refs back to folder-relative on disk.
    .DESCRIPTION
    Pre-commit runs this on staged .tscn/.tres files at commit time.
    If any file was still absolute, it gets rewritten to folder-relative.
    Godot 3.6 editor absolutizes ext_resource paths on save.
    Needed for relocatability of godot_ap/ (res://addons/, res://mods-unpacked/, etc).
    BranchRegex makes it run only on branches that match.
    Skip inverts that to skip branches that match.
    When neither is given, runs on every branch.
    .PARAMETER BranchRegex
    Regex pattern to match current branch against before running.
    .PARAMETER Skip
    Inverts BranchRegex; runs if pattern doesn't match.
    .PARAMETER Path
    List of .tscn/.tres files to check.
    Appended by pre-commit.
    .EXAMPLE
    pwsh -NoProfile -File hooks/pre-commit-relativize.ps1 -BranchRegex '^downpatch-3\.6\.0' godot_ap/ui/main.tscn
    Rewrites the file only on downpatch-3.6.0* branches.
    .EXAMPLE
    .\hooks\pre-commit-relativize.ps1 (git diff --cached --name-only -- '*.tscn' '*.tres')
    Rewrites files that have pending changes, on any branch.
#>

param(
    [string]$BranchRegex,

    [switch]$Skip,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Path
)

function ConvertTo-Relative {
    param(
        [string]$Content,
        [string]$FileRelativePath
    )

    $fdir = $FileRelativePath.Replace('\', '/')
    $slash = $fdir.LastIndexOf('/')
    if ($slash -ge 0) {
        $fdir = $fdir.Substring(0, $slash)
    } else {
        $fdir = ''
    }
    $fromParts = @($fdir.Split('/') | Where-Object { $_ -ne '' })

    $pattern = '(path=")res://godot_ap/([^"]+)(")'
    $converter = {
        param($m)
        $toParts = @('godot_ap') + @($m.Groups[2].Value.Split('/'))
        $common = 0
        $max = [Math]::Min($fromParts.Count, $toParts.Count)
        while ($common -lt $max -and $fromParts[$common] -eq $toParts[$common]) { $common++ }
        $segments = @()
        for ($i = $common; $i -lt $fromParts.Count; $i++) { $segments += '..' }
        for ($i = $common; $i -lt $toParts.Count; $i++) { $segments += $toParts[$i] }
        if ($segments.Count -eq 0) { $segments = @('.') }
        return $m.Groups[1].Value + ([string]::Join('/', $segments)) + $m.Groups[3].Value
    }
    return [regex]::Replace($Content, $pattern, $converter)
}

# A positional filename can spill into -BranchRegex when the switch is
# omitted (PowerShell binds positionals in declaration order). Regexes
# are anchored like '^downpatch-3\.6\.0', never a real path, so demote:
if ($BranchRegex -and (Test-Path -LiteralPath $BranchRegex)) {
    if ($Path) { $Path = @($BranchRegex) + $Path } else { $Path = @($BranchRegex) }
    $BranchRegex = ''
}

$this_filename = $MyInvocation.MyCommand.Name

# Only process .tscn/.tres files
$sceneFiles = @($Path | Where-Object { $_ -match '\.(tscn|tres)$' })
$dropped = @($Path | Where-Object { $_ -notmatch '\.(tscn|tres)$' })
if ($dropped) {
    Write-Warning "$($this_filename): skipping non-.tscn/.tres file(s): $($dropped -join ', ')"
}

if (-not $sceneFiles) {
    exit 0
}

# Get current branch
$branch = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0) {
    $branch = '' 
}

if ($Skip -and -not $BranchRegex) {
    Write-Error "$($this_filename): -BranchRegex is required with -Skip"
    exit 2
}

$run = $true
if ($BranchRegex) {
    $run = $branch -match $BranchRegex
    if ($Skip) {
        $run = -not $run
    }
}

if (-not $run) {
    Write-Output "$($this_filename): skipped on branch '$branch'"
    exit 0
}

$changed = @()
foreach ($f in $sceneFiles) {
    $content = [System.IO.File]::ReadAllText($f)
    $rel = ConvertTo-Relative -Content $content -FileRelativePath $f
    if ($rel -cne $content) {
        [System.IO.File]::WriteAllText($f, $rel, [System.Text.UTF8Encoding]::new($false))
        $changed += $f
    }
}

if ($changed.Count) {
    Write-Output ("relativized: " + ($changed -join ', '))
    exit 1
}

exit 0
