@echo off
setlocal

set "BRAVE_ORIGIN_BAT=%~f0"
set "BRAVE_ORIGIN_PROFILE_ARG=%~1"

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo powershell.exe was not found.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$raw = Get-Content -LiteralPath $env:BRAVE_ORIGIN_BAT -Raw; $marker = '::POWERSHELL_PAYLOAD::'; $idx = $raw.LastIndexOf($marker); if ($idx -lt 0) { throw 'PowerShell payload marker not found.' }; $code = $raw.Substring($idx + $marker.Length); Invoke-Expression $code"
set "STATUS=%ERRORLEVEL%"

if "%BRAVE_ORIGIN_NO_PAUSE%"=="1" exit /b %STATUS%
echo.
pause
exit /b %STATUS%

::POWERSHELL_PAYLOAD::
$ErrorActionPreference = "Stop"

function Set-PropertyValue {
  param(
    [Parameter(Mandatory = $true)] $Object,
    [Parameter(Mandatory = $true)] [string] $Name,
    [Parameter(Mandatory = $true)] $Value
  )

  if ($Object.PSObject.Properties[$Name]) {
    $Object.$Name = $Value
  } else {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  }
}

function Ensure-PropertyObject {
  param(
    [Parameter(Mandatory = $true)] $Object,
    [Parameter(Mandatory = $true)] [string] $Name
  )

  $prop = $Object.PSObject.Properties[$Name]
  if ($null -eq $prop -or $null -eq $prop.Value -or -not ($prop.Value -is [pscustomobject])) {
    Set-PropertyValue $Object $Name ([pscustomobject]@{})
  }

  return $Object.$Name
}

function Resolve-LocalStatePath {
  param([string] $PathArg)

  if (-not [string]::IsNullOrWhiteSpace($PathArg)) {
    $expanded = [Environment]::ExpandEnvironmentVariables($PathArg)
    if ([IO.Path]::GetFileName($expanded) -eq "Local State") {
      return $expanded
    }

    return (Join-Path $expanded "Local State")
  }

  $candidates = @(
    (Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Origin-Beta\User Data\Local State"),
    (Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Origin-Beta\User Data\Local State")
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  return $candidates[0]
}

function Stop-BraveOrigin {
  Get-Process brave -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Path -like "*\BraveSoftware\Brave-Origin-Beta\Application\brave.exe" -or
      $_.Path -like "*\BraveSoftware\Brave-Origin-Beta\Application\brave.exe"
    } |
    Stop-Process -Force
}

function Read-LocalState {
  param([string] $Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return [pscustomobject]@{}
  }

  $raw = Get-Content -LiteralPath $Path -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return [pscustomobject]@{}
  }

  try {
    return ($raw | ConvertFrom-Json)
  } catch {
    $backup = "$Path.invalid-json.$(Get-Date -Format yyyyMMdd-HHmmss).bak"
    Copy-Item -LiteralPath $Path -Destination $backup -Force
    Write-Host "Backed up invalid Local State JSON to:"
    Write-Host "  $backup"
    return [pscustomobject]@{}
  }
}

$localStatePath = Resolve-LocalStatePath $env:BRAVE_ORIGIN_PROFILE_ARG
$userDataPath = Split-Path -Parent $localStatePath
New-Item -ItemType Directory -Force -Path $userDataPath | Out-Null

Stop-BraveOrigin

$localState = Read-LocalState $localStatePath

$brave = Ensure-PropertyObject $localState "brave"
$origin = Ensure-PropertyObject $brave "origin"
Set-PropertyValue $origin "purchase_validated" $true
Set-PropertyValue $origin "policies_were_enforced" $true

$credentialState = @{
  credentials = @{
    items = @{
      "origin-local-unlock" = @{
        remaining_credential_count = 1
        expires_at = "2999-12-31T23:59:59Z"
      }
    }
  }
} | ConvertTo-Json -Depth 20 -Compress

$skus = Ensure-PropertyObject $localState "skus"
$skusState = Ensure-PropertyObject $skus "state"
Set-PropertyValue $skusState "development" $credentialState
Set-PropertyValue $skusState "staging" $credentialState
Set-PropertyValue $skusState "production" $credentialState

$json = $localState | ConvertTo-Json -Depth 80 -Compress
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($localStatePath, $json, $utf8NoBom)

Write-Host "Brave Origin unlock patch applied."
Write-Host "Patched Local State:"
Write-Host "  $localStatePath"
Write-Host
Write-Host "Thank you for running my first github fork! You probably dont give two shits, but open brave origin stable and it SHOULD work. (NOTE: IF YOU WANT BETA REPLACE ALL Brave-Origin with Brave-Origin-Beta"
Write-Host
Write-Host "What does 'local state' mean? You basically bypassed the pay prompt, so like enjoy brave origin for free. And if it gets patched, i dunno what to say 😭🙏"
