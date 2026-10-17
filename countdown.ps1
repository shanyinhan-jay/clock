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
        [bool]$SoundEnabled
    )
    $path = Get-CountdownSettingsPath
    $data = @{
        Minutes            = $Minutes
        Seconds            = $Seconds
        BorderColorArgb    = $BorderColor.ToArgb()
        TimeShadowEnabled  = $TimeShadowEnabled
        TimeShadowBlur     = $TimeShadowBlur
        WarnSeconds        = $WarnSeconds
        SoundEnabled       = $SoundEnabled
    }
    if (Test-Path -LiteralPath $path) {
        try {
            $existing = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($prop in $existing.PSObject.Properties) {
                if ($prop.Name -notin @(
                        'Minutes', 'Seconds', 'BorderColorArgb', 'TimeShadowEnabled',
                        'TimeShadowBlur', 'WarnSeconds', 'SoundEnabled')) {
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
    $dlg.Size = New-Object System.Drawing.Size(360, 396)
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
    $lblM.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $numM = New-Object System.Windows.Forms.NumericUpDown
    $numM.Location = New-Object System.Drawing.Point($inputX, 24)
    $numM.Size = New-Object System.Drawing.Size($inputW, 28)
    $numM.Maximum = 9999

    $lblS = New-Object System.Windows.Forms.Label
    $lblS.Text = '秒'
    $lblS.Location = New-Object System.Drawing.Point(20, 68)
    $lblS.Size = New-Object System.Drawing.Size($labelW, 24)
    $lblS.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $numS = New-Object System.Windows.Forms.NumericUpDown
    $numS.Location = New-Object System.Drawing.Point($inputX, 64)
    $numS.Size = New-Object System.Drawing.Size($inputW, 28)
    $numS.Maximum = 59

    $lblW = New-Object System.Windows.Forms.Label
    $lblW.Text = '最后提醒 (秒)'
    $lblW.Location = New-Object System.Drawing.Point(20, 108)
    $lblW.Size = New-Object System.Drawing.Size($labelW, 24)
    $lblW.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
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
    $lblC.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
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
    $lblShadowR.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $numShadowR = New-Object System.Windows.Forms.NumericUpDown
    $numShadowR.Location = New-Object System.Drawing.Point($inputX, 224)
    $numShadowR.Size = New-Object System.Drawing.Size($inputW, 28)
    $numShadowR.Minimum = 0
    $numShadowR.Maximum = 80
    $numShadowR.Value = 10
    $tipShadowR = New-Object System.Windows.Forms.Label
    $tipShadowR.Text = '数值越大，阴影扩散越广'
    $tipShadowR.Location = New-Object System.Drawing.Point($inputX, 252)
    $tipShadowR.Size = New-Object System.Drawing.Size($inputW, 20)
    $tipShadowR.ForeColor = [System.Drawing.Color]::Gray

    $tipW = New-Object System.Windows.Forms.Label
    $tipW.Text = '0 表示关闭；进入该秒数后圆环红色内光随秒搏动'
    $tipW.Location = New-Object System.Drawing.Point($inputX, 274)
    $tipW.Size = New-Object System.Drawing.Size($inputW, 36)
    $tipW.ForeColor = [System.Drawing.Color]::Gray

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = '开始'
    $btnOk.Location = New-Object System.Drawing.Point($inputX, 318)
    $btnOk.Size = New-Object System.Drawing.Size(90, 32)
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $dlg.AcceptButton = $btnOk

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = '取消'
    $btnCancel.Location = New-Object System.Drawing.Point(242, 318)
    $btnCancel.Size = New-Object System.Drawing.Size(90, 32)
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dlg.CancelButton = $btnCancel

    $savedCfg = Get-CountdownSettings
    $numM.Value = [Math]::Min($numM.Maximum, [Math]::Max(0, $savedCfg.Minutes))
    $numS.Value = [Math]::Min($numS.Maximum, [Math]::Max(0, $savedCfg.Seconds))
    $chkShadow.Checked = [bool]$savedCfg.TimeShadowEnabled
    $numShadowR.Value = [Math]::Min($numShadowR.Maximum, [Math]::Max($numShadowR.Minimum, [decimal]$savedCfg.TimeShadowBlur))
    $numW.Value = [Math]::Min($numW.Maximum, [Math]::Max(0, $savedCfg.WarnSeconds))
    $chkMute.Checked = -not [bool]$savedCfg.SoundEnabled

    $dlg.Controls.AddRange(@(
            $lblM, $numM, $lblS, $numS, $lblW, $numW, $chkMute,
            $lblC, $panelC, $btnPickC, $chkShadow, $lblShadowR, $numShadowR, $tipShadowR,
            $tipW, $btnOk, $btnCancel))
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
    Save-CountdownSettings -Minutes $minutes -Seconds $seconds -BorderColor $borderColor `
        -TimeShadowEnabled $timeShadowEnabled -TimeShadowBlur $timeShadowBlur `
        -WarnSeconds $warnSeconds -SoundEnabled $soundEnabled
    return @{
        TotalSeconds       = $minutes * 60 + $seconds
        WarnSeconds        = $warnSeconds
        SoundEnabled       = $soundEnabled
        BorderColor        = $borderColor
        TimeShadowEnabled  = $timeShadowEnabled
        TimeShadowBlur     = $timeShadowBlur
    }
}

$savedCfg = Get-CountdownSettings
$script:warnSeconds = [int]$savedCfg.WarnSeconds
$script:soundEnabled = [bool]$savedCfg.SoundEnabled
$script:borderColor = [System.Drawing.Color]::FromArgb([int]$savedCfg.BorderColorArgb)
$script:timeShadowEnabled = [bool]$savedCfg.TimeShadowEnabled
$script:timeShadowBlur = [double]$savedCfg.TimeShadowBlur
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
      <Grid Margin="8,10,8,12">
        <Grid x:Name="TimeDragArea" HorizontalAlignment="Center" VerticalAlignment="Center"
              Margin="0,0,0,10" MinWidth="108" MinHeight="52"
              Background="#01000000" Cursor="SizeAll">
          <TextBlock x:Name="TimeText" IsHitTestVisible="False"
                     HorizontalAlignment="Center" VerticalAlignment="Center"
                     FontSize="40" FontWeight="Bold" Foreground="#FFF5F5FA"/>
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

$timeText = $window.FindName('TimeText')
$ring = $window.FindName('Ring')

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
        $timeText.Effect = $effect
        return
    }
    $timeText.Effect = $null
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
    $timeText.Foreground = New-FollowBrushFromRing $ringBrush 0.98
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
        $timeText.Text = Format-Remaining 0
        Clear-WarnVisual
        Set-RingAndButtons $brushRingNormal
        $ring.StrokeThickness = $ringNormalThickness
        $timer.Stop()
        Invoke-RemindBeep 880 300
        Invoke-RemindBeep 1100 500
        return
    }
    Clear-WarnVisual
    $timeText.Text = Format-Remaining $script:remaining
}

$timeText.Text = Format-Remaining $total
Set-RingAndButtons $brushRingNormal

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
    $timeText.Text = Format-Remaining $script:remaining
    Update-WarnVisual $script:remaining
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
