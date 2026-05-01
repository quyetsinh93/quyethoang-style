. .\send_email.ps1
$e = Get-Email1-Welcome -Name "Test"
$result = Send-ResendEmail -To "delivered@resend.dev" -Subject $e.subject -Html $e.html
Write-Host "Send result: $result"
