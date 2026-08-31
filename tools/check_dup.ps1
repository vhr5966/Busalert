$lines = Get-Content 'lib\data\gtfs_stop_routes.dart'
$stop1 = $lines | Select-String -Pattern "'5710AWA10055':" | Select-Object -Last 1
Write-Host "Stop 5710AWA10055 directional line:"
Write-Host $stop1.Line
Write-Host ""
$route30Count = ([regex]::Matches($stop1.Line, "shortName: '30'")).Count
Write-Host "Route 30 appears $route30Count time(s) in the directional list"
Write-Host ""
$stop2 = $lines | Select-String -Pattern "'5310AWB32203':" | Select-Object -Last 1
Write-Host "Stop 5310AWB32203 directional line:"
Write-Host $stop2.Line
Write-Host ""
$route30Count2 = ([regex]::Matches($stop2.Line, "shortName: '30'")).Count
Write-Host "Route 30 appears $route30Count2 time(s) in the directional list"
