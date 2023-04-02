# init
$RegistryPath = 'Registry::HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\'
$OriginalTitle = $Host.UI.RawUI.WindowTitle

function Wait-PressEnter {
	$Host.UI.RawUI.FlushInputBuffer()
	$KeyEvent = $null
	do {
		$PrevKeyEvent = $KeyEvent
		$KeyEvent = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown,IncludeKeyUp')
	} while (-not ($PrevKeyEvent -and ($KeyEvent.VirtualKeyCode -eq 13) -and ($PrevKeyEvent.VirtualKeyCode -eq $KeyEvent.VirtualKeyCode) -and ($PrevKeyEvent.KeyDown -ne $KeyEvent.KeyDown)))
}

function Output-SessionsList {
    param (
		[string[]]$Sessions
    )

	$counter = 1
	Write-Host "0. putty"
	$Sessions | ForEach-Object {Write-Host "$($counter). $_"; $counter++}
	Write-Host "---"
}

function Get-AllSessions {
	if ($script:AllSessions -eq $null) {
		$script:AllSessions = @(Get-Item -Path "$($RegistryPath)*" |
								Select-Object -ExpandProperty Name |
								Split-Path -leaf |
								Sort-Object)
	}
	return $script:AllSessions
}

function Choose-Session {
    param (
        $Mask
    )
	# get all sessions
	$AllSessions = Get-AllSessions
	$ServerPort = $null
	$Number = $null

	$PrevMask = ''
	while ($true) {
		# output list
		if ($PrevMask -ne $Mask) {
			# filter list
			if ($Mask.Length -gt 0) {
				$Sessions = @($AllSessions | Where-Object {$_ -match $Mask})
			} else {
				$Sessions = @($AllSessions)
				$Mask = '' # redefine because it can be $null
			}

			# nothing found => try to use mask as direct host name
			if ($Sessions.Count -eq 0) {
				Try-ToUseDirectHostNameAndExit $Mask
			}

			Output-SessionsList $Sessions
			$PrevMask = $Mask
		}

		# prompt
		Write-Host 'Choose session by ' -NoNewLine
		Write-Host 'number' -ForegroundColor Green -NoNewLine
		Write-Host ', enter filter ' -NoNewLine
		Write-Host 'word' -ForegroundColor Green -NoNewLine
		Write-Host ' or ' -NoNewLine
		Write-Host 'address:port' -ForegroundColor Green -NoNewLine
		Write-Host ': ' -NoNewLine
		$Number = Read-Host
		if ($Number -match '^\d+$' -and [int]$Number -ge 0 -and [int]$Number -le $Sessions.Length) {
			break
		} elseif ($Number -eq '-' -or $Number -eq '.') {
			exit
		} else {
			if ($Number -notmatch '^-?\d+$') {
				$Mask = $Number
			} else {
				Write-Host "wrong number"
			}
		}
	}

	if ($Number -eq 0) {
		return $null
	}

	return $Sessions[$Number-1]
}

function Get-Timestamp {
	return [Math]::Floor(([DateTime](Get-Date)).ToFileTimeUtc() / 10000000)
}

function Get-UserName {
    param (
		[string]$UserName,
		[int]$UserNameFromEnvironment
    )

	if ($UserNameFromEnvironment -eq 0) {
		if ($UserName.Length -eq 0) {
			# ask username
			[string]$UserName = Read-Host 'login as'
		} else {
			Write-Host "login as: $UserName"
		}
		$UserName = "$UserName@"
	} else {
		$UserName = ''
		Write-Host "login as: $($env:UserName)"
	}
	return $UserName
}

function Open-Session {
    param (
		[string]$SessionName,
        [string]$HostName,
		[int]$PortNumber,
		[string]$UserName,
		[int]$UserNameFromEnvironment
    )

	if ($SessionName.Length -eq 0) {
		$SessionName = "$($HostName):$PortNumber"
	}

	Write-Host "connecting to " -NoNewLine
	Write-Host $SessionName -ForegroundColor Yellow -NoNewLine
	if ($SessionName -ne "$($HostName):$PortNumber") {
		Write-Host " ($($HostName):$PortNumber)" -NoNewLine
	}
	Write-Host '...'

	$UserName = Get-UserName $UserName $UserNameFromEnvironment

	# start session
	$Host.UI.RawUI.WindowTitle = "$SessionName ($HostName)"

	$PauseSeconds = 5
	while ($true) {
		$ts = Get-Timestamp
		ssh -p $PortNumber $UserName$HostName
		if ($?) {
			# normal exit
			break
		}

		if (($(Get-Timestamp) - $ts) -gt 120) {
			# was successfuly connection (>120s) => start retries from begin
			$PauseSeconds = 5
		} elseif ($PauseSeconds -gt 30) {
			Write-Host "[ $((Get-Date).toString('yyyy-MM-dd HH:mm:ss')) ]"
			Write-Host -NoNewLine "Too many reconnections. Press ENTER to retry..."
			Wait-PressEnter
			Write-Host ""
			$PauseSeconds = 5
			continue
		}

		# retry on errors
		Write-Host "Reconnection after $PauseSeconds seconds."
		Start-Sleep -Seconds $PauseSeconds
		Write-Host "Reconnecting..."
		$PauseSeconds = $PauseSeconds * 2
	}

	$Host.UI.RawUI.WindowTitle = $OriginalTitle
}

function Try-ToUseDirectHostNameAndExit {
    param (
		[string]$HostString
    )

	if ($HostString -notmatch '^[a-zA-Z0-9_\-:@\.]+$') {
		return
	}

	$AllSessions = Get-AllSessions
	$Sessions = @($AllSessions | Where-Object {$_ -match $HostString})
	if ($Sessions.Count -ne 0) {
		return
	}

	if ($HostString -match '@') {
		$UserHost = $HostString.Split("@", 2)
	} else {
		$UserHost = '', $HostString
	}

	if ($UserHost[1] -match ':') {
		$HostPort = $UserHost[1].Split(":", 2)
	} else {
		# skip address without port to allow mistaken filter words
		return
	}

	if ($HostPort[1] -notmatch '^\d*$') {
		return
	}

	Open-Session '' $HostPort[0] $HostPort[1] $UserHost[0]
	exit 0
}


### Main ####
$Mask = $args[0]

Try-ToUseDirectHostNameAndExit $Mask
$SessionName = Choose-Session $Mask

# execute
if ($SessionName -eq $null) {
	Write-Host "Start putty"
	putty
} else {
	# get connection parameters
	$HostPortUser = Get-ItemPropertyValue -Path "$($RegistryPath)$($SessionName)" -Name HostName, PortNumber, UserName, UserNameFromEnvironment

	Open-Session $SessionName $HostPortUser[0] $HostPortUser[1] $HostPortUser[2] $HostPortUser[3]
}
