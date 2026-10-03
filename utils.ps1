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
		$Input | more
	} else {
		Get-Content $file | more
	}
}

function wc_ {
	param (
		[string]$file = ""
	)

	if ($file -eq "") {
		$lines = @($Input)
	} else {
		$lines = @(Get-Content $file)
	}

	$lineCount = $lines.Count
	$wordCount = @(($lines -join "`n") -split '\s+' | Where-Object { $_ -ne '' }).Count
	$charCount = ($lines -join '').Length

	"$lineCount $wordCount $charCount"
}

function grep_ {
	param (
		[string]$pattern = "",
		[string]$file = "",
		[Switch]$v,		# Invert match
		[Switch]$i,		# Case insensitive
		[Switch]$c		# Count lines
	)

	$params = @{ Pattern = $pattern; AllMatches = $true }
	if (-not $i) { $params['CaseSensitive'] = $true }
	if ($v) { $params['NotMatch'] = $true }

	if ($file -eq "") {
		$result = $Input | Select-String @params
	} else {
		$result = Select-String -Path $file @params
	}

	if ($c) {
		@($result).Count
	} else {
		$result
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
		[string]$d = "`t",
		[string]$file = ""
	)

	if ($file -eq "") {
		$Input | ForEach-Object {
			$fields = $_.Split($d, [System.StringSplitOptions]::None)
			if ($f -le $fields.Length) { $fields[$f - 1] }
		}
	} else {
		Get-Content $file | ForEach-Object {
			$fields = $_.Split($d, [System.StringSplitOptions]::None)
			if ($f -le $fields.Length) { $fields[$f - 1] }
		}
	}
}

function tr {
    param (
            [string]$old = $null,
            [string]$new = $null,
            [string]$d = $null,
            [string]$file = $null
    )

    if ($d) {
        $trSet = [System.Collections.Generic.HashSet[char]]::new($d.ToCharArray())
        $transform = {
            param($line)
            ($line.ToCharArray() | Where-Object { -not $trSet.Contains($_) }) -join ''
        }
    } else {
        if (-not $old -or -not $new) {
            Write-Error "Invalid parameters"
            Write-Host "Usage: tr <old_chars> <new_chars> [-file <file_path>]"
            Write-Host "   or: tr -d <chars_to_delete> [-file <file_path>]"
            return
        }
        $expand = {
            param($s)
            $out = [System.Collections.Generic.List[char]]::new()
            $i = 0
            while ($i -lt $s.Length) {
                if ($i + 2 -lt $s.Length -and $s[$i + 1] -eq '-') {
                    $start = [int]$s[$i]
                    $end = [int]$s[$i + 2]
                    if ($end -ge $start) {
                        for ($c = $start; $c -le $end; $c++) { $out.Add([char]$c) }
                        $i += 3
                        continue
                    }
                }
                $out.Add($s[$i])
                $i++
            }
            -join $out
        }
        $oldChars = & $expand $old
        $newChars = & $expand $new
        $trMap = @{}
        for ($i = 0; $i -lt $oldChars.Length; $i++) {
            $trMap[$oldChars[$i]] = $newChars[[Math]::Min($i, $newChars.Length - 1)]
        }
        $transform = {
            param($line)
            $chars = $line.ToCharArray()
            for ($i = 0; $i -lt $chars.Length; $i++) {
                if ($trMap.ContainsKey($chars[$i])) { $chars[$i] = $trMap[$chars[$i]] }
            }
            -join $chars
        }
    }

    if ($file) {
        Get-Content $file | ForEach-Object { & $transform $_ }
    } else {
        $Input | ForEach-Object { & $transform $_ }
    }
}

function join_ {
	param (
		[string]$d = " ",
		[string]$file1 = "",
		[string]$file2 = ""
	)

	$lines1 = @(Get-Content $file1)
	$lines2 = @(Get-Content $file2)

	$count = [Math]::Max($lines1.Count, $lines2.Count)
	for ($i = 0; $i -lt $count; $i++) {
		$l1 = if ($i -lt $lines1.Count) { $lines1[$i] } else { "" }
		$l2 = if ($i -lt $lines2.Count) { $lines2[$i] } else { "" }
		$l1 + $d + $l2
	}
}

function paste_ {
	param (
		[string]$d = " ",
		[string]$file1 = "",
		[string]$file2 = ""
	)

	$lines1 = @(Get-Content $file1)
	$lines2 = @(Get-Content $file2)

	$count = [Math]::Max($lines1.Count, $lines2.Count)
	for ($i = 0; $i -lt $count; $i++) {
		$l1 = if ($i -lt $lines1.Count) { $lines1[$i] } else { "" }
		$l2 = if ($i -lt $lines2.Count) { $lines2[$i] } else { "" }
		$l1 + $d + $l2
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

	$sum = (Get-ChildItem -Path $path -Recurse -File | Measure-Object -Property Length -Sum).Sum
	"{0:N2} MB" -f ($sum / 1MB)
}

function df_ {
	Get-PSDrive -PSProvider FileSystem | Select-Object -Property Name, Used, Free
}

function top_ {
	Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 10
}

function free_ {
	$os = Get-CimInstance -Class Win32_OperatingSystem

	[PSCustomObject]@{
		TotalMB = [math]::Round($os.TotalVisibleMemorySize / 1KB)
		FreeMB  = [math]::Round($os.FreePhysicalMemory / 1KB)
	}
}

function uname_ {
	$os = Get-CimInstance -Class Win32_OperatingSystem
	$cs = Get-CimInstance -Class Win32_ComputerSystem

	$os.Caption + " " + $os.Version + " " + $cs.Manufacturer + " " + $cs.Model
}
