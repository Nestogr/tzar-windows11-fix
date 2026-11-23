<#
  Fix for Tzar: The Burden of the Crown (GOG) on Windows 11 (tested) and 10.

  Actions:
    -Action Install    Backup + fix + verification (used by the installer).
    -Action Repair     Same as Install; self-elevates and shows the result (Start menu shortcut).
    -Action Uninstall  Restores everything from the original backup.

  Exit codes: 0 = verified/ok, 2 = ok with warnings, 1 = error.
  MIT License. https://github.com/Nestogr/tzar-windows11-fix
#>
[CmdletBinding()]
param(
  [ValidateSet('Install', 'Repair', 'Uninstall')] [string]$Action = 'Repair',
  [string]$GameDir,
  [string]$Payload,
  [string]$ResultFile,
  [ValidateSet('', 'es', 'en', 'spanish', 'english')] [string]$Lang = '',
  [switch]$NoUI         # Repair: no message boxes (internal, used after self-elevation)
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $PSCommandPath
if (-not $Payload) { $Payload = Join-Path $ScriptDir 'cnc-ddraw' }
$RegKey = 'HKLM:\SOFTWARE\TzarFix'

# ---------------------------------------------------------------- language (user-facing messages)
if ($Lang -eq 'spanish') { $Lang = 'es' } elseif ($Lang -eq 'english') { $Lang = 'en' }
if (-not $Lang) { $Lang = if ((Get-UICulture).TwoLetterISOLanguageName -eq 'es') { 'es' } else { 'en' } }
$Msgs = @{
  es = @{
    NotAdmin      = 'Hace falta ejecutar como administrador.'
    NoGameDir     = 'No se encuentra la carpeta de Tzar. Reinstala el arreglo y elige la carpeta del juego.'
    NoExe         = 'No se encuentra Tzar.exe en: {0}'
    NoIni         = 'No se encuentra tzar.ini en la carpeta del juego. Verifica los archivos del juego en GOG Galaxy.'
    Running       = 'Tzar se esta ejecutando. Cierralo y vuelve a intentarlo.'
    Unsupported   = 'Esta version de Tzar.exe no es compatible (se espera la version GOG 1.10). No se ha cambiado nada.'
    NoPayload     = 'Faltan los archivos de cnc-ddraw en: {0}'
    Measuring     = 'Abriendo Tzar unos segundos para medir los dispositivos (no toques nada)...'
    GameExited    = 'Tzar se cerro antes de terminar la comprobacion. Revisa el log: {0}'
    Verified      = 'Verificado: Tzar arranca sin el aviso de configuracion no valida.'
    NoMidi        = 'Verificado, pero el juego no detecta ningun dispositivo MIDI: no habra musica.'
    VerifyFail    = 'El arreglo se aplico pero la verificacion fallo ({0}). Revisa el log: {1}'
    Restored      = 'Se ha restaurado la configuracion original del juego.'
    NoBackup      = 'No hay copia de seguridad original en {0}; no hay nada que restaurar.'
    Error         = 'Error: {0}  (log: {1})'
    PlayNow       = '{0}' + "`n`n" + 'Quieres jugar ahora?'
    Title         = 'Reparar Tzar'
    ShimRemoved   = 'Desinstalado el shim de compatibilidad de GOG ({0}).'
    ShimRestored  = 'Reinstalado el shim de compatibilidad de GOG.'
  }
  en = @{
    NotAdmin      = 'This must be run as administrator.'
    NoGameDir     = 'Tzar folder not found. Reinstall the fix and choose the game folder.'
    NoExe         = 'Tzar.exe not found in: {0}'
    NoIni         = 'tzar.ini not found in the game folder. Verify the game files in GOG Galaxy.'
    Running       = 'Tzar is running. Close it and try again.'
    Unsupported   = 'This Tzar.exe version is not supported (GOG 1.10 expected). Nothing was changed.'
    NoPayload     = 'cnc-ddraw files are missing in: {0}'
    Measuring     = 'Opening Tzar for a few seconds to measure devices (do not touch anything)...'
    GameExited    = 'Tzar closed before the check finished. See the log: {0}'
    Verified      = 'Verified: Tzar starts without the invalid configuration warning.'
    NoMidi        = 'Verified, but the game does not detect any MIDI device: there will be no music.'
    VerifyFail    = 'The fix was applied but verification failed ({0}). See the log: {1}'
    Restored      = 'The original game configuration has been restored.'
    NoBackup      = 'No original backup in {0}; nothing to restore.'
    Error         = 'Error: {0}  (log: {1})'
    PlayNow       = '{0}' + "`n`n" + 'Play now?'
    Title         = 'Repair Tzar'
    ShimRemoved   = 'Uninstalled the GOG compatibility shim ({0}).'
    ShimRestored  = 'Reinstalled the GOG compatibility shim.'
  }
}
$T = $Msgs[$Lang]   # user-facing messages
$E = $Msgs['en']    # log is always English

# ---------------------------------------------------------------- helpers
$script:LogFile = $null
function Write-Log([string]$msg) {
  # The log may be shared (e.g. in bug reports): never write the user's profile path / user name
  if ($env:USERPROFILE) { $msg = $msg.Replace($env:USERPROFILE, '%USERPROFILE%') }
  if ($env:USERNAME -and $env:USERNAME.Length -ge 3) { $msg = $msg -ireplace ('\\' + [regex]::Escape($env:USERNAME) + '\\'), '\%USERNAME%\' }
  $line = '{0}  [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Action, $msg
  Write-Host $msg
  if ($script:LogFile) { try { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 } catch {} }
}
function Stop-Tz([string]$key, [object[]]$fmt = @()) {
  $ex = New-Object Exception (($T[$key]) -f $fmt)
  $ex.Data['en'] = ($E[$key]) -f $fmt
  throw $ex
}
function Set-Result([int]$code, [string]$msg) {
  if ($ResultFile) { [IO.File]::WriteAllText($ResultFile, "$code`r`n$msg", (New-Object Text.UTF8Encoding $false)) }
}
function Test-Admin {
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
$Latin1 = [Text.Encoding]::GetEncoding(28591)   # keeps the ini bytes exactly as they are

function Read-Ini([string]$path) { [Collections.Generic.List[string]]([IO.File]::ReadAllLines($path, $Latin1)) }
function Write-Ini([string]$path, $lines) {
  if (Test-Path -LiteralPath $path) { (Get-Item -LiteralPath $path).IsReadOnly = $false }
  [IO.File]::WriteAllLines($path, [string[]]$lines, $Latin1)
}
function Get-IniValue($lines, [string]$section, [string]$key) {
  $in = $false
  foreach ($l in $lines) {
    if ($l -match '^\s*\[(.+?)\]') { $in = ($Matches[1] -eq $section); continue }
    if ($in -and $l -match "^\s*$([regex]::Escape($key))\s*=(.*)$") { return $Matches[1].Trim() }
  }
  $null
}
function Set-IniValue($lines, [string]$section, [string]$key, $value) {
  $start = -1; $end = $lines.Count
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*\[(.+?)\]') {
      if ($start -ge 0) { $end = $i; break }
      if ($Matches[1] -eq $section) { $start = $i }
    }
  }
  if ($start -lt 0) { $lines.Add(''); $lines.Add("[$section]"); $lines.Add("$key=$value"); return }
  $lastKey = $start
  for ($i = $start + 1; $i -lt $end; $i++) {
    if ($lines[$i] -match "^\s*$([regex]::Escape($key))\s*=") { $lines[$i] = "$key=$value"; return }
    if ($lines[$i].Trim()) { $lastKey = $i }
  }
  $lines.Insert($lastKey + 1, "$key=$value")
}

# ---------------------------------------------------------------- game memory reading
if (-not ('TzFix.Mem' -as [type])) {
  Add-Type -Namespace TzFix -Name Mem -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int access, bool inherit, int pid);
[DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out int read);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
'@
}

# Finds the variables used by Tzar.exe's "invalidcfg" check by scanning for the code of its video and
# sound validation functions, instead of relying on hard-coded addresses.
function Find-TzarAddresses([string]$exe) {
  $s = $Latin1.GetString([IO.File]::ReadAllBytes($exe))
  $o = [Text.RegularExpressions.RegexOptions]::Singleline
  $v = [regex]::Match($s, '\xA1(....)\x85\xC0\x74.\x66\xA1(....)\x66\x39\x05(....)\x75.\x66\x39\x05(....)\x7C.\x66\x85\xC0\x74.\xB8\x01\x00\x00\x00\xC3', $o)
  $e = [regex]::Match($s, '\xA1(....)\x85\xC0\x74.\xE8....\x85\xC0\x75.\xE8....\x85\xC0\x75.\xC3', $o)
  $a = [regex]::Match($s, '\x66\xA1(....)\x66\x8B\x0D(....)\x66\x39\x0D(....)\x75.\x66\x8B\x15(....)\x66\x39\x15(....)\x75.\x66\x39\x05(....)\x75.\x0F\xBF\x35(....)\x0F\xBF\xD9\x46\x3B\xF3\x7C.\x66\x85\xC9\x75.\x0F\xBF\x0D(....)\x0F\xBF\xF2\x41\x3B\xCE\x7C.\x66\x85\xD2\x75.\x0F\xBF\x15(....)', $o)
  if (-not ($v.Success -and $e.Success -and $a.Success)) { return $null }
  $u = { param($m, $g) [BitConverter]::ToUInt32($Latin1.GetBytes($m.Groups[$g].Value), 0) }
  [pscustomobject]@{
    DxEnabled = & $u $v 1; DdCount = & $u $v 2; DdCfgM1 = & $u $v 3; DxDevice = & $u $v 4
    CheckOn   = & $u $e 1
    MidiReal  = & $u $a 1; WaveReal = & $u $a 2; WaveCfg = & $u $a 3; DsReal = & $u $a 4; DsCfg = & $u $a 5
    MidiCfg   = & $u $a 6; WaveIdx = & $u $a 7; DsIdx = & $u $a 8; MidiIdx = & $u $a 9
  }
}

# Starts Tzar.exe, waits for its check and reads both what it detected and what it read from the ini.
function Invoke-TzarProbe([string]$gameDir, $addr, [int]$timeoutSec = 25) {
  $exe = Join-Path $gameDir 'Tzar.exe'
  $p = Start-Process -FilePath $exe -WorkingDirectory $gameDir -PassThru
  $h = [IntPtr]::Zero
  try {
    Start-Sleep -Milliseconds 300
    $h = [TzFix.Mem]::OpenProcess(0x0410, $false, $p.Id)
    if ($h -eq [IntPtr]::Zero) { throw 'OpenProcess failed' }
    $rd16 = { param($a) $b = New-Object byte[] 2; $n = 0; [void][TzFix.Mem]::ReadProcessMemory($h, [IntPtr][int64]$a, $b, 2, [ref]$n); [int][BitConverter]::ToInt16($b, 0) }
    $rd32 = { param($a) $b = New-Object byte[] 4; $n = 0; [void][TzFix.Mem]::ReadProcessMemory($h, [IntPtr][int64]$a, $b, 4, [ref]$n); [BitConverter]::ToInt32($b, 0) }
    $sw = [Diagnostics.Stopwatch]::StartNew(); $seen = $false
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSec -and -not $p.HasExited) {
      if ((& $rd16 $addr.DsReal) -ne 0 -or (& $rd16 $addr.WaveReal) -ne 0 -or (& $rd16 $addr.MidiReal) -ne 0) { $seen = $true; break }
      Start-Sleep -Milliseconds 250
    }
    Start-Sleep -Milliseconds 2000   # let the MIDI detection finish
    if ($p.HasExited) { return [pscustomobject]@{ Exited = $true } }
    [pscustomobject]@{
      Exited = $false; Seen = $seen
      CheckOn = & $rd32 $addr.CheckOn; DxEnabled = & $rd32 $addr.DxEnabled; DxDevice = & $rd16 $addr.DxDevice
      DdCount = & $rd16 $addr.DdCount; DdCfgM1 = & $rd16 $addr.DdCfgM1
      WaveReal = & $rd16 $addr.WaveReal; WaveCfg = & $rd16 $addr.WaveCfg; WaveIdx = & $rd16 $addr.WaveIdx
      DsReal = & $rd16 $addr.DsReal; DsCfg = & $rd16 $addr.DsCfg; DsIdx = & $rd16 $addr.DsIdx
      MidiReal = & $rd16 $addr.MidiReal; MidiCfg = & $rd16 $addr.MidiCfg; MidiIdx = & $rd16 $addr.MidiIdx
    }
  } finally {
    if ($h -ne [IntPtr]::Zero) { [void][TzFix.Mem]::CloseHandle($h) }
    if (-not $p.HasExited) { try { Stop-Process -Id $p.Id -Force } catch {} ; [void]$p.WaitForExit(10000) }
    Start-Sleep -Milliseconds 500
  }
}

# Mirrors the game's logic (Tzar.exe 1.10): returns the list of failures; empty = valid.
function Test-TzarConfig($m) {
  $f = @()
  if ($m.CheckOn -eq 0) { return $f }
  if ($m.DxEnabled -ne 0) {
    if ($m.DdCfgM1 -ne $m.DdCount) { $f += "DIRECTDRAW_DEVICESNUMBER=$($m.DdCfgM1 + 1) (game: $($m.DdCount + 1))" }
    elseif ($m.DxDevice -ge $m.DdCount -and $m.DdCount -ne 0) { $f += "DIRECTXDEVICE=$($m.DxDevice)" }
  }
  if ($m.WaveCfg -ne $m.WaveReal) { $f += "SOUNDDEVICENUMBER=$($m.WaveCfg) (game: $($m.WaveReal))" }
  if ($m.DsCfg -ne $m.DsReal) { $f += "SOUNDDEVICEDXNUMBER=$($m.DsCfg) (game: $($m.DsReal))" }
  if ($m.MidiCfg -ne $m.MidiReal) { $f += "SOUNDDEVICEMIDINUMBER=$($m.MidiCfg) (game: $($m.MidiReal))" }
  if (-not (($m.WaveIdx + 1) -lt $m.WaveReal -or $m.WaveReal -eq 0)) { $f += "SOUNDDEVICE=$($m.WaveIdx)" }
  if (-not (($m.DsIdx + 1) -lt $m.DsReal -or $m.DsReal -eq 0)) { $f += "SOUNDDEVICEDX=$($m.DsIdx)" }
  if (-not (($m.MidiIdx + 1) -lt $m.MidiReal -or $m.MidiReal -eq 0)) { $f += "SOUNDDEVICEMIDI=$($m.MidiIdx)" }
  $f
}

# ---------------------------------------------------------------- GOG shim and compatibility layers
$AcfRoot  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags'
function Get-GogShims {
  $custom = "$AcfRoot\Custom\Tzar.exe"
  if (-not (Test-Path $custom)) { return @() }
  @((Get-Item $custom).Property | Where-Object { $_ -match '^\{[0-9a-fA-F-]+\}\.sdb$' } | ForEach-Object {
      $g = $_ -replace '\.sdb$', ''
      $i = Get-ItemProperty "$AcfRoot\InstalledSDB\$g" -ErrorAction SilentlyContinue
      if ($i -and $i.DatabaseDescription -like '*GOG*Tzar*') { [pscustomobject]@{ Guid = $g; Path = $i.DatabasePath; Description = $i.DatabaseDescription } }
    })
}
function Invoke-Sdbinst([string[]]$arguments) {
  # Start-Process does not quote arguments: paths with spaces would be split
  $quoted = $arguments | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }
  $p = Start-Process -FilePath (Join-Path $env:windir 'System32\sdbinst.exe') -ArgumentList $quoted -Wait -PassThru -WindowStyle Hidden
  $p.ExitCode
}
$LayerKeys = @('HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers', "$AcfRoot\Layers")
function Get-TzarLayers([string]$gameDir) {
  $exe = (Join-Path $gameDir 'Tzar.exe')
  foreach ($k in $LayerKeys) {
    if (-not (Test-Path $k)) { continue }
    $item = Get-Item $k
    foreach ($n in $item.Property) {
      if ($n -ieq $exe) { [pscustomobject]@{ Key = $k; Name = $n; Value = $item.GetValue($n) } }
    }
  }
}

# ---------------------------------------------------------------- paths
function Get-VirtualStoreIni([string]$gameDir) {
  if ($gameDir.Length -lt 4 -or $gameDir[1] -ne ':') { return $null }
  Join-Path (Join-Path $env:LOCALAPPDATA 'VirtualStore') (Join-Path $gameDir.Substring(3) 'tzar.ini')
}
$PayloadItems = @('ddraw.dll', 'ddraw.ini', 'cnc-ddraw config.exe', 'Shaders')

# ---------------------------------------------------------------- backup
function New-OriginalBackup([string]$gameDir, [string]$orig) {
  if (Test-Path -LiteralPath (Join-Path $orig 'manifest.json')) { Write-Log "Original backup already exists, left untouched: $orig"; return }
  Write-Log "Creating original backup: $orig"
  $files = Join-Path $orig 'files'
  New-Item -ItemType Directory -Force -Path $files | Out-Null
  $m = [ordered]@{ created = (Get-Date).ToString('s'); gameDir = $gameDir; computer = 'local'; items = [ordered]@{} }

  Copy-Item -LiteralPath (Join-Path $gameDir 'tzar.ini') -Destination (Join-Path $files 'tzar.ini')
  $vs = Get-VirtualStoreIni $gameDir
  $m.virtualStoreIni = [bool]($vs -and (Test-Path -LiteralPath $vs))
  if ($m.virtualStoreIni) { Copy-Item -LiteralPath $vs -Destination (Join-Path $files 'virtualstore_tzar.ini') }

  foreach ($it in $PayloadItems) {
    $src = Join-Path $gameDir $it
    $ex = Test-Path -LiteralPath $src
    $m.items[$it] = $ex
    if ($ex) { Copy-Item -LiteralPath $src -Destination (Join-Path $files $it) -Recurse }
  }
  $sdb = Join-Path $gameDir 'goggame.sdb'
  if (Test-Path -LiteralPath $sdb) { Copy-Item -LiteralPath $sdb -Destination (Join-Path $files 'goggame.sdb') }

  $shims = @(Get-GogShims)
  $m.shims = @()
  foreach ($s in $shims) {
    $sd = Join-Path $orig "shim\$($s.Guid)"
    New-Item -ItemType Directory -Force -Path $sd | Out-Null
    if ($s.Path -and (Test-Path -LiteralPath $s.Path)) { Copy-Item -LiteralPath $s.Path -Destination (Join-Path $sd "$($s.Guid).sdb") }
    & reg.exe export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\InstalledSDB\$($s.Guid)" (Join-Path $sd 'InstalledSDB.reg') /y /reg:64 | Out-Null
    & reg.exe export 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom\Tzar.exe' (Join-Path $sd 'Custom_Tzar.exe.reg') /y /reg:64 | Out-Null
    $m.shims += [ordered]@{ guid = $s.Guid; description = $s.Description }
  }
  $m.layers = @(Get-TzarLayers $gameDir | ForEach-Object { [ordered]@{ key = $_.Key; name = $_.Name; value = $_.Value } })
  ($m | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath (Join-Path $orig 'manifest.json') -Encoding UTF8
  Write-Log ("Original state: shims={0} layers={1} previous ddraw.dll={2} VirtualStore={3}" -f $m.shims.Count, $m.layers.Count, $m.items['ddraw.dll'], $m.virtualStoreIni)
}

# ---------------------------------------------------------------- INSTALL / REPAIR
function Invoke-Fix([string]$gameDir) {
  $exe = Join-Path $gameDir 'Tzar.exe'
  $ini = Join-Path $gameDir 'tzar.ini'
  if (-not (Test-Path -LiteralPath $ini)) { Stop-Tz 'NoIni' }
  foreach ($it in @('ddraw.dll', 'ddraw.ini')) { if (-not (Test-Path -LiteralPath (Join-Path $Payload $it))) { Stop-Tz 'NoPayload' @($Payload) } }
  $addr = Find-TzarAddresses $exe
  if (-not $addr) { Stop-Tz 'Unsupported' }
  Write-Log ('Tzar.exe supported ({0:X}/{1:X}/{2:X})' -f $addr.DdCount, $addr.WaveReal, $addr.MidiReal)

  # 1. Backups
  $bkRoot = Join-Path $gameDir '_tzarfix_backup'
  New-OriginalBackup $gameDir (Join-Path $bkRoot 'original')
  $run = Join-Path $bkRoot ('run_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
  New-Item -ItemType Directory -Force -Path $run | Out-Null
  Copy-Item -LiteralPath $ini -Destination $run
  $vs = Get-VirtualStoreIni $gameDir
  if ($vs -and (Test-Path -LiteralPath $vs)) { Copy-Item -LiteralPath $vs -Destination (Join-Path $run 'virtualstore_tzar.ini') }
  Write-Log "Backup of this run: $run"

  # 2. GOG shim (EmulateHeap): makes winmm fail inside the game -> no MIDI/wave
  foreach ($s in @(Get-GogShims)) {
    $rc = Invoke-Sdbinst @('-q', '-u', '-g', $s.Guid)
    Write-Log (($E.ShimRemoved -f $s.Guid) + " sdbinst=$rc")
    if ($rc -ne 0 -and @(Get-GogShims).Count) { throw "sdbinst -u $($s.Guid) = $rc" }
  }
  # Compatibility layers on Tzar.exe (e.g. DWM8And16BitMitigation) interfere with cnc-ddraw
  foreach ($l in @(Get-TzarLayers $gameDir)) {
    Remove-ItemProperty -LiteralPath $l.Key -Name $l.Name
    Write-Log "Removed compatibility layer: $($l.Key) = $($l.Value)"
  }

  # 3. cnc-ddraw
  foreach ($it in $PayloadItems) {
    $src = Join-Path $Payload $it; $dst = Join-Path $gameDir $it
    if (-not (Test-Path -LiteralPath $src)) { continue }
    if ($it -eq 'ddraw.ini' -and (Test-Path -LiteralPath $dst) -and (Select-String -LiteralPath $dst -Pattern '^\s*renderer\s*=' -Quiet)) {
      Write-Log 'cnc-ddraw ddraw.ini already present: kept (user settings).'; continue
    }
    if ((Test-Path -LiteralPath $dst) -and (Get-Item -LiteralPath $dst).PSIsContainer) { Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force }
    else { Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force }
  }
  Write-Log 'cnc-ddraw installed.'

  # 4. tzar.ini: required fixed values
  $base = [ordered]@{
    'VIDEO|DIRECTXDEVICE' = 0; 'VIDEO|BUFFER_IN_VIDEO_MEMORY' = 0; 'SETUP|DONESETUP' = 1
    'SOUND|SOUNDDEVICE' = -1; 'SOUND|SOUNDDEVICEDX' = -1; 'SOUND|SOUNDDEVICEMIDI' = -1
  }
  $targets = @($ini) + @($vs | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
  function Update-Inis($values) {
    foreach ($f in $targets) {
      $l = Read-Ini $f
      foreach ($k in $values.Keys) { $sec, $key = $k -split '\|'; Set-IniValue $l $sec $key $values[$k] }
      Write-Ini $f $l
    }
  }
  Update-Inis $base

  # 5. Measure the devices the way the game does
  Write-Log $E.Measuring
  $m = Invoke-TzarProbe $gameDir $addr
  if ($m.Exited) { Stop-Tz 'GameExited' @($script:LogFile) }
  Write-Log ("Measured in game: DirectDraw={0} wave={1} DirectSound={2} MIDI={3} (check={4}, seen={5})" -f ($m.DdCount + 1), $m.WaveReal, $m.DsReal, $m.MidiReal, $m.CheckOn, $m.Seen)
  $vals = [ordered]@{
    'VIDEO|DIRECTDRAW_DEVICESNUMBER' = $m.DdCount + 1
    'SOUND|SOUNDDEVICENUMBER' = $m.WaveReal; 'SOUND|SOUNDDEVICEDXNUMBER' = $m.DsReal; 'SOUND|SOUNDDEVICEMIDINUMBER' = $m.MidiReal
  }
  if ($m.MidiReal -gt 0) { $vals['SOUND|MUSIC'] = 1; $vals['SOUND|CDAUDIO'] = 0 }
  Update-Inis $vals
  Write-Log ('tzar.ini updated: ' + (($vals.Keys | ForEach-Object { "$($_.Split('|')[1])=$($vals[$_])" }) -join ' '))

  # 6. Verify with a second start
  $v = Invoke-TzarProbe $gameDir $addr
  if ($v.Exited) { Stop-Tz 'GameExited' @($script:LogFile) }
  $fails = @(Test-TzarConfig $v)
  if ($fails.Count) { Write-Log ('Verification FAILED: ' + ($fails -join '; ')); return @(1, ($T.VerifyFail -f ($fails -join ', '), $script:LogFile)) }
  if ($m.MidiReal -le 0) { Write-Log $E.NoMidi; return @(2, $T.NoMidi) }
  Write-Log $E.Verified
  @(0, $T.Verified)
}

# ---------------------------------------------------------------- UNINSTALL
function Invoke-Restore([string]$gameDir) {
  $bkRoot = Join-Path $gameDir '_tzarfix_backup'
  $orig = Join-Path $bkRoot 'original'
  $mf = Join-Path $orig 'manifest.json'
  if (-not (Test-Path -LiteralPath $mf)) { Write-Log ($E.NoBackup -f $orig); return @(2, ($T.NoBackup -f $orig)) }
  $m = Get-Content -LiteralPath $mf -Raw -Encoding UTF8 | ConvertFrom-Json
  $files = Join-Path $orig 'files'
  $errors = @()

  # Save the current state before restoring
  $pre = Join-Path $bkRoot ('before_uninstall_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
  New-Item -ItemType Directory -Force -Path $pre | Out-Null
  foreach ($f in @('tzar.ini', 'ddraw.ini')) { $p = Join-Path $gameDir $f; if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination $pre } }

  try { Copy-Item -LiteralPath (Join-Path $files 'tzar.ini') -Destination (Join-Path $gameDir 'tzar.ini') -Force; Write-Log 'Restored tzar.ini' } catch { $errors += "tzar.ini: $_" }
  $vs = Get-VirtualStoreIni $gameDir
  if ($vs) {
    if ($m.virtualStoreIni) { Copy-Item -LiteralPath (Join-Path $files 'virtualstore_tzar.ini') -Destination $vs -Force; Write-Log 'Restored VirtualStore tzar.ini' }
    elseif (Test-Path -LiteralPath $vs) { Move-Item -LiteralPath $vs -Destination (Join-Path $pre 'virtualstore_tzar.ini') -Force; Write-Log 'Moved away VirtualStore tzar.ini created after the fix' }
  }
  foreach ($it in $PayloadItems) {
    $dst = Join-Path $gameDir $it
    try {
      if ($m.items.$it) {
        if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
        Copy-Item -LiteralPath (Join-Path $files $it) -Destination $dst -Recurse -Force; Write-Log "Restored original $it"
      } elseif (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force; Write-Log "Deleted $it" }
    } catch { $errors += "${it}: $_" }
  }
  foreach ($l in @($m.layers)) {
    if (-not $l) { continue }
    try {
      if (-not (Test-Path $l.key)) { New-Item -Path $l.key -Force | Out-Null }
      New-ItemProperty -LiteralPath $l.key -Name $l.name -Value $l.value -PropertyType String -Force | Out-Null
      Write-Log "Restored compatibility layer: $($l.name) = $($l.value)"
    } catch { $errors += "layer: $_" }
  }
  foreach ($s in @($m.shims)) {
    if (-not $s) { continue }
    if (@(Get-GogShims | Where-Object { $_.Guid -eq $s.guid }).Count) { Write-Log "Shim $($s.guid) already installed"; continue }
    $cands = @((Join-Path $orig "shim\$($s.guid)\$($s.guid).sdb"), (Join-Path $gameDir 'goggame.sdb'), (Join-Path $files 'goggame.sdb')) |
      Where-Object { Test-Path -LiteralPath $_ }
    $ok = $false
    foreach ($sdb in $cands) {
      $rc = Invoke-Sdbinst @('-q', $sdb)
      Write-Log "sdbinst -q $sdb = $rc"
      if ($rc -eq 0 -and @(Get-GogShims | Where-Object { $_.Guid -eq $s.guid }).Count) { $ok = $true; Write-Log $E.ShimRestored; break }
    }
    if (-not $ok) { $errors += "sdbinst ($($s.guid))" }
  }
  # On errors keep 'original' so the restore can be retried and a later install never takes the fixed state as original
  if ($errors.Count) { Write-Log ('Errors (original backup kept for retry): ' + ($errors -join '; ')); return @(1, ($T.Error -f ($errors -join '; '), $script:LogFile)) }
  # Allows a future install to take a fresh original backup
  Rename-Item -LiteralPath $orig -NewName ('restored_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
  Write-Log $E.Restored
  @(0, $T.Restored)
}

# ---------------------------------------------------------------- Repair from the Start menu (not elevated)
if ($Action -eq 'Repair' -and -not $NoUI) {
  Add-Type -AssemblyName System.Windows.Forms
  if (-not $GameDir) { $GameDir = (Get-ItemProperty $RegKey -ErrorAction SilentlyContinue).GameDir }
  $rf = Join-Path $env:TEMP ("tzarfix_{0}.txt" -f [guid]::NewGuid())
  $args2 = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Action', 'Repair', '-NoUI', '-ResultFile', "`"$rf`"", '-Lang', $Lang)
  if ($GameDir) { $args2 += @('-GameDir', "`"$GameDir`"") }
  try { $p = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $args2 -Verb RunAs -Wait -PassThru }
  catch { [Windows.Forms.MessageBox]::Show($T.NotAdmin, $T.Title, 'OK', 'Warning') | Out-Null; exit 1 }
  $code = 1; $msg = $T.Error -f 'no result', ''
  if (Test-Path -LiteralPath $rf) { $c = [IO.File]::ReadAllText($rf) -split "`r`n", 2; $code = [int]$c[0]; $msg = $c[1]; Remove-Item -LiteralPath $rf -Force }
  if ($code -eq 1) { [Windows.Forms.MessageBox]::Show($msg, $T.Title, 'OK', 'Error') | Out-Null; exit 1 }
  if (-not $GameDir) { $GameDir = (Get-ItemProperty $RegKey -ErrorAction SilentlyContinue).GameDir }
  if ([Windows.Forms.MessageBox]::Show(($T.PlayNow -f $msg), $T.Title, 'YesNo', 'Information') -eq 'Yes') {
    Start-Process -FilePath (Join-Path $GameDir 'Tzar.exe') -WorkingDirectory $GameDir
  }
  exit $code
}

# ---------------------------------------------------------------- main (elevated)
$code = 1; $msg = ''
try {
  if (-not (Test-Admin)) { Stop-Tz 'NotAdmin' }
  if (-not $GameDir) { $GameDir = (Get-ItemProperty $RegKey -ErrorAction SilentlyContinue).GameDir }
  if (-not $GameDir) { Stop-Tz 'NoGameDir' }
  $GameDir = $GameDir.TrimEnd('\')
  if (-not (Test-Path -LiteralPath (Join-Path $GameDir 'Tzar.exe'))) { Stop-Tz 'NoExe' @($GameDir) }
  $bk = Join-Path $GameDir '_tzarfix_backup'
  New-Item -ItemType Directory -Force -Path $bk | Out-Null
  $script:LogFile = Join-Path $bk 'log.txt'
  Write-Log ("==== {0} | {1} | PS {2} | {3}" -f $Action, [Environment]::OSVersion.VersionString, $PSVersionTable.PSVersion, $GameDir)
  if (Get-Process -Name 'Tzar' -ErrorAction SilentlyContinue) { Stop-Tz 'Running' }

  $r = if ($Action -eq 'Uninstall') { Invoke-Restore $GameDir } else { Invoke-Fix $GameDir }
  $code = $r[0]; $msg = $r[1]
} catch {
  $err = $_.Exception.Message
  $known = $_.Exception.Data.Contains('en')
  $errEn = if ($known) { $_.Exception.Data['en'] } else { $err }
  $where = if ($known) { '' } else { " (line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim()))" }
  if ($script:LogFile) { Write-Log ("ERROR: $errEn$where") }
  $msg = if ($known) { $err } else { $T.Error -f $err, $script:LogFile }
  $code = 1
}
Set-Result $code $msg
exit $code
