param(
    [switch]$TestAlert
)

$ErrorActionPreference = "Continue"
$py = "C:\Users\001\.workbuddy\binaries\python\envs\default\Scripts\python.exe"
$proj = "C:\Users\001\WorkBuddy\2026-11-14-21-48-40\deploy\douyin-auto-fire"
$artifacts = Join-Path $proj "artifacts"
$dailyLog = Join-Path $artifacts "daily-task.log"

if (-not (Test-Path -LiteralPath $artifacts)) {
    New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
}

function Write-DailyLog([string]$text) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $dailyLog -Value "$stamp $text" -Encoding UTF8
}

function Show-FailureAlert([string]$message, [int]$seconds = 60) {
    $shown = $false
    try {
        $wshell = New-Object -ComObject WScript.Shell
        # 16 = stop icon + OK button; auto-dismiss after $seconds so the task never hangs
        $ret = $wshell.Popup($message, $seconds, "抖音续火花 - 发送失败", 16)
        $shown = $true
        Write-DailyLog "本地弹窗已触发 (Popup 返回 $ret)"
    } catch {
        Write-DailyLog "Popup 失败: $($_.Exception.Message)"
    }
    if (-not $shown) {
        try {
            & msg.exe $env:USERNAME /TIME:60 $message 2>&1 | Out-Null
            Write-DailyLog "已改用 msg.exe 发送提示"
        } catch {
            Write-DailyLog "msg.exe 也失败: $($_.Exception.Message)"
        }
    }
    return $shown
}

if ($TestAlert) {
    $ok = Show-FailureAlert "这是一条测试提示：失败弹窗功能已就绪。`n此提示不会发送任何消息。`n（几秒后自动关闭）" 5
    Write-Output "TEST_ALERT_TRIGGERED=$ok"
    return
}

Push-Location $proj
try {
    Write-DailyLog "开始执行 run.py"
    & $py "run.py" 2>&1 | Out-File (Join-Path $artifacts "daily-task-console.log") -Encoding utf8
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}

$failed = @()
$detail = ""
try {
    $resultPath = Join-Path $artifacts "result.json"
    if (Test-Path -LiteralPath $resultPath) {
        $parsed = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $failed = @($parsed.results | Where-Object { $_.status -ne "success" })
        if ($failed.Count -gt 0) {
            $detail = ($failed | ForEach-Object { "$($_.target): $($_.error)" }) -join "`n"
        }
    }
} catch {
    Write-DailyLog "解析 result.json 失败: $($_.Exception.Message)"
}

if ($code -ne 0 -or $failed.Count -gt 0) {
    $body = "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n退出码: $code`n失败条目: $($failed.Count)`n`n$detail`n`n详情见: $dailyLog"
    Write-DailyLog "检测到失败 (退出码 $code, 失败 $($failed.Count) 条)，触发弹窗"
    Show-FailureAlert $body | Out-Null
    Write-Output "RESULT=FAILED"
    exit 1
}

Write-DailyLog "执行成功，无需弹窗"
Write-Output "RESULT=OK"
exit 0
