# Docker settings for linux-arm for DCU

$IMAGE = $IMAGE ? $IMAGE : 'linux'
$CONTAINER = $CONTAINER ? $CONTAINER : 'linux'
$DOCKER_USER = $DOCKER_USER ? $DOCKER_USER : 'himanshu'
$NETWORK = $NETWORK ? $NETWORK : 'bridge'
$DOCKER_SHELL = $DOCKER_SHELL ? $DOCKER_SHELL : 'zsh'

$WSL_USER = $WSL_USER ? $WSL_USER : 'himanshu'
$BASE_IMAGE = $BASE_IMAGE ? $BASE_IMAGE : 'debian'
$DOCKER_SAVE = $null -ne $DOCKER_SAVE ? $DOCKER_SAVE : $false

# Initialize-Docker-Variables -image 'ubuntu:14.04-dev' -container 'trusty' -docker_user 'root' -docker_shell '' -network 'test' -base_image 'ubuntu:14.04' -docker_save $true
function Initialize-Docker-Variables {
    param (
        [string]$image = 'linux-arm',
        [string]$container = 'linux-arm',
        [string]$network = 'linux-arm',
        [string]$docker_user = 'himanshu',
        [string]$wsl_user = 'himanshu',
        [string]$docker_shell = 'zsh',
        [string]$base_image = 'osrf/ubuntu_armhf:focal',
        [bool]$docker_save = $false
    )

    $global:IMAGE = $image ? $image : $global:IMAGE
    $global:CONTAINER = $container ? $container : $global:CONTAINER
    $global:NETWORK = $network ? $network : $global:NETWORK
    $global:DOCKER_USER = $docker_user ? $docker_user : $global:DOCKER_USER
    $global:WSL_USER = $wsl_user ? $wsl_user : $global:WSL_USER
    $global:DOCKER_SHELL = $docker_shell ? $docker_shell : $global:DOCKER_SHELL
    $global:BASE_IMAGE = $base_image ? $base_image : $global:BASE_IMAGE
    $global:DOCKER_SAVE = $docker_save ? $docker_save : $global:DOCKER_SAVE
}

function Get-Docker-Binaries {
    param (
        [Switch]$force = $false
    )
    if ( $force -or $null -eq (Get-Command docker.exe -ErrorAction SilentlyContinue) ) {
        Write-Debug 'Downloading Docker binaries...'
        Invoke-WebRequest 'https://download.docker.com/win/static/stable/x86_64/docker-27.3.1.zip' -OutFile $env:TEMP\docker.zip
        Expand-Archive -Path $env:TEMP\docker.zip -DestinationPath $env:ProgramFiles\Docker
        Invoke-WebRequest 'https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-windows-x86_64.exe' -OutFile $Env:ProgramFiles\Docker\docker-compose.exe
        Remove-Item $env:TEMP\docker.zip
        Write-Debug 'Setup complete'
    }
    $env:Path = "$env:ProgramFiles\Docker;$env:Path"
    $env:DOCKER_HOST = 'tcp://localhost:2375'
}

function Initialize-Docker-Image {
    param (
        [Switch]$install = $false,
        [string]$image = $IMAGE,
        [string]$base_image = $BASE_IMAGE,
        [string]$container = $CONTAINER,
        [string]$docker_user = $DOCKER_USER
    )
    if ( $image -ne 'linux-arm' -and -not $install ) {
        docker tag $base_image $image
        Write-Output "Tagged $base_image as $image"
        return
    }

    $docker_user_home = if ($docker_user -eq 'root') { '/root' } else { "/home/$docker_user" }

    # basic setup
    if ( (docker ps -a --format '{{.Names}}') -contains $container ) { docker stop $container }
    docker pull $base_image
    docker run --rm -d -it --name $container $base_image sh

    if ( $docker_user -ne 'root' ) {
        docker exec --user=root -it $container useradd -mG 'adm,dialout,cdrom,floppy,sudo,audio,dip,video,plugdev' $docker_user
    }
    docker exec --user=root -it $container apt update
    docker exec --user=root -it $container apt install -y git zsh nano vim build-essential gcc g++ gdb libssl-dev
    docker exec --user=root -it $container apt install -y iputils-ping net-tools iproute2

    docker exec --user=root -it $container apt-get install -y zsh-*
    docker exec --user=root -it $container apt install -y zsh-autosuggestions zsh-syntax-highlighting
    docker exec --user=$docker_user -it $container git clone https://github.com/htanwar922/.zsh.git $docker_user_home/.zsh
    # docker exec --user=$docker_user -it $container git clone https://github.com/zsh-users/zsh-autosuggestions.git $docker_user_home/.zsh/zsh-autosuggestions
    # docker exec --user=$docker_user -it $container git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $docker_user_home/.zsh/zsh-syntax-highlighting

    docker exec --user=root -it $container ln -s $docker_user_home/.zsh/zshrc /root/.zshrc
    docker exec --user=root -it $container ln -s $docker_user_home/.zsh/zprofile /root/.zprofile
    docker exec --user=root -it $container ln -s $docker_user_home/.zsh/zshenv /root/.zshenv
    docker exec --user=root -it $container ln -s $docker_user_home/.zsh/zlogin /root/.zlogin
    docker exec --user=root -it $container ln -s $docker_user_home/.zsh/zlogout /root/.zlogout
    docker exec --user=root -it $container chsh -s /bin/zsh

    if ( $docker_user -ne 'root' ) {
        docker exec --user=$docker_user -it $container ln -s $docker_user_home/.zsh/zshrc $docker_user_home/.zshrc
        docker exec --user=$docker_user -it $container ln -s $docker_user_home/.zsh/zprofile $docker_user_home/.zprofile
        docker exec --user=$docker_user -it $container ln -s $docker_user_home/.zsh/zshenv $docker_user_home/.zshenv
        docker exec --user=$docker_user -it $container ln -s $docker_user_home/.zsh/zlogin $docker_user_home/.zlogin
        docker exec --user=$docker_user -it $container ln -s $docker_user_home/.zsh/zlogout $docker_user_home/.zlogout
        docker exec --user=root -it $container chsh -s /bin/zsh $docker_user

        docker exec --user=root -it $container zsh -c "echo '$docker_user' ALL='(ALL)' NOPASSWD:ALL | tee -a /etc/sudoers"
    }

    docker commit $container $image
    docker stop $container
    Write-Debug 'Setup complete'
}

function Start-Docker-Container {
    param (
        [string]$container = $CONTAINER,
        [string]$image = $IMAGE,
        [string]$network = $NETWORK,
        [string]$docker_user = $DOCKER_USER
    )
    $docker_user_home = if ($docker_user -eq 'root') { '/root' } else { "/home/$docker_user" }
    if ( $network -notin (docker network ls --format '{{.Name}}') ) {
        docker network create $network
    }
    if ( (docker ps -a --format '{{.Names}}') -contains $container ) {
        docker stop $container
        Start-Sleep -Seconds 1
        docker rm $container 2> $null
        Start-Sleep -Seconds 1
    }

    $DISPLAY = (wsl -e sh -c 'echo $DISPLAY')

    Start-Sleep -Seconds 1
    docker run --rm -d -it --privileged --cap-add=SYS_PTRACE `
        --security-opt seccomp=unconfined --security-opt apparmor=unconfined `
        --network $network @args `
        -e TZ=Asia/Kolkata -e DISPLAY=$DISPLAY `
        -v /tmp/.X11-unix:/tmp/.X11-unix `
        -v /home/$WSL_USER/.ssh:$docker_user_home/.ssh `
        -v /home/$WSL_USER/concentrator:$docker_user_home/concentrator `
        -v /home/$WSL_USER/Downloads:$docker_user_home/Downloads `
        --name $container --user=$docker_user $image sh
}

function Invoke-Docker-Container {
    param (
        [string]$cmd = '',
        [string]$container = $CONTAINER,
        [string]$docker_user = $DOCKER_USER,
        [Switch]$save
    )

    docker version > $null
    $cmd = $cmd ? $cmd : "$DOCKER_SHELL -ilsc 'cd; $DOCKER_SHELL -ils'"
    Invoke-Expression "docker exec --user=$docker_user -it $container $cmd"

    if ( $DOCKER_SAVE -or $save ) {
        Save-Docker-Container -container $container
    }
}

function Save-Docker-Container {
    param (
        [string]$container = $CONTAINER,
        [string]$image = $null
    )
    if (-not $image) {
        $image = (docker inspect $container | ConvertFrom-Json).Config.Image
    }

    Write-Host "Saving container $container as image $image"
    docker commit $container $image
}

function Clear-Docker-Images {
    (docker images --format "{{.Repository}}:{{.Tag}}:{{.ID}}") -like "*<none>*" | ForEach-Object {
        docker rmi ($_ -split ':')[2] --force
    }
}

function Remove-Docker-Container {
    param (
        [Switch]$force = $false,
        [string]$container = $CONTAINER
    )

    $networks = (docker container inspect $container | ConvertFrom-Json).NetworkSettings.Networks.PSObject.Properties.Name

    docker stop $container; Start-Sleep -Seconds 1
    if ( (docker ps -a --format '{{.Names}}') -contains $container ) {
        docker rm $container $($force ? '--force' : $null) || `
            Write-Output 'Failed to remove container $container' && `
            return
    }

    if ( -not $force ) {
        return
    }

    Foreach ($network in $networks) {
        $containers = (docker network inspect $network | ConvertFrom-Json).Containers
        if (-not $containers.PSObject.Properties.Value -and $network -notin ('bridge', 'host', 'none')) {
            docker network rm $network
        }
    }

    Clear-Docker-Images
}

function Stop-Docker-Container {
    param (
        [string]$container = $CONTAINER
    )
    if ( $DOCKER_SAVE ) {
        Save-Docker-Container -container $container
    }
    Remove-Docker-Container -container $container
}

function Set-Docker-AutoComplete-Suggestions {
    param($type = $null)

    switch ($type) {
        'image' {
            return {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

                $images = @('$null')
                $images += docker images --format "{{.Repository}}:{{.Tag}}"
                $images += docker images --format "{{.ID}}"
                $images -like "$wordToComplete*"
            }
        }
        'container' {
            return {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

                $containers = @()
                $containers += docker ps --format "{{.Names}}"
                $containers += docker ps --format "{{.ID}}"
                $containers -like "$wordToComplete*"
            }
        }
        'network' {
            return {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

                $networks = @()
                $networks += docker network ls --format '{{.Name}}'
                $networks -like "$wordToComplete*"
            }
        }
        'user' {
            return {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

                $users = @('root', 'himanshu')
                $users -like "$wordToComplete*"
            }
        }
        'bool' {
            return {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

                $bools = @('$true', '$false')
                $bools -like "$wordToComplete*"
            }
        }
        'wsl_user' {
            return {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

                $users = @('himanshu')
                $users -like "$wordToComplete*"
            }
        }
        'shell' {
            return {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

                $shells = @('bash', 'zsh', 'sh', 'ash', 'dash', 'ksh', 'csh', 'tcsh')
                $shells -like "$wordToComplete*"
            }
        }
        Default {
            return {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            }
        }
    }
}

Register-ArgumentCompleter -CommandName Initialize-Docker-Variables -ParameterName image -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'image').Invoke($args) }
Register-ArgumentCompleter -CommandName Initialize-Docker-Variables -ParameterName container -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'container').Invoke($args) }
Register-ArgumentCompleter -CommandName Initialize-Docker-Variables -ParameterName network -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'network').Invoke($args) }
Register-ArgumentCompleter -CommandName Initialize-Docker-Variables -ParameterName docker_user -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'user').Invoke($args) }
Register-ArgumentCompleter -CommandName Initialize-Docker-Variables -ParameterName base_image -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'image').Invoke($args) }
Register-ArgumentCompleter -CommandName Initialize-Docker-Variables -ParameterName docker_save -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'bool').Invoke($args) }
Register-ArgumentCompleter -CommandName Initialize-Docker-Variables -ParameterName wsl_user -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'wsl_user').Invoke($args) }
Register-ArgumentCompleter -CommandName Initialize-Docker-Variables -ParameterName docker_shell -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'shell').Invoke($args) }

Register-ArgumentCompleter -CommandName Initialize-Docker-Image -ParameterName install -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'bool').Invoke($args) }
Register-ArgumentCompleter -CommandName Initialize-Docker-Image -ParameterName image -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'image').Invoke($args) }
Register-ArgumentCompleter -CommandName Initialize-Docker-Image -ParameterName base_image -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'image').Invoke($args) }
Register-ArgumentCompleter -CommandName Initialize-Docker-Image -ParameterName container -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'container').Invoke($args) }
Register-ArgumentCompleter -CommandName Initialize-Docker-Image -ParameterName docker_user -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'user').Invoke($args) }

Register-ArgumentCompleter -CommandName Start-Docker-Container -ParameterName container -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'container').Invoke($args) }
Register-ArgumentCompleter -CommandName Start-Docker-Container -ParameterName image -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'image').Invoke($args) }
Register-ArgumentCompleter -CommandName Start-Docker-Container -ParameterName network -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'network').Invoke($args) }
Register-ArgumentCompleter -CommandName Start-Docker-Container -ParameterName docker_user -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'user').Invoke($args) }

Register-ArgumentCompleter -CommandName Invoke-Docker-Container -ParameterName cmd -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'shell').Invoke($args) }
Register-ArgumentCompleter -CommandName Invoke-Docker-Container -ParameterName container -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'container').Invoke($args) }
Register-ArgumentCompleter -CommandName Invoke-Docker-Container -ParameterName docker_user -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'user').Invoke($args) }

Register-ArgumentCompleter -CommandName Save-Docker-Container -ParameterName container -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'container').Invoke($args) }
Register-ArgumentCompleter -CommandName Save-Docker-Container -ParameterName image -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'image').Invoke($args) }

Register-ArgumentCompleter -CommandName Remove-Docker-Container -ParameterName force -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'bool').Invoke($args) }
Register-ArgumentCompleter -CommandName Remove-Docker-Container -ParameterName container -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'container').Invoke($args) }

Register-ArgumentCompleter -CommandName Stop-Docker-Container -ParameterName container -ScriptBlock { (Set-Docker-AutoComplete-Suggestions 'container').Invoke($args) }

Set-Alias 'docker-setup-image'        'Initialize-Docker-Image'
Set-Alias 'docker-start-container'    'Start-Docker-Container'
Set-Alias 'docker-run-container'      'Invoke-Docker-Container'
Set-Alias 'docker-stop-container'     'Stop-Docker-Container'
Set-Alias 'docker-cleanup-container'  'Remove-Docker-Container'
Set-Alias 'docker-save-container'     'Save-Docker-Container'
Set-Alias 'docker-clear-images'       'Clear-Docker-Images'
