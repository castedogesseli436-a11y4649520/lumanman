$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$sourcePath = Join-Path $root 'work/design-spec/approved/app-icon.png'
if ((Get-FileHash $sourcePath).Hash -ne 'C416E2BDBD5A9AE31735940A2348A3AA4529CEAAF1565DADA781078048FD6A61') {
    throw 'Locked icon hash mismatch. Stop without replacing assets.'
}
$res = Join-Path $root 'app/android/app/src/main/res'
$source = [System.Drawing.Image]::FromFile($sourcePath)
$background = [System.Drawing.ColorTranslator]::FromHtml('#BB4C2C')

function Save-Icon([int]$size, [int]$contentSize, [string]$path, [bool]$rounded) {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = 'HighQualityBicubic'
    $graphics.PixelOffsetMode = 'HighQuality'
    $graphics.SmoothingMode = 'AntiAlias'
    $graphics.Clear($background)
    $offset = [int](($size - $contentSize) / 2)
    if ($rounded) {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $clip = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $diameter = [single]($size * .46)
        $edge = [single]($size - $diameter)
        $clip.AddArc(0, 0, $diameter, $diameter, 180, 90)
        $clip.AddArc($edge, 0, $diameter, $diameter, 270, 90)
        $clip.AddArc($edge, $edge, $diameter, $diameter, 0, 90)
        $clip.AddArc(0, $edge, $diameter, $diameter, 90, 90)
        $clip.CloseFigure()
        $graphics.SetClip($clip)
        $clip.Dispose()
    }
    $graphics.DrawImage($source, $offset, $offset, $contentSize, $contentSize)
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    $check = [System.Drawing.Image]::FromFile($path)
    if ($check.Width -ne $size -or $check.Height -ne $size) { throw "Invalid dimensions: $path" }
    $check.Dispose()
}

foreach ($density in @(@('mdpi', 1), @('hdpi', 1.5), @('xhdpi', 2), @('xxhdpi', 3), @('xxxhdpi', 4))) {
    $folder = Join-Path $res "mipmap-$($density[0])"
    $scale = $density[1]
    Save-Icon (48 * $scale) (48 * $scale) (Join-Path $folder 'ic_launcher.png') $true
    # The central 72 dp of the 108 dp layer holds the unchanged artwork.
    Save-Icon (108 * $scale) (72 * $scale) (Join-Path $folder 'ic_launcher_foreground.png') $false
    Write-Output "$($density[0]): legacy $([int](48 * $scale)) px; adaptive $([int](108 * $scale)) px"
}
$source.Dispose()

# Simulate the launcher masks from the generated adaptive resource, not a new design.
$foreground = [System.Drawing.Image]::FromFile((Join-Path $res 'mipmap-xxxhdpi/ic_launcher_foreground.png'))
$preview = [System.Drawing.Bitmap]::new(560, 270)
$canvas = [System.Drawing.Graphics]::FromImage($preview)
$canvas.Clear([System.Drawing.ColorTranslator]::FromHtml('#F3F0E7'))
$canvas.InterpolationMode = 'HighQualityBicubic'
$canvas.SmoothingMode = 'AntiAlias'
$font = [System.Drawing.Font]::new('Microsoft YaHei', 12)
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#1E281F'))
$canvas.DrawString('Android 图标资源 · 裁切预览', $font, $brush, 24, 15)
foreach ($sample in @(@(24, 72, 144, $false), @(208, 72, 144, $true), @(404, 118, 48, $false), @(484, 118, 48, $true))) {
    $x, $y, $size, $circle = $sample
    $state = $canvas.Save()
    $mask = [System.Drawing.Drawing2D.GraphicsPath]::new()
    if ($circle) {
        $mask.AddEllipse($x, $y, $size, $size)
    } else {
        $d = [single]($size * .46)
        $mask.AddArc($x, $y, $d, $d, 180, 90)
        $mask.AddArc(($x + $size - $d), $y, $d, $d, 270, 90)
        $mask.AddArc(($x + $size - $d), ($y + $size - $d), $d, $d, 0, 90)
        $mask.AddArc($x, ($y + $size - $d), $d, $d, 90, 90)
        $mask.CloseFigure()
    }
    $canvas.SetClip($mask)
    $canvas.DrawImage($foreground, [System.Drawing.Rectangle]::new($x, $y, $size, $size), 72, 72, 288, 288, [System.Drawing.GraphicsUnit]::Pixel)
    $canvas.Restore($state)
    $mask.Dispose()
}
$canvas.DrawString('圆角方形', $font, $brush, 52, 230)
$canvas.DrawString('圆形', $font, $brush, 262, 230)
$canvas.DrawString('48 px', $font, $brush, 440, 190)
$preview.Save((Join-Path $PSScriptRoot 'app-icon-android-preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$foreground.Dispose()
$font.Dispose()
$brush.Dispose()
$canvas.Dispose()
$preview.Dispose()
