# WCH/MounRiver OpenOCD feature test script (ASCII only)
$ErrorActionPreference = 'Continue'
$ocd = 'C:\MounRiver\MounRiver_Studio2\resources\app\resources\win32\components\WCH\OpenOCD\OpenOCD\bin\openocd.exe'

Write-Host '=== 1. Version ==='
& $ocd --version 2>&1 | Select-Object -First 1 | ForEach-Object { $_.ToString() }

Write-Host "`n=== 2. Adapter drivers ==="
& $ocd -c 'adapter list' -c 'shutdown' 2>&1 | Where-Object { $_ -match '^\d+:' } | ForEach-Object { $_.ToString().Trim() }

Write-Host "`n=== 3. Transports ==="
& $ocd -c 'transport list' -c 'shutdown' 2>&1 | Where-Object { $_ -match '^\s+\w' } | ForEach-Object { $_.ToString().Trim() }

Write-Host "`n=== 4. Transport selectability ==="
foreach ($t in @('jtag','swd','hla_jtag','hla_swd','sdi','swim','dapdirect_jtag','dapdirect_swd')) {
    $o = (& $ocd -c "transport select $t" -c 'shutdown' 2>&1 | Out-String)
    if ($o -match 'already selected|autoselect|transport select') { "OK   $t" }
    elseif ($o -match 'not a valid|not valid|unknown') { "N/A  $t" }
    else { "?    $t" }
}

Write-Host "`n=== 5. Target types ==="
& $ocd -c 'target types' -c 'shutdown' 2>&1 | Where-Object { $_ -match 'arm7tdmi|wch_riscv|riscv' } | ForEach-Object { $_.ToString().Trim() }

Write-Host "`n=== 6. WCH-specific commands ==="
$o = (& $ocd -c 'adapter driver ch347' -c 'ch347 vid_pid 0x1a86 0x55dd' -c 'shutdown' 2>&1 | Out-String)
if ($o -match 'Unknown command|invalid command') { 'ch347 vid_pid    : NOT recognized' } else { 'ch347 vid_pid    : recognized' }
$o = (& $ocd -c 'adapter driver wlinke' -c 'transport select sdi' -c 'wlink_set_address 0x00000000' -c 'shutdown' 2>&1 | Out-String)
if ($o -match 'Unknown command|invalid command') { 'wlink_set_address: NOT recognized' } else { 'wlink_set_address: recognized' }

Write-Host "`n=== 7. Live test: CH347 connect ==="
& $ocd -c 'adapter driver ch347' -c 'ch347 vid_pid 0x1a86 0x55dd' -c 'adapter speed 10000' -c 'transport select jtag' -c 'init' -c 'shutdown' 2>&1 | Where-Object { $_ -match 'CH347|Open|Error|JTAG tap|tap/device' } | Select-Object -Last 4 | ForEach-Object { $_.ToString().Trim() }

Write-Host "`n=== 8. Live test: WCH-Link SDI ==="
& $ocd -f 'C:\MounRiver\MounRiver_Studio2\resources\app\resources\win32\components\WCH\OpenOCD\OpenOCD\bin\wch-riscv.cfg' 2>&1 | Where-Object { $_ -match 'WLink|Open|Error|Ready|Listening' } | Select-Object -Last 5 | ForEach-Object { $_.ToString().Trim() }

Write-Host "`nDone"
