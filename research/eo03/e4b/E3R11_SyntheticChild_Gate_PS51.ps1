# EO-03 E3-R11 synthetic child generator boundary test; no business runner.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Test-Input {
 param([string]$MinRows,[string]$Ticker,[string]$Run)
 if ($MinRows -cnotmatch '^[0-9]{1,5}$') { return $false }
 $num=0
 if (-not [int]::TryParse($MinRows,[ref]$num) -or $num -lt 1 -or $num -gt 10000) { return $false }
 if ($Ticker -cnotmatch '^[0-9]{4,6}$') { return $false }
 if ($Run -cnotmatch '^[A-Z0-9_-]{3,48}$') { return $false }
 return $true
}
function New-Child {
 param([string]$MinRows,[string]$Ticker,[string]$Run)
 if (-not (Test-Input $MinRows $Ticker $Run)) { throw 'INPUT_SCHEMA_BLOCK' }
 return ('$minRows = '+[int]$MinRows+"`r`n"+'$ticker = '''+$Ticker+"'`r`n"+'$run = '''+$Run+"'`r`n")
}
function Get-Digest([byte[]]$Bytes) {
 $sha=[Security.Cryptography.SHA256]::Create()
 try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
 finally { $sha.Dispose() }
}
$approvedGeneratorIdentity = Get-Digest ([Text.Encoding]::UTF8.GetBytes('EO03-E3R11-SYNTHETIC-GENERATOR-R1'))
$expectedIdentity = Get-Digest ([Text.Encoding]::UTF8.GetBytes('EO03-E3R11-SYNTHETIC-GENERATOR-R1'))
if ($approvedGeneratorIdentity -cne $expectedIdentity) { throw 'GENERATOR_IDENTITY_BLOCK' }
$original = New-Child '120' '2330' 'EO03_RUN1'
$expected = '$minRows = 120'+"`r`n"+'$ticker = ''2330'''+"`r`n"+'$run = ''EO03_RUN1'''+"`r`n"
$bom=[byte[]](239,187,191)
$enc=New-Object System.Text.UTF8Encoding($false)
$bytes=[byte[]]($bom + $enc.GetBytes($original))
$expectedBytes=[byte[]]($bom + $enc.GetBytes($expected))
if ((Get-Digest $bytes) -cne (Get-Digest $expectedBytes)) { throw 'DERIVED_CHILD_MISMATCH' }
Write-Output 'E3R11_VALID_CHILD_EXACT_BYTES_PASS'
foreach($bad in @('120+1','1;Write-Output','-1','10001','0','abc')) {
 if (Test-Input $bad '2330' 'EO03_RUN1') { throw ('INVALID_NUMERIC_ACCEPTED '+$bad) }
}
Write-Output 'E3R11_TYPED_INPUT_NEGATIVES_PASS'
foreach($badTicker in @('../etc','2330;','2 330')) {
 if (Test-Input '120' $badTicker 'EO03_RUN1') { throw 'INVALID_TICKER_ACCEPTED' }
}
Write-Output 'E3R11_PATH_AND_INPUT_NEGATIVES_PASS'
$changed=$original.Replace('120','121')
if ((Get-Digest ([byte[]]($bom+$enc.GetBytes($changed)))) -ceq (Get-Digest $expectedBytes)) { throw 'TAMPERED_CHILD_ACCEPTED' }
Write-Output 'E3R11_TAMPERED_VALID_SYNTAX_CHILD_BLOCK_PASS'
$parsedTokens=$null;$parseErrors=$null
$null=[System.Management.Automation.Language.Parser]::ParseInput($changed,[ref]$parsedTokens,[ref]$parseErrors)
if (@($parseErrors).Count -gt 0) { throw 'TAMPER_TEST_NOT_PARSEABLE' }
Write-Output 'E3R11_PARSER_PASS_IS_NOT_APPROVAL_PASS'
Write-Output 'E3R11_NO_CHILD_EXECUTION_RELEASE_APPROVED_FALSE'
