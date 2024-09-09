# sudo

function sudo {
	$openShell = $false
	$logOutput = $false
	while ( $args[0].StartsWith('-') ) {
		if ( $args[0] -eq '-i' ) {
			$openShell = $true
			$args = $args[1..($args.Length - 1)]
		}
		if ( $args[0] -eq '-l' ) {
			$logOutput = $true
			$args = $args[1..($args.Length - 1)]
		}
	}

	if ($openShell) {
		$process = Start-Process -FilePath 'pwsh' -ArgumentList "-ExecutionPolicy Bypass -NoExit" -Verb RunAs -PassThru
		return $process
	}

	if ($logOutput) {
		$outputFile = [System.IO.Path]::GetTempFileName()
		Out-File -FilePath $outputFile -Encoding utf8
		$process = Start-Process -FilePath 'pwsh' -ArgumentList "-ExecutionPolicy Bypass -Command $args | Out-File -FilePath '$outputFile' -Encoding utf8" -Verb RunAs -PassThru

		$lineCount = (Get-Content $outputFile | Measure-Object -Line).Lines
		while (-not $process.HasExited) {
			$lineCountNew = (Get-Content $outputFile | Measure-Object -Line).Lines
			if ($lineCountNew -gt $lineCount) {
				$lines = Get-Content $outputFile -Tail ($lineCountNew - $lineCount)
				foreach ($line in $lines) {
					"$line"
				}
				$lineCount = $lineCountNew
			}
		}

		$lineCountNew = (Get-Content $outputFile | Measure-Object -Line).Lines
		if ($lineCountNew -gt $lineCount) {
			$lines = Get-Content $outputFile -Tail ($lineCountNew - $lineCount)
			foreach ($line in $lines) {
				"$line"
			}
		}

		Remove-Item $outputFile
		return $process
	}

	for ($i = 0; $i -lt $args.Length; $i++) {
		$args[$i] = $args[$i] -replace ' ', '` '
		$args[$i] = $args[$i] -replace '"', '""'
		$args[$i] = "`"$($args[$i])`""
	}
	$process = Start-Process -FilePath 'pwsh' -ArgumentList "-ExecutionPolicy Bypass -NoExit -Command $args" -Verb RunAs -PassThru

	return $process
}
