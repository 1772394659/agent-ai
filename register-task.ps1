param(
    [string]$Time = "00:00"
)

# 注册每日定时任务：执行 run-daily.ps1（内部负责运行 + 失败弹窗）
$ErrorActionPreference = "Stop"
$proj = "C:\Users\001\WorkBuddy\2026-11-14-21-48-40\deploy\douyin-auto-fire"
$daily = Join-Path $proj "run-daily.ps1"

if (-not (Test-Path -LiteralPath $daily)) {
    Write-Warning "缺少 run-daily.ps1，无法注册。"
    return
}
if (-not (Test-Path (Join-Path $proj "storage-state.json")) -and -not (Test-Path (Join-Path $proj "cookie.json"))) {
    Write-Warning "尚未检测到 storage-state.json 或 cookie.json，请先完成抖音登录再注册定时任务。"
    return
}

$argLine = '-ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $daily + '"'
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argLine -WorkingDirectory $proj
$trigger = New-ScheduledTaskTrigger -Daily -At $Time
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "Douyin Auto Fire" -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Write-Output "已注册每日 $Time 执行的任务 Douyin Auto Fire"

# 如需卸载：Unregister-ScheduledTask -TaskName "Douyin Auto Fire" -Confirm:$false
