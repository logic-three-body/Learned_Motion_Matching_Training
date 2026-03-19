param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [int]$NIter03 = 300,
    [int]$NIter45 = 800
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cases = Join-Path $RepoRoot 'scripts\cases'

function Run-Timed {
    param([scriptblock]$Block)
    return (Measure-Command $Block).TotalSeconds
}

Write-Host 'Running hardware benchmark...'

$cpu03 = Run-Timed { & (Join-Path $cases 'case-03-train-decompressor.ps1') -RepoRoot $RepoRoot -NIter $NIter03 -Device cpu -BatchSize 128 -SaveEvery -1 }
$cpu04 = Run-Timed { & (Join-Path $cases 'case-04-train-projector.ps1') -RepoRoot $RepoRoot -NIter $NIter45 -Device cpu -BatchSize 128 -SaveEvery -1 }
$cpu05 = Run-Timed { & (Join-Path $cases 'case-05-train-stepper.ps1') -RepoRoot $RepoRoot -NIter $NIter45 -Device cpu -BatchSize 128 -SaveEvery -1 }

$gpu03 = Run-Timed { & (Join-Path $cases 'case-03-train-decompressor.ps1') -RepoRoot $RepoRoot -NIter $NIter03 -Device cuda:1 -BatchSize 256 -SaveEvery -1 }
$gpu04 = Run-Timed { & (Join-Path $cases 'case-04-train-projector.ps1') -RepoRoot $RepoRoot -NIter $NIter45 -Device cuda:0 -BatchSize 32 -SaveEvery -1 }
$gpu05 = Run-Timed { & (Join-Path $cases 'case-05-train-stepper.ps1') -RepoRoot $RepoRoot -NIter $NIter45 -Device cuda:1 -BatchSize 64 -SaveEvery -1 }

$dualParallel = Run-Timed {
    $j1 = Start-Job -ScriptBlock {
        param($repo, $script)
        & $script -RepoRoot $repo -NIter 800 -Device cuda:0 -BatchSize 32 -SaveEvery -1
    } -ArgumentList $RepoRoot, (Join-Path $cases 'case-04-train-projector.ps1')

    $j2 = Start-Job -ScriptBlock {
        param($repo, $script)
        & $script -RepoRoot $repo -NIter 800 -Device cuda:1 -BatchSize 64 -SaveEvery -1
    } -ArgumentList $RepoRoot, (Join-Path $cases 'case-05-train-stepper.ps1')

    Wait-Job $j1, $j2 | Out-Null
    Receive-Job $j1 | Out-Null
    Receive-Job $j2 | Out-Null
    Remove-Job $j1, $j2
}

$summary = @()
$summary += [pscustomobject]@{ Scenario='CPU baseline'; case03=$cpu03; case04=$cpu04; case05=$cpu05; total=($cpu03+$cpu04+$cpu05) }
$summary += [pscustomobject]@{ Scenario='Single GPU tuned'; case03=$gpu03; case04=$gpu04; case05=$gpu05; total=($gpu03+$gpu04+$gpu05) }
$summary += [pscustomobject]@{ Scenario='Dual GPU tuned (04/05 parallel)'; case03=$gpu03; case04=[double]::NaN; case05=[double]::NaN; total=($gpu03+$dualParallel) }

$summary | Format-Table -AutoSize

$report = Join-Path $RepoRoot 'docs\hardware_benchmark_latest.md'
$lines = @(
    '# Hardware Benchmark Summary',
    '',
    '| Scenario | case-03 (s) | case-04 (s) | case-05 (s) | Total (s) |',
    '|---|---:|---:|---:|---:|'
)
foreach ($row in $summary) {
    $c4 = if ([double]::IsNaN($row.case04)) { '-' } else { '{0:N3}' -f $row.case04 }
    $c5 = if ([double]::IsNaN($row.case05)) { '-' } else { '{0:N3}' -f $row.case05 }
    $lines += "| $($row.Scenario) | {0:N3} | $c4 | $c5 | {1:N3} |" -f $row.case03, $row.total
}
$lines += ''
$lines += '- Recommendation: use Dual GPU tuned profile for best wall-clock under this machine.'
Set-Content -Path $report -Value $lines -Encoding utf8
Write-Host "Benchmark report written: $report"
