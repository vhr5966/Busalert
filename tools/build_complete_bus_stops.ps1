$webClient = [System.Net.WebClient]::new()

Write-Host "Downloading NaPTAN CSVs..."
$csv571 = $webClient.DownloadString("https://naptan.api.dft.gov.uk/v1/access-nodes?atcoAreaCodes=571&dataFormat=csv")
$csv572 = $webClient.DownloadString("https://naptan.api.dft.gov.uk/v1/access-nodes?atcoAreaCodes=572&dataFormat=csv")
$csv531 = $webClient.DownloadString("https://naptan.api.dft.gov.uk/v1/access-nodes?atcoAreaCodes=531&dataFormat=csv")

$naptanMap = @{}

function Parse-NaPTAN($csvText) {
    $lines = $csvText -split "`n"
    if ($lines.Length -lt 2) { return }
    for ($i = 1; $i -lt $lines.Length; $i++) {
        $line = $lines[$i].Trim()
        if (-not $line) { continue }
        $cols = $line -split ','
        if ($cols.Length -lt 31) { continue }
        $atco = $cols[0].Trim().Trim('"')
        $commonName = $cols[4].Trim().Trim('"')
        $street = $cols[10].Trim().Trim('"')
        $indicator = $cols[14].Trim().Trim('"')
        $town = $cols[21].Trim().Trim('"')
        $suburb = $cols[23].Trim().Trim('"')
        $lon = $cols[29].Trim().Trim('"')
        $lat = $cols[30].Trim().Trim('"')
        $status = if ($cols.Length -gt 38) { $cols[38].Trim().Trim('"') } else { 'active' }
        
        if ($status -eq 'del' -or -not $lat -or -not $lon) { continue }
        
        $naptanMap[$atco] = @{
            name = $commonName
            indicator = $indicator
            street = $street
            town = $town
            suburb = $suburb
            lat = [double]$lat
            lon = [double]$lon
        }
    }
}

Parse-NaPTAN $csv571
Parse-NaPTAN $csv572
Parse-NaPTAN $csv531
Write-Host "NaPTAN stops loaded: $($naptanMap.Count)"

# Read GTFS stops.txt
$stopsTxt = Get-Content .\stops.txt | Select-Object -Skip 1
$gtfsMap = @{}
foreach ($line in $stopsTxt) {
    if (-not [string]::IsNullOrWhiteSpace($line)) {
        $cols = $line -split ','
        $atco = $cols[0].Trim().Trim('"')
        $name = $cols[2].Trim().Trim('"')
        $lat = [double]$cols[4].Trim()
        $lon = [double]$cols[5].Trim()
        $gtfsMap[$atco] = @{
            name = $name
            lat = $lat
            lon = $lon
        }
    }
}
Write-Host "GTFS stops.txt loaded: $($gtfsMap.Count)"

# Read kGtfsStopRouteNames to prefill routes
$gtfsRoutesFile = Get-Content .\lib\data\gtfs_stop_routes.dart
$stopRoutes = @{}
foreach ($line in $gtfsRoutesFile) {
    if ($line -match "^\s*'([^']+)':\s*(\[[^\]]*\])") {
        $stopRoutes[$matches[1]] = $matches[2]
    }
}
Write-Host "Stop routes loaded: $($stopRoutes.Count)"

# Build merged stops dictionary (keyed by ATCO code)
$mergedStops = [System.Collections.Generic.Dictionary[string, hashtable]]::new()

# 1. First add all GTFS stops (they have verified scheduled routes)
foreach ($atco in $gtfsMap.Keys) {
    $gtfs = $gtfsMap[$atco]
    $displayName = $gtfs.name
    $indicator = ''
    $street = ''
    
    if ($naptanMap.ContainsKey($atco)) {
        $n = $naptanMap[$atco]
        $indicator = $n.indicator
        $street = $n.street
        # If indicator exists and not in name, append it (e.g. "Royal Gwent Hospital (opp)")
        if ($indicator -and -not $displayName.Contains("($indicator)")) {
            $displayName = "$($n.name) ($indicator)"
        }
    }
    
    $routesStr = if ($stopRoutes.ContainsKey($atco)) { $stopRoutes[$atco] } else { '<String>[]' }
    
    $mergedStops[$atco] = @{
        atcoCode = $atco
        name = $displayName
        latitude = $gtfs.lat
        longitude = $gtfs.lon
        routes = $routesStr
        indicator = $indicator
        street = if ($street) { $street } else { $displayName }
    }
}

# 2. Add remaining NaPTAN stops in Cardiff (571), Vale of Glamorgan (572), Newport (531)
foreach ($atco in $naptanMap.Keys) {
    if (-not $mergedStops.ContainsKey($atco)) {
        $n = $naptanMap[$atco]
        $displayName = $n.name
        if ($n.indicator) {
            $displayName = "$($n.name) ($($n.indicator))"
        }
        $routesStr = if ($stopRoutes.ContainsKey($atco)) { $stopRoutes[$atco] } else { '<String>[]' }
        $mergedStops[$atco] = @{
            atcoCode = $atco
            name = $displayName
            latitude = $n.lat
            longitude = $n.lon
            routes = $routesStr
            indicator = $n.indicator
            street = if ($n.street) { $n.street } else { $displayName }
        }
    }
}

Write-Host "Total unique merged stops: $($mergedStops.Count)"

# Generate cardiff_bus_stops.dart file
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("/// Complete Cardiff and Regional Bus stops from NaPTAN & GTFS databases.")
[void]$sb.AppendLine("/// Includes Cardiff (571), Vale of Glamorgan (572), and Newport (531).")
[void]$sb.AppendLine("/// Total stops: $($mergedStops.Count).")
[void]$sb.AppendLine("library;")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("const List<Map<String, dynamic>> kNaPTANBusStops = [")

foreach ($stop in $mergedStops.Values) {
    $atco = $stop.atcoCode
    $name = $stop.name.Replace("'", "\'")
    $lat = $stop.latitude
    $lon = $stop.longitude
    $rStr = $stop.routes
    $ind = $stop.indicator.Replace("'", "\'")
    $st = $stop.street.Replace("'", "\'")
    
    [void]$sb.AppendLine("  {")
    [void]$sb.AppendLine("    'atcoCode': '$atco',")
    [void]$sb.AppendLine("    'name': '$name',")
    [void]$sb.AppendLine("    'latitude': $lat,")
    [void]$sb.AppendLine("    'longitude': $lon,")
    [void]$sb.AppendLine("    'routes': $rStr,")
    [void]$sb.AppendLine("    'indicator': '$ind',")
    [void]$sb.AppendLine("    'street': '$st',")
    [void]$sb.AppendLine("  },")
}

[void]$sb.AppendLine("];")

[System.IO.File]::WriteAllText("$PWD\lib\data\cardiff_bus_stops.dart", $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "Successfully wrote lib/data/cardiff_bus_stops.dart ($($mergedStops.Count) stops)!"
