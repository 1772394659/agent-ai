param(
    [ValidateSet("login", "dry-run", "run")]
    [string]$Action = "dry-run"
)

$ErrorActionPreference = "Continue"
$py = "C:\Users\001\.workbuddy\binaries\python\envs\default\Scripts\python.exe"

Push-Location $PSScriptRoot
try {
    switch ($Action) {
        "login"   { & $py "scripts\login.py" }
        "dry-run" { & $py "run.py" --dry-run }
        "run"     { & $py "run.py" }
    }
    Write-Output "EXITCODE=$LASTEXITCODE"
}
finally {
    Pop-Location
}
