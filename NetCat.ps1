
# Netcat using powershell

function NetCat {
    param(
        [string]$h = "",
        [int]$p,
        [Switch]$l = $false,  # "server" or "client"
        [Switch]$u = $false
    )

    $ip = $h
    $port = $p
    Write-Output $ip`:$port

    $jobs = New-Object System.Collections.ArrayList
    $input_ = [ref]''

    function getchar {
        param (
            [int]$TimeoutInSeconds = 1
        )

        $endTime = [DateTime]::Now.AddSeconds($TimeoutInSeconds)

        $c = $null
        while ([DateTime]::Now -lt $endTime) {
            if ([Console]::KeyAvailable) {
                $c = [Console]::ReadKey($true).KeyChar
                break
            }
        }
        return $c
    }

    function GetInputInParallel {
        # Write-Host "Enter message: " -NoNewline
        $input_.Value = ''

        while ($true) {
            $jobs | ForEach-Object {
                Receive-Job -Job $_
            }
            $c = getchar
            if ($null -eq $c) {
                continue
            }
            $input_.Value += $c
            Write-Host $c -NoNewline
            if ($c -eq "`r") {
                Write-Host
                break
            }
        }
        if ($input_.Value.EndsWith("`r")) {
            $input_.Value = $input_.Value.Substring(0, $input_.Value.Length - 1)
        }
    }

    function Start-TCPServer {
        param(
            [int]$port
        )

        $listener = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Any, $port)
        $listener.Start()
        Write-Host "Listening on port $port..."

        while ($global:keepRunning) {
            if ($listener.Pending()) {
                $client = $listener.AcceptTcpClient()
                $stream = $client.GetStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $writer = New-Object System.IO.StreamWriter($stream)

                while ($global:keepRunning -and $null -ne ($line = [Console]::In.ReadLine())) {
                    $writer.WriteLine($line)
                    $writer.Flush()
                }

                $client.Close()
            } else {
                Start-Sleep -Milliseconds 100
            }
        }

        $listener.Stop()
        Write-Host "Server stopped."
    }

    function Start-TCPClient {
        param(
            [string]$ip,
            [int]$port
        )

        # Define the named pipe name
        $pipeName = "\\.\pipe\MyNamedPipe"

        # Create a named pipe
        $pipeServer = New-Object System.IO.Pipes.NamedPipeServerStream($pipeName, [System.IO.Pipes.PipeDirection]::InOut)

        # Create a TCP client
        $client = New-Object System.Net.Sockets.TcpClient($ip, $port)
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $writer = New-Object System.IO.StreamWriter($stream)

        # Start the named pipe server and connect it
        $pipeServer.WaitForConnection()
        $pipeReader = New-Object System.IO.StreamReader($pipeServer)
        $pipeWriter = New-Object System.IO.StreamWriter($pipeServer)

        # Job to read from stdin and send to the server
        $txJob = Start-Job -ScriptBlock {
            param($pipeWriter, $pipeReader)
            while ($keepRunning) {
                if ($pipeReader.Peek() -ne -1) {
                    $input_ = $pipeReader.ReadLine()
                    if ($null -ne $input_) {
                        # Send data to the server
                        $pipeWriter.WriteLine($input_)
                        $pipeWriter.Flush()
                    }
                }
                Start-Sleep -Milliseconds 100
            }
        } -ArgumentList $pipeWriter, $pipeReader

        # Job to read from the server and write to stdout
        $rxJob = Start-Job -ScriptBlock {
            param($reader)
            while ($keepRunning) {
                if ($reader.Peek() -ne -1) {
                    $line = $reader.ReadLine()
                    if ($null -ne $line) {
                        Write-Output "Received from server: $line"
                    }
                }
                Start-Sleep -Milliseconds 100
            }
        } -ArgumentList $reader

        # Main loop to handle user input and manage job states
        while ($true) {
            $input_ = Read-Host "Press 'q' to quit"
            if ($input_ -eq 'q') {
                $keepRunning = $false
                break
            }

            # Write to the named pipe
            $pipeWriter.WriteLine($input_)
            $pipeWriter.Flush()

            # Check for job errors
            if ($txJob.State -eq 'Failed' -or $rxJob.State -eq 'Failed') {
                Write-Error "One or more jobs failed"
                break
            }

            # Check for job completion
            if ($txJob.State -eq 'Completed' -and $rxJob.State -eq 'Completed') {
                break
            }

            # Wait for a bit before checking again
            Start-Sleep -Milliseconds 100

            # Check for job output
            $txJob | Receive-Job
            $rxJob | Receive-Job
        }

        # Clean up
        Remove-Job -Job $txJob -Force
        Remove-Job -Job $rxJob -Force
        $client.Close()
        $pipeServer.Close()
    }

    function Start-UDPServer {
        param(
            [int]$port
        )

        $rxJobName = 'UDP-RX:' + $port
        Get-Job -Name $rxJobName -ErrorAction SilentlyContinue | Remove-Job -Force | Out-Null

        $server = New-Object System.Net.Sockets.UdpClient $port
        Write-Output "UDP server listening at $port"

        $client = [ref] $null
        $rxJob = Start-ThreadJob -Name $rxJobName -ScriptBlock {
            param($server, [ref]$client)
            while ($true) {
                try {
                    $remoteEndPoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, 0)
                    $data = $server.Receive([ref]$remoteEndPoint)
                    $client.Value = $remoteEndPoint
                    $message = [System.Text.Encoding]::ASCII.GetString($data)
                    $message
                } catch {
                    Write-Error $_.Exception.Message
                    Start-Sleep -Milliseconds 1000
                }
            }
        } -ArgumentList $server, $client

        $jobs.Add($rxJob)

        while ($true) {
            GetInputInParallel

            if ($input_.Value -eq "exit") {
                break
            }

            if ($input_.Value -eq "") {
                continue
            }

            $data = [System.Text.Encoding]::ASCII.GetBytes($input_.Value)
            if ( $server.Send($data, $data.Length, $client.Value) -ne $data.Length ) {
                Write-Error "Failed to send data"
            }
        }

        $server.Close()
    }

    function Start-UDPClient {
        param(
            [string]$ip,
            [int]$port
        )

        $rxJobName = 'UDP-RX:' + $ip + ':' + $port
        Get-Job -Name $rxJobName -ErrorAction SilentlyContinue | Remove-Job -Force | Out-Null

        $client = New-Object System.Net.Sockets.UdpClient
        $client.Connect($ip, $port)
        Write-Output "Connecting UDP to $ip`:$port"

        $rxJob = Start-ThreadJob -Name $rxJobName -ScriptBlock {
            param($client, $rxQueue)
            # $client.Client.ReceiveTimeout = 1000
            while ($true) {
                try {
                    $remoteEndPoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, 0)
                    $data = $client.Receive([ref]$remoteEndPoint)
                    $message = [System.Text.Encoding]::ASCII.GetString($data)
                    $message
                } catch {
                    Write-Error $_.Exception.Message
                    Start-Sleep -Milliseconds 1000
                }
            }
        } -ArgumentList $client, $rxQueue

        $jobs.Add($rxJob)

        while ($true) {
            GetInputInParallel

            if ($input_.Value -eq "exit") {
                break
            }
            if ($input_.Value -eq "") {
                continue
            }

            $data = [System.Text.Encoding]::ASCII.GetBytes($input_.Value)
            if ( $client.Send($data, $data.Length) -ne $data.Length ) {
                Write-Error "Failed to send data"
            }
        }

        $client.Close()
    }

    try {
        if ($l) {
            if ($port -eq 0) {
                throw 'Port number is required for TCP/UDP server'
            }
            if ($u) {
                Start-UDPServer -port $port
            } else {
                Start-NetCatTCPServer -port $port
            }
        } else {
            if ($u) {
                Start-UDPClient -ip $ip -port $port
            } else {
                Start-NetCatTCPClient -ip $ip -port $port
            }
        }
    } finally {
        $jobs | Remove-Job -Force
    }
}


Set-Alias nc NetCat
