param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BonsaiArgs
)

$ErrorActionPreference = 'Stop'

$CONTAINER_NAME = 'bonsai'
$IMAGE_NAME = 'pachkov/bonsai'
$INPUT_DIR = (Get-Location).Path
$NUM_THREADS = 4

$argsTokens = (($BonsaiArgs -join ' ').Trim() -split '\s+') | Where-Object { $_ -ne '' }
$nIndex = [Array]::IndexOf($argsTokens, '-n')
if ($nIndex -ge 0) {
    if ($nIndex + 1 -ge $argsTokens.Count) {
        throw 'Error: -n requires a positive integer value.'
    }

    $parsedThreads = 0
    if (-not [int]::TryParse($argsTokens[$nIndex + 1], [ref]$parsedThreads) -or $parsedThreads -lt 1) {
        throw 'Error: -n requires a positive integer value.'
    }
    $NUM_THREADS = $parsedThreads
}
elseif ($argsTokens.Count -ge 2) {
    $parsedThreads = 0
    if (-not [int]::TryParse($argsTokens[1], [ref]$parsedThreads) -or $parsedThreads -lt 1) {
        throw 'Error: second token in BonsaiArgs must be a positive integer for NUM_THREADS.'
    }
    $NUM_THREADS = $parsedThreads
}

if (-not (Test-Path -Path 'sanity_results' -PathType Container)) {
    throw "Error: sanity_results directory not found in the current directory: $INPUT_DIR"
}

function Cleanup {
    Write-Host ''
    Write-Host "Stopping and removing container '$CONTAINER_NAME'..."
    docker rm -f $CONTAINER_NAME *> $null
}

try {
    $runningContainers = docker ps --format '{{.Names}}'
    if ($runningContainers -contains $CONTAINER_NAME) {
        Write-Host "Container '$CONTAINER_NAME' is already running. Restarting it..."
        docker rm -f $CONTAINER_NAME | Out-Null
    }
    else {
        $allContainers = docker ps -a --format '{{.Names}}'
        if ($allContainers -contains $CONTAINER_NAME) {
            Write-Host "Container '$CONTAINER_NAME' exists but is not running. Removing it..."
            docker rm $CONTAINER_NAME | Out-Null
        }
    }

    Write-Host "Starting container '$CONTAINER_NAME' from image '$IMAGE_NAME'..."
    docker run -d `
        --name $CONTAINER_NAME `
        -v "${INPUT_DIR}:/mnt" `
        $IMAGE_NAME | Out-Null

    Write-Host 'Container is running.'
    Write-Host "Mounted: $INPUT_DIR -> /mnt"
    Write-Host 'Starting bonsai in the container...'

    if (Test-Path -Path 'cellstates_results/optimized_clusters.txt' -PathType Leaf) {
        docker exec `
            -w /mnt `
            -t $CONTAINER_NAME `
            bash -c "mkdir -p bonsai_results/premerge_cs && python /bonsai/bonsai/create_config_file.py --new_yaml_path /mnt/bonsai_results/bonsai_config.yaml --dataset 'bonsai_docker' --data_folder /mnt/sanity_results --results_folder /mnt/bonsai_results --nnn_n_randomtrees 8 --nnn_n_randommoves 1000 --tmp_folder /mnt/bonsai_results/premerge_cs --input_is_sanity_output True"
        
        docker exec `
            -w /mnt `
            -t $CONTAINER_NAME `
            bash -c "python /bonsai/optional_preprocessing/create_cellstates_premerged_tree.py --config_filepath /mnt/bonsai_results/bonsai_config.yaml --verbose True --premerged_folder /mnt/bonsai_results/premerge_cs --cellstates_file /mnt/cellstates_results/optimized_clusters.txt"
    }
    else {
        Write-Host 'Skipping Cellstates premerged tree step: cellstates_results/optimized_clusters.txt not found.'

        docker exec `
            -w /mnt `
            -t $CONTAINER_NAME `
            bash -c "mkdir -p bonsai_results/premerge_cs && python /bonsai/bonsai/create_config_file.py --new_yaml_path /mnt/bonsai_results/bonsai_config.yaml --dataset 'bonsai_docker' --data_folder /mnt/sanity_results --results_folder /mnt/bonsai_results --nnn_n_randomtrees 8 --nnn_n_randommoves 1000 --input_is_sanity_output True"
    }

    
    docker exec `
        -w /mnt `
        -t $CONTAINER_NAME `
        bash -c "mpiexec --allow-run-as-root -n $NUM_THREADS python -m mpi4py /bonsai/bonsai/bonsai_main.py --config_filepath /mnt/bonsai_results/bonsai_config.yaml"

    docker exec `
        -w /mnt `
        -t $CONTAINER_NAME `
        bash -c "rm -rf /mnt/bonsai_results/bonsai_vis*; mkdir -p /mnt/annotation; python /bonsai/bonsai_scout/bonsai_scout_preprocess.py --results_folder /mnt/bonsai_results --annotation_path /mnt/annotation --take_all_genes False"

    Write-Host 'Bonsai run finished.'
}
finally {
    Cleanup
}
