Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

$configPath = "$env:LOCALAPPDATA\roblox_lagswitch_config.json"

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="roblox lagswitch" Height="200" Width="300" WindowStartupLocation="CenterScreen">
    <StackPanel Margin="10" VerticalAlignment="Center" HorizontalAlignment="Center">
        <Button Name="ToggleButton" Content="Block Roblox" Width="200" Height="40" Margin="0,0,0,10"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,10">
            <TextBox Name="PathTextBox" Width="180" IsReadOnly="True"/>
            <Button Name="BrowseButton" Content="Browse" Width="60" Margin="5,0,0,0"/>
        </StackPanel>
        <TextBlock Name="StatusText" Text="STATUS: ALLOWED." HorizontalAlignment="Center"/>
    </StackPanel>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

$toggleButton = $window.FindName("ToggleButton")
$statusText   = $window.FindName("StatusText")
$browseButton = $window.FindName("BrowseButton")
$pathTextBox  = $window.FindName("PathTextBox")

$global:blocked = $false
$global:robloxPath = ""

if (Test-Path $configPath) {
    $cfg = Get-Content $configPath | ConvertFrom-Json
    if (Test-Path $cfg.RobloxPath) {
        $global:robloxPath = $cfg.RobloxPath
        $pathTextBox.Text = $global:robloxPath
    }
}

$browseButton.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "Roblox Player|RobloxPlayerBeta.exe"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:robloxPath = $ofd.FileName
        $pathTextBox.Text = $global:robloxPath
        @{ RobloxPath = $global:robloxPath } | ConvertTo-Json | Set-Content $configPath
    }
})

function Block-Roblox {
    if (-not (Test-Path $global:robloxPath)) { 
        [System.Windows.MessageBox]::Show("Roblox path invalid","Error"); return 
    }
    Write-Host "Blocking Roblox..."
    netsh advfirewall firewall add rule name="Roblox Block In"  dir=in  action=block program="$global:robloxPath" enable=yes | Out-Null
    netsh advfirewall firewall add rule name="Roblox Block Out" dir=out action=block program="$global:robloxPath" enable=yes | Out-Null
}

function Unblock-Roblox {
    Write-Host "Unblocking Roblox..."
    netsh advfirewall firewall delete rule name="Roblox Block In"  | Out-Null
    netsh advfirewall firewall delete rule name="Roblox Block Out" | Out-Null
}

$window.add_Closing({
    if ($global:blocked) { Unblock-Roblox }
})

$toggleButton.Add_Click({
    if (-not (Test-Path $global:robloxPath)) {
        [System.Windows.MessageBox]::Show("Roblox path not valid","Error")
        return
    }
    if ($global:blocked) {
        Unblock-Roblox
        $global:blocked = $false
        $toggleButton.Content = "Block Roblox"
        $statusText.Text = "STATUS: ALLOWED."
    } else {
        Block-Roblox
        $global:blocked = $true
        $toggleButton.Content = "Unblock Roblox"
        $statusText.Text = "STATUS: BLOCKED."
    }
})

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell -ArgumentList "-NoExit", "-noprofile", "-executionpolicy bypass", "-file `"$PSCommandPath`"" -Verb RunAs
    exit
}

$window.ShowDialog() | Out-Null
