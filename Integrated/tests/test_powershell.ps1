param([string]$Root=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$syntaxErrors=@()
Get-ChildItem $Root -Recurse -File -Include *.ps1,*.psm1 | ForEach-Object {
    $tokens=$null; $errors=$null
    $null=[System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors)
    $syntaxErrors+=@($errors)
}
if ($syntaxErrors.Count) { throw ($syntaxErrors | Out-String) }
foreach ($module in @('Config','Ssh','Runtime','Results')) {
    Import-Module (Join-Path $Root "modules/$module.psm1") -Force
}
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$work=Join-Path $tempRoot ('ota test '+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $fake=Join-Path $work 'fake-plink.exe'
    Add-Type -OutputAssembly $fake -OutputType ConsoleApplication -TypeDefinition @'
using System;
using System.IO;
using System.Threading;
public class FakePlink {
    public static int Main(string[] args) {
        int index=Array.IndexOf(args,"-m");
        string command=File.ReadAllText(args[index+1]);
        if(command.Contains("wait-test")) Thread.Sleep(10000);
        Console.WriteLine("fake-secret");
        Console.WriteLine("REMOTE_OK");
        return command.Contains("fail-test") ? 1 : 0;
    }
}
'@
    $session=@{Config=@{ssh_port=22;ssh_host_key='SHA256:test';username='test';ip='127.0.0.1';password='fake-secret';remote_command_timeout_seconds=1;ssh_connect_timeout_seconds=1};RunDir=$work;PasswordFile=(Join-Path $work 'password.tmp');Plink=$fake}
    $output=Invoke-Pi $session 'success-test'
    if ($output -notmatch 'REMOTE_OK' -or $output -match 'fake-secret' -or $output -notmatch '\[REDACTED\]') { throw 'SSH output/redaction check failed' }
    $failed=$false
    try { $null=Invoke-Pi $session 'fail-test' } catch { $failed=$true }
    if (!$failed) { throw 'Remote exit failure was ignored' }
    $timedOut=$false
    try { $null=Invoke-Pi $session 'wait-test' } catch { $timedOut=$_.Exception.Message -match 'timeout' }
    if (!$timedOut) { throw 'Remote timeout was ignored' }
    Save-LabResult $work 'PASSED' '' 'test-path' @(@{scenario='test';result='PASSED'})
    $saved=Get-Content (Join-Path $work 'result.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($saved.result -ne 'PASSED' -or $saved.scenarios.Count -ne 1) { throw 'Result serialization failed' }
    Write-Host 'PASS: PowerShell syntax, module imports, SSH quoting/redaction/failure/timeout, result serialization'
} finally {
    $resolved=[IO.Path]::GetFullPath($work)
    if (!$resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'ota test *') { throw 'Unsafe temporary cleanup path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
