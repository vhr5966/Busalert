$lines = Get-Content 'lib\data\gtfs_stop_routes.dart'
$bidir = $lines | Where-Object { ($_ -match 'directionId: 0') -and ($_ -match 'directionId: 1') }
Write-Host "Total bidirectional lines: $($bidir.Count)"
$bidir | Select-Object -First 3 | ForEach-Object { Write-Host $_ }
