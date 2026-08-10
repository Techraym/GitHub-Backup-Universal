$ErrorActionPreference = 'Stop'

$Installer = Join-Path $PSScriptRoot '..\Install.ps1'
$Text = Get-Content $Installer -Raw
$Names = @('BackupScript','TrayScript','ConfigScript')
$Failed = $false

foreach ($Name in $Names) {
    $Pattern = '(?s)\$' + [regex]::Escape($Name) + '\s*=\s*@''\r?\n(.*?)\r?\n''@'
    $Match = [regex]::Match($Text, $Pattern)

    if (-not $Match.Success) {
        Write-Host "Embedded script '$Name' not found." -ForegroundColor Red
        $Failed = $true
        continue
    }

    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseInput(
        $Match.Groups[1].Value,
        [ref]$Tokens,
        [ref]$Errors
    ) | Out-Null

    if ($Errors.Count -gt 0) {
        Write-Host "Syntax errors in embedded script '$Name':" -ForegroundColor Red
        $Errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        $Failed = $true
    }
    else {
        Write-Host "$Name syntax OK" -ForegroundColor Green
    }
}

if ($Failed) { exit 1 }
