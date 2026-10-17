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

function Format-Remaining([int]$sec) {
    $m = [math]::Floor($sec / 60)
    $s = $sec % 60
    return ('{0:00}:{1:00}' -f $m, $s)
}

function Show-SetupDialog {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = '倒计时'
    $dlg.Size = New-Object System.Drawing.Size(360, 292)
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
    $numM.Value = 5

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
    $numW.Value = 10
    $chkMute = New-Object System.Windows.Forms.CheckBox
    $chkMute.Text = '关闭提醒声音'
    $chkMute.Location = New-Object System.Drawing.Point($inputX, 136)
    $chkMute.Size = New-Object System.Drawing.Size($inputW, 24)
    $chkMute.Checked = $false

    $tipW = New-Object System.Windows.Forms.Label
    $tipW.Text = '0 表示关闭；进入该秒数后圆环红色内光随秒搏动'
    $tipW.Location = New-Object System.Drawing.Point($inputX, 162)
    $tipW.Size = New-Object System.Drawing.Size($inputW, 36)
    $tipW.ForeColor = [System.Drawing.Color]::Gray

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = '开始'
    $btnOk.Location = New-Object System.Drawing.Point($inputX, 208)
    $btnOk.Size = New-Object System.Drawing.Size(90, 32)
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $dlg.AcceptButton = $btnOk

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = '取消'
    $btnCancel.Location = New-Object System.Drawing.Point(242, 208)
    $btnCancel.Size = New-Object System.Drawing.Size(90, 32)
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dlg.CancelButton = $btnCancel

    $dlg.Controls.AddRange(@($lblM, $numM, $lblS, $numS, $lblW, $numW, $chkMute, $tipW, $btnOk, $btnCancel))
    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        exit 0
    }
    return @{
        TotalSeconds  = [int]$numM.Value * 60 + [int]$numS.Value
        WarnSeconds   = [int]$numW.Value
        SoundEnabled  = -not $chkMute.Checked
    }
}

$script:warnSeconds = 10
$script:soundEnabled = $true
$total = $Minutes * 60 + $Seconds
if ($total -le 0) {
    $setup = Show-SetupDialog
    $total = $setup.TotalSeconds
    $script:warnSeconds = $setup.WarnSeconds
    $script:soundEnabled = $setup.SoundEnabled
}
if ($total -le 0) {
    [System.Windows.Forms.MessageBox]::Show('时长必须大于 0 秒。', '倒计时', 'OK', 'Warning') | Out-Null
    exit 1
}

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
                     FontSize="40" FontWeight="Bold" Foreground="#FFF5F5FA">
            <TextBlock.Effect>
              <DropShadowEffect ShadowDepth="0" BlurRadius="10" Color="Black" Opacity="0.9"/>
            </TextBlock.Effect>
          </TextBlock>
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
$brushTimeNormal = $bc.ConvertFromString('#FFF5F5FA')
$brushRingNormal = $bc.ConvertFromString('#D9FFFFFF')
$brushRingWarn = $bc.ConvertFromString('#FFFF5555')
$brushRingFinished = $bc.ConvertFromString('#FFFF8888')
$brushBtnNormal = $bc.ConvertFromString('#CCFFFFFF')
$brushBtnWarn = $bc.ConvertFromString('#FFFF6666')
$brushBtnFinished = $bc.ConvertFromString('#FFFFAAAA')
$ringNormalThickness = 2.0

function Set-ButtonsForeground([System.Windows.Media.Brush]$brush) {
    foreach ($btn in @($btnPause, $btnReset, $btnClose)) {
        if ($null -ne $btn) { $btn.Foreground = $brush }
    }
}

function Invoke-RemindBeep([int]$frequency, [int]$durationMs) {
    if (-not $script:soundEnabled) { return }
    try { [console]::Beep($frequency, $durationMs) } catch { }
}

function Clear-WarnVisual {
    $ringGlow.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $ring.BeginAnimation([System.Windows.Shapes.Shape]::StrokeThicknessProperty, $null)
    $ringGlow.Opacity = 0
    $ring.Stroke = $brushRingNormal
    $ring.StrokeThickness = $ringNormalThickness
    if (-not $script:finished) {
        $timeText.Foreground = $brushTimeNormal
        Set-ButtonsForeground $brushBtnNormal
    }
}

function Start-WarnPulse {
    $ring.Stroke = $brushRingWarn
    Set-ButtonsForeground $brushBtnWarn
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
        $timeText.Foreground = $bc.ConvertFromString('#FFFF7777')
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
        $timeText.Foreground = $bc.ConvertFromString('#FFFF7878')
        Clear-WarnVisual
        $ring.Stroke = $brushRingFinished
        Set-ButtonsForeground $brushBtnFinished
        $timer.Stop()
        Invoke-RemindBeep 880 300
        Invoke-RemindBeep 1100 500
        return
    }
    $timeText.Foreground = $brushTimeNormal
    $ring.Stroke = $brushRingNormal
    Clear-WarnVisual
    $timeText.Text = Format-Remaining $script:remaining
}

$timeText.Text = Format-Remaining $total
Set-ButtonsForeground $brushBtnNormal

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
    $script:paused = $false
    $script:finished = $false
    $btnPause.Content = [char]0xE769
    Set-FinishedUi $false
    $timer.Start()
})

$btnClose.Add_Click({ $window.Close() })

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
$window.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
        $window.Close()
    }
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
