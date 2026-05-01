# ============================================================
#  server.ps1 — Backend API & Static File Server bằng PowerShell
# ============================================================

# Load .env file if it exists
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object { $_ -match '=' -and $_ -notmatch '^\s*#' } | ForEach-Object {
        $name, $value = $_.Split('=', 2)
        [Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim())
    }
}

$port = if ($env:PORT) { [int]$env:PORT } else { 8081 }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")

try {
    $listener.Start()
} catch {
    Write-Host "Lỗi: Không thể khởi chạy Server trên cổng $port. Thử chạy PowerShell quyền Admin hoặc thay đổi cổng." -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  Admin Server đang chạy thành công!" -ForegroundColor Green
Write-Host "  Landing   : http://localhost:$port/" -ForegroundColor Yellow
Write-Host "  LeadMagnet: http://localhost:$port/leadmagnet" -ForegroundColor Yellow
Write-Host "  Product-1 : http://localhost:$port/product-1" -ForegroundColor Yellow
Write-Host "  Admin     : http://localhost:$port/admin" -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "Nhấn Ctrl+C để dừng server."


$db = if ($env:DB_PATH) { $env:DB_PATH } else { Join-Path $PSScriptRoot "brain.db" }
$sqlite = if ($IsLinux) { "sqlite3" } else { Join-Path $PSScriptRoot "sqlite3.exe" }

# Load email helper (dot-source)
. (Join-Path $PSScriptRoot "send_email.ps1")
Write-Host "[EMAIL] Resend email helper da san sang" -ForegroundColor Cyan

# ─── Email Scheduler (delayed send via background job) ───────
function Schedule-Email {
    param([int]$DelaySeconds, [string]$To, [string]$Subject, [string]$Html)
    $block = {
        param($sec, $to, $subj, $html, $apiKey, $fromAddr)
        Start-Sleep -Seconds $sec
        try {
            $body = @{ from = $fromAddr; to = @($to); subject = $subj; html = $html } | ConvertTo-Json -Depth 3
            Invoke-RestMethod -Uri "https://api.resend.com/emails" -Method POST `
                -Headers @{ Authorization = "Bearer $apiKey"; "Content-Type" = "application/json" } `
                -Body $body | Out-Null
        } catch {}
    }
    Start-Job -ScriptBlock $block -ArgumentList $DelaySeconds, $To, $Subject, $Html, $RESEND_API_KEY, $RESEND_FROM | Out-Null
}

function ExecQuery($query) {
    # Chạy sqlite3 CLI để lấy kết quả dạng JSON
    # Cách DML (INSERT/UPDATE) nếu gọi -json sẽ không có kết quả, vẫn an toàn.
    $tempSql = Join-Path $env:TEMP "$([guid]::NewGuid()).sql"
    Set-Content -Path $tempSql -Value $query -Encoding UTF8
    
    $out = & $sqlite $db -json ".read `"$tempSql`""
    Remove-Item $tempSql -ErrorAction SilentlyContinue

    if (-not $out -or $out.Trim() -eq "") { return "[]" }
    return ($out -join "`n")
}

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $req = $context.Request
    $res = $context.Response
    
    # CORS Headers
    $res.Headers.Add("Access-Control-Allow-Origin", "*")
    $res.Headers.Add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    $res.Headers.Add("Access-Control-Allow-Headers", "Content-Type")

    if ($req.HttpMethod -eq "OPTIONS") {
        $res.StatusCode = 200
        $res.Close()
        continue
    }

    $path = $req.Url.LocalPath
    $method = $req.HttpMethod
    
    # === API ROUTING ===
    if ($path.StartsWith("/api/")) {
        $res.ContentType = "application/json; charset=utf-8"
        try {
            if ($path -eq "/api/products" -and $method -eq "GET") {
                $json = ExecQuery "SELECT * FROM products ORDER BY id ASC;"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.OutputStream.Write($buffer, 0, $buffer.Length)

            } elseif ($path -eq "/api/customers" -and $method -eq "GET") {
                $json = ExecQuery "SELECT * FROM customers ORDER BY id DESC;"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.OutputStream.Write($buffer, 0, $buffer.Length)

            } elseif ($path -eq "/api/orders" -and $method -eq "GET") {
                $q = @"
SELECT orders.*, products.name as product_name, customers.name as customer_name 
FROM orders 
LEFT JOIN products ON orders.product_id = products.id 
LEFT JOIN customers ON orders.customer_id = customers.id 
ORDER BY orders.id DESC;
"@
                $json = ExecQuery $q
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.OutputStream.Write($buffer, 0, $buffer.Length)

            } elseif ($path -eq "/api/orders" -and $method -eq "POST") {
                $reader = New-Object System.IO.StreamReader($req.InputStream)
                $body = $reader.ReadToEnd() | ConvertFrom-Json
                
                $custId = [int]$body.customer_id
                $prodId = [int]$body.product_id
                $amt = [double]$body.amount
                $now = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                
                # Tự động trừ kho (Chỉ thực hiện trong Transaction để đảm bảo toàn vẹn)
                $tx = @"
BEGIN TRANSACTION;
INSERT INTO orders (customer_id, product_id, amount, status, created_at) VALUES ($custId, $prodId, $amt, 'pending', '$now');
UPDATE products SET stock_quantity = stock_quantity - 1 WHERE id = $prodId;
COMMIT;
"@
                ExecQuery $tx | Out-Null
                $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"success":true}')
                $res.OutputStream.Write($buffer, 0, $buffer.Length)

            } elseif ($path -match "^/api/orders/(\d+)/success$") {
                $orderId = $matches[1]
                ExecQuery "UPDATE orders SET status = 'success' WHERE id = $orderId;" | Out-Null

                # Gửi email xác nhận đơn hàng
                $oInfoJson = ExecQuery "SELECT o.order_code, o.amount, p.name as pname, c.email, c.name as cname FROM orders o LEFT JOIN products p ON o.product_id=p.id LEFT JOIN customers c ON o.customer_id=c.id WHERE o.id=$orderId LIMIT 1;"
                $oInfo = $oInfoJson | ConvertFrom-Json
                if ($oInfo -and $oInfo.Count -gt 0 -and $oInfo[0].email) {
                    $oc = if ($oInfo[0].order_code) { $oInfo[0].order_code } else { "#$orderId" }
                    $destEmail = $oInfo[0].email -replace '\+test', ''
                    $eConf = Get-Email-OrderConfirm -Name $oInfo[0].cname -ProductName $oInfo[0].pname -Amount $oInfo[0].amount -OrderCode $oc
                    Send-ResendEmail -To $destEmail -Subject $eConf.subject -Html $eConf.html | Out-Null
                }

                $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"success":true}')
                $res.OutputStream.Write($buffer, 0, $buffer.Length)

            } elseif ($path -eq "/api/leads" -and $method -eq "POST") {
                $reader2 = New-Object System.IO.StreamReader($req.InputStream)
                $leadBody = $reader2.ReadToEnd() | ConvertFrom-Json
                $lName  = ($leadBody.name  -replace "'","''")
                $lPhone = ($leadBody.phone -replace "'","''")
                $lEmail = ($leadBody.email -replace "'","''")
                $now2   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

                # Thêm nếu chưa có (dùng email hoặc phone làm unique key)
                $existCheck = ExecQuery "SELECT id FROM customers WHERE email = '$lEmail' OR phone = '$lPhone' LIMIT 1;"
                $existParsed = $existCheck | ConvertFrom-Json
                if (-not $existParsed -or $existParsed.Count -eq 0) {
                    ExecQuery "INSERT INTO customers (name, phone, email, zalo, created_at) VALUES ('$lName', '$lPhone', '$lEmail', '', '$now2');" | Out-Null
                    Write-Host "[LEAD] Khach moi: $lName | $lEmail | $lPhone" -ForegroundColor Green
                } else {
                    # Cập nhật email nếu đã có nhưng chưa có email
                    ExecQuery "UPDATE customers SET email = '$lEmail', name = '$lName' WHERE (email = '$lEmail' OR phone = '$lPhone') AND (email IS NULL OR email = '');" | Out-Null
                    Write-Host "[LEAD] Cap nhat: $lName | $lEmail" -ForegroundColor Yellow
                }

                $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"success":true}')
                $res.OutputStream.Write($buffer, 0, $buffer.Length)

                # ── Gửi email sequence nếu là khách mới ──
                if ($lEmail -and (-not $existParsed -or $existParsed.Count -eq 0)) {
                    # Phát hiện chế độ +test: gửi cả 3 email ngay lập tức
                    $isTest = $lEmail -match '\+test'
                    
                    # Fix cho Resend Trial: Bo qua phan +test de gui ve mail chinh chu
                    $sendTo = $lEmail
                    if ($isTest) {
                        $sendTo = $lEmail -replace '\+test', ''
                    }

                    # Email 1: Ngay lập tức
                    $e1 = Get-Email1-Welcome -Name $lName
                    Send-ResendEmail -To $sendTo -Subject $e1.subject -Html $e1.html | Out-Null

                    if ($isTest) {
                        Write-Host "[EMAIL] Che do +test: gui ca 3 email ngay cho $sendTo" -ForegroundColor Magenta
                        $e2 = Get-Email2-Nurture -Name $lName
                        $e3 = Get-Email3-Offer   -Name $lName
                        Send-ResendEmail -To $sendTo -Subject $e2.subject -Html $e2.html | Out-Null
                        Send-ResendEmail -To $sendTo -Subject $e3.subject -Html $e3.html | Out-Null
                    } else {
                        # Email 2: 2 ngày sau (172800s)
                        $e2 = Get-Email2-Nurture -Name $lName
                        Schedule-Email -DelaySeconds 172800 -To $sendTo -Subject $e2.subject -Html $e2.html
                        # Email 3: 3 ngày sau (259200s)
                        $e3 = Get-Email3-Offer   -Name $lName
                        Schedule-Email -DelaySeconds 259200 -To $sendTo -Subject $e3.subject -Html $e3.html
                        Write-Host "[EMAIL] Da len lich Email 2 (2 ngay) va Email 3 (3 ngay) cho $sendTo" -ForegroundColor Yellow
                    }
                }

            } elseif ($path -eq "/api/product-orders" -and $method -eq "POST") {
                # Tạo đơn hàng khi user bấm "Tạo QR" từ trang product-1
                $reader = New-Object System.IO.StreamReader($req.InputStream)
                $body   = $reader.ReadToEnd() | ConvertFrom-Json

                $oName   = ($body.name  -replace "'","''")
                $oPhone  = ($body.phone -replace "'","''")
                $oProd   = [int]$body.product_id
                $oAmt    = [double]$body.amount
                $oCode   = "DH" + (Get-Date).ToString("ddHHmmss") + (Get-Random -Maximum 999)
                $now     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

                # 1. Thêm/bỏ qua khách hàng
                ExecQuery "INSERT OR IGNORE INTO customers (name, phone, zalo, created_at) VALUES ('$oName', '$oPhone', '', '$now');" | Out-Null

                # 2. Lấy customer_id
                $custJson = ExecQuery "SELECT id FROM customers WHERE phone = '$oPhone' LIMIT 1;"
                $custId   = ($custJson | ConvertFrom-Json)[0].id

                # 3. Tạo đơn hàng với order_code, status=pending
                # Thêm cột order_code nếu chưa có (idempotent)
                ExecQuery "ALTER TABLE orders ADD COLUMN order_code TEXT;" | Out-Null
                $tx = @"
INSERT INTO orders (customer_id, product_id, amount, status, order_code, created_at)
VALUES ($custId, $oProd, $oAmt, 'pending', '$oCode', '$now');
UPDATE products SET stock_quantity = stock_quantity - 1 WHERE id = $oProd;
"@
                ExecQuery $tx | Out-Null

                # 4. Trả về order_id và order_code để frontend dùng
                $newOrderJson = ExecQuery "SELECT id FROM orders WHERE order_code = '$oCode' LIMIT 1;"
                $newOrderId   = ($newOrderJson | ConvertFrom-Json)[0].id

                $result = "{`"success`":true,`"order_id`":$newOrderId,`"order_code`":`"$oCode`"}"
                Write-Host "[ORDER] Tao don $oCode - Khach: $oName ($oPhone)" -ForegroundColor Green
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($result)
                $res.OutputStream.Write($buffer, 0, $buffer.Length)

            } elseif ($path -match "^/api/orders/check/(.+)$" -and $method -eq "GET") {
                # Frontend polling: kiểm tra trạng thái đơn theo order_code
                $checkCode  = $matches[1]
                $statusJson = ExecQuery "SELECT id, status FROM orders WHERE order_code = '$checkCode' LIMIT 1;"
                $parsed     = $statusJson | ConvertFrom-Json

                if ($parsed -and $parsed.Count -gt 0) {
                    $st     = $parsed[0].status
                    $oid    = $parsed[0].id
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes("{`"order_id`":$oid,`"status`":`"$st`"}")
                } else {
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes("{`"status`":`"not_found`"}")
                }
                $res.OutputStream.Write($buffer, 0, $buffer.Length)

            } elseif ($path -eq "/api/sepay-webhook" -and $method -eq "POST") {
                # ─── SePay Webhook ───────────────────────────────────────
                # SePay POST JSON: { content, transferAmount, transferType, ... }
                $reader  = New-Object System.IO.StreamReader($req.InputStream)
                $payload = $reader.ReadToEnd()
                Write-Host "[WEBHOOK] Nhan du lieu: $payload" -ForegroundColor Cyan

                try {
                    $spData = $payload | ConvertFrom-Json
                    $content = $spData.content       # VD: "0901234567 DH21091234"
                    $txType  = $spData.transferType  # "in" = tien vao
                    $txAmt   = $spData.transferAmount

                    if ($txType -eq "in" -and $content -match "(DH\d+)") {
                        $matchedCode = $matches[1]
                        ExecQuery "UPDATE orders SET status = 'success' WHERE order_code = '$matchedCode' AND status = 'pending';" | Out-Null
                        Write-Host "[WEBHOOK] Xac nhan thanh toan thanh cong: $matchedCode | $txAmt VND" -ForegroundColor Green

                        # Gửi email xác nhận qua webhook
                        $wInfoJson = ExecQuery "SELECT o.order_code, o.amount, p.name as pname, c.email, c.name as cname FROM orders o LEFT JOIN products p ON o.product_id=p.id LEFT JOIN customers c ON o.customer_id=c.id WHERE o.order_code='$matchedCode' LIMIT 1;"
                        $wInfo = $wInfoJson | ConvertFrom-Json
                        if ($wInfo -and $wInfo.Count -gt 0 -and $wInfo[0].email) {
                            $destWebEmail = $wInfo[0].email -replace '\+test', ''
                            $eConf = Get-Email-OrderConfirm -Name $wInfo[0].cname -ProductName $wInfo[0].pname -Amount $wInfo[0].amount -OrderCode $matchedCode
                            Send-ResendEmail -To $destWebEmail -Subject $eConf.subject -Html $eConf.html | Out-Null
                        }
                    }
                } catch {
                    Write-Host "[WEBHOOK] Loi xu ly: $_" -ForegroundColor Red
                }
                # SePay yêu cầu response 200 OK
                $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":1}')
                $res.OutputStream.Write($buffer, 0, $buffer.Length)

            } else {
                $res.StatusCode = 404
            }

        } catch {
            Write-Host "Lỗi API: $_" -ForegroundColor Red
            $res.StatusCode = 500
            $err = [System.Text.Encoding]::UTF8.GetBytes("{`"error`":`"$($_.Exception.Message)`"}")
            $res.OutputStream.Write($err, 0, $err.Length)
        }
    } 
    # === STATIC FILE SERVING ===
    else {
        # Xử lý đường dẫn
        $localFile = $path
        # Route clean URLs to index.html files
        $routeMap = @{
            "/"            = "\index.html"
            "/admin"       = "\admin\index.html"
            "/admin/"      = "\admin\index.html"
            "/leadmagnet"  = "\leadmagnet\index.html"
            "/leadmagnet/" = "\leadmagnet\index.html"
            "/product-1"   = "\product-1\index.html"
            "/product-1/"  = "\product-1\index.html"
            "/test-pay"    = "\test-pay\index.html"
            "/test-pay/"   = "\test-pay\index.html"
        }
        if ($routeMap.ContainsKey($localFile)) {
            $localFile = $routeMap[$localFile]
        }

        # Normalize to physical path (replace / with \)
        $fullPath = Join-Path $PSScriptRoot $localFile.Replace("/", "\")

        if (Test-Path $fullPath) {
            # Content Type
            if ($fullPath.EndsWith(".html")) { $res.ContentType = "text/html; charset=utf-8" }
            elseif ($fullPath.EndsWith(".css")) { $res.ContentType = "text/css" }
            elseif ($fullPath.EndsWith(".js")) { $res.ContentType = "application/javascript" }
            elseif ($fullPath.EndsWith(".png")) { $res.ContentType = "image/png" }

            try {
                $buffer = [System.IO.File]::ReadAllBytes($fullPath)
                $res.OutputStream.Write($buffer, 0, $buffer.Length)
            } catch {
                $res.StatusCode = 500
            }
        } else {
            $res.StatusCode = 404
            Write-Host "404 Not Found: $path" -ForegroundColor DarkGray
        }
    }

    $res.Close()
}
