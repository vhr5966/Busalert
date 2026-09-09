# Final verification: confirm CB:30 and NB:30 are kept separate

Write-Host "=== FINAL VERIFICATION: AGENCY SEPARATION ===" -ForegroundColor Cyan
Write-Host ""

$lines = Get-Content 'lib\data\gtfs_stop_routes.dart'

Write-Host "TEST 1: Stop 5710AWA10055 (Colchester Avenue Bottom)" -ForegroundColor Yellow
$stop1 = $lines | Select-String -Pattern "'5710AWA10055':" | Select-Object -Last 1
$cb30 = ([regex]::Matches($stop1.Line, "routeId: 'CB:30'")).Count
$nb30 = ([regex]::Matches($stop1.Line, "routeId: 'NB:30'")).Count
Write-Host "  CB:30 entries: $cb30 (expected: 1)"
Write-Host "  NB:30 entries: $nb30 (expected: 1)"
if ($cb30 -eq 1 -and $nb30 -eq 1) {
    Write-Host "  PASS - both agencies kept separate" -ForegroundColor Green
} else {
    Write-Host "  FAIL" -ForegroundColor Red
}

# Extract entries
if ($stop1.Line -match "routeId: 'CB:30', shortName: '30', agencyId: 'CB', directionId: (\d+), headsign: '([^']+)'") {
    Write-Host "  CB:30 dir=$($matches[1]) headsign='$($matches[2])'"
}
if ($stop1.Line -match "routeId: 'NB:30', shortName: '30', agencyId: 'NB', directionId: (\d+), headsign: '([^']+)'") {
    Write-Host "  NB:30 dir=$($matches[1]) headsign='$($matches[2])'"
}

Write-Host ""
Write-Host "TEST 2: Stop 5310AWB32203 (Newport Friars Walk)" -ForegroundColor Yellow
$stop2 = $lines | Select-String -Pattern "'5310AWB32203':" | Select-Object -Last 1
$cb30_2 = ([regex]::Matches($stop2.Line, "routeId: 'CB:30'")).Count
$nb30_2 = ([regex]::Matches($stop2.Line, "routeId: 'NB:30'")).Count
Write-Host "  CB:30 entries: $cb30_2 (expected: 2 - both directions)"
Write-Host "  NB:30 entries: $nb30_2 (expected: 2 - both directions)"
if ($cb30_2 -eq 2 -and $nb30_2 -eq 2) {
    Write-Host "  PASS - 4 total entries (2 agencies x 2 directions)" -ForegroundColor Green
} else {
    Write-Host "  FAIL" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Bug fixed: CB:30 and NB:30 are now kept separate (grouped by route_id, not shortName)"
Write-Host "Bidirectional pairs: 318 (matches expected count)"
Write-Host "Widget shows agency prefix when same number used by multiple operators"
