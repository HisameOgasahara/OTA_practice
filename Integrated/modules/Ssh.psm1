function Invoke-Pi($Session, [string]$Commands) {
    $config=$Session.Config; $runDir=$Session.RunDir; $passwordFile=$Session.PasswordFile; $plink=$Session.Plink
    $utf8=[Text.UTF8Encoding]::new($false)
    $commandFile = Join-Path $runDir 'remote-command.sh'
    [IO.File]::WriteAllText($commandFile, "set -eu`n" + $Commands.Replace("`r`n","`n") + "`n", $utf8)
    # Password contents are never placed on the command line or printed.
    $argsList = @('-ssh','-P',[string]$config.ssh_port,'-batch','-no-antispoof','-noagent','-hostkey',$config.ssh_host_key,'-pwfile',$passwordFile,'-l',$config.username,$config.ip,'-m',$commandFile)
    $lines = [Collections.Generic.List[string]]::new()
    $process=[Diagnostics.Process]::new()
    $process.StartInfo.FileName=$plink
    $process.StartInfo.Arguments=($argsList | ForEach-Object { '"'+$_+'"' }) -join ' '
    $process.StartInfo.UseShellExecute=$false
    $process.StartInfo.CreateNoWindow=$true
    $process.StartInfo.RedirectStandardOutput=$true
    $process.StartInfo.RedirectStandardError=$true
    try {
        $null=$process.Start()
        $stdout=$process.StandardOutput.ReadToEndAsync()
        $stderr=$process.StandardError.ReadToEndAsync()
        $timeout=([int]$config.remote_command_timeout_seconds+[int]$config.ssh_connect_timeout_seconds)*1000
        if (!$process.WaitForExit($timeout)) {
            $process.Kill(); $process.WaitForExit()
            throw 'SSH remote command timeout'
        }
        $remoteExit=$process.ExitCode
        foreach ($line in (($stdout.Result+"`n"+$stderr.Result) -split '\r?\n')) {
            $text=$line.Replace($config.password,'[REDACTED]')
            $lines.Add($text); Write-Host $text
        }
    } finally { $process.Dispose() }
    if ($remoteExit -ne 0) { throw 'Pi 명령 실패. 위 오류와 config.json의 IP, 계정, 비밀번호, SSH 지문을 확인하세요. 자동 재탐색은 하지 않습니다.' }
    return ($lines -join "`n")
}

function New-PiSession($Config, [string]$RunDir, [string]$Root) {
    $utf8=[Text.UTF8Encoding]::new($false)
    $tools=Get-Content (Join-Path $Root 'tools.json') -Raw | ConvertFrom-Json
    $toolDir=Join-Path $Root '.tools'
    New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
    $plink=Join-Path $toolDir 'plink.exe'
    if (!(Test-Path $plink)) {
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest $tools.url -OutFile $plink -UseBasicParsing
    }
    if ((Get-FileHash $plink -Algorithm SHA256).Hash -ne $tools.sha256) { throw 'Plink integrity check failed' }
    $probe=[Net.Sockets.TcpClient]::new()
    try {
        if (!$probe.ConnectAsync($Config.ip,[int]$Config.ssh_port).Wait([int]$Config.ssh_connect_timeout_seconds*1000)) { throw 'SSH connection timeout' }
    } finally { $probe.Dispose() }
    $passwordFile=Join-Path $RunDir 'password.tmp'
    [IO.File]::WriteAllText($passwordFile,$Config.password+"`n",$utf8)
    return @{Config=$Config;RunDir=$RunDir;PasswordFile=$passwordFile;Plink=$plink}
}
function Assert-PiIdentity($Session, [string]$ConfigPath) {
    $config=$Session.Config
    $identity=Invoke-Pi $Session 'hostname; whoami; hostname -I; cat /sys/class/net/*/address; python3 --version; openssl version'
    $lines=$identity -split '\r?\n'
    if ($config.host_name -notin $lines -or $config.username -notin $lines -or $config.mac.Replace('-',':').ToLowerInvariant() -notin $lines) { throw 'Pi identity mismatch' }
    $config | Add-Member -NotePropertyName last_verified_at -NotePropertyValue ([DateTimeOffset]::Now.ToString('o')) -Force
    [IO.File]::WriteAllText($ConfigPath,($config | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
}
function Send-LabFiles($Session, [string]$Root, [string]$RunId) {
    $files=@{}
    foreach ($folder in @('vehicle','scenarios')) {
        Get-ChildItem (Join-Path $Root $folder) -Recurse -File | Where-Object { $_.FullName -notmatch '__pycache__' } | ForEach-Object {
            $name=$_.FullName.Substring($Root.Length+1).Replace('\','/')
            $files[$name]=[Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
        }
    }
    $config=$Session.Config
    $settings=@{pc_server_ip=$config.pc_ip;port=$config.day3_port;http_timeout_seconds=$config.http_timeout_seconds;remote_command_timeout_seconds=$config.remote_command_timeout_seconds}
    $files['server_config.json']=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($settings | ConvertTo-Json)))
    $payload=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($files | ConvertTo-Json -Compress)))
    $command=@'
python3 - <<'PY'
import base64,json,sys
from pathlib import Path
if sys.version_info < (3,9): raise RuntimeError('Python 3.9+ required')
root=Path.home()/'ota_integrated_runs'/'__RUN__'
root.mkdir(parents=True,exist_ok=False)
for name,content in json.loads(base64.b64decode('__PAYLOAD__')).items():
    target=root/name
    if not target.resolve().is_relative_to(root.resolve()): raise ValueError('Invalid lab path')
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(base64.b64decode(content))
print('[READY]',root)
PY
'@
    $null=Invoke-Pi $Session ($command.Replace('__RUN__',$RunId).Replace('__PAYLOAD__',$payload))
}
Export-ModuleMember -Function New-PiSession,Assert-PiIdentity,Send-LabFiles,Invoke-Pi
