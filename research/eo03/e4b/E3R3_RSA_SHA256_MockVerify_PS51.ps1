# EO03 E3-R3. Windows PowerShell 5.1 .NET Framework RSA verification, research only.
# This mock public key and test vectors are GPT-generated and NOT independent approval.
# NO ZIP extraction, NO trading data, NO production runner, NO release authority.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$publicModulus = 'yAN1ZwcjakH4Af7ILl3VwC5oeI0fUHcykNAvWIszxmSdKJCcudUvStjyl2/OriwVK0YWRuFMRk5P/G4iEDb0OlT9Dgf91xh4cMsf2mGGD4lRix8ebDMClthI/yJYkr/gSCciiSl8AbUUV3wZMxrJNkOCN7Z8a8dOUf/csVSR7cIjIp4O/E5FHL3YnyzfBcbu5YbeKTP0xpR9hdhcESA5kqiQdgf+4hzSXw2VNjOhsJ5FkFvataUsTsWWXKf9XqBkikZq4bNqz2pAk2Q5aQrdYs3MXy+TYKwt+GwbwtgUVcVrcvObIMbNvjJQJaqYLEX2w7W4GNWl0XujyEAW+kK0Iw=='
$signature = 'vIZ27dzRVS2vLXBeM2BoQ2i6f4gDXPHGCvCRic4hmxs7pAkrKr8Drh4BeiTQ8vi/Ocx/jzbwa0vucJbn1NqtIB4nlxxeAUr5Db+pvonmRe3udiaZvC2ZsRceTNh1ryWqoSfRVGc+AGEWPJlx37vac8ZX0E08s9SCzHwCSiIgC4sTe2mmntqt6aT5otZ5j5R4PQsX2+VYcPQ7dH5oITX4+ToKU+IUSdp9Yjdf4HGMDsYmCJ7WpUaPV3lQ3oooAX3/bWYcm4GbaTgNIcy7qVbWjp1AQTvzI7WBsw9x+jbdtuqqoY+yLmkAUOSQcI5TtEYba+b5ifHUwRmgUwvWu+8HPA=='
$statement = 'EO03-MOCK-RSA-v1|artifact_sha256=8186c14ade3ae1ed29874625ad30cb551f0a2ded98c2d53dd30e4a2460142289|run_id=EO03-E3R3-PS51|purpose=RESEARCH_VERIFY_ONLY'
$artifact = 'EO03_E3_R3_SYNTHETIC_ARTIFACT_BYTES_ONLY_NOT_EXECUTABLE'
if ($PSVersionTable.PSVersion.ToString() -notlike '5.1*') { throw 'NOT_WINDOWS_PS51' }
$bytes = [System.Text.Encoding]::ASCII.GetBytes($artifact)
$sha = [System.Security.Cryptography.SHA256]::Create()
try { $actualDigest = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
$expectedDigest='8186c14ade3ae1ed29874625ad30cb551f0a2ded98c2d53dd30e4a2460142289'
if ($actualDigest -cne $expectedDigest) { throw 'ARTIFACT_DIGEST_FIXTURE_INVALID' }
$xml = '<RSAKeyValue><Modulus>' + $publicModulus + '</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'
$csp = [System.Security.Cryptography.CspParameters]::new(24)
$rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new($csp)
try {
  $rsa.FromXmlString($xml)
  $original = [System.Text.Encoding]::ASCII.GetBytes($statement)
  $sigBytes = [Convert]::FromBase64String($signature)
  $ok = $rsa.VerifyData($original, [System.Security.Cryptography.CryptoConfig]::MapNameToOID('SHA256'), $sigBytes)
  if (-not $ok) { throw 'POSITIVE_RSA_SHA256_MOCK_VERIFY_FAILED' }
  Write-Output 'E3R3_RSA_PS51_MOCK_POSITIVE_PASS'
  $tamperedClaim = [System.Text.Encoding]::ASCII.GetBytes($statement.Replace('EO03-E3R3-PS51', 'EO03-OTHER-RUN'))
  if ($rsa.VerifyData($tamperedClaim,[System.Security.Cryptography.CryptoConfig]::MapNameToOID('SHA256'),$sigBytes)) { throw 'TAMPERED_RUN_CLAIM_WAS_ACCEPTED' }
  Write-Output 'E3R3_RSA_PS51_WRONG_RUN_BLOCK_PASS'
  $badSignature = [byte[]]$sigBytes.Clone()
  $badSignature[0] = $badSignature[0] -bxor 1
  if ($rsa.VerifyData($original,[System.Security.Cryptography.CryptoConfig]::MapNameToOID('SHA256'),$badSignature)) { throw 'TAMPERED_SIGNATURE_WAS_ACCEPTED' }
  Write-Output 'E3R3_RSA_PS51_WRONG_SIGNATURE_BLOCK_PASS'
  $wrongArtifact = [System.Text.Encoding]::ASCII.GetBytes($artifact + '_CHANGED')
  $actualOther = $null
  $h2 = [System.Security.Cryptography.SHA256]::Create()
  try {$actualOther = ([BitConverter]::ToString($h2.ComputeHash($wrongArtifact))).Replace('-','').ToLowerInvariant()} finally {$h2.Dispose()}
  if ($actualOther -ceq $expectedDigest) { throw 'TAMPERED_ARTIFACT_DIGEST_EQUAL' }
  Write-Output 'E3R3_RSA_PS51_WRONG_ARTIFACT_BLOCK_PASS'
} finally { $rsa.Dispose() }
Write-Output 'E3R3_RSA_PS51_4_OF_4_MOCK_BOUNDARY_CHECKS_PASS_RELEASE_APPROVED_FALSE'
