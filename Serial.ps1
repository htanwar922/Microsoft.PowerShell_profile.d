function Get-ComPorts {
	$comPorts = [System.IO.Ports.SerialPort]::GetPortNames()
	if ($comPorts.Count -eq 0) {
		Write-Host "No COM ports found."
	} else {
		Write-Host "Available COM ports:"
		$comPorts
	}
}

function Read-ComPort {
	param (
		[string]$comPort,
		[int]$baudRate = 9600,
		[int]$dataBits = 8,
		[System.IO.Ports.Parity]$parity = [System.IO.Ports.Parity]::None,
		[System.IO.Ports.StopBits]$stopBits = [System.IO.Ports.StopBits]::One
	)

	$serialPort = New-Object System.IO.Ports.SerialPort $comPort
	$serialPort.BaudRate = $baudRate
	$serialPort.DataBits = $dataBits
	$serialPort.Parity = $parity
	$serialPort.StopBits = $stopBits
	$serialPort.Open()

	Write-Host "Reading data from $comPort..."
	while ($true) {
		if ($serialPort.BytesToRead -gt 0) {
			$data = $serialPort.ReadLine()
			Write-Host "Received data: $data"
		}
		Start-Sleep -Seconds 1
	}

	$serialPort.Close()
}
