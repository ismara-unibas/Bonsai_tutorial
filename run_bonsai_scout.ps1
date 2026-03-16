param(
    [Alias("input-dir")]
    [string]$InputDir = (Get-Location).Path,

    [int]$Port = 9000
)

$ErrorActionPreference = "Stop"

$ContainerName = "bonsai"
$ImageName = "pachkov/bonsai"

if (-not (Test-Path -Path $InputDir -PathType Container)) {
    Write-Error "input-dir does not exist: $InputDir"
}

if (-not (Test-Path -Path 'bonsai_results' -PathType Container)) {
    Write-Error "bonsai_results directory not found in the current directory: $((Get-Location).Path)"
}

function Stop-BonsaiContainer {
    docker rm -f $ContainerName *> $null
}

function Test-ContainerRunning {
    $runningNames = docker ps --format '{{.Names}}'
    return $runningNames -contains $ContainerName
}

function Test-ContainerExists {
    $allNames = docker ps -a --format '{{.Names}}'
    return $allNames -contains $ContainerName
}

try {
    if (Test-ContainerRunning) {
        Write-Host "Container '$ContainerName' is already running. Restarting it..."
        Stop-BonsaiContainer
    }
    elseif (Test-ContainerExists) {
        Write-Host "Container '$ContainerName' exists but is not running. Removing it..."
        docker rm $ContainerName *> $null
    }

    Write-Host "Starting container '$ContainerName' from image '$ImageName'..."
    docker run -d `
        --name $ContainerName `
        -v "${InputDir}:/mnt" `
        -p "${Port}:${Port}" `
        $ImageName *> $null

    Write-Host "Starting bonsai_scout in the container..."
    docker exec `
        -w /mnt `
        -d $ContainerName `
        python3 /bonsai/bonsai_scout/run_bonsai_scout_app.py `
        --results_folder /mnt/bonsai_results `
        --settings_filename /mnt/bonsai_results/bonsai_vis_settings.json `
        --port 9000

    Write-Host "Container is running."
    Write-Host "Mounted: $InputDir -> /mnt"
    Write-Host "Port mapping: ${Port}:${Port}"
    Write-Host "Access the app at: http://localhost:$Port"
    Write-Host "Press CTRL-C to stop and remove the container."

    while ($true) {
        if (-not (Test-ContainerRunning)) {
            Write-Host "Container '$ContainerName' is no longer running. Exiting."
            Stop-BonsaiContainer
            exit 1
        }
        Start-Sleep -Seconds 1
    }
}
finally {
    Write-Host "Stopping and removing container '$ContainerName'..."
    Stop-BonsaiContainer
}
