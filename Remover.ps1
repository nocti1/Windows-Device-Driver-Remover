# Find and remove devices/drivers via the specified keyword
# Script made by nocti1ucent
# Designed and tested for Windows 10 22H2

# Modifyable options
[string]$Keyword = "HyperX"
[int]$ArraySize = 1024

# Initialise variables
[int]$DeviceNum = 0
[int]$DriverNum = 0
[int]$ProtectedDriverNum = 0
[bool[]]$ProtectedDriver = New-Object string[] $ArraySize
[string[]]$Signer = New-Object string[] $ArraySize
[string[]]$Provider = New-Object string[] $ArraySize
[string[]]$Class = New-Object string[] $ArraySize

# Custom logging function with date/time
function Log {
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [string]$Message,
        [System.ConsoleColor]$ForegroundColor,
        [switch]$PreSpace
    )

    $Timestamp = (Get-Date -Format "dd-MM-yyyy@h:mmtt").ToLower()

    if ($PSBoundParameters.ContainsKey('ForegroundColor')) {
        if($PreSpace) {
            Write-Host "`n[$Timestamp] $Message" -ForegroundColor $ForegroundColor
        } else {
            Write-Host "[$Timestamp] $Message" -ForegroundColor $ForegroundColor
        }
    } else {
        if($PreSpace) {
            Write-Host "`n[$Timestamp] $Message"
        } else {
            Write-Host "[$Timestamp] $Message"
        }
    }
}

# Write out the welcome message
Write-Host "`n`n`n            Uninstall devices and drivers script" -ForegroundColor Cyan
Write-Host "`n                    Made by nocti1ucent`n`n`n" -ForegroundColor Cyan

# Hold up a sec
Start-Sleep -Seconds 1

# Begin searching for devices...
Log "Detecting devices matching the keyword `"$($Keyword)`" ..." -ForegroundColor White

# Find all devices with the keyword in the name or instance ID
$Devices = Get-PnpDevice | Where-Object {
    $_.FriendlyName -match $Keyword -or $_.InstanceId -match $Keyword
}

if($Devices) {
    Log "Found $($Devices.count) devices." -ForegroundColor Green
} else {
    Log "Found $($Devices.count) devices!" -ForegroundColor Yellow
}

foreach ($Device in $Devices) {
    $DeviceNum++
    Log "[$($DeviceNum)/$($Devices.count)] Name: $($Device.FriendlyName)" -ForegroundColor Gray
    Log "[$($DeviceNum)/$($Devices.count)] ID:   $($Device.InstanceId)" -ForegroundColor Gray

    $Response = Read-Host "Remove this device? (Y/N)"

    if ($Response -match '^[Yy]$') {
        try {
            pnputil /remove-device "$($Device.InstanceId)" /force | Out-Null
            Log "Removed device!`n" -ForegroundColor Green
        }
        catch {
            Log "Failed removing device instance!`n" -ForegroundColor Red
        }
    }
    else {
        Log "Skipping this device...`n" -ForegroundColor Green
    }
}

# Begin searching for drivers...
Log "Detecting drivers matching the keyword `"$($Keyword)`" ..." -ForegroundColor White -PreSpace

# Find all drivers with the keyword in the name
$Drivers = pnputil /enum-drivers | Select-String $Keyword -Context 0,5
for ($i = 0; $i -lt $Drivers.Count; $i++) {
    $Driver = $Drivers[$i]
    $AllLines = $Driver.Context.PreContext + $Driver.Line + $Driver.Context.PostContext

    # Extract signer name
    $SignerLine = $AllLines | Where-Object { $_ -match "^\s*>?\s*Signer Name:" }
    if ($SignerLine) {
        $Signer[$i] = ($SignerLine -replace "^\s*>?\s*Signer Name:\s*", "").Trim()
    }

    # Extract provider Name
    $ProviderLine = $AllLines | Where-Object { $_ -match "^\s*>?\s*Provider Name:" }
    if ($ProviderLine) {
        $Provider[$i] = ($ProviderLine -replace "^\s*>?\s*Provider Name:\s*", "").Trim()
    }

    # Extract class Name
    $ClassLine = $AllLines | Where-Object { $_ -match "^\s*>?\s*Class Name:" }
    if ($ClassLine) {
        $Class[$i] = ($ClassLine -replace "^\s*>?\s*Class Name:\s*", "").Trim()
    }

    if ($Driver.Line -match "Published Name:\s+(oem\d+\.inf)" -and $Signer[$i] -and ($Signer[$i] -notmatch "Microsoft Windows Hardware Compatibility Publisher")) {
        $DriverNum++
        $ProtectedDriver[$i] = $False
    } elseif ($Signer[$i] -and ($Signer[$i] -match "Microsoft Windows Hardware Compatibility Publisher")) {
        $ProtectedDriverNum++
        $ProtectedDriver[$i] = $True
    } else {
        Log "Failed to categorise driver! $($Driver)`n" -ForegroundColor Yellow
    }
}

if($DriverNum -gt 0) {
    Log "Found $($DriverNum) drivers." -ForegroundColor Green
} else {
    Log "Found $($DriverNum) drivers!" -ForegroundColor Yellow
}

if($ProtectedDriverNum -gt 0) {
    Log "Found $($ProtectedDriverNum) protected drivers." -ForegroundColor Green
} else {
    Log "Found $($ProtectedDriverNum) protected drivers!" -ForegroundColor Yellow
}

for ($i = 0; $i -lt $Drivers.Count; $i++) {
    $Driver = $Drivers[$i]

    if ($ProtectedDriver[$i] -eq $False) {
        $InfFile = $Matches[1]

        Log "[$($DriverNum)/$($Drivers.count)] Found driver package: $InfFile" -ForegroundColor Gray
        $Response = Read-Host "Delete this driver package? (Y/N)"

        if ($Response -match '^[Yy]$') {
            Log " -> Deleting driver package...`n" -ForegroundColor Green
            pnputil /delete-driver $InfFile /uninstall /force | Out-Null
        }
        else {
            Log "Skipping this driver...`n" -ForegroundColor Green
        }
    } else {
        Log "Skipping protected driver $($Provider[$i]) ($($Class[$i]))..." -ForegroundColor Gray
    }
} 
