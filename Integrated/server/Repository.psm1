function Publish-LabRelease($scenario, [string]$root) {
    $utf8=[Text.UTF8Encoding]::new($false)
    if ($scenario.release -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid release name' }
    if ($scenario.action -notin @('none','firmware','manifest')) { throw 'Invalid repository action' }
            $release=Join-Path (Join-Path $PSScriptRoot 'releases') $scenario.release
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
}
Export-ModuleMember -Function Publish-LabRelease
