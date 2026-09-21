param([Parameter(Mandatory=$true)][string]$RunDir, [int]$OwnerPid)
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'A - Day 2 OTA Server'
$utf8 = [Text.UTF8Encoding]::new($false)
$listener = $null
try {
    Start-Transcript -Path (Join-Path $RunDir 'server.log') | Out-Null
    $settings = Get-Content (Join-Path $RunDir 'server.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $root = Join-Path $RunDir 'repository'
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Copy-Item (Join-Path $PSScriptRoot 'lab\server\*.json') $root
    Write-Host '[10.2] 서버 초기화: v2 NORMAL' -ForegroundColor Cyan
    Get-Content (Join-Path $root 'firmware_v2.json')
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]$settings.pc_ip,[int]$settings.port)
    $listener.Start()
    Write-Host "[10.4] 서버 시작: http://$($settings.pc_ip):$($settings.port)" -ForegroundColor Green
    [IO.File]::WriteAllText((Join-Path $RunDir 'ready'),'ready',$utf8)
    $tampered = $false
    while (!(Test-Path (Join-Path $RunDir 'stop'))) {
        if (!(Get-Process -Id $OwnerPid -ErrorAction SilentlyContinue)) { break }
        if (!$tampered -and (Test-Path (Join-Path $RunDir 'tamper'))) {
            $listener.Stop()
            Write-Host "`n[10.9] 서버 중지 후 정상 v2로 초기화" -ForegroundColor Cyan
            Copy-Item (Join-Path $PSScriptRoot 'lab\server\*.json') $root -Force
            $manifestHash = (Get-FileHash (Join-Path $root 'manifest.json')).Hash
            Write-Host '[10.10] 펌웨어 behavior를 FORCE_HEADLAMP_OFF로 변경' -ForegroundColor Yellow
            $path = Join-Path $root 'firmware_v2.json'
            $firmware = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
            $firmware.behavior = 'FORCE_HEADLAMP_OFF'
            [IO.File]::WriteAllText($path,($firmware | ConvertTo-Json),$utf8)
            Get-Content $path
            if ((Get-FileHash (Join-Path $root 'manifest.json')).Hash -ne $manifestHash) { throw 'Manifest가 변경되었습니다.' }
            Write-Host '[확인] Manifest 변경 없음'
            $listener.Start()
            Write-Host '[10.11] 서버 재시작: 변조 펌웨어 제공' -ForegroundColor Yellow
            $tampered = $true
            [IO.File]::WriteAllText((Join-Path $RunDir 'tampered'),'ready',$utf8)
        }
        if (!$listener.Pending()) { Start-Sleep -Milliseconds 100; continue }
        $client = $listener.AcceptTcpClient()
        try {
            $peer = $client.Client.RemoteEndPoint.Address.ToString()
            if ($peer -notin @($settings.ip,$settings.pc_ip)) { continue }
            $stream = $client.GetStream(); $stream.ReadTimeout = 2000; $stream.WriteTimeout = 2000
            $reader = [IO.StreamReader]::new($stream,[Text.Encoding]::ASCII,$false,1024,$true)
            $request = $reader.ReadLine()
            if ($request -notmatch '^GET (/[^ ]*) HTTP/1\.[01]$') { continue }
            $url = $Matches[1]
            # Only the two educational files are served; arbitrary paths are rejected.
            $name = $url.TrimStart('/')
            $status = '404 Not Found'; $body = $utf8.GetBytes('Not Found')
            if ($url -in @('/manifest.json','/firmware_v2.json')) {
                $body = [IO.File]::ReadAllBytes((Join-Path $root $name)); $status = '200 OK'
            }
            $header = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Length: $($body.Length)`r`nContent-Type: application/json`r`nConnection: close`r`n`r`n")
            $stream.Write($header,0,$header.Length); $stream.Write($body,0,$body.Length); $stream.Flush()
            Write-Host "[HTTP] $peer GET $url -> $status ($($body.Length) bytes)"
        } catch { Write-Host '[HTTP] 연결이 종료되었거나 요청 시간이 초과되었습니다.' } finally { $client.Dispose() }
    }
    Write-Host "`n서버가 종료되었습니다. 실습 결과는 이 창에 남아 있습니다." -ForegroundColor Green
} catch {
    [IO.File]::WriteAllText((Join-Path $RunDir 'server-error'),$_.Exception.Message,$utf8)
    Write-Host "서버 오류: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($listener) { $listener.Stop() }
    try { Stop-Transcript | Out-Null } catch {}
}
Read-Host '창을 닫으려면 Enter' | Out-Null
