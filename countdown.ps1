# Desktop countdown — WPF circle, transparent center (Windows built-in)
param(
    [Parameter(Position = 0)]
    [int]$Minutes = 0,
    [Parameter(Position = 1)]
    [int]$Seconds = 0
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms

function Hide-ConsoleWindow {
    if (-not ('Win32.ConsoleWindow' -as [type])) {
        Add-Type -Namespace Win32 -Name ConsoleWindow -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
'@
    }
    $handle = [Win32.ConsoleWindow]::GetConsoleWindow()
    if ($handle -ne [IntPtr]::Zero) {
        [void][Win32.ConsoleWindow]::ShowWindow($handle, 0)
    }
}

function Format-Remaining([int]$sec) {
    $m = [math]::Floor($sec / 60)
    $s = $sec % 60
    return ('{0:00}:{1:00}' -f $m, $s)
}

function Get-CountdownAppRoot {
    if (-not [string]::IsNullOrEmpty($PSScriptRoot)) {
        return $PSScriptRoot
    }
    try {
        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        if (-not [string]::IsNullOrEmpty($exePath)) {
            return [System.IO.Path]::GetDirectoryName($exePath)
        }
    } catch { }
    return (Get-Location).Path
}

function Get-CountdownSettingsPath {
    Join-Path (Get-CountdownAppRoot) 'countdown.settings.json'
}

function Get-CountdownSettings {
    $settings = @{
        Minutes            = 5
        Seconds            = 0
        BorderColorArgb    = [System.Drawing.Color]::FromArgb(217, 255, 255, 255).ToArgb()
        TimeShadowEnabled  = $true
        TimeShadowBlur     = 10
        WarnSeconds        = 10
        SoundEnabled       = $true
        ProgressBulgeEnabled = $true
    }
    $path = Get-CountdownSettingsPath
    if (-not (Test-Path -LiteralPath $path)) { return $settings }
    try {
        $json = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $json.Minutes) { $settings.Minutes = [int]$json.Minutes }
        if ($null -ne $json.Seconds) { $settings.Seconds = [int]$json.Seconds }
        if ($null -ne $json.BorderColorArgb) {
            $settings.BorderColorArgb = [int]$json.BorderColorArgb
        }
        if ($null -ne $json.TimeShadowEnabled) {
            $settings.TimeShadowEnabled = [bool]$json.TimeShadowEnabled
        }
        if ($null -ne $json.TimeShadowBlur) {
            $settings.TimeShadowBlur = [double]$json.TimeShadowBlur
        }
        if ($null -ne $json.WarnSeconds) { $settings.WarnSeconds = [int]$json.WarnSeconds }
        if ($null -ne $json.SoundEnabled) { $settings.SoundEnabled = [bool]$json.SoundEnabled }
        if ($null -ne $json.ProgressBulgeEnabled) {
            $settings.ProgressBulgeEnabled = [bool]$json.ProgressBulgeEnabled
        }
    } catch { }
    if ($settings.Seconds -lt 0) { $settings.Seconds = 0 }
    if ($settings.Seconds -gt 59) { $settings.Seconds = 59 }
    if ($settings.Minutes -lt 0) { $settings.Minutes = 0 }
    if ($settings.WarnSeconds -lt 0) { $settings.WarnSeconds = 0 }
    if ($settings.WarnSeconds -gt 600) { $settings.WarnSeconds = 600 }
    if ($settings.TimeShadowBlur -lt 0) { $settings.TimeShadowBlur = 0 }
    if ($settings.TimeShadowBlur -gt 80) { $settings.TimeShadowBlur = 80 }
    return $settings
}

function Save-CountdownSettings {
    param(
        [int]$Minutes,
        [int]$Seconds,
        [System.Drawing.Color]$BorderColor,
        [bool]$TimeShadowEnabled,
        [double]$TimeShadowBlur,
        [int]$WarnSeconds,
        [bool]$SoundEnabled,
        [bool]$ProgressBulgeEnabled
    )
    $path = Get-CountdownSettingsPath
    $data = @{
        Minutes              = $Minutes
        Seconds              = $Seconds
        BorderColorArgb      = $BorderColor.ToArgb()
        TimeShadowEnabled    = $TimeShadowEnabled
        TimeShadowBlur       = $TimeShadowBlur
        WarnSeconds          = $WarnSeconds
        SoundEnabled         = $SoundEnabled
        ProgressBulgeEnabled = $ProgressBulgeEnabled
    }
    if (Test-Path -LiteralPath $path) {
        try {
            $existing = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($prop in $existing.PSObject.Properties) {
                if ($prop.Name -notin @(
                        'Minutes', 'Seconds', 'BorderColorArgb', 'TimeShadowEnabled',
                        'TimeShadowBlur', 'WarnSeconds', 'SoundEnabled', 'ProgressBulgeEnabled')) {
                    $data[$prop.Name] = $prop.Value
                }
            }
        } catch { }
    }
    $data | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
}

function Show-SetupDialog {
    param([System.Drawing.Color]$InitialBorderColor)
    Hide-ConsoleWindow
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = '倒计时'
    $dlg.Size = New-Object System.Drawing.Size(360, 452)
    $dlg.StartPosition = 'CenterScreen'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)

    $labelW = 108
    $inputX = 136
    $inputW = 196

    $lblM = New-Object System.Windows.Forms.Label
    $lblM.Text = '分钟'
    $lblM.Location = New-Object System.Drawing.Point(20, 28)
    $lblM.Size = New-Object System.Drawing.Size($labelW, 24)
    $lblM.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $numM = New-Object System.Windows.Forms.NumericUpDown
    $numM.Location = New-Object System.Drawing.Point($inputX, 24)
    $numM.Size = New-Object System.Drawing.Size($inputW, 28)
    $numM.Maximum = 9999

    $lblS = New-Object System.Windows.Forms.Label
    $lblS.Text = '秒'
    $lblS.Location = New-Object System.Drawing.Point(20, 68)
    $lblS.Size = New-Object System.Drawing.Size($labelW, 24)
    $lblS.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $numS = New-Object System.Windows.Forms.NumericUpDown
    $numS.Location = New-Object System.Drawing.Point($inputX, 64)
    $numS.Size = New-Object System.Drawing.Size($inputW, 28)
    $numS.Maximum = 59

    $lblW = New-Object System.Windows.Forms.Label
    $lblW.Text = '最后提醒 (秒)'
    $lblW.Location = New-Object System.Drawing.Point(20, 108)
    $lblW.Size = New-Object System.Drawing.Size($labelW, 24)
    $lblW.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $numW = New-Object System.Windows.Forms.NumericUpDown
    $numW.Location = New-Object System.Drawing.Point($inputX, 104)
    $numW.Size = New-Object System.Drawing.Size($inputW, 28)
    $numW.Maximum = 600
    $chkMute = New-Object System.Windows.Forms.CheckBox
    $chkMute.Text = '关闭提醒声音'
    $chkMute.Location = New-Object System.Drawing.Point($inputX, 136)
    $chkMute.Size = New-Object System.Drawing.Size($inputW, 24)
    $chkMute.Checked = $false

    $lblC = New-Object System.Windows.Forms.Label
    $lblC.Text = '边框颜色'
    $lblC.Location = New-Object System.Drawing.Point(20, 168)
    $lblC.Size = New-Object System.Drawing.Size($labelW, 24)
    $lblC.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $panelC = New-Object System.Windows.Forms.Panel
    $panelC.Location = New-Object System.Drawing.Point($inputX, 164)
    $panelC.Size = New-Object System.Drawing.Size(28, 28)
    $panelC.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $panelC.BackColor = $InitialBorderColor
    $btnPickC = New-Object System.Windows.Forms.Button
    $btnPickC.Text = '选择...'
    $btnPickC.Location = New-Object System.Drawing.Point(172, 162)
    $btnPickC.Size = New-Object System.Drawing.Size(72, 28)
    $btnPickC.Add_Click({
        $cd = New-Object System.Windows.Forms.ColorDialog
        $cd.Color = $panelC.BackColor
        $cd.FullOpen = $true
        if ($cd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $panelC.BackColor = $cd.Color
        }
    })

    $chkShadow = New-Object System.Windows.Forms.CheckBox
    $chkShadow.Text = '启用时间阴影'
    $chkShadow.Location = New-Object System.Drawing.Point($inputX, 198)
    $chkShadow.Size = New-Object System.Drawing.Size($inputW, 24)

    $lblShadowR = New-Object System.Windows.Forms.Label
    $lblShadowR.Text = '阴影范围'
    $lblShadowR.Location = New-Object System.Drawing.Point(20, 228)
    $lblShadowR.Size = New-Object System.Drawing.Size($labelW, 24)
    $lblShadowR.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $numShadowR = New-Object System.Windows.Forms.NumericUpDown
    $numShadowR.Location = New-Object System.Drawing.Point($inputX, 224)
    $numShadowR.Size = New-Object System.Drawing.Size($inputW, 28)
    $numShadowR.Minimum = 0
    $numShadowR.Maximum = 80
    $numShadowR.Value = 10
    $tipShadowR = New-Object System.Windows.Forms.Label
    $tipShadowR.Location = New-Object System.Drawing.Point($inputX, 252)
    $tipShadowR.Size = New-Object System.Drawing.Size($inputW, 20)
    $tipShadowR.ForeColor = [System.Drawing.Color]::Gray

    $chkBulge = New-Object System.Windows.Forms.CheckBox
    $chkBulge.Text = '显示总进度'
    $chkBulge.Location = New-Object System.Drawing.Point($inputX, 276)
    $chkBulge.Size = New-Object System.Drawing.Size($inputW, 24)

    $tipW = New-Object System.Windows.Forms.Label
    $tipW.Location = New-Object System.Drawing.Point($inputX, 302)
    $tipW.Size = New-Object System.Drawing.Size($inputW, 36)
    $tipW.ForeColor = [System.Drawing.Color]::Gray

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = '开始'
    $btnOk.Location = New-Object System.Drawing.Point(135, 346)
    $btnOk.Size = New-Object System.Drawing.Size(90, 32)
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $dlg.AcceptButton = $btnOk

    $lblFooter = New-Object System.Windows.Forms.Label
    $lblFooter.Text = '绍兴第二医院超声科'
    $lblFooter.AutoSize = $false
    $lblFooter.Size = New-Object System.Drawing.Size(328, 24)
    $lblFooter.Location = New-Object System.Drawing.Point(16, 396)
    $lblFooter.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $lblFooter.ForeColor = [System.Drawing.Color]::DimGray

    $savedCfg = Get-CountdownSettings
    $numM.Value = [Math]::Min($numM.Maximum, [Math]::Max(0, $savedCfg.Minutes))
    $numS.Value = [Math]::Min($numS.Maximum, [Math]::Max(0, $savedCfg.Seconds))
    $chkShadow.Checked = [bool]$savedCfg.TimeShadowEnabled
    $numShadowR.Value = [Math]::Min($numShadowR.Maximum, [Math]::Max($numShadowR.Minimum, [decimal]$savedCfg.TimeShadowBlur))
    $numW.Value = [Math]::Min($numW.Maximum, [Math]::Max(0, $savedCfg.WarnSeconds))
    $chkMute.Checked = -not [bool]$savedCfg.SoundEnabled
    $chkBulge.Checked = [bool]$savedCfg.ProgressBulgeEnabled

    $dlg.Controls.AddRange(@(
            $lblM, $numM, $lblS, $numS, $lblW, $numW, $chkMute,
            $lblC, $panelC, $btnPickC, $chkShadow, $lblShadowR, $numShadowR, $tipShadowR,
            $chkBulge, $tipW, $btnOk, $lblFooter))
    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        exit 0
    }
    $borderColor = $panelC.BackColor
    $minutes = [int]$numM.Value
    $seconds = [int]$numS.Value
    $timeShadowEnabled = [bool]$chkShadow.Checked
    $timeShadowBlur = [double]$numShadowR.Value
    $warnSeconds = [int]$numW.Value
    $soundEnabled = -not $chkMute.Checked
    $progressBulgeEnabled = [bool]$chkBulge.Checked
    Save-CountdownSettings -Minutes $minutes -Seconds $seconds -BorderColor $borderColor `
        -TimeShadowEnabled $timeShadowEnabled -TimeShadowBlur $timeShadowBlur `
        -WarnSeconds $warnSeconds -SoundEnabled $soundEnabled `
        -ProgressBulgeEnabled $progressBulgeEnabled
    return @{
        TotalSeconds         = $minutes * 60 + $seconds
        WarnSeconds          = $warnSeconds
        SoundEnabled         = $soundEnabled
        BorderColor          = $borderColor
        TimeShadowEnabled    = $timeShadowEnabled
        TimeShadowBlur       = $timeShadowBlur
        ProgressBulgeEnabled = $progressBulgeEnabled
    }
}

$savedCfg = Get-CountdownSettings
$script:warnSeconds = [int]$savedCfg.WarnSeconds
$script:soundEnabled = [bool]$savedCfg.SoundEnabled
$script:borderColor = [System.Drawing.Color]::FromArgb([int]$savedCfg.BorderColorArgb)
$script:timeShadowEnabled = [bool]$savedCfg.TimeShadowEnabled
$script:timeShadowBlur = [double]$savedCfg.TimeShadowBlur
$script:progressBulgeEnabled = [bool]$savedCfg.ProgressBulgeEnabled
$script:returnToSetup = $false
$useCommandLineDuration = ($Minutes * 60 + $Seconds) -gt 0
$total = 0

while ($true) {
    Hide-ConsoleWindow
    if ($useCommandLineDuration) {
        $total = $Minutes * 60 + $Seconds
        $useCommandLineDuration = $false
    } else {
        $setup = Show-SetupDialog -InitialBorderColor $script:borderColor
        $total = $setup.TotalSeconds
        $script:warnSeconds = $setup.WarnSeconds
        $script:soundEnabled = $setup.SoundEnabled
        $script:borderColor = $setup.BorderColor
        $script:timeShadowEnabled = $setup.TimeShadowEnabled
        $script:timeShadowBlur = $setup.TimeShadowBlur
        $script:progressBulgeEnabled = $setup.ProgressBulgeEnabled
    }
    if ($total -le 0) {
        [System.Windows.Forms.MessageBox]::Show('时长必须大于 0 秒。', '倒计时', 'OK', 'Warning') | Out-Null
        continue
    }

    $script:returnToSetup = $false

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="倒计时" Width="158" Height="158"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="True" ResizeMode="NoResize"
        FontFamily="Microsoft YaHei UI">
  <Window.Resources>
    <Style x:Key="SymbolButton" TargetType="Button">
      <Setter Property="Width" Value="38"/>
      <Setter Property="Height" Value="38"/>
      <Setter Property="Margin" Value="0"/>
      <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Foreground" Value="#CCFFFFFF"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid Background="Transparent" Width="38" Height="38">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"
                                IsHitTestVisible="False"/>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Foreground" Value="#FFFFFFFF"/>
        </Trigger>
        <Trigger Property="IsPressed" Value="True">
          <Setter Property="Foreground" Value="#AAFFFFFF"/>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>
  <Grid x:Name="Root">
    <Grid Width="140" Height="140" HorizontalAlignment="Center" VerticalAlignment="Center">
      <Ellipse x:Name="RingGlow" Opacity="0" IsHitTestVisible="False">
        <Ellipse.Fill>
          <RadialGradientBrush GradientOrigin="0.5,0.5" Center="0.5,0.5"
                               RadiusX="0.5" RadiusY="0.5" MappingMode="RelativeToBoundingBox">
            <GradientStop Color="#00FF5533" Offset="0"/>
            <GradientStop Color="#00FF5533" Offset="0.58"/>
            <GradientStop Color="#55FF4433" Offset="0.82"/>
            <GradientStop Color="#AAFF5544" Offset="0.94"/>
            <GradientStop Color="#FFFF6655" Offset="1"/>
          </RadialGradientBrush>
        </Ellipse.Fill>
      </Ellipse>
      <Ellipse x:Name="Ring" Stroke="#D9FFFFFF" StrokeThickness="2" Fill="Transparent"/>
      <Path x:Name="ProgressBulge" StrokeThickness="0" Fill="#FFFFFFFF" IsHitTestVisible="False"/>
      <Grid Margin="8,10,8,12">
        <Grid x:Name="TimeDragArea" HorizontalAlignment="Center" VerticalAlignment="Center"
              Margin="0,0,0,10" MinWidth="108" MinHeight="52"
              Background="#01000000" Cursor="SizeAll">
          <StackPanel x:Name="TimeDisplay" Orientation="Horizontal" IsHitTestVisible="False"
                      HorizontalAlignment="Center" VerticalAlignment="Center">
            <TextBlock x:Name="TimeMin" FontSize="40" FontWeight="Bold" Foreground="#FFF5F5FA"
                       VerticalAlignment="Center" LineStackingStrategy="BlockLineHeight" LineHeight="40"/>
            <TextBlock x:Name="TimeColon" Text=":" FontSize="40" FontWeight="Bold" Foreground="#FFF5F5FA"
                       VerticalAlignment="Center" LineStackingStrategy="BlockLineHeight" LineHeight="40"
                       Margin="0,-7,0,0"/>
            <TextBlock x:Name="TimeSec" FontSize="40" FontWeight="Bold" Foreground="#FFF5F5FA"
                       VerticalAlignment="Center" LineStackingStrategy="BlockLineHeight" LineHeight="40"/>
          </StackPanel>
        </Grid>
        <Grid x:Name="BtnBar" Panel.ZIndex="10" Width="84" Height="38"
              HorizontalAlignment="Center" VerticalAlignment="Bottom"
              Background="#01000000">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="28"/>
            <ColumnDefinition Width="28"/>
            <ColumnDefinition Width="28"/>
          </Grid.ColumnDefinitions>
          <Button x:Name="BtnPause" Grid.Column="0" Style="{StaticResource SymbolButton}"
                  HorizontalAlignment="Center" VerticalAlignment="Center" Content="&#xE769;"/>
          <Button x:Name="BtnReset" Grid.Column="1" Style="{StaticResource SymbolButton}"
                  HorizontalAlignment="Center" VerticalAlignment="Center" Content="&#xE72C;"/>
          <Button x:Name="BtnClose" Grid.Column="2" Style="{StaticResource SymbolButton}"
                  HorizontalAlignment="Center" VerticalAlignment="Center" Content="&#xE711;"/>
        </Grid>
      </Grid>
    </Grid>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$timeDisplay = $window.FindName('TimeDisplay')
$timeMin = $window.FindName('TimeMin')
$timeColon = $window.FindName('TimeColon')
$timeSec = $window.FindName('TimeSec')
$ring = $window.FindName('Ring')
$progressBulge = $window.FindName('ProgressBulge')

function Set-TimeDisplay {
    param([int]$Sec)
    $m = [math]::Floor($Sec / 60)
    $s = $Sec % 60
    $timeMin.Text = ('{0:00}' -f $m)
    $timeSec.Text = ('{0:00}' -f $s)
}

function Set-TimeDisplayForeground([System.Windows.Media.Brush]$brush) {
    foreach ($part in @($timeMin, $timeColon, $timeSec)) {
        if ($null -ne $part) { $part.Foreground = $brush }
    }
}

function Set-TimeTextShadow {
    param(
        [bool]$enabled,
        [double]$blurRadius
    )
    if ($enabled) {
        $effect = New-Object System.Windows.Media.Effects.DropShadowEffect
        $effect.ShadowDepth = 0
        $effect.BlurRadius = [Math]::Max(0, $blurRadius)
        $effect.Color = [System.Windows.Media.Colors]::Black
        $effect.Opacity = 0.9
        $timeDisplay.Effect = $effect
        return
    }
    $timeDisplay.Effect = $null
}

Set-TimeTextShadow -enabled $script:timeShadowEnabled -blurRadius $script:timeShadowBlur
$ringGlow = $window.FindName('RingGlow')
$btnPause = $window.FindName('BtnPause')
$btnReset = $window.FindName('BtnReset')
$btnClose = $window.FindName('BtnClose')

function Test-IsClickOnButton([object]$source) {
    while ($null -ne $source) {
        if ($source -is [System.Windows.Controls.Button]) { return $true }
        if ($source -is [System.Windows.Controls.Grid] -and $source.Name -eq 'BtnBar') { return $true }
        $source = [System.Windows.Media.VisualTreeHelper]::GetParent($source)
    }
    return $false
}

$bc = [System.Windows.Media.BrushConverter]::new()
$ringNormalThickness = 2.0

# 圆环进度隆起（底贴在 Ring 上，顶朝圆心；随已用时间比例顺时针滑动）
# 几何与 XAML 中 140×140 的 Ring 对齐，一般无需改动
$script:ringProgressCx = 70.0   # 圆心 X（像素）
$script:ringProgressCy = 70.0   # 圆心 Y（像素）
$script:ringProgressR = 68.0     # 底边所在半径（与圆环描边中心线一致）
$script:progressBulgeSweepDeg = 20.0   # 隆起底边在圆上的张角（度）；越大越「宽」
$script:progressBulgePeakDepth = 6.0   # 峰顶向内偏移（像素）；越大越「鼓」
$script:progressBulgeSigma = 0.40      # 高斯标准差（相对半弧宽 u∈[-1,1]）；越小越尖，越大越平
$script:progressBulgeSegments = 22      # 轮廓折线分段数；越大曲线越光滑

function Get-ProgressBulgeInward {
    param(
        [double]$u,
        [double]$peakDepth,
        [double]$sigma
    )
    if ($sigma -le 0.0001) { return 0.0 }
    $uClamped = [Math]::Max(-1.0, [Math]::Min(1.0, $u))
    $edge = 1.0 - ($uClamped * $uClamped)
    if ($edge -le 0.0) { return 0.0 }
    $gauss = [Math]::Exp(-0.5 * (($uClamped / $sigma) * ($uClamped / $sigma)))
    return $peakDepth * $gauss * $edge
}

function Get-ProgressBulgePathData {
    param([double]$angleDeg)
    $half = $script:progressBulgeSweepDeg / 2.0
    $startDeg = $angleDeg - $half
    $endDeg = $angleDeg + $half
    $cx = $script:ringProgressCx
    $cy = $script:ringProgressCy
    $r = $script:ringProgressR
    $peakDepth = $script:progressBulgePeakDepth
    $sigma = $script:progressBulgeSigma
    $seg = $script:progressBulgeSegments

    function Get-PointAt([double]$deg, [double]$radius) {
        $rad = $deg * [Math]::PI / 180.0
        return @{
            X = $cx + ($radius * [Math]::Cos($rad))
            Y = $cy + ($radius * [Math]::Sin($rad))
        }
    }

    $pStart = Get-PointAt $startDeg $r
    $pEnd = Get-PointAt $endDeg $r
    $parts = New-Object System.Collections.Generic.List[string]
    [void]$parts.Add(('M {0:F2},{1:F2}' -f $pStart.X, $pStart.Y))
    [void]$parts.Add(('A {0:F2},{0:F2} 0 0 1 {1:F2},{2:F2}' -f $r, $pEnd.X, $pEnd.Y))

    for ($i = $seg - 1; $i -ge 0; $i--) {
        $t = $i / [double]$seg
        $deg = $startDeg + (($endDeg - $startDeg) * $t)
        $u = if ($half -le 0.0001) { 0.0 } else { ($deg - $angleDeg) / $half }
        $inward = Get-ProgressBulgeInward -u $u -peakDepth $peakDepth -sigma $sigma
        $pt = Get-PointAt $deg ($r - $inward)
        [void]$parts.Add(('L {0:F2},{1:F2}' -f $pt.X, $pt.Y))
    }
    [void]$parts.Add('Z')
    return ($parts -join ' ')
}

function Update-ProgressBulge {
    param(
        [int]$Remaining,
        [int]$Total
    )
    if ($null -eq $progressBulge) { return }
    if (-not $script:progressBulgeEnabled -or $Total -le 0) {
        $progressBulge.Visibility = [System.Windows.Visibility]::Collapsed
        return
    }
    $progressBulge.Visibility = [System.Windows.Visibility]::Visible
    $elapsed = [Math]::Max(0, $Total - $Remaining)
    $ratio = [Math]::Max(0.0, [Math]::Min(1.0, $elapsed / [double]$Total))
    $angleDeg = -90.0 + ($ratio * 360.0)
    $pathData = Get-ProgressBulgePathData -angleDeg $angleDeg
    $progressBulge.Data = [System.Windows.Media.Geometry]::Parse($pathData)
    if ($ring.Stroke -is [System.Windows.Media.SolidColorBrush]) {
        $c = $ring.Stroke.Color
        $bulgeColor = [System.Windows.Media.Color]::FromArgb(255, $c.R, $c.G, $c.B)
        $bulgeBrush = New-Object System.Windows.Media.SolidColorBrush $bulgeColor
        $progressBulge.Fill = $bulgeBrush
    } else {
        $progressBulge.Fill = $ring.Stroke
    }
}


function New-WpfBrushFromDrawingColor([System.Drawing.Color]$color) {
    $mediaColor = [System.Windows.Media.Color]::FromArgb($color.A, $color.R, $color.G, $color.B)
    return New-Object System.Windows.Media.SolidColorBrush $mediaColor
}

function New-FollowBrushFromRing([System.Windows.Media.Brush]$ringBrush, [double]$alphaFactor) {
    if ($ringBrush -isnot [System.Windows.Media.SolidColorBrush]) {
        return $ringBrush
    }
    $c = $ringBrush.Color
    $alpha = [byte][Math]::Min(255, [Math]::Max(80, [int]($c.A * $alphaFactor)))
    $followColor = [System.Windows.Media.Color]::FromArgb($alpha, $c.R, $c.G, $c.B)
    return New-Object System.Windows.Media.SolidColorBrush $followColor
}

function Set-RingAndButtons([System.Windows.Media.Brush]$ringBrush) {
    $ring.Stroke = $ringBrush
    Set-ButtonsForeground (New-FollowBrushFromRing $ringBrush 0.92)
    Set-TimeDisplayForeground (New-FollowBrushFromRing $ringBrush 0.98)
    if ($script:initialTotal -gt 0) {
        Update-ProgressBulge -Remaining $script:remaining -Total $script:initialTotal
    }
}

function Set-ButtonsForeground([System.Windows.Media.Brush]$brush) {
    foreach ($btn in @($btnPause, $btnReset, $btnClose)) {
        if ($null -ne $btn) { $btn.Foreground = $brush }
    }
}

$brushRingNormal = New-WpfBrushFromDrawingColor $script:borderColor
$brushRingWarn = $bc.ConvertFromString('#FFFF5555')

function Invoke-RemindBeep([int]$frequency, [int]$durationMs) {
    if (-not $script:soundEnabled) { return }
    try { [console]::Beep($frequency, $durationMs) } catch { }
}

function Clear-WarnVisual {
    $ringGlow.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $ring.BeginAnimation([System.Windows.Shapes.Shape]::StrokeThicknessProperty, $null)
    $ringGlow.Opacity = 0
    if (-not $script:finished) {
        Set-RingAndButtons $brushRingNormal
        $ring.StrokeThickness = $ringNormalThickness
    }
}

function Start-WarnPulse {
    Set-RingAndButtons $brushRingWarn
    $ringGlow.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $ring.BeginAnimation([System.Windows.Shapes.Shape]::StrokeThicknessProperty, $null)
    $ringGlow.Opacity = 1
    $ring.StrokeThickness = 3

    $fade = New-Object System.Windows.Media.Animation.DoubleAnimation
    $fade.From = 1.0
    $fade.To = 0.05
    $fade.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(900))
    $fade.EasingFunction = New-Object System.Windows.Media.Animation.QuadraticEase

    $thick = New-Object System.Windows.Media.Animation.DoubleAnimation
    $thick.From = 3.0
    $thick.To = $ringNormalThickness
    $thick.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(900))
    $thick.EasingFunction = New-Object System.Windows.Media.Animation.QuadraticEase

    $ringGlow.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
    $ring.BeginAnimation([System.Windows.Shapes.Shape]::StrokeThicknessProperty, $thick)

    Invoke-RemindBeep 920 80
}

function Update-WarnVisual([int]$remaining) {
    if ($script:warnSeconds -le 0 -or $script:finished) {
        return
    }
    if ($remaining -le $script:warnSeconds -and $remaining -ge 0) {
        Start-WarnPulse
    } else {
        Clear-WarnVisual
    }
}

function Set-FinishedUi([bool]$finished) {
    $script:finished = $finished
    if ($finished) {
        $script:remaining = 0
        Set-TimeDisplay -Sec 0
        Clear-WarnVisual
        Set-RingAndButtons $brushRingNormal
        $ring.StrokeThickness = $ringNormalThickness
        Update-ProgressBulge -Remaining 0 -Total $script:initialTotal
        $timer.Stop()
        Invoke-RemindBeep 880 300
        Invoke-RemindBeep 1100 500
        return
    }
    Clear-WarnVisual
    Set-TimeDisplay -Sec $script:remaining
    Update-ProgressBulge -Remaining $script:remaining -Total $script:initialTotal
}

Set-TimeDisplay -Sec $total
Set-RingAndButtons $brushRingNormal
Update-ProgressBulge -Remaining $total -Total $total

$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$window.Left = $area.Right - $window.Width - 24
$window.Top = $area.Top + 24

$script:initialTotal = $total
$script:remaining = $total
$script:finished = $false
$script:paused = $false

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    if ($script:paused -or $script:finished) { return }
    $script:remaining--
    if ($script:remaining -lt 0) {
        Set-FinishedUi $true
        return
    }
    Set-TimeDisplay -Sec $script:remaining
    Update-WarnVisual $script:remaining
    Update-ProgressBulge -Remaining $script:remaining -Total $script:initialTotal
})

$btnPause.Add_Click({
    if ($script:finished) { return }
    if (-not $script:paused) {
        $script:paused = $true
        $timer.Stop()
        $btnPause.Content = [char]0xE768
    } else {
        $script:paused = $false
        $timer.Start()
        $btnPause.Content = [char]0xE769
    }
})

$btnReset.Add_Click({
    $script:remaining = $script:initialTotal
    $script:finished = $false
    $script:paused = $true
    $timer.Stop()
    $btnPause.Content = [char]0xE768
    Set-FinishedUi $false
})

$btnClose.Add_Click({
    $script:returnToSetup = $true
    $window.Close()
})

$window.Add_Loaded({
    Update-WarnVisual $script:remaining
    Update-ProgressBulge -Remaining $script:remaining -Total $script:initialTotal
    $timer.Start()
})
function Start-WindowDrag {
    param($sender, $e)
    if ($e.ClickCount -gt 1) { return }
    $e.Handled = $true
    $window.DragMove()
}

$timeDragArea = $window.FindName('TimeDragArea')
$timeDragArea.Add_MouseLeftButtonDown({ param($s, $e) Start-WindowDrag $s $e })
$ring.Add_MouseLeftButtonDown({ param($s, $e) Start-WindowDrag $s $e })
$window.Add_PreviewMouseDoubleClick({
    param($sender, $e)
    if (Test-IsClickOnButton $e.OriginalSource) {
        $e.Handled = $true
        return
    }
    $window.Close()
})

try {
    [void]$window.ShowDialog()
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.Message,
        'Countdown',
        'OK',
        'Error') | Out-Null
    exit 1
} finally {
    if ($null -ne $timer) { $timer.Stop() }
}

    if ($script:returnToSetup) { continue }
    break
}
