param([string]$ConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'config.json'), [switch]$NoHold)
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'B - Day 2 Raspberry Pi OTA Lab'
$utf8 = [Text.UTF8Encoding]::new($false)
$runDir = $null; $passwordFile = $null; $lock = $null; $result = 'FAILED'; $failure = ''; $remoteRoot = ''

function Write-Stage([string]$Text) {
    Write-Host "`n========== $Text ==========" -ForegroundColor Cyan
    Start-Sleep -Seconds ([int]$config.step_pause_seconds)
}
function Wait-Signal([string]$Name) {
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while (!(Test-Path (Join-Path $runDir $Name))) {
        if (Test-Path (Join-Path $runDir 'server-error')) { throw (Get-Content (Join-Path $runDir 'server-error') -Raw) }
        if ([DateTime]::UtcNow -gt $deadline) { throw '서버 시작/변조 확인 시간 초과. A 창의 오류와 포트 사용 여부를 확인하세요.' }
        Start-Sleep -Milliseconds 200
    }
}
function Invoke-Pi([string]$Commands) {
    $commandFile = Join-Path $runDir 'remote-command.sh'
    [IO.File]::WriteAllText($commandFile, "set -eu`n" + $Commands.Replace("`r`n","`n") + "`n", $utf8)
    # Password contents are never placed on the command line or printed.
    $argsList = @('-ssh','-batch','-no-antispoof','-noagent','-hostkey',$config.ssh_host_key,'-pwfile',$passwordFile,'-l',$config.username,$config.ip,'-m',$commandFile)
    $lines = [Collections.Generic.List[string]]::new()
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $plink @argsList 2>&1 | ForEach-Object {
            $text = $_.ToString().Replace($config.password,'[REDACTED]')
            $lines.Add($text); Write-Host $text
        }
        $remoteExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($remoteExit -ne 0) { throw 'Pi 명령 실패. 위 오류와 config.json의 IP, 계정, 비밀번호, SSH 지문을 확인하세요. 자동 재탐색은 하지 않습니다.' }
    return ($lines -join "`n")
}
function Assert-Vehicle([string]$Version,[string]$Behavior) {
    $check = @'
cd "__ROOT__"
python3 - <<'PY'
import json
from pathlib import Path
s=json.loads(Path('day2_basic_ota/vehicle/state.json').read_text())
assert s['version']=='__VERSION__' and s['behavior']=='__BEHAVIOR__', s
print('[PASS] vehicle state verified')
PY
'@
    $null = Invoke-Pi ($check.Replace('__ROOT__',$remoteRoot).Replace('__VERSION__',$Version).Replace('__BEHAVIOR__',$Behavior))
}

try {
    if (!(Test-Path -LiteralPath $ConfigPath)) { throw '프로젝트 루트의 config_example.json을 config.json으로 복사하고 접속 정보를 입력하세요.' }
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($field in @('host_name','username','password','mac','ip','pc_ip','ssh_host_key')) {
        if (![string]$config.$field) { throw "config.json의 $field 값이 비어 있습니다." }
    }
    if ($config.username -notmatch '^[a-zA-Z_][a-zA-Z0-9_-]*[$]?$' -or $config.host_name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9.-]*$') { throw '계정 또는 호스트 이름 형식 오류' }
    if ($config.mac -notmatch '^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$') { throw 'MAC 주소 형식 오류' }
    foreach ($field in @('ip','pc_ip')) {
        $ipObject=$null
        if (![Net.IPAddress]::TryParse($config.$field,[ref]$ipObject) -or $ipObject.AddressFamily -ne 'InterNetwork') { throw "$field IPv4 형식 오류" }
    }
    if ([int]$config.port -ne 8000) { throw '교재의 Day 2 클라이언트는 8000번 포트를 사용합니다.' }
    if ([int]$config.step_pause_seconds -lt 0 -or [int]$config.step_pause_seconds -gt 30) { throw '단계 대기 시간은 0~30초 범위로 설정하세요.' }
    if ($config.password -match '[\r\n]') { throw '비밀번호에는 줄바꿈을 사용할 수 없습니다.' }
    if ($config.ssh_host_key -notmatch '^SHA256:[A-Za-z0-9+/]+={0,2}$') { throw 'SSH 호스트 지문은 SHA256: 형식으로 입력하세요.' }
    if (!(Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -eq $config.pc_ip)) { throw 'config.json의 pc_ip가 현재 PC 주소와 다릅니다. 값을 수정하세요.' }
    $runtime=Join-Path $PSScriptRoot '.runtime'
    New-Item -ItemType Directory -Path $runtime -Force | Out-Null
    try { $lock=[IO.File]::Open((Join-Path $runtime 'run.lock'),'OpenOrCreate','ReadWrite','None') } catch { throw 'Day 2 실습이 이미 실행 중입니다.' }
    if (Get-NetTCPConnection -LocalPort $config.port -State Listen -ErrorAction SilentlyContinue) { throw '8000번 포트가 이미 사용 중입니다. 기존 A 서버 창에서 Ctrl+C로 종료하고 다시 실행하세요.' }
    $probe=[Net.Sockets.TcpClient]::new()
    try { if (!$probe.ConnectAsync($config.ip,22).Wait(5000)) { throw 'SSH 접속 시간 초과. config.json의 IP와 Pi 전원을 확인하세요.' } } finally { $probe.Dispose() }
    $runId=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6)
    $runDir=Join-Path $runtime $runId
    New-Item -ItemType Directory -Path $runDir | Out-Null
    Start-Transcript -Path (Join-Path $runDir 'vehicle.log') | Out-Null
    Write-Host "설정된 Pi: $($config.host_name) / $($config.ip) / $($config.mac)"
    $tools=Get-Content (Join-Path $PSScriptRoot 'tools.json') -Raw | ConvertFrom-Json
    $toolDir=Join-Path $PSScriptRoot '.tools'
    New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
    $plink=Join-Path $toolDir 'plink.exe'
    if (!(Test-Path $plink)) {
        Write-Host "최초 실행: 공식 Plink $($tools.version) 다운로드"
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest $tools.url -OutFile $plink -UseBasicParsing
    }
    if ((Get-FileHash $plink -Algorithm SHA256).Hash -ne $tools.sha256) { throw 'Plink 다운로드 검증 실패. .tools/plink.exe를 삭제하고 다시 실행하세요.' }
    $passwordFile=Join-Path $runDir 'password.tmp'
    [IO.File]::WriteAllText($passwordFile,$config.password+"`n",$utf8)
    Write-Stage '1. SSH 접속과 장치 확인'
    $identity=Invoke-Pi 'hostname; whoami; hostname -I; cat /sys/class/net/*/address; python3 --version'
    $identityLines=$identity -split '\r?\n'
    if ($config.host_name -notin $identityLines -or $config.username -notin $identityLines -or ($config.mac.Replace('-',':').ToLowerInvariant()) -notin $identityLines) { throw '로그인한 장치의 호스트 이름/계정/MAC이 config.json과 다릅니다.' }
    # Informational timestamp only: never used for connection decisions.
    $config | Add-Member -NotePropertyName last_verified_at -NotePropertyValue ([DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz')) -Force
    [IO.File]::WriteAllText($ConfigPath,($config | ConvertTo-Json),$utf8)
    Write-Host '접속 정보 검증 성공. last_verified_at 갱신 완료.' -ForegroundColor Green

    Write-Stage '2. 실습 파일 준비'
    $files=@{}
    $lab=Join-Path $PSScriptRoot 'lab\vehicle'
    Get-ChildItem $lab -Recurse -File | ForEach-Object {
        $name=$_.FullName.Substring($lab.Length+1).Replace('\','/')
        $files[$name]=[Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
    }
    $payload=[Convert]::ToBase64String($utf8.GetBytes(($files | ConvertTo-Json -Compress)))
    $remoteRoot="`$HOME/ota_day2_runs/$runId"
    $bootstrap=@'
python3 - <<'PY'
import base64,json
from pathlib import Path
root=Path.home()/'ota_day2_runs'/'__RUN__'
root.mkdir(parents=True,exist_ok=False)
files=json.loads(base64.b64decode('__PAYLOAD__'))
for name,content in files.items():
    target=root/name
    if not target.resolve().is_relative_to(root.resolve()): raise ValueError('Invalid lab path')
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(base64.b64decode(content))
(root/'common/server_config.json').write_text(json.dumps({'pc_server_ip':'__PC__'}))
print('[OK] Lab files:',root)
PY
'@
    $null=Invoke-Pi ($bootstrap.Replace('__RUN__',$runId).Replace('__PAYLOAD__',$payload).Replace('__PC__',$config.pc_ip))
    @{pc_ip=$config.pc_ip;ip=$config.ip;port=$config.port} | ConvertTo-Json | Set-Content (Join-Path $runDir 'server.json') -Encoding UTF8
    $shell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $server=Join-Path $PSScriptRoot 'Server.ps1'
    Start-Process -FilePath "$env:SystemRoot\System32\conhost.exe" -ArgumentList @(('"'+$shell+'"'),'-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$server+'"'),'-RunDir',('"'+$runDir+'"'),'-OwnerPid',$PID) -WindowStyle Normal | Out-Null
    Wait-Signal 'ready'

    Write-Stage '3. 차량 초기화: v1 / NORMAL / ON'
    $null=Invoke-Pi "cd `"$remoteRoot`"; python3 day2_basic_ota/reset_day2_vehicle.py; python3 day2_basic_ota/vehicle/status.py; python3 day2_basic_ota/vehicle/ecu_run.py"
    Assert-Vehicle '1.0' 'NORMAL'
    Write-Stage '4. 정상 OTA 실행: v2 / NORMAL / ON'
    $null=Invoke-Pi "cd `"$remoteRoot`"; python3 day2_basic_ota/ota_client_basic.py; python3 day2_basic_ota/vehicle/status.py; python3 day2_basic_ota/vehicle/ecu_run.py"
    Assert-Vehicle '2.0' 'NORMAL'
    Write-Stage '5. 차량을 v1으로 복원, 서버 펌웨어 변조'
    $null=Invoke-Pi "cd `"$remoteRoot`"; python3 day2_basic_ota/reset_day2_vehicle.py"
    Assert-Vehicle '1.0' 'NORMAL'
    [IO.File]::WriteAllText((Join-Path $runDir 'tamper'),'tamper',$utf8)
    Wait-Signal 'tampered'
    Write-Stage '6. 변조 OTA 실행: v2 / FORCE_HEADLAMP_OFF / OFF'
    $null=Invoke-Pi "cd `"$remoteRoot`"; python3 day2_basic_ota/ota_client_basic.py; python3 day2_basic_ota/vehicle/status.py; python3 day2_basic_ota/vehicle/ecu_run.py"
    Assert-Vehicle '2.0' 'FORCE_HEADLAMP_OFF'
    $result='PASSED'
    Write-Host "`nDay 2 완료: 정상 OTA=ON, 변조 OTA=OFF, 둘 다 ACCEPTED / 보안 검사 NONE" -ForegroundColor Green
    Write-Host "Pi 실습 경로: $remoteRoot"
} catch {
    $failure=$_.Exception.Message
    if ($config -and $config.password) { $failure=$failure.Replace($config.password,'[REDACTED]') }
    Write-Host "`n오류: $failure" -ForegroundColor Red
} finally {
    if ($runDir) {
        [IO.File]::WriteAllText((Join-Path $runDir 'stop'),'stop',$utf8)
        if ($passwordFile -and (Test-Path $passwordFile)) { Remove-Item -LiteralPath $passwordFile -Force }
        @{result=$result;error=$failure;completed_at=[DateTimeOffset]::Now.ToString('o');remote_path=$remoteRoot} | ConvertTo-Json | Set-Content (Join-Path $runDir 'result.json') -Encoding UTF8
        try { Stop-Transcript | Out-Null } catch {}
    }
    if ($lock) { $lock.Dispose() }
}
if (!$NoHold) { Read-Host '결과를 확인한 뒤 Enter를 누르면 B 창이 닫힙니다' | Out-Null }
if ($result -ne 'PASSED') { exit 1 }
