
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

    $input_ = [ref]''
    $jobs = New-Object System.Collections.ArrayList
    $sockets = New-Object System.Collections.ArrayList

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
        $input_.Value = ''

        while ($true) {
            $jobs | ForEach-Object {
                if ($_.State -eq 'Completed') {
                    'Job completed'
                    $input_.Value = 'exit'
                    $jobs.Remove($_)
                    break
                }
                Receive-Job -Job $_
            }
            $c = getchar
            if ($null -eq $c) {
                continue
            }
            if ($c -eq "`b") {
                $input_.Value = $input_.Value.Substring(0, $input_.Value.Length - 1)
                Write-Host "`b `b" -NoNewline
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

    function Start-UDP-RX {
        param(
            [System.Object] $socket,
            [ref] $remoteEndPoint,
            [string] $rxJobName
        )

        Get-Job -Name $rxJobName -ErrorAction SilentlyContinue | Remove-Job -Force | Out-Null

        $remoteEndPoint.Value = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, 0)
        $rxJob = Start-ThreadJob -Name $rxJobName -ScriptBlock {
            param($socket, [ref] $remoteEndPoint)
            while ($true) {
                try {
                    $data = $socket.Receive($remoteEndPoint)
                    $message = [System.Text.Encoding]::ASCII.GetString($data)
                    $message
                } catch {
                    Write-Error $_.Exception.Message
                    Start-Sleep -Milliseconds 1000
                }
            }
        } -ArgumentList $socket, $remoteEndPoint

        $jobs.Add($rxJob) | Out-Null
    }

    function Start-UDP-TX {
        param(
            [System.Object] $socket,
            [ref] $remoteEndPoint = $null
        )

        while ($true) {
            GetInputInParallel

            if ($input_.Value -eq "exit") {
                break
            }

            if ($input_.Value -eq "") {
                continue
            }

            $data = [System.Text.Encoding]::ASCII.GetBytes($input_.Value)
            if ($null -eq $remoteEndPoint.Value) {
                $length = $socket.Send($data, $data.Length)
            } else {
                $length = $socket.Send($data, $data.Length, $remoteEndPoint.Value)
            }
            if ($length -ne $data.Length ) {
                "Failed to send data"
                "Invalid parameters. Data: " + $input_.Value + ", RemoteEndPoint: " + $remoteEndPoint.Value.ToString()
            }
        }

        $socket.Close()
    }

    function Start-UDPServer {
        param(
            [int]$port
        )

        $server = New-Object System.Net.Sockets.UdpClient $port
        $sockets.Add($server) | Out-Null
        Write-Output "UDP server listening at $port"

        [ref] $remoteEndPoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, 0)
        $rxJobName = 'UDP-RX:' + $port

        Start-UDP-RX -socket $server -remoteEndPoint $remoteEndPoint -rxJobName $rxJobName
        Start-UDP-TX -socket $server -remoteEndPoint $remoteEndPoint
    }

    function Start-UDPClient {
        param(
            [string]$ip,
            [int]$port
        )

        $client = New-Object System.Net.Sockets.UdpClient
        $sockets.Add($client) | Out-Null
        Write-Output "Connecting UDP to $ip`:$port"

        $client.Connect($ip, $port)
        [ref] $remoteEndPoint = $null
        $rxJobName = 'UDP-RX:' + $ip + ':' + $port

        Start-UDP-RX -socket $client -remoteEndPoint $remoteEndPoint -rxJobName $rxJobName
        Start-UDP-TX -socket $client -remoteEndPoint ([ref] $null)
    }

    function Start-TCP-RX {
        param(
            [System.Object] $socket,
            [System.IO.StreamReader] $reader,
            [string] $rxJobName
        )

        Get-Job -Name $rxJobName -ErrorAction SilentlyContinue | Remove-Job -Force | Out-Null

        $rxJob = Start-ThreadJob -Name $rxJobName -ScriptBlock {
            param($reader)
            while ($true) {
                try {
                    $message = $reader.ReadLine()
                    $message
                } catch {
                    'Client disconnected'
                    break
                }
            }
        } -ArgumentList $reader

        $jobs.Add($rxJob) | Out-Null
    }

    function Start-TCP-TX {
        param(
            [System.Object] $socket,
            [System.IO.StreamWriter] $writer
        )

        while ($socket.Connected) {
            GetInputInParallel

            if ($input_.Value -eq "exit") {
                break
            }

            if ($input_.Value -eq "") {
                continue
            }

            try {
                $writer.WriteLine($input_.Value)
                $writer.Flush()
            } catch {
                'Client disconnected'
                break
            }
        }
    }

    function Start-TCPServer {
        param(
            [int]$port
        )

        $listener = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Any, $port)
        $sockets.Add($listener) | Out-Null
        $listener.Start()
        Write-Output "TCP server listening at $port"

        while ($true) {
            $client = $listener.AcceptTcpClient()
            $sockets.Add($client) | Out-Null
            Write-Output "Client connected"

            $stream = $client.GetStream()
            $reader = New-Object System.IO.StreamReader $stream
            $writer = New-Object System.IO.StreamWriter $stream

            $rxJobName = 'TCP-RX:' + $port
            Start-TCP-RX -socket $client -reader $reader -rxJobName $rxJobName
            Start-TCP-TX -socket $client -writer $writer

            $reader.Close()
            $writer.Close()
            $client.Close()
            $sockets.Remove($client)

            if ($input_.Value -eq "exit") {
                break
            }
        }

        $listener.Stop()
        $sockets.Remove($listener)
    }

    function Start-TCPClient {
        param(
            [string]$ip,
            [int]$port
        )

        $client = New-Object System.Net.Sockets.TcpClient
        $sockets.Add($client) | Out-Null
        Write-Output "Connecting TCP to $ip`:$port"

        $client.Connect($ip, $port)
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader $stream
        $writer = New-Object System.IO.StreamWriter $stream

        $rxJobName = 'TCP-RX:' + $ip + ':' + $port
        Start-TCP-RX -socket $client -reader $reader -rxJobName $rxJobName
        Start-TCP-TX -socket $client -writer $writer

        $reader.Close()
        $writer.Close()
        $client.Close()
        $sockets.Remove($client)
    }

    try {
        if ($l) {
            if ($port -eq 0) {
                throw 'Port number is required for TCP/UDP server'
            }
            if ($u) {
                Start-UDPServer -port $port
            } else {
                Start-TCPServer -port $port
            }
        } else {
            if ($u) {
                Start-UDPClient -ip $ip -port $port
            } else {
                Start-TCPClient -ip $ip -port $port
            }
        }
    } catch {
        Write-Error $_.Exception.Message
        $sockets | ForEach-Object {
            $_.Dispose()
        }
    } finally {
        $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }
}


Set-Alias nc NetCat
