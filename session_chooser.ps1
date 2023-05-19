# Support arguments:
# - filter_word
# - host:port
# - host:port check_host_timeout

# init
$RegistryPath = 'Registry::HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\'
$OriginalTitle = $Host.UI.RawUI.WindowTitle
$ForegroundColor = $Host.UI.RawUI.ForegroundColor
$BackgroundColor = $Host.UI.RawUI.BackgroundColor

$InputMask = $args[0]
$CheckConnectionTimeout = $args[1]

function Get-Timestamp {
	return [Math]::Floor(([DateTime](Get-Date)).ToFileTimeUtc() / 10000000)
}

function Get-ClearHostLine {
	return (" " * $Host.UI.RawUI.WindowSize.Width) + "`r"
}

function Wait-PressEnter {
	$Host.UI.RawUI.FlushInputBuffer()
	$KeyEvent = $null
	do {
		$PrevKeyEvent = $KeyEvent
		$KeyEvent = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown,IncludeKeyUp')
	} while (-not ($PrevKeyEvent -and ($KeyEvent.VirtualKeyCode -eq 13) -and ($PrevKeyEvent.VirtualKeyCode -eq $KeyEvent.VirtualKeyCode) -and ($PrevKeyEvent.KeyDown -ne $KeyEvent.KeyDown)))
	$Host.UI.RawUI.FlushInputBuffer()
}

function Start-AbortableSleep {
    param (
		[int]$Seconds,
		[string]$TextPattern
    )

	$Aborted = $false
	$StartTime = Get-Timestamp
	$Host.UI.RawUI.FlushInputBuffer()
	while (($(Get-Timestamp) - $StartTime) -lt $Seconds)
	{
		$LeftSeconds = $($Seconds - ($(Get-Timestamp) - $StartTime))
		if ($TextPattern.Length -ne 0) {
			Write-Host ("`r$(Get-ClearHostLine)$TextPattern" -f $LeftSeconds) -NoNewLine
		} else {
			Write-Host "`r$(Get-ClearHostLine)$LeftSeconds" -NoNewLine
		}

		if ($Host.UI.RawUI.KeyAvailable) {
			$KeyEvent = $Host.UI.RawUI.ReadKey('AllowCtrlC,NoEcho,IncludeKeyDown,IncludeKeyUp')
			if ($KeyEvent.KeyDown -eq $true -and ($KeyEvent.VirtualKeyCode -eq 13 -or $KeyEvent.VirtualKeyCode -eq 27)) {
				$Host.UI.RawUI.FlushInputBuffer()
				$Aborted = $true
				break
			}
		} else {
			Start-Sleep -Milliseconds 100
		}
	}

	if ($TextPattern.Length -ne 0) {
		if ($Aborted) {
			Write-Host " timer aborted."
		} else {
			# restore original text for history
			Write-Host ("`r$(Get-ClearHostLine)$TextPattern" -f $Seconds)
		}
	} else {
		# clear timer line
		Write-Host "`r$(Get-ClearHostLine)" -NoNewLine
	}
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

function Get-PuttySessions {
	if ($script:AllSessions -eq $null) {
		$script:AllSessions = @(Get-Item -Path "$($RegistryPath)*" |
								Select-Object -ExpandProperty Name |
								Split-Path -leaf |
								Sort-Object)
	}
	return $script:AllSessions
}

function Get-UniqueSessionName {
	param (
		[string[]]$AllSessions,
		[string]$SessionName
	)

	$OriginalSessionName = $SessionName
	$counter = 2;
	while ((@($AllSessions | Where-Object {$_ -eq $SessionName})).Length -gt 0) {
		$SessionName = "$OriginalSessionName($counter)"
		$counter += 1
	}
	return $SessionName
}

function Save-PuttySession {
	param (
		[string]$SessionName,
		[string]$HostName,
		[string]$PortNumber,
		[string]$UserName
	)

	$AllSessions = Get-PuttySessions
	$HostNameExists = $false
	$ErrorActionPreference="SilentlyContinue"
	foreach ($item in $AllSessions) {
		$HostPortUser = Get-ItemPropertyValue -Path "$($RegistryPath)$($item)" -Name HostName, PortNumber
		if (($HostPortUser[0] -eq $HostName -or $HostPortUser[0] -eq $SessionName) -and ($HostPortUser[1] -eq $PortNumber)) {
			$HostNameExists = $true
			$HostUserNameExists = ($HostPortUser[2] -eq $UserName)
			break
		}
	}
	$ErrorActionPreference="Continue"

	if (-not $HostNameExists -or (-not $HostUserNameExists -and $UserName -eq "")) {
		$Host.UI.RawUI.FlushInputBuffer()
		Write-Host "Do you want to save this session ($($UserName)@$($HostName):$($PortNumber))? [y/N]: " -NoNewLine
		$confirmation = $Host.UI.RawUI.ReadKey('AllowCtrlC,IncludeKeyDown')
		$Host.UI.RawUI.FlushInputBuffer()
		Write-Host ""
		if ($confirmation.Character -eq 'y') {
			$SessionName = Get-UniqueSessionName $AllSessions $SessionName
			if (!($NewSessionName = Read-Host "Session name [$SessionName]")) { $NewSessionName = $SessionName }
			if (!($NewHostName = Read-Host "Host name [$HostName]")) { $NewHostName = $HostName }
			if (!($NewPortNumber = Read-Host "Port number [$PortNumber]")) { $NewPortNumber = $PortNumber }
			$NewUserName = Read-Host "User name []"

			$NewSessionName = Get-UniqueSessionName $AllSessions $NewSessionName

			New-Item -Path "$($RegistryPath)$($NewSessionName)" -ErrorAction SilentlyContinue | out-null
			if ($? -eq $true) {
				New-ItemProperty -Path "$($RegistryPath)$($NewSessionName)" -Name "HostName" -Value $NewHostName  -PropertyType "String" | out-null
				New-ItemProperty -Path "$($RegistryPath)$($NewSessionName)" -Name "PortNumber" -Value $NewPortNumber  -PropertyType "DWord" | out-null
				if ($NewUserName -ne "") {
					New-ItemProperty -Path "$($RegistryPath)$($NewSessionName)" -Name "UserName" -Value $NewUserName  -PropertyType "String" | out-null
				}
				Write-Host 'New session successfully saved!' -ForegroundColor Green
			} else {
				Write-Host "Can't write: $($RegistryPath)$($NewSessionName)" -ForegroundColor Red
			}
		}
	}
}

function Choose-Session {
    param (
        $Mask
    )
	# get all sessions
	$AllSessions = Get-PuttySessions
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
		Write-Host 'host:port' -ForegroundColor Green -NoNewLine
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

function Choose-UserName {
    param (
		[string]$UserName,
		[int]$UserNameFromEnvironment
    )

	if ($UserNameFromEnvironment -eq 0) {
		if ($UserName.Length -eq 0) {
			# ask username
			[string]$UserName = Read-Host "login as"
		} else {
			Write-Host "login as: $UserName"
		}
	} else {
		$UserName = ''
		Write-Host "login as: $($env:UserName)"
	}
	return $UserName
}

function Check-HostConnection {
    param (
        [string]$HostName,
		[int]$PortNumber
    )

	$timeout = 2000
	if ($CheckConnectionTimeout -ne $null) {
		$timeout = $CheckConnectionTimeout
	}

	$Socket = New-Object System.Net.Sockets.TcpClient
	try {
		$Result = $Socket.BeginConnect($HostName, $PortNumber, $NULL, $NULL)
		if (!$result.AsyncWaitHandle.WaitOne($timeout, $false)) {
			throw [System.Exception]::new('Connection Timeout')
		}
		$Socket.EndConnect($Result) | Out-Null
		$HostAccessibility = $Socket.Connected
	}
	catch {
		$HostAccessibility = $false
	}
	finally {
		$Socket.Close()
	}

	return $HostAccessibility
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
		# setup session name
		try {
			if ($HostName -match '^\d+\.\d+\.\d+\.\d+$') {
				$SessionName = (Resolve-DnsName $HostName -CacheOnly -ErrorAction Stop).NameHost
			} else {
				$IPAddress = (Resolve-DnsName $HostName -Type A -CacheOnly -ErrorAction Stop)[0].IPAddress
				$SessionName = $HostName
				$HostName = $IPAddress
			}
		}
		catch {
			$SessionName = "$($HostName):$PortNumber"
		}
	}

	Write-Host "connecting to " -NoNewLine
	Write-Host $SessionName -ForegroundColor Yellow -NoNewLine
	if ($SessionName -ne "$($HostName):$PortNumber") {
		Write-Host " ($($HostName):$PortNumber)" -NoNewLine
	}
	Write-Host '...'

	$HostAccessibility = Check-HostConnection $HostName $PortNumber
	if ($HostAccessibility -eq $false) {
		Write-Host "Error" -ForegroundColor Red -NoNewLine
		Write-Host ". Can't connect to the host."
		exit 1
	}

	# setup window title
	if ($SessionName -eq "$($HostName):$PortNumber") {
		$Host.UI.RawUI.WindowTitle = "$SessionName"
	} else {
		$Host.UI.RawUI.WindowTitle = "$SessionName ($($HostName):$PortNumber)"
	}

	# setup username as prefix
	$UserNamePrefix = ""
	$UserName = Choose-UserName $UserName $UserNameFromEnvironment
	if ($UserName -ne "") {
		$UserNamePrefix = "$UserName@"
	}

	# start session
	$PauseSeconds = 5
	while ($true) {
		$ts = Get-Timestamp
		ssh -p $PortNumber $UserNamePrefix$HostName

		# check normal exit or via self close (bash/Ctrl-C,..)
		if ($? -or $LASTEXITCODE -eq 130) {
			Save-PuttySession $SessionName $HostName $PortNumber $UserName
			break
		}
		Write-Host "$(Get-ClearHostLine)Exit code = $LASTEXITCODE"

		# check exit by Ctrl-C
		if ($Host.UI.RawUI.KeyAvailable) {
			$KeyEvent = $Host.UI.RawUI.ReadKey('AllowCtrlC,NoEcho,IncludeKeyDown,IncludeKeyUp')
			if ($KeyEvent.KeyDown -eq $false -and $KeyEvent.VirtualKeyCode -eq 67) {	# meta + 8 in Mac?
				# exit
				break
			}
		}

		# pause before next try
		if (($(Get-Timestamp) - $ts) -gt 120) {
			# was successfuly connection (>120s) => start retries from begin
			$PauseSeconds = 5
		} elseif ($PauseSeconds -gt 30) {
			Write-Host "$(Get-ClearHostLine)[ $((Get-Date).toString('yyyy-MM-dd HH:mm:ss')) ]"
			Write-Host "$(Get-ClearHostLine)Too many reconnections. Press ENTER to retry..." -NoNewLine
			Wait-PressEnter
			Write-Host ""
			Write-Host "$(Get-ClearHostLine)Reconnecting..."
			$PauseSeconds = 5
			continue
		}

		Start-AbortableSleep $PauseSeconds "Reconnection after {0} seconds..."

		Write-Host "$(Get-ClearHostLine)Reconnecting..."
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

	$AllSessions = Get-PuttySessions
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
Try-ToUseDirectHostNameAndExit $InputMask
$SessionName = Choose-Session $InputMask

# execute
if ($SessionName -eq $null) {
	Write-Host "Start putty"
	putty
} else {
	# get connection parameters
	$HostPortUser = Get-ItemPropertyValue -Path "$($RegistryPath)$($SessionName)" -Name HostName, PortNumber, UserName, UserNameFromEnvironment

	Open-Session $SessionName $HostPortUser[0] $HostPortUser[1] $HostPortUser[2] $HostPortUser[3]
}
