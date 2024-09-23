# Docker settings for linux-arm for DCU

$IMAGE = $IMAGE ? $IMAGE : "linux-arm"
$CONTAINER = $CONTAINER ? $CONTAINER : "linux-arm"
$NETWORK = $NETWORK ? $NETWORK : "linux-arm"
$USER = $USER ? $USER : "himanshu"
$WSL_USER = $WSL_USER ? $WSL_USER : "himanshu"
$BASE_IMAGE = $BASE_IMAGE ? $BASE_IMAGE : "osrf/ubuntu_armhf:focal"

$DOCKER_SHELL = $DOCKER_SHELL ? $DOCKER_SHELL : "zsh"
$DOCKER_SAVE = $null -ne $DOCKER_SAVE ? $DOCKER_SAVE : $true

$DOCKER_IS_WSL_COMMAND = $null -ne $DOCKER_IS_WSL_COMMAND ? $DOCKER_IS_WSL_COMMAND : $false
$DOCKER_USE_EXE = $null -ne $DOCKER_USE_EXE ? $DOCKER_USE_EXE : $false

function _quote {
    param (
        [string]$str
    )

    if ($DOCKER_IS_WSL_COMMAND -and $DOCKER_USE_EXE) {
        return "'$str'"
    } else {
        return "$str"
    }
}

function docker-env {
    param (
        [hashtable]$kvp = @{}
        # [PSCustomObject]$kvp
    )

    docker version > $null

    # foreach ($property in $kvp.PSObject.Properties) {
    #     Set-Item -Path "Env:$($property.Name)" -Value $property.Value
    #     $WSLENV += ':' + $property.Name
    # }

    $kvp.GetEnumerator() | ForEach-Object {
        Set-Item -Path "Env:$($_.Key)" -Value $_.Value

        if ($DOCKER_IS_WSL_COMMAND) {
            $WSLENV = (Get-Item -Path "Env:WSLENV").Value
            if (-not [string]::IsNullOrEmpty($WSLENV) -and $WSLENV[-1] -ne ":") {
                $WSLENV += ":"
            }
            $WSLENV += $_.Key
            Set-Item -Path "Env:WSLENV" -Value $WSLENV
        }
    }
}

function docker-setup-image {
    # basic setup
    if ( docker ps -a | Select-String $CONTAINER ) { docker stop $CONTAINER }
    docker pull $BASE_IMAGE
    docker run --rm -d -it --name $CONTAINER $BASE_IMAGE bash
    docker exec --user=root -it $CONTAINER useradd -mG 'adm,dialout,cdrom,floppy,sudo,audio,dip,video,plugdev' $USER
    docker exec --user=root -it $CONTAINER bash -c (_quote 'apt update')
    docker exec --user=root -it $CONTAINER bash -c (_quote 'apt install git zsh nano vim build-essential gcc g++ gdb -y')
    docker exec --user=$USER -it $CONTAINER git clone https://github.com/htanwar922/.zsh.git /home/$USER/.zsh
    # docker exec --user=$USER -it $CONTAINER git clone https://github.com/zsh-users/zsh-autosuggestions.git /home/$USER/.zsh/zsh-autosuggestions
    # docker exec --user=$USER -it $CONTAINER git clone https://github.com/zsh-users/zsh-syntax-highlighting.git /home/$USER/.zsh/zsh-syntax-highlighting
    docker exec --user=root -it $CONTAINER bash -c (_quote 'apt-get install zsh-* -y')
    docker exec --user=root -it $CONTAINER bash -c (_quote 'apt install zsh-autosuggestions zsh-syntax-highlighting -y')
    docker exec --user=root -it $CONTAINER ln -s /home/$USER/.zsh/zshrc /root/.zshrc
    docker exec --user=root -it $CONTAINER ln -s /home/$USER/.zsh/zprofile /root/.zprofile
    docker exec --user=root -it $CONTAINER chsh -s /bin/zsh
    docker exec --user=$USER -it $CONTAINER ln -s /home/$USER/.zsh/zshrc /home/$USER/.zshrc
    docker exec --user=$USER -it $CONTAINER ln -s /home/$USER/.zsh/zprofile /home/$USER/.zprofile
    docker exec --user=root -it $CONTAINER chsh -s /bin/zsh $USER
    if ($DOCKER_IS_WSL_COMMAND) {
        docker exec --user=root -it $CONTAINER zsh -c (_quote "echo $USER ALL=\(ALL\) NOPASSWD:ALL | tee -a /etc/sudoers")
    } else {
        docker exec --user=root -it $CONTAINER zsh -c "echo '$USER' ALL='(ALL)' NOPASSWD:ALL | tee -a /etc/sudoers"
    }
    docker commit $CONTAINER $IMAGE
    docker stop $CONTAINER
    Write-Debug "Setup complete"
}
function docker-start-container {
    param (
        [string]$cmd = ""
    )

    docker network create $NETWORK
    if ( docker ps -a | Select-String $CONTAINER ) {
        docker stop $CONTAINER
    }

    if ($DOCKER_IS_WSL_COMMAND) {
        if ( "$args" -eq "" ) {
            docker run --rm -d -it --privileged --cap-add=SYS_PTRACE `
                --security-opt seccomp=unconfined --security-opt apparmor=unconfined `
                --network $NETWORK -p 58020:58020 -p 58021:58021 -p 9020:9020/udp `
                ($env:WSLENV -split ':' | ForEach-Object { $_ ? "-e $_" : $null }) `
                -v /home/$WSL_USER/.ssh:/home/$USER/.ssh `
                -v /home/$WSL_USER/concentrator/:/home/$USER/concentrator `
                --name $CONTAINER --user=$USER $IMAGE
        } else {
            docker run --rm -d -it --privileged --cap-add=SYS_PTRACE `
                --security-opt seccomp=unconfined --security-opt apparmor=unconfined `
                --network $NETWORK "$args" `
                ($env:WSLENV -split ':' | ForEach-Object { $_ ? "-e $_" : $null }) `
                -v /home/$WSL_USER/.ssh:/home/$USER/.ssh `
                -v /home/$WSL_USER/concentrator/:/home/$USER/concentrator `
                --name $CONTAINER --user=$USER $IMAGE
        }
    } else {
        if ( "$args" -eq "" ) {
            docker run --rm -d -it --privileged --cap-add=SYS_PTRACE `
            --security-opt seccomp=unconfined --security-opt apparmor=unconfined `
            --network $NETWORK -p 58020:58020 -p 58021:58021 -p 9020:9020/udp `
            -v \\wsl.localhost\Ubuntu\home\$WSL_USER\.ssh:/home/$USER/.ssh `
            -v \\wsl.localhost\Ubuntu\home\$WSL_USER\concentrator\:/home/$USER/concentrator `
            --name $CONTAINER --user=$USER $IMAGE
        } else {
            docker run --rm -d -it --privileged --cap-add=SYS_PTRACE `
                --security-opt seccomp=unconfined --security-opt apparmor=unconfined `
                --network $NETWORK "$args" `
                -v \\wsl.localhost\Ubuntu\home\$WSL_USER\.ssh:/home/$USER/.ssh `
                -v \\wsl.localhost\Ubuntu\home\$WSL_USER\concentrator\:/home/$USER/concentrator `
                --name $CONTAINER --user=$USER $IMAGE
        }
    }
}
function docker-run-container {
    param (
        [string]$cmd = ""
    )

    docker version > $null
    if ($cmd -eq "") {
        if ($DOCKER_USE_EXE) {
            Write-Debug 'Using WSL from docker.exe...'
            $cmd = "$DOCKER_SHELL -ilsc (_quote 'cd; $DOCKER_SHELL -ils')"
        } else {
            $cmd = "$DOCKER_SHELL -ilsc 'cd; $DOCKER_SHELL -ils'"
        }
    }
    docker exec --user=$USER -it $CONTAINER $cmd
    docker-save-container
}
function docker-save-container {
    if ($DOCKER_SAVE) {
        docker commit $CONTAINER $IMAGE
    }
}
function docker-cleanup-container {
    docker stop $CONTAINER
    docker network rm $NETWORK

    # cleanup after commit
    ( docker images | Select-String "<none>" ) -replace '\s{2,}', ',' `
        | ConvertFrom-Csv -Header "REPOSITORY", "TAG", "IMAGE_ID", "CREATED", "SIZE" `
        | Select-Object -ExpandProperty IMAGE_ID | ForEach-Object { docker rmi $_ --force }
}
function docker-stop-container {
    docker-save-container
    docker-cleanup-container
}

function docker {
    if ( $DOCKER_IS_WSL_COMMAND ) {
        if ( $DOCKER_USE_EXE ) {
            Write-Debug "Using WSL from docker.exe..."
            docker.exe $args
        } else {
            Write-Debug "Using WSL..."
            wsl -d Ubuntu -e docker $args
        }
        return
    }
    if ( $null -eq (Get-Command docker.exe -ErrorAction SilentlyContinue) -or `
            (docker.exe info 2>&1 | Select-String 'ERROR: error during connect') ) {
        Write-Debug "Choosing WSL..."
        $global:DOCKER_IS_WSL_COMMAND = $true
        wsl -d Ubuntu -e docker $args
    } elseif ( (docker.exe info 2>&1 | Select-String 'Operating System' | `
                ConvertFrom-StringData -Delimiter :).Values.Contains('Ubuntu') ) {
        Write-Debug "Using WSL from docker.exe..."
        $global:DOCKER_IS_WSL_COMMAND = $true
        $global:DOCKER_USE_EXE = $true
        docker.exe $args
    } else {
        Write-Debug "Not using WSL..."
        docker.exe $args
    }
}
