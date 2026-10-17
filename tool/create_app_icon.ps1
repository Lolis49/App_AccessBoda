Add-Type -AssemblyName System.Drawing

$iconDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\icon'
[System.IO.Directory]::CreateDirectory($iconDirectory) | Out-Null
$green = [System.Drawing.ColorTranslator]::FromHtml('#3F5140')
$gold = [System.Drawing.ColorTranslator]::FromHtml('#E8D6A9')

function New-MonogramIcon([bool]$transparent, [string]$fileName) {
    $bitmap = New-Object System.Drawing.Bitmap 1024, 1024
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    if ($transparent) { $graphics.Clear([System.Drawing.Color]::Transparent) }
    else { $graphics.Clear($green) }

    $pen = New-Object System.Drawing.Pen $gold, 8
    $finePen = New-Object System.Drawing.Pen $gold, 2
    $brush = New-Object System.Drawing.SolidBrush $gold
    $font = New-Object System.Drawing.Font 'Georgia', 210, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    try {
        $graphics.DrawEllipse($pen, 144, 144, 736, 736)
        $graphics.DrawEllipse($finePen, 164, 164, 696, 696)
        $rectangle = New-Object System.Drawing.RectangleF 180, 275, 664, 400
        $graphics.DrawString('L&J', $font, $brush, $rectangle, $format)
        $graphics.DrawLine($finePen, 390, 670, 634, 670)
        $graphics.FillEllipse($brush, 504, 704, 16, 16)
        $bitmap.Save((Join-Path $iconDirectory $fileName), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $format.Dispose()
        $font.Dispose()
        $brush.Dispose()
        $finePen.Dispose()
        $pen.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

New-MonogramIcon $false 'app_icon.png'
New-MonogramIcon $true 'app_icon_foreground.png'
