$DbPath = Join-Path $PSScriptRoot "brain.db"
$NugetDir = Join-Path $PSScriptRoot ".nuget"

$DllPath  = Get-ChildItem "$NugetDir" -Recurse -Filter "Microsoft.Data.Sqlite.dll" `
            | Where-Object { $_.FullName -match "net6|net5|netstandard2" } `
            | Select-Object -First 1 -ExpandProperty FullName

Add-Type -Path $DllPath

$NativeDll = Get-ChildItem "$NugetDir" -Recurse -Filter "e_sqlite3.dll" `
             | Where-Object { $_.FullName -match "win-x64|x64" } `
             | Select-Object -First 1 -ExpandProperty FullName
if ($NativeDll) {
    [System.Runtime.InteropServices.NativeLibrary]::Load($NativeDll) | Out-Null
}

$conn = [Microsoft.Data.Sqlite.SqliteConnection]::new("Data Source=$DbPath")
$conn.Open()

foreach ($table in @("products", "customers", "orders")) {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT * FROM $table"
    
    try {
        $reader = $cmd.ExecuteReader()
        Write-Host "--- Bảng $table ---" -ForegroundColor Yellow
        $hasRows = $false
        while ($reader.Read()) {
            $hasRows = $true
            $row = @()
            for ($i=0; $i -lt $reader.FieldCount; $i++) {
                $val = $reader.GetValue($i)
                $row += "$val"
            }
            Write-Host "  $($row -join ' | ')"
        }
        if (-not $hasRows) {
            Write-Host "  (Bảng trống)"
        }
        $reader.Close()
    } catch {
        Write-Host "Lỗi khi đọc bảng $table : $_" -ForegroundColor Red
    }
}
$conn.Close()
