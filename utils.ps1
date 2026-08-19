# Basic linux functionalities

function head_ {
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

function tail_ {
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

function less_ {
	param (
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | Out-Host
	} else {
		Get-Content $file | Out-Host
	}
}

function wc_ {
	param (
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | Measure-Object | Select-Object -ExpandProperty Count
	} else {
		(Get-Content $file | Measure-Object).Count
	}
}

function grep_ {
	param (
		[string]$pattern = "",
		[string]$file = "",
		[Switch]$v,		# Invert match
		[Switch]$i,		# Case insensitive
		[Switch]$c		# Count lines
	)

	$pattern = [regex]::Escape($pattern)

	if ($i) {
		$pattern = "(?i)$pattern"
	}

	if ($file -eq "") {
		if ($c) {
			$Input | Select-String -Pattern $pattern -AllMatches | Measure-Object | Select-Object -ExpandProperty Count
		} else {
			if ($v) {
				$Input | Select-String -Pattern $pattern -AllMatches -NotMatch -CaseSensitive
			} else {
				$Input | Select-String -Pattern $pattern -AllMatches -CaseSensitive
			}
		}
	} else {
		if ($c) {
			(Get-Content $file | Select-String -Pattern $pattern -AllMatches).Count
		} else {
			if ($v) {
				Select-String -Path $file -Pattern $pattern -AllMatches -NotMatch -CaseSensitive
			} else {
				Select-String -Path $file -Pattern $pattern -AllMatches -CaseSensitive
			}
		}
	}
}

function sed_ {
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

function awk_ {
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

function uniq_ {
	param (
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | Get-Unique
	} else {
		Get-Content $file | Get-Unique
	}
}

function cut_ {
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
            [string]$old = $null,
            [string]$new = $null,
            [string]$d = $null,
            [string]$file = $null
    )

    if ($old -and $new) {
        if (-not $file) {
                $Input | ForEach-Object { $_ -replace "[$old]", $new }
        } else {
                (Get-Content $file) -replace "[$old]", $new
        }
        return
    }

    if ($d) {
        if (-not $file) {
                $Input | ForEach-Object { $_ -split "[$d]" -join "" }
        } else {
                (Get-Content $file) -split "[$d]" -join ""
        }
        return
    }

    Write-Error "Invalid parameters"
    Write-Host "Usage: tr [-old] <old_chars> [-new] <new_chars> [-file <file_path>]"
    Write-Host "   or: tr -d <chars_to_delete> [-file <file_path>]"
    return $null
}

function join_ {
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

function paste_ {
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

function split_ {
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

function xargs_ {
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

function du_ {
	param (
		[string]$path = "."
	)

	Get-ChildItem -Path $path -Recurse | Measure-Object -Property Length -Sum
}

function df_ {
	Get-PSDrive -PSProvider FileSystem | Select-Object -Property Name, Used, Free
}

function top_ {
	Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 10
}

function free_ {
	Get-WmiObject -Class Win32_OperatingSystem | Select-Object -Property FreePhysicalMemory
}

function uname_ {
	$os = Get-WmiObject -Class Win32_OperatingSystem
	$cs = Get-WmiObject -Class Win32_ComputerSystem

	$os.Caption + " " + $os.Version + " " + $cs.Manufacturer + " " + $cs.Model
}
