<#
.SYNOPSIS
    Sample PowerShell script: parameters, pipelines, error handling, classes.
.EXAMPLE
    ./deploy.ps1 -Environment prod -Version 1.4.2 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [ValidateRange(1, 10)]
    [int]$MaxRetries = 3,

    [switch]$SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

enum DeployStatus {
    Pending
    Running
    Succeeded
    Failed
}

class DeployResult {
    [string]$Target
    [DeployStatus]$Status
    [timespan]$Duration

    DeployResult([string]$target, [DeployStatus]$status, [timespan]$duration) {
        $this.Target = $target
        $this.Status = $status
        $this.Duration = $duration
    }

    [string] ToString() {
        return "{0} => {1} in {2:n1}s" -f $this.Target, $this.Status, $this.Duration.TotalSeconds
    }
}

$script:Config = @{
    Registry = 'ghcr.io/blaccorek'
    Image    = "api:$Version"
    Replicas = @{ dev = 1; staging = 2; prod = 6 }
    Tags     = @('theme', 'vscode', 'samples')
}

function Write-Step {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)

    Write-Host ("==> {0}" -f $Message) -ForegroundColor Cyan
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [int]$Retries = $MaxRetries
    )

    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        try {
            return & $Action
        }
        catch {
            Write-Warning "attempt $attempt/$Retries failed: $($_.Exception.Message)"
            if ($attempt -eq $Retries) { throw }
            Start-Sleep -Milliseconds (250 * $attempt)
        }
        finally {
            Write-Verbose "attempt $attempt finished"
        }
    }
}

function Deploy-Environment {
    [OutputType([DeployResult])]
    param([string]$Name)

    $replicas = $script:Config.Replicas[$Name]
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    if ($PSCmdlet.ShouldProcess($Name, "deploy $($script:Config.Image) x$replicas")) {
        Invoke-WithRetry -Action {
            Write-Step "kubectl set image deployment/api api=$($script:Config.Registry)/$($script:Config.Image)"
            & kubectl set image "deployment/api" "api=$($script:Config.Registry)/$($script:Config.Image)" --namespace bnw
            if ($LASTEXITCODE -ne 0) { throw "kubectl exited with $LASTEXITCODE" }
        }
    }

    $stopwatch.Stop()
    return [DeployResult]::new($Name, [DeployStatus]::Succeeded, $stopwatch.Elapsed)
}

Write-Step "Deploying $Version to $Environment"

if (-not $SkipTests) {
    Write-Step 'Running tests'
    npm test -- --reporter=dot
}

$results = @($Environment) | ForEach-Object { Deploy-Environment -Name $_ }

$results |
    Where-Object { $_.Status -eq [DeployStatus]::Succeeded } |
    Sort-Object -Property Duration -Descending |
    Select-Object -Property Target, Status, @{ Name = 'Seconds'; Expression = { [math]::Round($_.Duration.TotalSeconds, 2) } } |
    Format-Table -AutoSize

Write-Host "done: $($results.Count) target(s), tags=$($script:Config.Tags -join ', ')" -ForegroundColor Green
exit 0
