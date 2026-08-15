@echo off
chcp 65001 >nul
setlocal
echo ================================================
echo   CAP NHAT TIN BAI  -^>  exhibitions.html
echo ================================================
echo.
echo CHE DO: CHI THEM BAI MOI, KHONG GHI DE
echo Bai viet hien co se duoc giu nguyen 100%%.
echo.
echo Nguon: RSS cac bao (Tuoi Tre, VnExpress, Nhan Dan,
echo        Lao Dong, Dan tri, VietnamPlus, VOV)
echo Tu khoa: son mai, my thuat, hoi hoa, trien lam,
echo        workshop, hoa si, nghe nhan, tranh, gallery...
echo.
echo Nhan 'commit' de tu dong commit len GitHub:
echo   update.bat commit
echo.
echo Dang chay...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$BaseDir = '%~dp0'; $env:TS_COMMIT = '%~1'; $c = Get-Content -LiteralPath '%~f0' -Encoding UTF8; $i = [Array]::IndexOf($c, '# ===== POWERSHELL BODY ====='); if ($i -lt 0) { Write-Host 'Marker khong tim thay.' -ForegroundColor Red; exit 1 }; $s = ($c[($i + 1)..($c.Length - 1)]) -join [Environment]::NewLine; & ([scriptblock]::Create($s))"
exit /b 0

# ===== POWERSHELL BODY =====
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function JSQ([string]$s) {
    if ($null -eq $s) { return '' }
    $s = $s -replace '\\', '\\\\'
    $s = $s -replace "'", "\'"
    $s = $s -replace "`r?`n", ' '
    return $s
}

function Get-NodeText($node) {
    if ($null -eq $node) { return '' }
    if ($node -is [System.Xml.XmlElement]) { return $node.InnerText }
    return ([string]$node).Trim()
}

function Get-ArticleImage($item) {
    foreach ($node in $item.ChildNodes) {
        if ($node.LocalName -eq 'content' -or $node.LocalName -eq 'thumbnail' -or $node.LocalName -eq 'enclosure') {
            $u = $node.GetAttribute('url')
            if ($u) { return $u }
        }
    }
    $txt = Get-NodeText $item.description
    if ($txt -match '<img[^>]+src="([^"]+)"') { return $Matches[1] }
    return ''
}

function Get-Desc($item) {
    $txt = Get-NodeText $item.description
    $txt = $txt -replace '<[^>]+>', ' '
    $txt = $txt -replace '\s+', ' '
    $txt = $txt.Trim()
    if ($txt.Length -gt 140) { $txt = $txt.Substring(0, 140).TrimEnd() + '...' }
    return $txt
}

function Get-EntryDate($pub) {
    if ($pub -match '(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})') {
        $day = [int]$Matches[1]
        $mon = @{Jan=1;Feb=2;Mar=3;Apr=4;May=5;Jun=6;Jul=7;Aug=8;Sep=9;Oct=10;Nov=11;Dec=12}[$Matches[2]]
        $year = [int]$Matches[3]
        if ($mon) {
            $dt = New-Object System.DateTime $year, $mon, $day
            return @{ display = ('{0:d2}.{1:d2}.{2}' -f $day, $mon, $year); dt = $dt }
        }
    }
    return $null
}

function Get-RssText([string]$url) {
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
    $req.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
    $req.Timeout = 20000
    $resp = $req.GetResponse()
    try {
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $text = $reader.ReadToEnd()
        $reader.Dispose()
        return $text
    } finally { $resp.Dispose() }
}

function Get-CategoryInfo($text) {
    $t = $text.ToLower()
    $tags = New-Object System.Collections.Generic.List[string]
    if ($t -match 'sơn mài' -or $t -match 'lacquer') { $tags.Add('son-mai') }
    if ($t -match 'triển lãm' -or $t -match 'exhibition' -or $t -match 'trưng bày') { $tags.Add('trien-lam') }
    if ($t -match 'workshop' -or $t -match 'lớp học' -or $t -match 'trải nghiệm') { $tags.Add('workshop') }
    if ($t -match 'họa sĩ' -or $t -match 'nghệ nhân' -or $t -match 'artist') { $tags.Add('nghe-si') }
    if ($t -match 'hội họa' -or $t -match 'mỹ thuật' -or $t -match 'painting' -or $t -match 'tranh') { $tags.Add('hoi-hoa') }
    if ($tags.Count -eq 0) { $tags.Add('nghe-thuat') }
    $catMap = @{ 'son-mai'='Sơn mài'; 'trien-lam'='Triển lãm'; 'workshop'='Workshop'; 'hoi-hoa'='Hội họa'; 'nghe-si'='Nghệ sĩ'; 'nghe-thuat'='Nghệ thuật' }
    return @{ cat = $catMap[$tags[0]]; tags = $tags }
}

$exhibFile = Join-Path $BaseDir 'exhibitions.html'
$startMarker = '/* === NEWS_DATA:START === */'
$endMarker   = '/* === NEWS_DATA:END === */'
$maxTotal = 30

if (-not (Test-Path -LiteralPath $exhibFile)) {
    Write-Host 'Khong tim thay exhibitions.html tai:' $exhibFile -ForegroundColor Red
    exit 1
}

$content = Get-Content -LiteralPath $exhibFile -Encoding UTF8 -Raw
if ($content.Contains("`r`n")) { $nl = "`r`n" } else { $nl = "`n" }

$si = $content.IndexOf($startMarker)
$ei = $content.IndexOf($endMarker)
if ($si -lt 0 -or $ei -lt 0) {
    Write-Host 'Chua co marker NEWS_DATA trong exhibitions.html.' -ForegroundColor Red
    exit 1
}

$openBracket = $content.IndexOf('[', $si)
$closeBracket = $content.IndexOf('];', $openBracket)
if ($openBracket -lt 0 -or $closeBracket -lt 0) {
    Write-Host 'Khong tim thay mang NEWS_DATA trong exhibitions.html.' -ForegroundColor Red
    exit 1
}

$before = $content.Substring(0, $openBracket + 1)
$after  = $content.Substring($closeBracket)
$inner  = $content.Substring($openBracket + 1, $closeBracket - $openBracket - 1)

# Existing URLs (de-dupe) + count
$existingUrls = @([regex]::Matches($inner, "sourceUrl:\s*'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
$existingCount = $existingUrls.Count
Write-Host ''
Write-Host ('So bai hien co: {0} (se giu nguyen, chi them moi)' -f $existingCount) -ForegroundColor Cyan

# Next id number
$nextNum = 1
foreach ($mm in [regex]::Matches($inner, "id:\s*'ex(\d+)'")) {
    $n = [int]$mm.Groups[1].Value
    if ($n -ge $nextNum) { $nextNum = $n + 1 }
}

Write-Host 'Dang doc RSS tu cac bao...' -ForegroundColor Gray

$feeds = @(
    @{ name='Báo Tuổi Trẻ';    url='https://tuoitre.vn/rss/van-hoa.rss' },
    @{ name='VnExpress';        url='https://vnexpress.net/rss/van-hoa.rss' },
    @{ name='Báo Nhân Dân';    url='https://nhandan.vn/rss/van-hoa.rss' },
    @{ name='Lao Động';         url='https://laodong.vn/rss/van-hoa.rss' },
    @{ name='Dân trí';          url='https://dantri.com.vn/van-hoa.rss' },
    @{ name='VietnamPlus';      url='https://www.vietnamplus.vn/rss/van-hoa.rss' },
    @{ name='VOV';              url='https://vov.vn/rss/van-hoa.rss' },
    @{ name='Tuổi Trẻ Mới nhất'; url='https://tuoitre.vn/rss/tin-moi-nhat.rss' }
)
$keywords = @('sơn mài','lacquer','mỹ thuật','hội họa','triển lãm','workshop','họa sĩ','nghệ nhân','điêu khắc','gallery','exhibition','painting','bảo tàng','trưng bày','tranh sơn mài','bức tranh','vẽ tranh','phòng tranh','nhiếp ảnh')
$fallbackImage = 'images/tamson_art_02.png'
$feedCap = 4

$newEntries = New-Object System.Collections.Generic.List[object]
$maxAgeDays = 60

foreach ($feed in $feeds) {
    $addedFromFeed = 0
    try {
        $raw = Get-RssText $feed.url
        [xml]$doc = $raw
        if (-not $doc.rss -or -not $doc.rss.channel) {
            Write-Host ('  - {0}: bo qua (khong phai RSS 2.0)' -f $feed.name) -ForegroundColor DarkGray
            continue
        }
        foreach ($it in @($doc.rss.channel.item)) {
            if ($addedFromFeed -ge $feedCap) { break }
            $title = Get-NodeText $it.title
            $descTxt = Get-NodeText $it.description
            $hay = ($title + ' ' + $descTxt).ToLower()
            $hit = $false
            foreach ($k in $keywords) { if ($hay.Contains($k.ToLower())) { $hit = $true; break } }
            if (-not $hit) { continue }
            $link = (Get-NodeText $it.link).Trim()
            if ($link -match '^link\s+(https?://.*)$') { $link = $Matches[1] }
            if (-not $link -or $existingUrls -contains $link) { continue }
            $img = Get-ArticleImage $it
            if (-not $img) { $img = $fallbackImage }
            $dateInfo = Get-EntryDate (Get-NodeText $it.pubDate)
            if ($dateInfo -and $dateInfo.dt -lt (Get-Date).AddDays(-$maxAgeDays)) { continue }
            $d = if ($dateInfo) { $dateInfo.display } else { '2026' }
            $ci = Get-CategoryInfo ($title + ' ' + $descTxt)
            $desc = Get-Desc $it
            if (-not $desc) { $desc = ($descTxt -replace '<[^>]+>',' ' -replace '\s+',' ').Trim(); if ($desc.Length -gt 140) { $desc = $desc.Substring(0, 140) + '...' } }
            $newId = 'ex' + ('{0:d2}' -f $nextNum); $nextNum++
            $newEntries.Add([PSCustomObject]@{ id=$newId; cat=$ci.cat; tags=@($ci.tags); date=$d; title=$title; source=$feed.name; url=$link; image=$img; desc=$desc })
            $existingUrls += $link
            $addedFromFeed++
        }
        Write-Host ('  - {0}: them {1} bai' -f $feed.name, $addedFromFeed) -ForegroundColor Green
    } catch {
        $err = (($_.Exception.Message) -replace '\s+',' ').Trim()
        if ($err.Length -gt 120) { $err = $err.Substring(0, 120) + '...' }
        Write-Host ('  - {0}: loi ({1})' -f $feed.name, $err) -ForegroundColor Yellow
    }
}

Write-Host ('Tong bai moi tim duoc: {0}' -f $newEntries.Count) -ForegroundColor Cyan

# --- CHI THEM, KHONG GHI DE ---
$maxNew = $maxTotal - $existingCount
if ($maxNew -le 0 -or $newEntries.Count -eq 0) {
    Write-Host ''
    Write-Host 'Khong co bai moi de them (hoac da dat so toi da). File giu nguyen.' -ForegroundColor Yellow
} else {
    $toAdd = @($newEntries | Select-Object -First $maxNew)
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($en in $toAdd) {
        $tagsJs = '[' + (($en.tags | ForEach-Object { "'" + $_ + "'" }) -join ',') + ']'
        $lines.Add("            {")
        $lines.Add("                id: '" + $en.id + "', cat: '" + (JSQ $en.cat) + "', tags: $tagsJs, date: '" + (JSQ $en.date) + "',")
        $lines.Add("                title: '" + (JSQ $en.title) + "',")
        $lines.Add("                source: '" + (JSQ $en.source) + "', sourceUrl: '" + (JSQ $en.url) + "',")
        $lines.Add("                image: '" + (JSQ $en.image) + "',")
        $lines.Add("                desc: '" + (JSQ $en.desc) + "'")
        $lines.Add("            },")
    }
    $newJs = ($lines -join $nl)

    $trimmed = $inner.TrimEnd()
    if ($trimmed.EndsWith(',')) { $trimmed = $trimmed.TrimEnd(',') }
    $innerNew = $trimmed + ',' + $nl + $newJs
    $newContent = $before + $innerNew + $nl + '        ' + $after

    [System.IO.File]::WriteAllText($exhibFile, $newContent, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('DA THEM {0} bai moi vao exhibitions.html (bai cu giu nguyen)' -f $toAdd.Count) -ForegroundColor Green
}

# Optional git commit (update.bat commit)
if ($env:TS_COMMIT -eq 'commit') {
    Write-Host 'Dang commit len GitHub...' -ForegroundColor Cyan
    Push-Location $BaseDir
    git add .
    git commit -m ('Update exhibitions ' + (Get-Date -Format 'yyyy-MM-dd HH-mm'))
    git push origin master
    Pop-Location
}

Write-Host ''
Write-Host 'Hoan tat!'
