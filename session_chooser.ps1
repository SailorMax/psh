# init
$RegistryPath = "Registry::HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\"
$OriginalTitle = "$Host.UI.RawUI.WindowTitle"

function Output-SessionsList {
    param (
        $Sessions
    )

	$counter = 1;
	Write-Host "-. exit"
	Write-Host "0. putty"
	$Sessions | ForEach-Object {"$($counter). $($_)"; $counter++}
	Write-Host "---"
}

# get all sessions
$AllSessions = Get-Item -Path "$($RegistryPath)*" |
			Select-Object -ExpandProperty Name |
			Split-Path -leaf |
			Sort-Object

$Mask = $args[0]
$PrevMask = "$([char]0x00)"
while (1) {
	# output list
	if ($PrevMask -ne $Mask) {
		# filter list
		if ($Mask.Length -gt 0) {
			$Sessions = @($AllSessions | Where-Object {$_ -match $Mask})
		} else {
			$Sessions = @($AllSessions)
		}

		Output-SessionsList $Sessions
		$PrevMask = $Mask
	}

	# prompt
	$Number = Read-Host "Choose session by number or enter mask"
	if ($Number -match '^\d+$' -and $Number -ge 0 -and $Number -le $Sessions.Length) {
		break
	} elseif ($Number -eq '-' -or $Number -eq '.') {
		exit
	} else {
		if ($Number -notmatch '^\d+$') {
			$Mask = $Number
		} else {
			Write-Host "wrong number"
		}
	}
}

# execute
if ($Number -eq 0) {
	Write-Host "Start putty"
	putty
} else {
	# get connection parameters
	$SessionName = $Sessions[$Number-1];
	$HostPortUser = Get-ItemPropertyValue -Path "$($RegistryPath)$($SessionName)" -Name HostName, PortNumber, UserName, UserNameFromEnvironment
	Write-Host "connecting to $SessionName ($($HostPortUser[0]):$($HostPortUser[1]))..."

	# get username
	$UserName=""
	if ($HostPortUser[3] -eq 0) {
		$UserName=$HostPortUser[2]
		if ($UserName.Length -eq 0) {
			# ask username
			[string]$UserName = Read-Host "login as"
		}
		$UserName="$UserName@"
	}

	# start session
	$Host.UI.RawUI.WindowTitle = "$SessionName ($($HostPortUser[0]))"
	$UserHost = "$($UserName)$($HostPortUser[0])"
	ssh -p $HostPortUser[1] $UserHost
	$Host.UI.RawUI.WindowTitle = $OriginalTitle
}
