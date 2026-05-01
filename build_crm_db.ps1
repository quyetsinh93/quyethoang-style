# ============================================================
#  build_crm_db.ps1 — Thêm 3 bảng CRM vào brain.db
#  Dùng Microsoft.Data.Sqlite (có sẵn trong .NET 6+)
# ============================================================

$DbPath = Join-Path $PSScriptRoot "brain.db"
$JsonFile = Join-Path $PSScriptRoot "waitlist.json"
$Now    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# ── Tải Microsoft.Data.Sqlite từ thư mục my-brain nếu có, hoặc tải lại ──────────
$NugetDir = Join-Path (Split-Path $PSScriptRoot) ".nuget"
if (-not (Test-Path $NugetDir)) {
    $NugetDir = Join-Path $PSScriptRoot ".nuget"
}

$DllPath  = Get-ChildItem "$NugetDir" -Recurse -Filter "Microsoft.Data.Sqlite.dll" `
            -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

if (-not $DllPath) {
    Write-Host "⬇  Đang tải Microsoft.Data.Sqlite..." -ForegroundColor Cyan

    $NugetExe = Join-Path $env:TEMP "nuget.exe"
    if (-not (Test-Path $NugetExe)) {
        Invoke-WebRequest "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" `
            -OutFile $NugetExe -UseBasicParsing
    }

    & $NugetExe install Microsoft.Data.Sqlite.Core `
        -OutputDirectory $NugetDir -NonInteractive -Verbosity quiet

    & $NugetExe install SQLitePCLRaw.bundle_e_sqlite3 `
        -OutputDirectory $NugetDir -NonInteractive -Verbosity quiet

    $DllPath = Get-ChildItem "$NugetDir" -Recurse -Filter "Microsoft.Data.Sqlite.dll" `
               | Where-Object { $_.FullName -match "net6|net5|netstandard2" } `
               | Select-Object -First 1 -ExpandProperty FullName
}

Add-Type -Path $DllPath

$NativeDll = Get-ChildItem "$NugetDir" -Recurse -Filter "e_sqlite3.dll" `
             | Where-Object { $_.FullName -match "win-x64|x64" } `
             | Select-Object -First 1 -ExpandProperty FullName
if ($NativeDll) {
    [System.Runtime.InteropServices.NativeLibrary]::Load($NativeDll) | Out-Null
}

$conn = [Microsoft.Data.Sqlite.SqliteConnection]::new("Data Source=$DbPath")
$conn.Open()

function Exec($sql) {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.ExecuteNonQuery() | Out-Null
}

# ── 1. Tạo 3 bảng: products, customers, orders ──────────────────

$ddl = @"
CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    price REAL NOT NULL,
    description TEXT,
    stock_quantity INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT UNIQUE NOT NULL,
    zalo TEXT,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL,
    FOREIGN KEY(customer_id) REFERENCES customers(id),
    FOREIGN KEY(product_id) REFERENCES products(id)
);
"@
foreach ($stmt in ($ddl -split ';' | Where-Object { $_.Trim() })) { Exec $stmt }

Write-Host "Vừa tạo xong/kiểm tra 3 bảng: products, customers, orders." -ForegroundColor Green

# ── 2. Import dữ liệu từ waitlist.json vào customers ─────────────

if (Test-Path $JsonFile) {
    $WaitlistData = Get-Content $JsonFile | ConvertFrom-Json
    $CountImported = 0
    foreach ($item in $WaitlistData) {
        $cName = $item.name
        $cPhone = $item.phone
        $cZalo =  $item.zalo
        $cDate = $item.registration_date

        # Kiểm tra trùng lập qua SĐT
        $chkCmd = $conn.CreateCommand()
        $chkCmd.CommandText = "SELECT COUNT(1) FROM customers WHERE phone = @p"
        $chkCmd.Parameters.AddWithValue("@p", $cPhone) | Out-Null
        $exists = [int]$chkCmd.ExecuteScalar()

        if ($exists -eq 0) {
            $insCmd = $conn.CreateCommand()
            $insCmd.CommandText = "INSERT INTO customers (name, phone, zalo, created_at) VALUES (@n, @p, @z, @c)"
            $insCmd.Parameters.AddWithValue("@n", $cName) | Out-Null
            $insCmd.Parameters.AddWithValue("@p", $cPhone) | Out-Null
            $insCmd.Parameters.AddWithValue("@z", $cZalo) | Out-Null
            $insCmd.Parameters.AddWithValue("@c", $cDate) | Out-Null
            $insCmd.ExecuteNonQuery() | Out-Null
            $CountImported++
        }
    }
    Write-Host "Đã import thành công $CountImported khách hàng từ waitlist.json (tránh trùng lặp)." -ForegroundColor Cyan
} else {
    Write-Host "Không tìm thấy file waitlist.json để import." -ForegroundColor Yellow
}

# Thêm vài product mẫu
$prodCheckCmd = $conn.CreateCommand()
$prodCheckCmd.CommandText = "SELECT COUNT(1) FROM products"
$prodCount = [int]$prodCheckCmd.ExecuteScalar()
if ($prodCount -eq 0) {
    Exec "INSERT INTO products (name, price, description, stock_quantity) VALUES ('Style Audit Online', 299000, 'Tư vấn chấm điểm style qua video', 100)"
    Exec "INSERT INTO products (name, price, description, stock_quantity) VALUES ('Capsule Wardrobe Template', 99000, 'Tài liệu danh sách 20 items cốt lõi của phái mạnh', 999)"
}

# ── 3. Hiển thị dữ liệu 3 bảng ──────────────────────────────────
Write-Host "`nĐọc dữ liệu trong các bảng hiện tại:" -ForegroundColor Magenta
foreach ($table in @("products", "customers", "orders")) {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT * FROM $table LIMIT 5"
    $r = $cmd.ExecuteReader()
    
    Write-Host "--- Bảng $table ---" -ForegroundColor Yellow
    while ($r.Read()) {
        $row = @()
        for ($i=0; $i -lt $r.FieldCount; $i++) {
            $val = $r.GetValue($i)
            $row += "$val"
        }
        Write-Host "  $($row -join ' | ')"
    }
    $r.Close()
}

$conn.Close()
Write-Host "`nHoàn thành!" -ForegroundColor Green
