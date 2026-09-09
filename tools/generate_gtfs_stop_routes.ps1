# generate_gtfs_stop_routes.ps1
# Regenerates lib/data/gtfs_stop_routes.dart from GTFS files at project root.
# Produces two maps:
#   kGtfsStopRouteNames  – stop_id -> List<String> route short names (existing)
#   kGtfsStopDirections  – stop_id -> List<GtfsDirectionalLine> (new, bidirectional)
#   kGtfsRouteColors     – route_short_name -> GtfsRouteColors (existing)

$root   = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $root "lib\data"
$out    = Join-Path $outDir "gtfs_stop_routes.dart"

Write-Host "Root: $root"

# ── 1. Parse routes.txt → route_id -> (short_name, agency_id, color, text_color) ──
$routeMap   = @{}   # route_id -> @{short, agency, colorHex, textColorHex}

$routesPath = Join-Path $root "routes.txt"
$rReader = [System.IO.StreamReader]::new($routesPath)
$header = $rReader.ReadLine() -split ','
$idxRId   = 0
$idxAgency = 1
$idxShort = 2
$idxColor = 7   # route_color
$idxTxt   = 8   # route_text_color

# Find column indices dynamically from header
for ($i = 0; $i -lt $header.Length; $i++) {
    switch ($header[$i].Trim().Trim('"')) {
        'route_id'         { $idxRId   = $i }
        'agency_id'        { $idxAgency = $i }
        'route_short_name' { $idxShort = $i }
        'route_color'      { $idxColor = $i }
        'route_text_color' { $idxTxt   = $i }
    }
}

while (-not $rReader.EndOfStream) {
    $line = $rReader.ReadLine()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $cols = $line -split ','
    if ($cols.Length -le $idxShort) { continue }
    $rid    = $cols[$idxRId].Trim().Trim('"')
    $agency = $cols[$idxAgency].Trim().Trim('"')
    $short  = $cols[$idxShort].Trim().Trim('"')
    $col    = if ($cols.Length -gt $idxColor) { $cols[$idxColor].Trim().Trim('"') } else { '' }
    $txt    = if ($cols.Length -gt $idxTxt)   { $cols[$idxTxt].Trim().Trim('"')   } else { '' }
    if ($rid -and $short) {
        $routeMap[$rid] = @{
            short = $short
            agency = $agency
            colorHex = $col
            textColorHex = $txt
        }
    }
}
$rReader.Dispose()
Write-Host "Routes loaded: $($routeMap.Count)"

# ── 2. Parse trips.txt → trip_id -> (route_id, direction_id, trip_headsign) ──
$tripRoute     = @{}  # trip_id -> route_id
$tripDirection = @{}  # trip_id -> direction_id (string "0" or "1")
$tripHeadsign  = @{}  # trip_id -> trip_headsign

$tripsPath = Join-Path $root "trips.txt"
$tReader = [System.IO.StreamReader]::new($tripsPath)
$theader = $tReader.ReadLine() -split ','
$idxTRId  = 0
$idxTTid  = 2
$idxTHsign = 3
$idxTDir  = 5

for ($i = 0; $i -lt $theader.Length; $i++) {
    switch ($theader[$i].Trim().Trim('"')) {
        'route_id'      { $idxTRId   = $i }
        'trip_id'       { $idxTTid   = $i }
        'trip_headsign' { $idxTHsign = $i }
        'direction_id'  { $idxTDir   = $i }
    }
}

while (-not $tReader.EndOfStream) {
    $line = $tReader.ReadLine()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    # Handle quoted fields (trip_headsign may be quoted with commas inside)
    # Simple CSV parse: split on comma, rejoin quoted sections
    $cols = @()
    $inQuote = $false
    $current = ''
    foreach ($ch in $line.ToCharArray()) {
        if ($ch -eq '"') {
            $inQuote = -not $inQuote
        } elseif ($ch -eq ',' -and -not $inQuote) {
            $cols += $current
            $current = ''
        } else {
            $current += $ch
        }
    }
    $cols += $current

    if ($cols.Length -le $idxTTid) { continue }
    $rid   = $cols[$idxTRId].Trim()
    $tid   = $cols[$idxTTid].Trim()
    $hs    = if ($cols.Length -gt $idxTHsign) { $cols[$idxTHsign].Trim() } else { '' }
    $dir   = if ($cols.Length -gt $idxTDir)   { $cols[$idxTDir].Trim()   } else { '0' }
    if ($tid -and $rid) {
        $tripRoute[$tid]     = $rid
        $tripDirection[$tid] = $dir
        $tripHeadsign[$tid]  = $hs
    }
}
$tReader.Dispose()
Write-Host "Trips loaded: $($tripRoute.Count)"

# ── 3. Stream stop_times.txt → build both maps ───────────────────────────────
# stopRoutes: stop_id -> HashSet<route_id> (NOT shortName!)
# stopDirFreq: "$stopId|$routeId|$dirId" -> hashtable of headsign->count
$stopRoutes = @{}   # stop_id -> HashSet of route_ids
$stopDirFreq = @{}  # composite key -> @{headsign -> count}

$stPath = Join-Path $root "stop_times.txt"
$sReader = [System.IO.StreamReader]::new($stPath)
$sheader = $sReader.ReadLine() -split ','
$idxSTtid = 0
$idxSTsid = 3
$idxSThs  = 5

for ($i = 0; $i -lt $sheader.Length; $i++) {
    switch ($sheader[$i].Trim().Trim('"')) {
        'trip_id'       { $idxSTtid = $i }
        'stop_id'       { $idxSTsid = $i }
        'stop_headsign' { $idxSThs  = $i }
    }
}

$rowCount = 0
while (-not $sReader.EndOfStream) {
    $line = $sReader.ReadLine()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $cols = $line -split ','
    if ($cols.Length -le $idxSTsid) { continue }

    $tid = $cols[$idxSTtid].Trim()
    $sid = $cols[$idxSTsid].Trim()
    if (-not $tid -or -not $sid) { continue }

    $rid = $tripRoute[$tid]
    if (-not $rid) { continue }

    $routeInfo = $routeMap[$rid]
    if (-not $routeInfo) { continue }

    # Add to stop -> route_ids (NOT shortName)
    if (-not $stopRoutes.ContainsKey($sid)) {
        $stopRoutes[$sid] = [System.Collections.Generic.HashSet[string]]::new()
    }
    $null = $stopRoutes[$sid].Add($rid)

    # Directional key uses route_id, NOT shortName
    $dir = $tripDirection[$tid]
    if ($null -eq $dir) { $dir = '0' }
    $key = "$sid|$rid|$dir"

    if (-not $stopDirFreq.ContainsKey($key)) {
        $stopDirFreq[$key] = @{}
    }

    # Prefer stop_headsign, fall back to trip_headsign
    $hs = if ($cols.Length -gt $idxSThs) { $cols[$idxSThs].Trim() } else { '' }
    if ([string]::IsNullOrWhiteSpace($hs)) {
        $hs = $tripHeadsign[$tid]
        if ($null -eq $hs) { $hs = '' }
    }

    # Increment count for this headsign
    $cnt = $stopDirFreq[$key][$hs]
    if ($null -eq $cnt) {
        $stopDirFreq[$key][$hs] = 1
    } else {
        $stopDirFreq[$key][$hs] = $cnt + 1
    }

    $rowCount++
    if ($rowCount % 50000 -eq 0) { Write-Host "  stop_times rows: $rowCount" }
}
$sReader.Dispose()
Write-Host "stop_times rows processed: $rowCount"
Write-Host "Stops with routes: $($stopRoutes.Count)"
Write-Host "Directional keys: $($stopDirFreq.Count)"

# ── 3b. Resolve most-frequent headsign per group ─────────────────────────────
$stopDirMap = @{}
foreach ($key in $stopDirFreq.Keys) {
    $best = ''
    $bestCount = 0
    foreach ($hs in $stopDirFreq[$key].Keys) {
        $c = $stopDirFreq[$key][$hs]
        if ($c -gt $bestCount) {
            $bestCount = $c
            $best = $hs
        }
    }
    $stopDirMap[$key] = $best
}

# ── 4. Count bidirectional (stop, route_id) pairs ───────────────────────────
$biDirPairs = 0
$pairDirCount = @{}
foreach ($key in $stopDirMap.Keys) {
    $parts = $key -split '\|'
    $pairKey = "$($parts[0])|$($parts[1])"  # stop|route_id
    if (-not $pairDirCount.ContainsKey($pairKey)) { $pairDirCount[$pairKey] = 0 }
    $pairDirCount[$pairKey]++
}
foreach ($pk in $pairDirCount.Keys) {
    if ($pairDirCount[$pk] -ge 2) { $biDirPairs++ }
}
Write-Host "Bidirectional (stop, route_id) pairs: $biDirPairs"

# ── 5. Natural sort helper ───────────────────────────────────────────────────
function NaturalKey($s) {
    # Pad numeric runs to 6 digits for lexicographic natural sort
    return [regex]::Replace($s, '\d+', { $args[0].Value.PadLeft(6, '0') })
}

# ── 6. Emit Dart file ────────────────────────────────────────────────────────
$sb = [System.Text.StringBuilder]::new()

$null = $sb.AppendLine("/// Auto-generated from GTFS data. DO NOT EDIT.")
$null = $sb.AppendLine("/// Generated by: tools/generate_gtfs_stop_routes.ps1")
$null = $sb.AppendLine("/// Grouping: by route_id (not shortName) to keep CB:30 and NB:30 separate")
$null = $sb.AppendLine("/// Stats: $($stopRoutes.Count) stops, $($stopDirMap.Count) directional entries")
$null = $sb.AppendLine("library;")
$null = $sb.AppendLine("")

# GtfsRouteColors class
$null = $sb.AppendLine("/// Color info for one route.")
$null = $sb.AppendLine("class GtfsRouteColors {")
$null = $sb.AppendLine("  final String colorHex;")
$null = $sb.AppendLine("  final String textColorHex;")
$null = $sb.AppendLine("  const GtfsRouteColors(this.colorHex, this.textColorHex);")
$null = $sb.AppendLine("}")
$null = $sb.AppendLine("")

# GtfsDirectionalLine class
$null = $sb.AppendLine("/// One direction of a route at a stop.")
$null = $sb.AppendLine("class GtfsDirectionalLine {")
$null = $sb.AppendLine("  /// GTFS route_id, e.g. 'CB:30', 'NB:30'.")
$null = $sb.AppendLine("  final String routeId;")
$null = $sb.AppendLine("  /// Route short name for display, e.g. '30'.")
$null = $sb.AppendLine("  final String shortName;")
$null = $sb.AppendLine("  /// GTFS agency_id, e.g. 'CB', 'NB'.")
$null = $sb.AppendLine("  final String agencyId;")
$null = $sb.AppendLine("  /// GTFS direction_id: 0 or 1.")
$null = $sb.AppendLine("  final int directionId;")
$null = $sb.AppendLine("  /// Headsign (trip_headsign or stop_headsign), e.g. 'City Centre'.")
$null = $sb.AppendLine("  final String headsign;")
$null = $sb.AppendLine("  const GtfsDirectionalLine({")
$null = $sb.AppendLine("    required this.routeId,")
$null = $sb.AppendLine("    required this.shortName,")
$null = $sb.AppendLine("    required this.agencyId,")
$null = $sb.AppendLine("    required this.directionId,")
$null = $sb.AppendLine("    required this.headsign,")
$null = $sb.AppendLine("  });")
$null = $sb.AppendLine("}")
$null = $sb.AppendLine("")

# kGtfsRouteColors map (keyed by route_id now, not shortName)
$null = $sb.AppendLine("/// Maps route_id -> color info.")
$null = $sb.AppendLine("const Map<String, GtfsRouteColors> kGtfsRouteColors = {")
$sortedRouteIds = $routeMap.Keys | Sort-Object
foreach ($rid in $sortedRouteIds) {
    $info = $routeMap[$rid]
    $escapedRid = $rid -replace "'", "\\'"
    $null = $sb.AppendLine("  '$escapedRid': GtfsRouteColors('$($info.colorHex)', '$($info.textColorHex)'),")
}
$null = $sb.AppendLine("};")
$null = $sb.AppendLine("")

# kGtfsStopRouteNames map (stop_id -> list of short names for backward compat)
$null = $sb.AppendLine("/// Maps stop_id -> list of route short names (for backward compat).")
$null = $sb.AppendLine("/// WARNING: if multiple agencies use the same number (e.g. CB:30 and NB:30),")
$null = $sb.AppendLine("/// this list will show '30' only once. Use kGtfsStopDirections for full detail.")
$null = $sb.AppendLine("const Map<String, List<String>> kGtfsStopRouteNames = {")
$sortedStops = $stopRoutes.Keys | Sort-Object
foreach ($sid in $sortedStops) {
    $routeIds = $stopRoutes[$sid]
    $shortNames = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($rid in $routeIds) {
        $info = $routeMap[$rid]
        if ($info) { $null = $shortNames.Add($info.short) }
    }
    $sorted = $shortNames | Sort-Object { NaturalKey $_ }
    $quotedNames = ($sorted | ForEach-Object { "'$($_ -replace "'", "\\'")'" }) -join ', '
    $null = $sb.AppendLine("  '$sid': [$quotedNames],")
}
$null = $sb.AppendLine("};")
$null = $sb.AppendLine("")

# kGtfsStopDirections map (full route_id detail)
$null = $sb.AppendLine("/// Maps stop_id -> list of directional line entries (by route_id).")
$null = $sb.AppendLine("/// Each entry includes routeId, shortName, agencyId, directionId, headsign.")
$null = $sb.AppendLine("/// Routes with both directions appear twice. Different agencies with the")
$null = $sb.AppendLine("/// same number (CB:30, NB:30) are kept separate.")
$null = $sb.AppendLine("const Map<String, List<GtfsDirectionalLine>> kGtfsStopDirections = {")

foreach ($sid in $sortedStops) {
    # Collect all directional keys for this stop
    $entries = @()
    foreach ($key in $stopDirMap.Keys) {
        $parts = $key -split '\|'
        if ($parts[0] -ne $sid) { continue }
        $rid = $parts[1]
        $dirId = [int]$parts[2]
        $hs = $stopDirMap[$key]
        $info = $routeMap[$rid]
        if (-not $info) { continue }
        $entries += [PSCustomObject]@{
            RouteId   = $rid
            ShortName = $info.short
            AgencyId  = $info.agency
            DirId     = $dirId
            Headsign  = $hs
        }
    }
    # Sort: by short name (natural), then agency, then direction
    $sorted = $entries | Sort-Object { NaturalKey $_.ShortName }, AgencyId, DirId

    $items = @()
    foreach ($e in $sorted) {
        $escapedRid   = $e.RouteId   -replace "'", "\\'" -replace '\\', '\\\\'
        $escapedShort = $e.ShortName -replace "'", "\\'"
        $escapedAgency = $e.AgencyId -replace "'", "\\'"
        $escapedHs    = $e.Headsign  -replace "'", "\\'" -replace '\\', '\\\\'
        $items += "GtfsDirectionalLine(routeId: '$escapedRid', shortName: '$escapedShort', agencyId: '$escapedAgency', directionId: $($e.DirId), headsign: '$escapedHs')"
    }
    $joined = $items -join ', '
    $null = $sb.AppendLine("  '$sid': [$joined],")
}
$null = $sb.AppendLine("};")

# Write file
[System.IO.File]::WriteAllText($out, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "Written: $out"
Write-Host "DONE"
