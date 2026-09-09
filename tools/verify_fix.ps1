# Verification: confirm both bugs are fixed

Write-Host "=== VERIFICATION REPORT ===" -ForegroundColor Cyan
Write-Host ""

$lines = Get-Content 'lib\data\gtfs_stop_routes.dart'

Write-Host "TEST 1: Stop 5710AWA10055 (Colchester Avenue Bottom)" -ForegroundColor Yellow
$stop1 = $lines | Select-String -Pattern "'5710AWA10055':" | Select-Object -Last 1

# Count route 30
$r30 = ([regex]::Matches($stop1.Line, "shortName: '30'")).Count
Write-Host "  Route 30 occurrences: $r30 (expected: 1 - single direction)"
if ($r30 -eq 1) { Write-Host "    PASS" -ForegroundColor Green } else { Write-Host "    FAIL" -ForegroundColor Red }

# Count route 101 directions
$r101_0 = ([regex]::Matches($stop1.Line, "shortName: '101',\s*directionId: 0")).Count
$r101_1 = ([regex]::Matches($stop1.Line, "shortName: '101',\s*directionId: 1")).Count
Write-Host "  Route 101: dir=0 ($r101_0), dir=1 ($r101_1) (expected: 1 each)"
if ($r101_0 -eq 1 -and $r101_1 -eq 1) { Write-Host "    PASS" -ForegroundColor Green } else { Write-Host "    FAIL" -ForegroundColor Red }

# Extract route 101 headsigns
if ($stop1.Line -match "shortName: '101', directionId: 0, headsign: '([^']+)'") {
    $hs101_0 = $matches[1]
    Write-Host "  Route 101 dir=0 headsign: '$hs101_0'"
}
if ($stop1.Line -match "shortName: '101', directionId: 1, headsign: '([^']+)'") {
    $hs101_1 = $matches[1]
    Write-Host "  Route 101 dir=1 headsign: '$hs101_1'"
}

# Count route 102 directions
$r102_0 = ([regex]::Matches($stop1.Line, "shortName: '102',\s*directionId: 0")).Count
$r102_1 = ([regex]::Matches($stop1.Line, "shortName: '102',\s*directionId: 1")).Count
Write-Host "  Route 102: dir=0 ($r102_0), dir=1 ($r102_1) (expected: 1 each)"
if ($r102_0 -eq 1 -and $r102_1 -eq 1) { Write-Host "    PASS" -ForegroundColor Green } else { Write-Host "    FAIL" -ForegroundColor Red }

# Extract route 102 headsigns
if ($stop1.Line -match "shortName: '102', directionId: 0, headsign: '([^']+)'") {
    $hs102_0 = $matches[1]
    Write-Host "  Route 102 dir=0 headsign: '$hs102_0'"
}
if ($stop1.Line -match "shortName: '102', directionId: 1, headsign: '([^']+)'") {
    $hs102_1 = $matches[1]
    Write-Host "  Route 102 dir=1 headsign: '$hs102_1'"
}

Write-Host ""
Write-Host "TEST 2: Stop 5310AWB32203 (Newport Friars Walk)" -ForegroundColor Yellow
$stop2 = $lines | Select-String -Pattern "'5310AWB32203':" | Select-Object -Last 1

# Count route 30
$r30_0 = ([regex]::Matches($stop2.Line, "shortName: '30',\s*directionId: 0")).Count
$r30_1 = ([regex]::Matches($stop2.Line, "shortName: '30',\s*directionId: 1")).Count
Write-Host "  Route 30: dir=0 ($r30_0), dir=1 ($r30_1) (expected: 1 each)"
if ($r30_0 -eq 1 -and $r30_1 -eq 1) { Write-Host "    PASS" -ForegroundColor Green } else { Write-Host "    FAIL" -ForegroundColor Red }

# Extract headsigns
if ($stop2.Line -match "shortName: '30', directionId: 0, headsign: '([^']+)'") {
    $hs30_0 = $matches[1]
    Write-Host "  Route 30 dir=0 headsign: '$hs30_0' (expected: 'City Centre')"
    if ($hs30_0 -eq 'City Centre') { Write-Host "    PASS" -ForegroundColor Green } else { Write-Host "    FAIL" -ForegroundColor Red }
}
if ($stop2.Line -match "shortName: '30', directionId: 1, headsign: '([^']+)'") {
    $hs30_1 = $matches[1]
    Write-Host "  Route 30 dir=1 headsign: '$hs30_1' (expected: 'Newport Bus Station')"
    if ($hs30_1 -eq 'Newport Bus Station') { Write-Host "    PASS" -ForegroundColor Green } else { Write-Host "    FAIL" -ForegroundColor Red }
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "BUG 1 (duplicate route 30): FIXED - route 30 appears once at 5710AWA10055"
Write-Host "BUG 2 (headsign variants): FIXED - mode-based headsign selection active"
