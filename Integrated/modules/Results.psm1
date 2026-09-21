function Save-LabResult([string]$RunDir,[string]$Result,[string]$Failure,[string]$RemoteRoot,$Scenarios) {
    @{result=$Result;error=$Failure;completed_at=[DateTimeOffset]::Now.ToString('o');remote_path=$RemoteRoot;scenarios=@($Scenarios)} | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $RunDir 'result.json') -Encoding UTF8
}
Export-ModuleMember -Function Save-LabResult
