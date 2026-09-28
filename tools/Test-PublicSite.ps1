[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$htmlPath = Join-Path $root 'index.html'
$cssPath = Join-Path $root 'assets\css\site.css'

$html = Get-Content -Raw -LiteralPath $htmlPath
$css = Get-Content -Raw -LiteralPath $cssPath
$errors = [System.Collections.Generic.List[string]]::new()

$forbidden = [ordered]@{
    'script element'          = '(?i)<script\b'
    'form element'            = '(?i)<form\b'
    'embedded frame'          = '(?i)<iframe\b'
    'tracking script source'  = '(?i)<script[^>]+src=["''][^"'']*(analytics|telemetry|pixel|segment|hotjar|clarity)'
    'CSS network import'      = '(?i)@import\s|url\(\s*["'']?https?://'
    'JavaScript network call' = '(?i)fetch\s*\(|XMLHttpRequest|WebSocket\s*\('
}

foreach ($entry in $forbidden.GetEnumerator()) {
    if ($html -match $entry.Value -or $css -match $entry.Value) {
        $errors.Add("Forbidden $($entry.Key) detected.")
    }
}

$ids = [regex]::Matches($html, '(?i)\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
$duplicateIds = $ids | Group-Object | Where-Object Count -gt 1
foreach ($duplicate in $duplicateIds) {
    $errors.Add("Duplicate id '$($duplicate.Name)'.")
}

$anchors = [regex]::Matches($html, '(?i)href="#([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
foreach ($anchor in $anchors) {
    if ($anchor -notin $ids) {
        $errors.Add("Internal link '#$anchor' has no matching id.")
    }
}

if ($html -notmatch '(?i)<meta\s+name="viewport"') {
    $errors.Add('Viewport metadata is missing.')
}

if ($html -notmatch '(?i)<a\s+class="skip-link"\s+href="#main"') {
    $errors.Add('Skip link to #main is missing.')
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "PASS: public-site static guardrails, $($ids.Count) unique ids, and $($anchors.Count) internal links validated."
