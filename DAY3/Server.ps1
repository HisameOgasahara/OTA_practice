param([Parameter(Mandatory=$true)][string]$RunDir, [int]$OwnerPid)
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'A - Day 3 OTA Server'
$utf8 = [Text.UTF8Encoding]::new($false)
$listener = $null
try {
    Start-Transcript -Path (Join-Path $RunDir 'server.log') | Out-Null
    $settings = Get-Content (Join-Path $RunDir 'server.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $root = Join-Path $RunDir 'repository'
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Write-Host 'Day 3 서명된 Release 게시 대기' -ForegroundColor Cyan
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]$settings.pc_ip,[int]$settings.port)
    $listener.Start()
    Write-Host "[12.4] 서버 시작: http://$($settings.pc_ip):$($settings.port)" -ForegroundColor Green
    [IO.File]::WriteAllText((Join-Path $RunDir 'ready'),'ready',$utf8)
    while (!(Test-Path (Join-Path $RunDir 'stop'))) {
        if (!(Get-Process -Id $OwnerPid -ErrorAction SilentlyContinue)) { break }
        $requestPath=Join-Path $RunDir 'request.json'
        if (Test-Path $requestPath) {
            $request=Get-Content $requestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $cases=Get-Content (Join-Path $PSScriptRoot 'scenarios.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $scenario=$cases | Where-Object { $_.id -eq $request.id }
            if (!$scenario) { throw '알 수 없는 실습 요청입니다.' }
            $listener.Stop()
            $release=Join-Path (Join-Path $PSScriptRoot 'lab/server/releases') $scenario.release
            foreach ($name in @('manifest.json','firmware.json','signature.sig')) {
                Copy-Item -LiteralPath (Join-Path $release $name) -Destination (Join-Path $root $name) -Force
            }
            Write-Host "`n[PUBLISH] $($scenario.title): $($scenario.release)" -ForegroundColor Cyan
            $manifestHash=(Get-FileHash (Join-Path $root 'manifest.json')).Hash
            $signatureHash=(Get-FileHash (Join-Path $root 'signature.sig')).Hash
            if ($scenario.action -eq 'firmware') {
                $path=Join-Path $root 'firmware.json'
                $obj=Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
                $obj.behavior='FORCE_HEADLAMP_OFF'
                [IO.File]::WriteAllText($path,($obj | ConvertTo-Json),$utf8)
                if ((Get-FileHash (Join-Path $root 'manifest.json')).Hash -ne $manifestHash) { throw 'Manifest가 변경되었습니다.' }
                Write-Host '[ATTACK] Firmware behavior=FORCE_HEADLAMP_OFF / Manifest 유지' -ForegroundColor Yellow
            } elseif ($scenario.action -eq 'manifest') {
                $path=Join-Path $root 'manifest.json'
                $obj=Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
                $obj.version='9.9'
                [IO.File]::WriteAllText($path,($obj | ConvertTo-Json),$utf8)
                Write-Host '[ATTACK] Manifest version=9.9 / 기존 서명 유지' -ForegroundColor Yellow
            }
            if ((Get-FileHash (Join-Path $root 'signature.sig')).Hash -ne $signatureHash) { throw '서명이 변경되었습니다.' }
            Remove-Item -LiteralPath $requestPath
            $listener.Start()
            [IO.File]::WriteAllText((Join-Path $RunDir ($scenario.id+'.ready')),'ready',$utf8)
        }
        if (!$listener.Pending()) { Start-Sleep -Milliseconds 100; continue }
        $client = $listener.AcceptTcpClient()
        try {
            $peer = $client.Client.RemoteEndPoint.Address.ToString()
            if ($peer -notin @($settings.ip,$settings.pc_ip)) { continue }
            $stream = $client.GetStream(); $stream.ReadTimeout = [int]$settings.http_timeout_seconds * 1000; $stream.WriteTimeout = [int]$settings.http_timeout_seconds * 1000
            $reader = [IO.StreamReader]::new($stream,[Text.Encoding]::ASCII,$false,1024,$true)
            $request = $reader.ReadLine()
            if ($request -notmatch '^GET (/[^ ]*) HTTP/1\.[01]$') { continue }
            $url = $Matches[1]
            # Only the three educational files are served; arbitrary paths are rejected.
            $name = $url.TrimStart('/')
            $status = '404 Not Found'; $body = $utf8.GetBytes('Not Found')
            if ($url -in @('/manifest.json','/firmware.json','/signature.sig')) {
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
