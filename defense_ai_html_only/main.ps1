#Requires -Version 5.1
<#
.SYNOPSIS
    국방 군수 AI 활용 방안 연구 - 일일 리포트 자동 생성기
    Daily Report Generator for AI in Defense Logistics Research

.DESCRIPTION
    글로벌/국내 뉴스와 ArXiv 학술 논문을 매일 자동 수집하여 HTML 파일 하나로 저장합니다.
    (HTML 전용판: 메일 발송·비밀번호 입력·Word/PPT/HWP 생성 없음, 사용자 입력을 받지 않음)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ─────────────────────────────────────────────
# 설정 로드
# ─────────────────────────────────────────────
$configPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $configPath)) {
    Write-Error "config.json 파일을 찾을 수 없습니다: $configPath"
    exit 1
}

$config    = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$reportDir = $config.report_directory
$maxNews   = $config.max_news_per_keyword
$maxArxiv  = $config.max_arxiv_per_query

if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    Write-Host "  리포트 폴더 생성: $reportDir" -ForegroundColor DarkGray
}

# ─────────────────────────────────────────────
# 유틸리티 함수
# ─────────────────────────────────────────────
function Remove-HtmlTags {
    param([string]$text)
    if ([string]::IsNullOrEmpty($text)) { return "" }
    $text = $text -replace '<[^>]+>', ''
    $text = $text -replace '&amp;',  '&'
    $text = $text -replace '&lt;',   '<'
    $text = $text -replace '&gt;',   '>'
    $text = $text -replace '&quot;', '"'
    $text = $text -replace '&#39;',  "'"
    $text = $text -replace '&nbsp;', ' '
    $text = $text -replace '\s+',    ' '
    return $text.Trim()
}

function Truncate {
    param([string]$text, [int]$maxLen = 300)
    if ([string]::IsNullOrEmpty($text)) { return "" }
    if ($text.Length -le $maxLen) { return $text }
    return $text.Substring(0, $maxLen) + "..."
}

function Translate-ToKorean {
    param([string]$text)
    if ([string]::IsNullOrEmpty($text)) { return "" }
    try {
        $encoded  = [System.Uri]::EscapeDataString($text)
        $url      = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=ko&dt=t&q=$encoded"
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $json     = $response.Content | ConvertFrom-Json
        # 번역된 세그먼트를 이어붙임
        $result   = ($json[0] | ForEach-Object { if ($_[0]) { $_[0] } }) -join ""
        return $result.Trim()
    }
    catch { return "" }
}

# ─────────────────────────────────────────────
# 검색 함수
# ─────────────────────────────────────────────
function Search-GoogleNewsRSS {
    param(
        [string]$keyword,
        [string]$lang  = "en-US",
        [string]$gl    = "US",
        [string]$ceid  = "US:en",
        [int]   $maxResults = 5
    )
    try {
        $encoded = [System.Uri]::EscapeDataString($keyword)
        $url     = "https://news.google.com/rss/search?q=$encoded&hl=$lang&gl=$gl&ceid=$ceid"
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
        [xml]$feed = $response.Content

        $articles = @()
        foreach ($item in ($feed.rss.channel.item | Select-Object -First $maxResults)) {
            $articles += @{
                Title     = Remove-HtmlTags $item.title
                Link      = $item.link
                Published = $item.pubDate
                Summary   = Truncate (Remove-HtmlTags $item.description) 280
                Source    = if ($item.source) { $item.source.'#text' } else { "Google News" }
            }
        }
        return $articles
    }
    catch {
        Write-Warning "  [뉴스 검색 실패] $keyword - $_"
        return @()
    }
}

function Search-ArXiv {
    param([string]$query, [int]$maxResults = 5)
    try {
        $encoded  = [System.Uri]::EscapeDataString($query)
        $url      = "https://export.arxiv.org/api/query?search_query=all:$encoded&start=0&max_results=$maxResults&sortBy=submittedDate&sortOrder=descending"
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25 -ErrorAction Stop
        [xml]$feed = $response.Content

        $papers = @()
        foreach ($entry in $feed.feed.entry) {
            $authors  = @($entry.author | ForEach-Object { $_.name })
            $authorStr = ($authors | Select-Object -First 3) -join ", "
            if ($authors.Count -gt 3) { $authorStr += " 외 $($authors.Count - 3)명" }
            $rawId   = if ($entry.id -is [string]) { $entry.id } else { $entry.id.'#text' }
            $arxivId = ($rawId -split '/') | Select-Object -Last 1
            $papers += @{
                Title     = ($entry.title -replace '\s+', ' ').Trim()
                Authors   = $authorStr
                Published = $entry.published.Substring(0, 10)
                Summary   = Truncate (($entry.summary -replace '\s+', ' ').Trim()) 380
                Link      = "https://arxiv.org/abs/$arxivId"
            }
        }
        return $papers
    }
    catch {
        Write-Warning "  [ArXiv 검색 실패] $query - $_"
        return @()
    }
}

# ─────────────────────────────────────────────
# 데이터 수집 → $reportData 구조체 반환
# ─────────────────────────────────────────────
function Collect-ReportData {
    $data = @{
        GeneratedAt  = Get-Date
        GlobalNews   = [ordered]@{}
        KrNews       = [ordered]@{}
        Papers       = [ordered]@{}
        Analysis     = ""
        TotalGlobal  = 0
        TotalKr      = 0
        TotalPapers  = 0
    }

    $seenGlobal = [System.Collections.Generic.HashSet[string]]::new()
    $seenKr     = [System.Collections.Generic.HashSet[string]]::new()
    $seenPaper  = [System.Collections.Generic.HashSet[string]]::new()

    # ── 글로벌 뉴스 ─────────────────────────────────────────
    foreach ($kw in $config.keywords_en) {
        Write-Host "  [글로벌] $kw" -ForegroundColor Cyan
        $articles = Search-GoogleNewsRSS -keyword $kw -maxResults $maxNews
        Start-Sleep -Milliseconds 600
        $new = @($articles | Where-Object { $seenGlobal.Add($_['Title']) })
        if ($new.Count -gt 0) {
            $data.GlobalNews[$kw] = $new
            $data.TotalGlobal    += $new.Count
        }
    }

    # ── 국내 뉴스 ────────────────────────────────────────────
    foreach ($kw in $config.keywords_kr) {
        Write-Host "  [국내] $kw" -ForegroundColor Magenta
        $articles = Search-GoogleNewsRSS -keyword $kw -lang "ko" -gl "KR" -ceid "KR:ko" -maxResults $maxNews
        Start-Sleep -Milliseconds 600
        $new = @($articles | Where-Object { $seenKr.Add($_['Title']) })
        if ($new.Count -gt 0) {
            $data.KrNews[$kw] = $new
            $data.TotalKr    += $new.Count
        }
    }

    # ── ArXiv 논문 ───────────────────────────────────────────
    foreach ($q in $config.arxiv_queries) {
        Write-Host "  [ArXiv] $q" -ForegroundColor Yellow
        $papers = Search-ArXiv -query $q -maxResults $maxArxiv
        Start-Sleep -Milliseconds 1000
        $new = @($papers | Where-Object { $seenPaper.Add($_['Title']) })
        if ($new.Count -gt 0) {
            $data.Papers[$q] = $new
            $data.TotalPapers += $new.Count
        }
    }

    # ── 영문 요약 → 한글 번역 ────────────────────────────────
    $translateTotal = ($data.GlobalNews.Values | ForEach-Object { $_ } | Where-Object { $_['Summary'] } | Measure-Object).Count +
                      ($data.Papers.Values     | ForEach-Object { $_ } | Where-Object { $_['Summary'] } | Measure-Object).Count
    Write-Host "  [번역] 영문 요약 한글 번역 중... ($($translateTotal)건)" -ForegroundColor White

    foreach ($kw in [string[]]($data.GlobalNews.Keys)) {
        foreach ($a in $data.GlobalNews[$kw]) {
            $a['SummaryKo'] = if ($a['Summary']) { Translate-ToKorean $a['Summary'] } else { "" }
            Start-Sleep -Milliseconds 150
        }
    }
    foreach ($q in [string[]]($data.Papers.Keys)) {
        foreach ($p in $data.Papers[$q]) {
            $p['SummaryKo'] = if ($p['Summary']) { Translate-ToKorean $p['Summary'] } else { "" }
            Start-Sleep -Milliseconds 150
        }
    }
    Write-Host "  [번역] 완료" -ForegroundColor White

    return $data
}

# ─────────────────────────────────────────────
# HTML 리포트 생성
# ─────────────────────────────────────────────
function ConvertTo-HtmlText([string]$t) {
    if ([string]::IsNullOrEmpty($t)) { return "" }
    $t = $t -replace '&', '&amp;'
    $t = $t -replace '<', '&lt;'
    $t = $t -replace '>', '&gt;'
    $t = $t -replace '"', '&quot;'
    return $t
}

$HtmlStyle = "body{font-family:'맑은 고딕','Malgun Gothic',sans-serif;font-size:11pt;margin:40px;color:#222;background:#fff} " +
             "h1{color:#1F3864;border-bottom:2px solid #1F3864;padding-bottom:4px} h2{color:#2E74B5} h3{color:#5B9BD5} " +
             ".article{margin-bottom:12px;padding:8px;background:#f5f8ff;border-left:3px solid #2E74B5} " +
             ".label{font-weight:bold} .label.ko{color:#1F5C8B} .ko{color:#1F5C8B} a{word-break:break-all} " +
             "table{border-collapse:collapse} td,th{border:1px solid #ccc;padding:6px 12px} " +
             "li{padding:6px 0;border-bottom:1px solid #e3e8f0;list-style:none} ul{padding:0} " +
             "@media (max-width:600px){body{margin:16px}}"

function Write-Utf8File([string]$path, [string]$text) {
    $utf8bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($path, $text, $utf8bom)
}

function New-HtmlReport {
    param($data)
    $d  = $data.GeneratedAt.ToString("yyyy년 MM월 dd일 HH:mm")
    $sb = [System.Text.StringBuilder]::new()
    $sb.Append("<!DOCTYPE html><html lang=`"ko`"><head><meta charset=`"UTF-8`">") | Out-Null
    $sb.Append("<meta name=`"viewport`" content=`"width=device-width, initial-scale=1`">") | Out-Null
    $sb.Append("<title>국방 군수 AI 일일 리포트 $($data.GeneratedAt.ToString('yyyy-MM-dd'))</title>") | Out-Null
    $sb.Append("<style>$HtmlStyle</style></head><body>") | Out-Null
    $sb.Append("<h1>국방 군수 AI 활용 방안 연구</h1><h2>일일 리포트 &middot; $d</h2>") | Out-Null
    $sb.Append("<p><a href=`"index.html`">&larr; 지난 리포트 목록</a></p><hr>") | Out-Null

    function Add-Article([hashtable]$a, [int]$idx) {
        $t     = ConvertTo-HtmlText $a['Title']
        $src   = ConvertTo-HtmlText $a['Source']
        $sum   = if ($a['Summary'])   { ConvertTo-HtmlText $a['Summary'] }   else { "" }
        $sumKo = if ($a['SummaryKo']) { ConvertTo-HtmlText $a['SummaryKo'] } else { "" }
        $lnk   = ConvertTo-HtmlText $a['Link']
        $sb.Append("<div class=`"article`"><p><b>$idx. $t</b></p>") | Out-Null
        $sb.Append("<p><span class=`"label`">출처:</span> $src &nbsp; <span class=`"label`">날짜:</span> $(ConvertTo-HtmlText $a['Published'])</p>") | Out-Null
        if ($sum)   { $sb.Append("<p><span class=`"label`">요약 (원문):</span> $sum</p>") | Out-Null }
        if ($sumKo) { $sb.Append("<p><span class=`"label ko`">요약 (한글):</span> <span class=`"ko`">$sumKo</span></p>") | Out-Null }
        $sb.Append("<p><span class=`"label`">링크:</span> <a href=`"$lnk`" target=`"_blank`">$lnk</a></p></div>") | Out-Null
    }

    $sb.Append("<h1>1. 글로벌 뉴스 (Global News)</h1>") | Out-Null
    foreach ($kw in $data.GlobalNews.Keys) {
        $sb.Append("<h2>검색어: $(ConvertTo-HtmlText $kw)</h2>") | Out-Null
        $i = 1; foreach ($a in $data.GlobalNews[$kw]) { Add-Article $a $i; $i++ }
    }
    $sb.Append("<h1>2. 국내 뉴스 (Korean News)</h1>") | Out-Null
    foreach ($kw in $data.KrNews.Keys) {
        $sb.Append("<h2>검색어: $(ConvertTo-HtmlText $kw)</h2>") | Out-Null
        $i = 1; foreach ($a in $data.KrNews[$kw]) { Add-Article $a $i; $i++ }
    }
    $sb.Append("<h1>3. 최신 학술 논문 (ArXiv)</h1>") | Out-Null
    foreach ($q in $data.Papers.Keys) {
        $sb.Append("<h2>검색어: $(ConvertTo-HtmlText $q)</h2>") | Out-Null
        $i = 1
        foreach ($p in $data.Papers[$q]) {
            $sum   = if ($p['Summary'])   { ConvertTo-HtmlText $p['Summary'] }   else { "" }
            $sumKo = if ($p['SummaryKo']) { ConvertTo-HtmlText $p['SummaryKo'] } else { "" }
            $lnk   = ConvertTo-HtmlText $p['Link']
            $sb.Append("<div class=`"article`"><p><b>$i. $(ConvertTo-HtmlText $p['Title'])</b></p>") | Out-Null
            $sb.Append("<p><span class=`"label`">저자:</span> $(ConvertTo-HtmlText $p['Authors']) &nbsp; <span class=`"label`">날짜:</span> $($p['Published'])</p>") | Out-Null
            if ($sum)   { $sb.Append("<p><span class=`"label`">초록 (원문):</span> $sum</p>") | Out-Null }
            if ($sumKo) { $sb.Append("<p><span class=`"label ko`">초록 (한글):</span> <span class=`"ko`">$sumKo</span></p>") | Out-Null }
            $sb.Append("<p><span class=`"label`">링크:</span> <a href=`"$lnk`" target=`"_blank`">$lnk</a></p></div>") | Out-Null
            $i++
        }
    }
    $sb.Append("<h1>4. 수집 통계</h1><table><tr><th>항목</th><th>건수</th></tr>") | Out-Null
    $sb.Append("<tr><td>글로벌 뉴스</td><td>$($data.TotalGlobal)건</td></tr>") | Out-Null
    $sb.Append("<tr><td>국내 뉴스</td><td>$($data.TotalKr)건</td></tr>") | Out-Null
    $sb.Append("<tr><td>학술 논문</td><td>$($data.TotalPapers)건</td></tr></table>") | Out-Null
    $sb.Append("<p style=`"color:#888`">* 본 리포트는 자동 생성되었습니다. 생성: $d</p></body></html>") | Out-Null
    return $sb.ToString()
}

# 리포트 폴더의 HTML 목록 페이지(index.html) 갱신
function Update-IndexHtml {
    param([string]$dir)
    $files = @(Get-ChildItem -Path $dir -Filter "defense_ai_report_*.html" -File | Sort-Object Name -Descending)
    $sb = [System.Text.StringBuilder]::new()
    $sb.Append("<!DOCTYPE html><html lang=`"ko`"><head><meta charset=`"UTF-8`">") | Out-Null
    $sb.Append("<meta name=`"viewport`" content=`"width=device-width, initial-scale=1`">") | Out-Null
    $sb.Append("<title>국방 군수 AI 일일 리포트 목록</title><style>$HtmlStyle</style></head><body>") | Out-Null
    $sb.Append("<h1>국방 군수 AI 일일 리포트 목록</h1><p>총 $($files.Count)건 (최신순)</p><ul>") | Out-Null
    foreach ($f in $files) {
        $label = $f.BaseName
        if ($f.BaseName -match '(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})') {
            $label = "$($Matches[1])-$($Matches[2])-$($Matches[3]) $($Matches[4]):$($Matches[5])"
        }
        $sb.Append("<li><a href=`"$($f.Name)`">$label</a></li>") | Out-Null
    }
    $sb.Append("</ul></body></html>") | Out-Null
    Write-Utf8File (Join-Path $dir "index.html") $sb.ToString()
}

# ─────────────────────────────────────────────
# 메인 실행 (사용자 입력 없음)
# ─────────────────────────────────────────────
$logPath = Join-Path $reportDir "last_run.log"
try { Start-Transcript -Path $logPath -Force | Out-Null } catch { }

Write-Host ""
Write-Host "  국방 군수 AI 일일 리포트 (HTML 전용) - 시작: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

Write-Host "1단계: 데이터 수집 중..." -ForegroundColor Yellow
$reportData = Collect-ReportData

Write-Host "`n2단계: HTML 생성 중..." -ForegroundColor Yellow
$htmlName = "defense_ai_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
$htmlPath = Join-Path $reportDir $htmlName
Write-Utf8File $htmlPath (New-HtmlReport -data $reportData)
Copy-Item -Path $htmlPath -Destination (Join-Path $reportDir "latest.html") -Force
Update-IndexHtml -dir $reportDir

Write-Host "  [HTML] $htmlPath" -ForegroundColor Green
Write-Host "  완료! 목록: $(Join-Path $reportDir 'index.html')" -ForegroundColor Green
try { Stop-Transcript | Out-Null } catch { }
