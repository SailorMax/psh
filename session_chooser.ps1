# init
$RegistryPath = "Registry::HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\"

# get all sessions
$Sessions = Get-Item -Path "$($RegistryPath)*" |
			Select-Object -ExpandProperty Name |
			Split-Path -leaf |
			Sort-Object

# filter list
$mask = $args[0]
if ($mask.Length -gt 0) {
	$Sessions = $Sessions | Where-Object {$_ -match $mask}
}

# output list
$counter = 1;
Write-Host "0. putty"
$Sessions | ForEach-Object {"$($counter). $($_)"; $counter++}
Write-Host "---"
# ask to choose
[ValidateScript({$_ -ge 0 -and $_ -le $Sessions.Length})]
[int]$Number = Read-Host "Choose session by number"
if (!$?) {
	exit
}

# execute
if ($Number -eq 0) {
	Write-Host "Start putty"
	putty
} else {
	# get connection parameters
	$HostPortUser = Get-ItemPropertyValue -Path "$($RegistryPath)$($Sessions[$Number-1])" -Name HostName, PortNumber, UserName, UserNameFromEnvironment
	Write-Host "connecting to $($Sessions[$Number-1]) ($($HostPortUser[0]):$($HostPortUser[1]))..."

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
	$UserHost = "$($UserName)$($HostPortUser[0])"
	ssh -p $HostPortUser[1] $UserHost
}
