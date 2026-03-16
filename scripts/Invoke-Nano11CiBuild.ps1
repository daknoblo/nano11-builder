[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Nano11ScriptPath,

    [Parameter(Mandatory = $true)]
    [string]$MountedIsoDrive,

    [Parameter(Mandatory = $true)]
    [string]$ImageIndex,

    [Parameter(Mandatory = $true)]
    [string]$OutputDir,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\\nano11-ci\\logs\\nano11-build.log"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$stamp] $Message"
}

function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw "Invoke-Nano11CiBuild.ps1 benötigt Administratorrechte."
    }
}

Assert-Admin

if (-not (Test-Path $Nano11ScriptPath)) {
    throw "Nano11-Skript nicht gefunden: $Nano11ScriptPath"
}

$resolvedScript = (Resolve-Path $Nano11ScriptPath).Path
$scriptDir = Split-Path -Path $resolvedScript -Parent
$isoDrive = $MountedIsoDrive.Trim()
if ($isoDrive.EndsWith(':')) {
    $isoDriveNoColon = $isoDrive.Substring(0, $isoDrive.Length - 1)
}
else {
    $isoDriveNoColon = $isoDrive
}

if ([string]::IsNullOrWhiteSpace($isoDriveNoColon)) {
    throw "Ungültiger MountedIsoDrive: '$MountedIsoDrive'"
}

if (-not (Test-Path "$isoDriveNoColon`:\\sources")) {
    throw "Gemountete ISO enthält kein sources-Verzeichnis: $isoDriveNoColon`:"
}

New-Item -Path (Split-Path $LogPath -Parent) -ItemType Directory -Force | Out-Null
New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null

Write-Log "Starte Nano11 CI Wrapper"
Write-Log "Nano11 Script: $resolvedScript"
Write-Log "Mounted ISO Drive: $isoDriveNoColon`:"
Write-Log "Image Index: $ImageIndex"
Write-Log "Output Dir: $OutputDir"
Write-Log "Log File: $LogPath"

# The upstream script is interactive. Feed expected answers in order:
# 1) continue: y
# 2) drive letter without colon
# 3) image index
# 4) final Enter on completion prompt
$answers = @(
    'y',
    $isoDriveNoColon,
    "$ImageIndex",
    ''
) -join "`r`n"

Write-Log "Führe nano11builder.ps1 nicht-interaktiv aus..."

Push-Location $scriptDir
try {
    $allOutput = $answers | & powershell -NoProfile -ExecutionPolicy Bypass -File $resolvedScript *>&1
    $allOutput | Tee-Object -FilePath $LogPath -Append | ForEach-Object { Write-Host $_ }

    if ($LASTEXITCODE -ne 0) {
        throw "Nano11-Skript fehlgeschlagen (ExitCode=$LASTEXITCODE)."
    }
}
finally {
    Pop-Location
}

$defaultIso = Join-Path $scriptDir 'nano11.iso'
if (-not (Test-Path $defaultIso)) {
    # Fallback: search in script dir for any ISO created recently.
    $fallbackIso = Get-ChildItem -Path $scriptDir -Filter '*.iso' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $fallbackIso) {
        throw "Nano11 hat keine ISO erzeugt. Erwartet: $defaultIso"
    }
    $sourceIso = $fallbackIso.FullName
}
else {
    $sourceIso = $defaultIso
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$targetIso = Join-Path $OutputDir "nano11-$timestamp.iso"
Copy-Item -Path $sourceIso -Destination $targetIso -Force

Write-Log "Nano11 Build abgeschlossen"
Write-Log "Quell-ISO: $sourceIso"
Write-Log "Ziel-ISO: $targetIso"

# Emit machine-readable marker for debugging and potential log parsing.
Write-Host "NANO11_OUTPUT_ISO=$targetIso"
