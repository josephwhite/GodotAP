<#
    .SYNOPSIS
    Pre-commit that rewrites forced-absolute godot_ap .tscn/.tres
    [ext_resource] refs back to folder-relative on disk.

    .DESCRIPTION
    Pre-commit runs this on staged .tscn/.tres files at commit time.
    If any file was still absolute, it gets rewritten to folder-relative.

    Exit codes: 
        0 = no file changed
        1 = one or more files rewritten

    .PARAMETER Path
    One or more .tscn/.tres files to rewrite.
    .EXAMPLE
    pwsh -NoProfile -File hooks/pre-commit-relativize.ps1 godot_ap/ui/main.tscn
    Checks specific file as a seperate session.
    .EXAMPLE
    .\hooks\pre-commit-relativize.ps1 (git diff --cached --name-only -- '*.tscn' '*.tres')
    Checks files that have pending changes.
    #>
param(
    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
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

if (-not $Path) {
    exit 0
}

$changed = @()
foreach ($f in $Path) {
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
