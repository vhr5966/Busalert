# Debug: show all headsigns per (stop, route, direction) for two test stops
param(
    [string[]]$StopIds = @('5710AWA10055', '5310AWB32203')
)

$root = Split-Path $PSScriptRoot -Parent

Write-Host "=== Loading trips.txt ==="
$tripRoute     = @{}
$tripDirection = @{}
$tripHeadsign  = @{}

$tReader = [System.IO.StreamReader]::new((Join-Path $root "trips.txt"))
$theader = $tReader.ReadLine() -split ','
$idxTRId=0; $idxTTid=2; $idxTHsign=3; $idxTDir=5
for ($i=0;$i -lt $theader.Length;$i++){
    switch($theader[$i].Trim().Trim('"')){
        'route_id'      {$idxTRId=$i}
        'trip_id'       {$idxTTid=$i}
        'trip_headsign' {$idxTHsign=$i}
        'direction_id'  {$idxTDir=$i}
    }
}
while(-not $tReader.EndOfStream){
    $line=$tReader.ReadLine()
    if([string]::IsNullOrWhiteSpace($line)){continue}
    $cols=@(); $inQ=$false; $cur=''
    foreach($ch in $line.ToCharArray()){
        if($ch -eq '"'){$inQ=-not $inQ}
        elseif($ch -eq ',' -and -not $inQ){$cols+=$cur;$cur=''}
        else{$cur+=$ch}
    }
    $cols+=$cur
    if($cols.Length -le $idxTTid){continue}
    $rid=$cols[$idxTRId].Trim(); $tid=$cols[$idxTTid].Trim()
    $hs=if($cols.Length -gt $idxTHsign){$cols[$idxTHsign].Trim()}else{''}
    $dir=if($cols.Length -gt $idxTDir){$cols[$idxTDir].Trim()}else{'0'}
    if($tid -and $rid){$tripRoute[$tid]=$rid;$tripDirection[$tid]=$dir;$tripHeadsign[$tid]=$hs}
}
$tReader.Dispose()
Write-Host "Trips: $($tripRoute.Count)"

Write-Host "=== Loading routes.txt ==="
$routeMap=@{}
$rReader=[System.IO.StreamReader]::new((Join-Path $root "routes.txt"))
$rheader=$rReader.ReadLine() -split ','
$idxRId=0;$idxShort=2
for($i=0;$i -lt $rheader.Length;$i++){
    switch($rheader[$i].Trim().Trim('"')){
        'route_id'         {$idxRId=$i}
        'route_short_name' {$idxShort=$i}
    }
}
while(-not $rReader.EndOfStream){
    $line=$rReader.ReadLine()
    if([string]::IsNullOrWhiteSpace($line)){continue}
    $cols=$line -split ','
    if($cols.Length -le $idxShort){continue}
    $rid=$cols[$idxRId].Trim().Trim('"'); $short=$cols[$idxShort].Trim().Trim('"')
    if($rid -and $short){$routeMap[$rid]=$short}
}
$rReader.Dispose()

Write-Host "=== Scanning stop_times.txt for target stops ==="
# key = "stopId|shortName|dirId" -> hashtable of headsign->count
$groupHeadsigns = @{}

$sReader=[System.IO.StreamReader]::new((Join-Path $root "stop_times.txt"))
$sheader=$sReader.ReadLine() -split ','
$idxSTtid=0;$idxSTsid=3;$idxSThs=5
for($i=0;$i -lt $sheader.Length;$i++){
    switch($sheader[$i].Trim().Trim('"')){
        'trip_id'       {$idxSTtid=$i}
        'stop_id'       {$idxSTsid=$i}
        'stop_headsign' {$idxSThs=$i}
    }
}
$stopIdSet = [System.Collections.Generic.HashSet[string]]::new($StopIds)
while(-not $sReader.EndOfStream){
    $line=$sReader.ReadLine()
    if([string]::IsNullOrWhiteSpace($line)){continue}
    $cols=$line -split ','
    if($cols.Length -le $idxSTsid){continue}
    $tid=$cols[$idxSTtid].Trim(); $sid=$cols[$idxSTsid].Trim()
    if(-not $stopIdSet.Contains($sid)){continue}
    $rid=$tripRoute[$tid]; if(-not $rid){continue}
    $short=$routeMap[$rid]; if(-not $short){continue}
    $dir=$tripDirection[$tid]; if($null -eq $dir){$dir='0'}
    $stopHs=if($cols.Length -gt $idxSThs){$cols[$idxSThs].Trim()}else{''}
    $hs=if([string]::IsNullOrWhiteSpace($stopHs)){$tripHeadsign[$tid]}else{$stopHs}
    if($null -eq $hs){$hs=''}
    $key="$sid|$short|$dir"
    if(-not $groupHeadsigns.ContainsKey($key)){$groupHeadsigns[$key]=@{}}
    $cnt=$groupHeadsigns[$key][$hs]
    if($null -eq $cnt){$groupHeadsigns[$key][$hs]=1}else{$groupHeadsigns[$key][$hs]=$cnt+1}
}
$sReader.Dispose()

Write-Host ""
Write-Host "=== BEFORE FIX: first-seen headsign per group ==="
$firstSeen=@{}
foreach($key in ($groupHeadsigns.Keys | Sort-Object)){
    $parts=$key -split '\|'
    $stop=$parts[0]; $route=$parts[1]; $dir=$parts[2]
    # first seen = just pick any (arbitrary)
    $arbitrary=($groupHeadsigns[$key].Keys | Select-Object -First 1)
    Write-Host "  stop=$stop  route=$route  dir=$dir  first='$arbitrary'"
}

Write-Host ""
Write-Host "=== AFTER FIX: most-frequent (mode) headsign per group ==="
foreach($key in ($groupHeadsigns.Keys | Sort-Object)){
    $parts=$key -split '\|'
    $stop=$parts[0]; $route=$parts[1]; $dir=$parts[2]
    $best=''; $bestCount=0
    foreach($hs in $groupHeadsigns[$key].Keys){
        $c=$groupHeadsigns[$key][$hs]
        if($c -gt $bestCount){$bestCount=$c;$best=$hs}
    }
    $allVariants=($groupHeadsigns[$key].Keys | ForEach-Object {"'$_'($($groupHeadsigns[$key][$_]))"}) -join ', '
    Write-Host "  stop=$stop  route=$route  dir=$dir  MODE='$best'  all=[$allVariants]"
}
