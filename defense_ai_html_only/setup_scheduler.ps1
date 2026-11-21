#Requires -Version 5.1
<#
.SYNOPSIS
    일일 리포트(HTML 전용) 작업을 Windows 작업 스케줄러에 등록합니다.
    - 비밀번호 입력/메일 발송을 하던 기존 작업을 지웁니다.
    - 새 작업은 wscript(run_hidden.vbs)로 실행되어 창이 뜨지 않습니다.
    - 관리자 권한(UAC) 없이 현재 사용자 계정으로 등록합니다.
#>

$configPath   = Join-Path $PSScriptRoot "config.json"
$vbsPath      = Join-Path $PSScriptRoot "run_hidden.vbs"
$config       = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$taskName     = "DefenseAI_DailyReport"
$scheduleTime = $config.schedule_time

Write-Host ""
Write-Host "  국방 AI 일일 리포트(HTML 전용) - 스케줄러 등록" -ForegroundColor Cyan
Write-Host "  작업 이름  : $taskName"
Write-Host "  실행 시각  : 매일 $scheduleTime"
Write-Host "  리포트 저장: $($config.report_directory)"
Write-Host ""

if (-not (Test-Path $vbsPath)) { Write-Error "run_hidden.vbs 를 찾을 수 없습니다: $vbsPath"; exit 1 }

# ── 1. 기존 리포트/메일 관련 작업 정리 ─────────────────────────────
#    (Windows 기본 작업인 \Microsoft\ 아래는 건드리지 않음)
$pattern = 'defense_?ai|DefenseAI|main\.ps1|run_now|send_?mail|smtp|군수|국방'
$old = @(Get-ScheduledTask | Where-Object {
    $_.TaskPath -notlike '\Microsoft\*' -and (
        $_.TaskName -match $pattern -or
        @($_.Actions | Where-Object { "$($_.Execute) $($_.Arguments) $($_.WorkingDirectory)" -match $pattern }).Count -gt 0
    )
})
foreach ($t in $old) {
    Unregister-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Confirm:$false
    Write-Host "  기존 작업 삭제: $($t.TaskPath)$($t.TaskName)" -ForegroundColor Yellow
}
if ($old.Count -eq 0) { Write-Host "  삭제할 기존 작업 없음" -ForegroundColor DarkGray }

# ── 2. 새 작업 등록 (창 없이 실행) ─────────────────────────────────
try {
    $trigger   = New-ScheduledTaskTrigger -Daily -At $scheduleTime
    $action    = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsPath`"" -WorkingDirectory $PSScriptRoot
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
    $settings  = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
        -MultipleInstances  IgnoreNew `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable

    Register-ScheduledTask -TaskName $taskName `
        -Description "국방 군수 AI 일일 리포트 - HTML만 생성 (메일/비밀번호 없음, 창 숨김)" `
        -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
    Write-Host "  등록 완료! 매일 $scheduleTime 에 창 없이 HTML 리포트를 만듭니다." -ForegroundColor Green
}
catch {
    Write-Error "스케줄러 등록 실패: $_"
    exit 1
}

# ── 3. 남아 있는 사용자 작업 목록 (비밀번호 창이 계속 뜨면 여기서 확인) ──
Write-Host ""
Write-Host "  [참고] 현재 등록된 사용자 작업:" -ForegroundColor DarkGray
Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' } |
    ForEach-Object { Write-Host ("    - {0}{1}  ({2})" -f $_.TaskPath, $_.TaskName, (($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join '; ')) -ForegroundColor DarkGray }
Write-Host ""
Write-Host "  리포트 보기: $(Join-Path $config.report_directory 'index.html')"
Write-Host "  지금 한 번 실행해 보려면 run_now.bat 을 더블클릭하세요."
Write-Host ""
