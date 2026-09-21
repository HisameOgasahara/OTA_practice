function Read-LabConfig([string]$ConfigPath) {
    if (!(Test-Path -LiteralPath $ConfigPath)) { throw '프로젝트 루트의 config_example.json을 config.json으로 복사하고 접속 정보를 입력하세요.' }
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($field in @('host_name','username','password','mac','ip','pc_ip','ssh_host_key','day3_port')) {
        if (![string]$config.$field) { throw "config.json의 $field 값이 비어 있습니다." }
    }
    if ($config.username -notmatch '^[a-zA-Z_][a-zA-Z0-9_-]*[$]?$' -or $config.host_name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9.-]*$') { throw '계정 또는 호스트 이름 형식 오류' }
    if ($config.mac -notmatch '^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$') { throw 'MAC 주소 형식 오류' }
    foreach ($field in @('ip','pc_ip')) {
        $ipObject=$null
        if (![Net.IPAddress]::TryParse($config.$field,[ref]$ipObject) -or $ipObject.AddressFamily -ne 'InterNetwork') { throw "$field IPv4 형식 오류" }
    }
    foreach ($field in @('ssh_port','day3_port','ssh_connect_timeout_seconds','server_signal_timeout_seconds','http_timeout_seconds','remote_command_timeout_seconds')) {
        $value=0
        if (![int]::TryParse([string]$config.$field,[ref]$value) -or $value -lt 1 -or $value -gt 65535) { throw "config.json의 $field 값은 1~65535 범위의 정수여야 합니다." }
    }
    if ([int]$config.step_pause_seconds -lt 0 -or [int]$config.step_pause_seconds -gt 30) { throw '단계 대기 시간은 0~30초 범위로 설정하세요.' }
    if ($config.password -match '[\r\n]') { throw '비밀번호에는 줄바꿈을 사용할 수 없습니다.' }
    if ($config.ssh_host_key -notmatch '^SHA256:[A-Za-z0-9+/]+={0,2}$') { throw 'SSH 호스트 지문은 SHA256: 형식으로 입력하세요.' }
    if (!(Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -eq $config.pc_ip)) { throw 'config.json의 pc_ip가 현재 PC 주소와 다릅니다. 값을 수정하세요.' }

    return $config
}
Export-ModuleMember -Function Read-LabConfig
