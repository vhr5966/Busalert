$path = "C:\Users\Administrator\AppData\Local\Pub\Cache\hosted\pub.dev\wifi_scan-0.2.1\android\build.gradle"
$content = Get-Content $path -Raw
if ($content -notmatch "namespace") {
    $content = $content -replace 'compileSdkVersion 30', "compileSdkVersion 30`r`n    namespace `"dev.flutternetwork.wifi`""
    Set-Content $path $content
    Write-Host "PATCHED: namespace added to wifi_scan build.gradle"
} else {
    Write-Host "OK: wifi_scan build.gradle already has namespace"
}
