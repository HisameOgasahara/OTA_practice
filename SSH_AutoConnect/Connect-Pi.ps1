param(
    [string]$ConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'config.json'),
    [switch]$VerifyOnly,
    [switch]$NoHold
)
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Raspberry Pi SSH'
$utf8 = [Text.UTF8Encoding]::new($false)
$passwordFile = $null; $result = 1; $runDir = $null

try {
    if (!(Test-Path -LiteralPath $ConfigPath)) { throw '프로젝트 루트의 config_example.json을 config.json으로 복사하고 접속 정보를 입력하세요.' }
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($field in @('host_name','username','password','mac','ip','ssh_host_key')) {
        if (![string]$config.$field) { throw "config.json의 $field 값이 비어 있습니다." }
    }
    if ($config.username -notmatch '^[a-zA-Z_][a-zA-Z0-9_-]*[$]?$' -or $config.host_name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9.-]*$') { throw '계정 또는 호스트 이름 형식 오류' }
    if ($config.mac -notmatch '^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$') { throw 'MAC 주소 형식 오류' }
    $parsed = $null
    if (![Net.IPAddress]::TryParse($config.ip,[ref]$parsed) -or $parsed.AddressFamily -ne 'InterNetwork') { throw 'ip 값에 올바른 IPv4를 입력하세요.' }
    if ($config.password -match '[\r\n]') { throw '비밀번호에는 줄바꿈을 사용할 수 없습니다.' }
    if ($config.ssh_host_key -notmatch '^SHA256:[A-Za-z0-9+/]+={0,2}$') { throw 'SSH 호스트 지문은 SHA256: 형식으로 입력하세요.' }
    Write-Host "Pi IP: $($config.ip) / MAC: $($config.mac)"
    $probe = [Net.Sockets.TcpClient]::new()
    try {
        if (!$probe.ConnectAsync($config.ip,22).Wait(5000)) { throw 'SSH 접속 시간 초과. config.json의 IP와 Pi 전원을 확인하세요.' }
    } finally { $probe.Dispose() }

    $tools = Get-Content (Join-Path $PSScriptRoot 'tools.json') -Raw | ConvertFrom-Json
    $toolDir = Join-Path $PSScriptRoot '.tools'
    New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
    $plink = Join-Path $toolDir 'plink.exe'
    if (!(Test-Path $plink)) {
        Write-Host "최초 실행: 공식 Plink $($tools.version) 다운로드"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest $tools.url -OutFile $plink -UseBasicParsing
    }
    if ((Get-FileHash $plink -Algorithm SHA256).Hash -ne $tools.sha256) { throw 'Plink 검증 실패. .tools/plink.exe를 삭제한 뒤 다시 실행하세요.' }
    $runDir = Join-Path (Join-Path $PSScriptRoot '.runtime') ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    $passwordFile = Join-Path $runDir 'password.tmp'
    [IO.File]::WriteAllText($passwordFile,$config.password+"`n",$utf8)
    $commandFile = Join-Path $runDir 'identity.sh'
    [IO.File]::WriteAllText($commandFile,"set -eu`nhostname`nwhoami`nhostname -I`ncat /sys/class/net/*/address`n",$utf8)
    $connection = @('-ssh','-batch','-no-antispoof','-noagent','-hostkey',$config.ssh_host_key,'-pwfile',$passwordFile,'-l',$config.username,$config.ip)
    $lines = [Collections.Generic.List[string]]::new()
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $plink @connection -m $commandFile 2>&1 | ForEach-Object {
            $line = $_.ToString().Replace($config.password,'[REDACTED]')
            $lines.Add($line); Write-Host $line
        }
        $verifyExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($verifyExit -ne 0) { throw 'SSH 인증 실패. config.json의 IP, 계정, 비밀번호, SSH 지문을 확인하세요.' }
    if ($config.host_name -notin $lines -or $config.username -notin $lines -or $config.mac.Replace('-',':').ToLowerInvariant() -notin $lines) { throw '접속한 장치의 호스트 이름·계정·MAC이 config.json과 다릅니다.' }
    # This timestamp is informational; it never determines whether to connect.
    $config | Add-Member -NotePropertyName last_verified_at -NotePropertyValue ([DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz')) -Force
    [IO.File]::WriteAllText($ConfigPath,($config | ConvertTo-Json),$utf8)
    Write-Host '장치 검증 완료. 루트 config.json의 last_verified_at을 갱신했습니다.' -ForegroundColor Green
    if (!$VerifyOnly) {
        Write-Host 'Pi 쉘을 엽니다. 명령을 입력할 수 있으며 종료는 exit입니다.' -ForegroundColor Cyan
        $commandFile = Join-Path $runDir 'interactive.sh'
        [IO.File]::WriteAllText($commandFile,"echo ---Hostname---; hostname; echo ---whoami---; whoami; echo ---IP---; hostname -I; echo ---MAC---; ip -brief link; exec bash -l`n",$utf8)
        & $plink @connection -t -m $commandFile
        if ($LASTEXITCODE -ne 0) { throw 'SSH 세션이 오류로 종료됐습니다.' }
    }
    $result = 0
} catch {
    $message = $_.Exception.Message
    if ($config -and $config.password) { $message = $message.Replace($config.password,'[REDACTED]') }
    Write-Host "오류: $message" -ForegroundColor Red
} finally {
    if ($passwordFile -and (Test-Path -LiteralPath $passwordFile)) { Remove-Item -LiteralPath $passwordFile -Force }
}
if (!$NoHold) { Read-Host '창을 닫으려면 Enter' | Out-Null }
exit $result
