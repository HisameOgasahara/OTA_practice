function Wait-LabSignal([string]$RunDir,[string]$Name,[int]$Timeout) {
    $deadline=[DateTime]::UtcNow.AddSeconds($Timeout)
    while (!(Test-Path (Join-Path $RunDir $Name))) {
        if (Test-Path (Join-Path $RunDir 'server-error')) { throw (Get-Content (Join-Path $RunDir 'server-error') -Raw -Encoding UTF8) }
        if ([DateTime]::UtcNow -gt $deadline) { throw "Server timeout: $Name" }
        Start-Sleep -Milliseconds 100
    }
}
function Start-LabServer($Config,[string]$RunDir,[string]$Root,[int]$OwnerPid) {
    if (Get-NetTCPConnection -LocalPort $Config.day3_port -State Listen -ErrorAction SilentlyContinue) { throw 'OTA port already in use' }
    @{pc_ip=$Config.pc_ip;ip=$Config.ip;port=$Config.day3_port;http_timeout_seconds=$Config.http_timeout_seconds} | ConvertTo-Json | Set-Content (Join-Path $RunDir 'server.json') -Encoding UTF8
    $shell=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $server=Join-Path $Root 'server/Start-Server.ps1'
    $previousModulePath=$env:PSModulePath
    try {
        $env:PSModulePath=Join-Path (Split-Path $shell -Parent) 'Modules'
        $process=Start-Process -FilePath $shell -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$server+'"'),'-RunDir',('"'+$RunDir+'"'),'-OwnerPid',$OwnerPid) -WindowStyle Hidden -PassThru
    } finally { $env:PSModulePath=$previousModulePath }
    return $process
}
function Request-LabScenario([string]$RunDir,$Scenario) {
    $temp=Join-Path $RunDir 'request.tmp'
    [IO.File]::WriteAllText($temp,($Scenario | ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temp -Destination (Join-Path $RunDir 'request.json') -Force
}
Export-ModuleMember -Function Wait-LabSignal,Start-LabServer,Request-LabScenario
