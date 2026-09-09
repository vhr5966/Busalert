# Check if multiple route_ids map to the same short_name "30"
$root = Split-Path $PSScriptRoot -Parent

Write-Host "=== Checking routes.txt for route_short_name '30' ===" -ForegroundColor Cyan
$routesPath = Join-Path $root "routes.txt"
$rReader = [System.IO.StreamReader]::new($routesPath)
$header = $rReader.ReadLine()
Write-Host "Header: $header"
Write-Host ""

$route30s = @()
while (-not $rReader.EndOfStream) {
    $line = $rReader.ReadLine()
    if ($line -match "^([^,]+),([^,]+),([^,]+)" -and $line -like "*,30,*") {
        $cols = $line -split ','
        $route30s += [PSCustomObject]@{
            RouteId = $cols[0].Trim().Trim('"')
            AgencyId = $cols[1].Trim().Trim('"')
            ShortName = $cols[2].Trim().Trim('"')
            LongName = if($cols.Length -gt 3){$cols[3].Trim().Trim('"')}else{''}
        }
    }
}
$rReader.Dispose()

Write-Host "Found $($route30s.Count) routes with short_name='30':"
$route30s | ForEach-Object {
    Write-Host "  route_id='$($_.RouteId)' agency_id='$($_.AgencyId)' long_name='$($_.LongName)'"
}

Write-Host ""
Write-Host "=== Checking generation script grouping logic ===" -ForegroundColor Cyan
$scriptContent = Get-Content (Join-Path $root "tools\generate_gtfs_stop_routes.ps1") -Raw

if ($scriptContent -match '\$shortName\s*=\s*\$routeMap\[\$rid\]') {
    Write-Host "Script maps: route_id -> shortName"
    Write-Host "  routeMap[rid] = shortName"
}

if ($scriptContent -match '\$key\s*=\s*"\$sid\|\$shortName\|\$dir"') {
    Write-Host "Composite key uses: stop_id | shortName | direction_id"
    Write-Host ""
    Write-Host "*** BUG CONFIRMED ***" -ForegroundColor Red
    Write-Host "The key uses shortName ('30'), not route_id ('CB:30' vs 'NB:30')."
    Write-Host "This merges different operators' routes with the same number."
} elseif ($scriptContent -match '\$key\s*=\s*"\$sid\|\$rid\|\$dir"') {
    Write-Host "Composite key uses: stop_id | route_id | direction_id"
    Write-Host "OK - keeps CB:30 and NB:30 separate"
}

Write-Host ""
Write-Host "=== Raw data check for stop 5710AWA10055 ===" -ForegroundColor Cyan

# Check what route_ids actually serve this stop
$tripRoute = @{}
$tripDir = @{}
$tReader = [System.IO.StreamReader]::new((Join-Path $root "trips.txt"))
$null = $tReader.ReadLine()
while (-not $tReader.EndOfStream) {
    $line = $tReader.ReadLine()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $cols = @(); $inQ=$false; $cur=''
    foreach($ch in $line.ToCharArray()){
        if($ch -eq '"'){$inQ=-not $inQ}
        elseif($ch -eq ',' -and -not $inQ){$cols+=$cur;$cur=''}
        else{$cur+=$ch}
    }
    $cols+=$cur
    if($cols.Length -gt 5){
        $tripRoute[$cols[2].Trim()]=$cols[0].Trim()
        $tripDir[$cols[2].Trim()]=$cols[5].Trim()
    }
}
$tReader.Dispose()

$stopRoutes = @{}
$sReader = [System.IO.StreamReader]::new((Join-Path $root "stop_times.txt"))
$null = $sReader.ReadLine()
while (-not $sReader.EndOfStream) {
    $line = $sReader.ReadLine()
    if ($line -notlike "*5710AWA10055*" -and $line -notlike "*5310AWB32203*") { continue }
    $cols = $line -split ','
    if ($cols.Length -gt 3) {
        $tid = $cols[0].Trim()
        $sid = $cols[3].Trim()
        $rid = $tripRoute[$tid]
        $dir = $tripDir[$tid]
        if ($rid -and $rid -like "*:30") {
            $key = "$sid|$rid|$dir"
            $stopRoutes[$key] = $true
        }
    }
}
$sReader.Dispose()

Write-Host "Route '30' entries at both test stops (route_id level):"
$stopRoutes.Keys | Sort-Object | ForEach-Object {
    Write-Host "  $_"
}
