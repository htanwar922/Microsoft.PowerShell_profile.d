# Basic linux functionalities

function head {
	param (
		[string]$file = "",
		[int]$n = 10
	)

	if ($file -eq "") {
		$Input | Select-Object -First $n
	} else {
		Get-Content $file | Select-Object -First $n
	}
}

function tail {
	param (
		[string]$file = "",
		[int]$n = 10
	)

	if ($file -eq "") {
		$Input | Select-Object -Last $n
	} else {
		Get-Content $file | Select-Object -Last $n
	}
}

function less {
	param (
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | Out-Host
	} else {
		Get-Content $file | Out-Host
	}
}

function wc {
	param (
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | Measure-Object | Select-Object -ExpandProperty Count
	} else {
		(Get-Content $file | Measure-Object).Count
	}
}

function grep {
	param (
		[string]$pattern = "",
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | Select-String $pattern
	} else {
		Get-Content $file | Select-String $pattern
	}
}

function sed {
	param (
		[string]$pattern = "",
		[string]$replacement = "",
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | ForEach-Object { $_ -replace $pattern, $replacement }
	} else {
		(Get-Content $file) -replace $pattern, $replacement
	}
}

function awk {
	param (
		[string]$script = "",
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | ForEach-Object { Invoke-Expression $script }
	} else {
		Get-Content $file | ForEach-Object { Invoke-Expression $script }
	}
}

function uniq {
	param (
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | Get-Unique
	} else {
		Get-Content $file | Get-Unique
	}
}

function cut {
	param (
		[int]$f = 1,
		[string]$d = " ",
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | ForEach-Object { $_.Split($d)[$f] }
	} else {
		Get-Content $file | ForEach-Object { $_.Split($d)[$f] }
	}
}

function tr {
	param (
		[string]$d = " ",
		[string]$s = "",
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | ForEach-Object { $_ -replace "[$s]", $d }
	} else {
		(Get-Content $file) -replace "[$s]", $d
	}
}

function join {
	param (
		[string]$d = " ",
		[string]$file1 = "",
		[string]$file2 = ""
	)

	$lines1 = Get-Content $file1
	$lines2 = Get-Content $file2

	for ($i = 0; $i -lt $lines1.Length; $i++) {
		$lines1[$i] + $d + $lines2[$i]
	}
}

function paste {
	param (
		[string]$d = " ",
		[string]$file1 = "",
		[string]$file2 = ""
	)

	$lines1 = Get-Content $file1
	$lines2 = Get-Content $file2

	for ($i = 0; $i -lt $lines1.Length; $i++) {
		$lines1[$i] + $d + $lines2[$i]
	}
}

function split {
	param (
		[string]$d = " ",
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | ForEach-Object { $_.Split($d) }
	} else {
		Get-Content $file | ForEach-Object { $_.Split($d) }
	}
}

function xargs {
	param (
		[string]$cmd = ""
	)

	$Input | ForEach-Object { Invoke-Expression "$cmd $_" }
}

function find_ {
	param (
		[string]$name = "*",
		[string]$path = "."
	)

	Get-ChildItem -Path $path -Recurse -Filter $name
}

function du {
	param (
		[string]$path = "."
	)

	Get-ChildItem -Path $path -Recurse | Measure-Object -Property Length -Sum
}

function df {
	Get-PSDrive -PSProvider FileSystem | Select-Object -Property Name, Used, Free
}

function top {
	Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 10
}

function free {
	Get-WmiObject -Class Win32_OperatingSystem | Select-Object -Property FreePhysicalMemory
}

function uname {
	$os = Get-WmiObject -Class Win32_OperatingSystem
	$cs = Get-WmiObject -Class Win32_ComputerSystem

	$os.Caption + " " + $os.Version + " " + $cs.Manufacturer + " " + $cs.Model
}
