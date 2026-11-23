# Genera src\tzarfix.ico (PNG 256x256 dentro de un ICO). Solo hace falta si se quiere regenerar.
Add-Type -AssemblyName System.Drawing
$size = 256
$bmp = New-Object Drawing.Bitmap $size, $size
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([Drawing.Color]::Transparent)
$bg = New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.Point]::new(0, 0)), ([Drawing.Point]::new(0, $size)), ([Drawing.Color]::FromArgb(255, 70, 62, 52)), ([Drawing.Color]::FromArgb(255, 28, 24, 20))
$path = New-Object Drawing.Drawing2D.GraphicsPath
$r = 48; $path.AddArc(8, 8, $r, $r, 180, 90); $path.AddArc($size - 8 - $r, 8, $r, $r, 270, 90)
$path.AddArc($size - 8 - $r, $size - 8 - $r, $r, $r, 0, 90); $path.AddArc(8, $size - 8 - $r, $r, $r, 90, 90); $path.CloseFigure()
$g.FillPath($bg, $path)
$g.DrawPath((New-Object Drawing.Pen ([Drawing.Color]::FromArgb(255, 200, 150, 40)), 10), $path)
# corona / crown
$gold = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 230, 170, 40))
$crown = [Drawing.Point[]]@([Drawing.Point]::new(56, 120), [Drawing.Point]::new(76, 52), [Drawing.Point]::new(102, 96), [Drawing.Point]::new(128, 40),
  [Drawing.Point]::new(154, 96), [Drawing.Point]::new(180, 52), [Drawing.Point]::new(200, 120))
$g.FillPolygon($gold, $crown)
$g.FillRectangle($gold, 56, 120, 144, 18)
# "T"
$font = New-Object Drawing.Font 'Georgia', 92, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
$sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'
$g.DrawString('T', $font, $gold, (New-Object Drawing.RectangleF 0, 132, $size, 110), $sf)
$g.Dispose()
$ms = New-Object IO.MemoryStream; $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $png = $ms.ToArray()
$out = Join-Path (Split-Path $PSScriptRoot) 'src\tzarfix.ico'
$fs = [IO.File]::Create($out); $w = New-Object IO.BinaryWriter $fs
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]1)
$w.Write([byte]0); $w.Write([byte]0); $w.Write([byte]0); $w.Write([byte]0)
$w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$png.Length); $w.Write([uint32]22)
$w.Write($png); $w.Close()
"Icono: $out ($($png.Length) bytes)"
