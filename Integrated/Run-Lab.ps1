param([string]$ConfigPath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'config.json'),[switch]$NoHold)
$ErrorActionPreference='Stop'
foreach ($name in @('Config','Ssh','Runtime','Results')) { Import-Module (Join-Path $PSScriptRoot "modules/$name.psm1") -Force }
$runDir=$null; $lock=$null; $server=$null; $config=$null; $remoteRoot=''; $result='FAILED'; $failure=''
$completed=[Collections.Generic.List[object]]::new()
try {
    $config=Read-LabConfig $ConfigPath
    $runtime=Join-Path $PSScriptRoot '.runtime'
    New-Item -ItemType Directory -Path $runtime -Force | Out-Null
    $lock=[IO.File]::Open((Join-Path $runtime 'run.lock'),'OpenOrCreate','ReadWrite','None')
    $runId=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
    $runDir=Join-Path $runtime $runId
    New-Item -ItemType Directory -Path $runDir | Out-Null
    Start-Transcript -Path (Join-Path $runDir 'vehicle.log') | Out-Null
    $session=New-PiSession $config $runDir $PSScriptRoot
    Assert-PiIdentity $session $ConfigPath
    Send-LabFiles $session $PSScriptRoot $runId
    $remoteRoot="`$HOME/ota_integrated_runs/$runId"
    $server=Start-LabServer $config $runDir $PSScriptRoot $PID
    Wait-LabSignal $runDir 'ready' $config.server_signal_timeout_seconds
    $cases=Get-Content (Join-Path $PSScriptRoot 'scenarios/scenarios.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($case in $cases) {
        if ($case.id -notmatch '^[a-z][a-z0-9_]*$') { throw 'Invalid scenario ID' }
        Write-Host "`n=== $($case.title) ===" -ForegroundColor Cyan
        Start-Sleep -Seconds $config.step_pause_seconds
        Request-LabScenario $runDir $case
        Wait-LabSignal $runDir ($case.id+'.ready') $config.server_signal_timeout_seconds
        $output=Invoke-Pi $session "cd `"$remoteRoot`"; python3 scenarios/verify_scenario.py $($case.id)"
        $line=@($output -split '\r?\n' | Where-Object { $_.StartsWith('RESULT_JSON=') })
        if ($line.Count -ne 1) { throw 'Missing scenario result' }
        $verified=$line[0].Substring(12) | ConvertFrom-Json
        if ($verified.scenario -ne $case.id -or $verified.result -ne 'PASSED') { throw 'Invalid scenario result' }
        $completed.Add($verified)
    }
    $result='PASSED'
    Write-Host "`n통합 실습 완료: $($completed.Count)개 시나리오 통과" -ForegroundColor Green
} catch {
    $failure=$_.Exception.Message
    if ($config -and $config.password) { $failure=$failure.Replace($config.password,'[REDACTED]') }
    Write-Host $failure -ForegroundColor Red
} finally {
    if ($runDir) {
        [IO.File]::WriteAllText((Join-Path $runDir 'stop'),'stop')
        if ($server -and !$server.HasExited) {
            if (!$server.WaitForExit(([int]$config.http_timeout_seconds+5)*1000)) { $server.Kill(); $server.WaitForExit() }
        }
        $secret=Join-Path $runDir 'password.tmp'
        if (Test-Path $secret) { Remove-Item -LiteralPath $secret -Force }
        Save-LabResult $runDir $result $failure $remoteRoot $completed.ToArray()
        Write-Host "결과: $runDir"
        try { Stop-Transcript | Out-Null } catch {}
    }
    if ($lock) { $lock.Dispose() }
}
if (!$NoHold) { Read-Host '결과 확인 후 Enter' | Out-Null }
if ($result -ne 'PASSED') { exit 1 }
