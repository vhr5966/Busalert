$path = "C:\Users\Administrator\AppData\Local\Pub\Cache\hosted\pub.dev\wifi_scan-0.2.1\android\src\main\AndroidManifest.xml"
$content = Get-Content $path -Raw
$content = $content -replace '\s*package="dev\.flutternetwork\.wifi\.wifi_scan"', ""
Set-Content $path $content
Write-Host "PATCHED: removed package attribute from wifi_scan AndroidManifest.xml"
