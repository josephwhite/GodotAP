<#
    .SYNOPSIS
    Pre-commit for gdtoolkit hooks.
    .DESCRIPTION
    Runs the named gdtoolkit tool (gdlint/gdformat).
    BranchRegex makes it run only on branches that match. Skip inverts that to skip branches that match.
    When neither is given, runs on every branch.
    .PARAMETER Tool
    Tool for GDScript Toolkit (https://github.com/Scony/godot-gdscript-toolkit)
    gdlint or gdformat.
    .PARAMETER BranchRegex
    Regex pattern to match current branch against.
    Runs tool if pattern matches.
    .PARAMETER Skip
    Inverts BranchRegex; runs tool if pattern doesn't match.
    .PARAMETER Files
    List of .gd files to check.
    Appended by pre-commit.
    .EXAMPLE
    pwsh -NoProfile -File hooks/pre-commit-gdtoolkit.ps1 -Tool gdlint -BranchRegex '^downpatch-3\.6\.0' godot_ap/foo.gd
    Runs gdlint on the given files only on downpatch-3.6.0* branches.
    .EXAMPLE
    pwsh -NoProfile -File hooks/pre-commit-gdtoolkit.ps1 -Tool gdlint -BranchRegex '^downpatch-3\.6\.0' -Skip godot_ap/foo.gd
    Runs gdlint on the given files on every branch except downpatch-3.6.0*.
#>
 
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("gdformat", "gdlint")]
    [string]$Tool,

    [string]$BranchRegex,

    [switch]$Skip,

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Files
)

# A positional filename can spill into -BranchRegex when the switch is
# omitted (PowerShell binds positionals in declaration order). 
# Regexes are anchored like '^downpatch-3\.6\.0', never a real path, so demote:
if ($BranchRegex -and (Test-Path -LiteralPath $BranchRegex)) {
    if ($Files) { 
        $Files = @($BranchRegex) + $Files 
    } else { 
        $Files = @($BranchRegex) 
    }
    $BranchRegex = ''
}

$this_filename = $MyInvocation.MyCommand.Name
if ($Skip -and -not $BranchRegex) {
    Write-Error "$($this_filename): -BranchRegex is required with -Skip"
    exit 2
}

# Only process .gd files.
$gdFiles = @($Files | Where-Object { $_ -match '\.gd$' })
$dropped = @($Files | Where-Object { $_ -notmatch '\.gd$' })
if ($dropped) {
    Write-Warning "$($this_filename): skipping non-.gd file(s): $($dropped -join ', ')"
}
if (-not $gdFiles) {
    Write-Output "$Tool : no .gd files to check"
    exit 0
}

# Get current git branch name
$branch = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0) {
    $branch = ''
}

# Regex match branch to pattern
$run = $true
if ($BranchRegex) {
    $run = $branch -match $BranchRegex
    if ($Skip) {
        $run = -not $run
    }
}

if (-not $run) {
    Write-Output "$Tool : skipped on branch '$branch'"
    exit 0
}

Write-Output "$Tool : running on branch '$branch'"

& $Tool @gdFiles

exit $LASTEXITCODE
