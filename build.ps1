<#
  build.ps1 - Builds the installer.
    .\build.ps1 [-Version 1.0.0] [-Iscc <path to ISCC.exe>]
  Downloads cnc-ddraw (pinned version, verified by SHA256), prepares build\payload and runs Inno Setup.
#>
param(
  [string]$Version = '1.0.0',
  [string]$Iscc
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

# Pinned, tested cnc-ddraw release
$CncVersion = 'v7.1.0.0'
$CncUrl     = "https://github.com/FunkyFr3sh/cnc-ddraw/releases/download/$CncVersion/cnc-ddraw.zip"
$CncSha256  = '0B13AB89A64C9918189B1DADD449EF6ED3CB3B7B19CABD96D8ADBD95505BB908'

$build   = Join-Path $Root 'build'
$zip     = Join-Path $build "cnc-ddraw-$CncVersion.zip"
$payload = Join-Path $build 'payload\cnc-ddraw'
New-Item -ItemType Directory -Force -Path $build | Out-Null

if (-not (Test-Path $zip) -or (Get-FileHash $zip -Algorithm SHA256).Hash -ne $CncSha256) {
  Write-Host "Downloading cnc-ddraw $CncVersion..."
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri $CncUrl -OutFile $zip -UseBasicParsing
}
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash
if ($hash -ne $CncSha256) { throw "cnc-ddraw SHA256 mismatch: $hash" }

if (Test-Path $payload) { Remove-Item $payload -Recurse -Force }
New-Item -ItemType Directory -Force -Path $payload | Out-Null
Expand-Archive -Path $zip -DestinationPath $payload -Force

# Settings tested with Tzar
$ini = Join-Path $payload 'ddraw.ini'
$t = [IO.File]::ReadAllText($ini)
$t = $t -replace '(?m)^fullscreen=false', 'fullscreen=true' -replace '(?m)^maintas=false', 'maintas=true' -replace '(?m)^vsync=false', 'vsync=true'
[IO.File]::WriteAllText($ini, $t)
Copy-Item (Join-Path $Root 'third_party\cnc-ddraw\LICENSE') (Join-Path $payload 'cnc-ddraw-LICENSE.txt')

if (-not $Iscc) {
  $Iscc = @(
    (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source,
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
  ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $Iscc) { throw 'ISCC.exe (Inno Setup 6) not found. Install it with: winget install JRSoftware.InnoSetup' }

& $Iscc "/DAppVersion=$Version" "/DPayloadDir=$build\payload" (Join-Path $Root 'src\TzarFix.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }
Get-ChildItem (Join-Path $Root 'dist') -Filter *.exe | ForEach-Object { "{0}  {1}" -f $_.FullName, (Get-FileHash $_.FullName).Hash }
