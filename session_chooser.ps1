# Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

# get all sessions
$Sessions = Get-Item -Path Registry::HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\* |
			Select-Object -ExpandProperty Name |
			Split-Path -leaf |
			Sort-Object

# filter list
$mask=$args[0]
if ($mask.Length -gt 0) {
	$Sessions = $Sessions | Where-Object {$_ -match $mask}
}

# output list
$counter=1;
Write-Host "0. putty"
$Sessions | ForEach-Object {"$($counter). $($_)"; $counter++}
Write-Host "---"
[ValidateScript({$_ -ge 0 -and $_ -le $Sessions.Length})]
[int]$Number = Read-Host "Choose session by number"

# exec
if ($?) {
	if ($Number -eq 0) {
		putty
	} else {
		$HostPortUser = Get-ItemPropertyValue -Path Registry::HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\$($Sessions[$Number-1]) -Name HostName, PortNumber, UserName, UserNameFromEnvironment
		Write-Host "connecting to $($Sessions[$Number-1]) ($($HostPortUser[0]):$($HostPortUser[1]))..."

		$UserName=""
		if ($HostPortUser[3] -eq 0) {
			$UserName=$HostPortUser[2]
			if ($UserName.Length -eq 0) {
				[string]$UserName = Read-Host "login as"
			}
			$UserName="$UserName@"
		}

		$UserHost = "$UserName$($HostPortUser[0])"
		ssh $UserHost -p $HostPortUser[1]
	}
}
