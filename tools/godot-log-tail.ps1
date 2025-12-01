param(
    [Parameter(Position = 0)]
    [int]$Lines = 10
)

$logPath = Join-Path $env:APPDATA 'Godot\app_userdata\jinglejam-2025\logs\godot.log'

if ($Lines -le 0) {
    Write-Error "Specify a positive number of lines to tail."
    exit 1
}

if (-not (Test-Path -LiteralPath $logPath)) {
    Write-Error "Log file not found at '$logPath'. Launch the game once to generate it."
    exit 1
}

Write-Host "Showing the last $Lines lines from:`n$logPath" -ForegroundColor Cyan
Get-Content -Path $logPath -Tail $Lines

