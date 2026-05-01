# ============================================================
#  send_email.ps1 - Helper gui email qua Resend API
# ============================================================

$RESEND_API_KEY = $env:RESEND_API_KEY
if (-not $RESEND_API_KEY) {
    Write-Host "[WARNING] RESEND_API_KEY is not set in environment variables!" -ForegroundColor Yellow
}
$RESEND_FROM    = "Quyet Hoang <onboarding@resend.dev>"

function Send-ResendEmail {
    param([string]$To, [string]$Subject, [string]$Html)

    if (-not $To -or $To -notmatch "@") {
        Write-Host "[EMAIL] Bo qua - khong co email: $To" -ForegroundColor DarkGray
        return $false
    }
    try {
        $bodyObj = [ordered]@{ from = $RESEND_FROM; to = @($To); subject = $Subject; html = $Html }
        $bodyJson = $bodyObj | ConvertTo-Json -Depth 3
        $response = Invoke-RestMethod `
            -Uri "https://api.resend.com/emails" `
            -Method POST `
            -Headers @{ Authorization = "Bearer $RESEND_API_KEY"; "Content-Type" = "application/json" } `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($bodyJson))
        Write-Host "[EMAIL] OK -> $To | $Subject | ID:$($response.id)" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[EMAIL] Loi: $_" -ForegroundColor Red
        return $false
    }
}

# Shared header/footer HTML snippets (no special chars)
function Get-EmailHeader { return '<html><head><meta charset="UTF-8"/></head><body style="margin:0;padding:0;background:#f0ede8;font-family:Arial,sans-serif;"><div style="max-width:560px;margin:40px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);"><div style="background:#1a1a1a;padding:28px 40px;text-align:center;"><p style="color:#b8963e;font-size:11px;letter-spacing:3px;text-transform:uppercase;margin:0 0 4px;">QUYET HOANG</p><p style="color:rgba(255,255,255,0.4);font-size:11px;margin:0;">Personal Style Consultant</p></div><div style="padding:38px;">' }
function Get-EmailFooter { return '</div><div style="background:#f8f7f5;padding:18px 40px;text-align:center;border-top:1px solid #e8e0d0;"><p style="font-size:12px;color:#aaa;margin:0;">2026 Quyet Hoang - quyetsinh.com</p></div></div></body></html>' }
function Get-BtnHtml { param([string]$Url,[string]$Text) return '<div style="text-align:center;margin:28px 0;"><a href="' + $Url + '" style="background:#1a1a1a;color:#fff;padding:14px 38px;border-radius:6px;text-decoration:none;font-weight:700;font-size:15px;display:inline-block;">' + $Text + '</a></div>' }
function Get-Row { param([string]$T) return '<p style="color:#555;line-height:1.8;font-size:15px;">' + $T + '</p>' }

# ── EMAIL 1: WELCOME ────────────────────────────────────────
function Get-Email1-Welcome {
    param([string]$Name)
    $subj = "Nay $Name - tai lieu cua ban day!"
    $h = Get-EmailHeader
    $h += '<p style="font-size:18px;font-weight:700;color:#1a1a1a;margin-bottom:4px;">Nay ' + $Name + ' &#128075;</p>'
    $h += Get-Row 'Tai lieu <strong>7 Cong Thuc Phoi Do Di Lam</strong> cua ban da san sang. Bam vao link ben duoi de xem ngay - khong can tai ve, khong can app gi them.'
    $h += Get-BtnHtml 'https://www.quyetsinh.com/leadmagnet' '&#128073; Xem Tai Lieu Ngay'
    $h += Get-Row 'That ra, file nay chi la buoc dau. Toi se gui them cho ban mot vai thu thiet thuc hon trong vai ngay toi - khong phai spam, ma la thu toi nghi anh em can biet.'
    $h += '<p style="color:#555;font-size:15px;margin-top:18px;">- Quyet</p>'
    $h += Get-EmailFooter
    return @{ subject = $subj; html = $h }
}

# ── EMAIL 2: NURTURE ────────────────────────────────────────
function Get-Email2-Nurture {
    param([string]$Name)
    $subj = "Loi nay 90% anh em dang mac phai"
    $h = Get-EmailHeader
    $h += '<p style="font-size:17px;font-weight:700;color:#1a1a1a;margin-bottom:18px;">' + $Name + ','
    $h += Get-Row 'Van de nam o cho nay: hau het anh em <strong>mua do theo cam xuc</strong>, khong theo chien luoc.'
    $h += Get-Row 'Ket qua: tu day ma sang nao cung khong biet mac gi. Co 30 cai ao nhung chi mac di mac lai 5 cai.'
    $h += '<div style="background:#f8f7f5;border-left:3px solid #b8963e;padding:14px 18px;margin:18px 0;border-radius:0 8px 8px 0;">'
    $h += '<p style="color:#1a1a1a;font-weight:700;margin:0 0 6px;">Quy tac 80/20 cho tu do</p>'
    $h += '<p style="color:#555;font-size:14px;margin:0;line-height:1.7;">80% lan mac cua ban den tu 20% so do ban co. Cot loi la: tim ra 20% do roi mua them nhung thu phoi duoc voi 20% do, thay vi mua theo mood.</p></div>'
    $h += Get-Row 'Don gian thoi - nhung 95% khong lam vi chua biet 20% do la gi voi tu do cua minh.'
    $h += Get-Row 'Ngay mai toi se gui cho ban thu giai quyet dung van de nay.'
    $h += '<p style="color:#555;font-size:15px;margin-top:22px;">- Quyet</p>'
    $h += Get-EmailFooter
    return @{ subject = $subj; html = $h }
}

# ── EMAIL 3: OFFER ──────────────────────────────────────────
function Get-Email3-Offer {
    param([string]$Name)
    $subj = "Cai danh sach 20 items toi dang noi toi"
    $h = Get-EmailHeader
    $h += '<p style="font-size:17px;font-weight:700;color:#1a1a1a;margin-bottom:18px;">' + $Name + ','
    $h += Get-Row 'Toi da lam san cai danh sach do cho ban roi.'
    $h += Get-Row '<strong>Capsule Wardrobe Starter Kit</strong> - 20 items cot loi xay nen tang tu do nam:'
    $h += '<ul style="color:#555;font-size:15px;line-height:2;padding-left:18px;margin:12px 0;">'
    $h += '<li>20 items cu the - danh dau cai nao can mua truoc</li>'
    $h += '<li>50+ cong thuc phoi tu 20 items do</li>'
    $h += '<li>Goi y thuong hieu 3 tam ngan sach</li>'
    $h += '<li>Checklist in ra tick tay duoc</li></ul>'
    $h += Get-Row 'Khong phai toi dang ban phong cach cho ban. Toi dang ban cho ban <strong>he thong de khong can suy nghi nua</strong>.'
    $h += '<div style="background:#f8f7f5;border:1px solid #e8e0d0;border-radius:8px;padding:18px;margin:22px 0;text-align:center;">'
    $h += '<p style="color:#1a1a1a;font-weight:700;font-size:22px;margin:0 0 4px;">199.000d</p>'
    $h += '<p style="color:#aaa;font-size:13px;text-decoration:line-through;margin:0 0 14px;">500.000d</p>'
    $h += '<a href="https://www.quyetsinh.com/product-1" style="background:#b8963e;color:#111;padding:14px 38px;border-radius:6px;text-decoration:none;font-weight:800;font-size:15px;display:inline-block;">Toi Muon Bo Kit Nay</a>'
    $h += '<p style="font-size:12px;color:#aaa;margin-top:10px;">Thanh toan an toan qua SePay - Nhan file ngay sau khi xac nhan</p></div>'
    $h += '<p style="color:#888;font-size:13px;font-style:italic;">Neu ban chua san sang mua ngay - khong sao ca. Cu giu tai lieu mien phi lai dung truoc. Toi van o day khi ban can.</p>'
    $h += '<p style="color:#555;font-size:15px;margin-top:22px;">- Quyet</p>'
    $h += Get-EmailFooter
    return @{ subject = $subj; html = $h }
}

# ── EMAIL 4: ORDER CONFIRM ───────────────────────────────────
function Get-Email-OrderConfirm {
    param([string]$Name, [string]$ProductName, [string]$Amount, [string]$OrderCode)
    $amtFmt = try { "{0:N0}" -f [double]$Amount } catch { $Amount }
    $subj = "Xac nhan don hang #$OrderCode - Cam on $Name!"
    $h  = '<html><head><meta charset="UTF-8"/></head><body style="margin:0;padding:0;background:#f0ede8;font-family:Arial,sans-serif;">'
    $h += '<div style="max-width:560px;margin:40px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);">'
    $h += '<div style="background:#1a1a1a;padding:28px 40px;text-align:center;">'
    $h += '<p style="color:#b8963e;font-size:11px;letter-spacing:3px;text-transform:uppercase;margin:0 0 4px;">QUYET HOANG</p>'
    $h += '<div style="font-size:38px;margin:8px 0;">&#9989;</div>'
    $h += '<p style="color:white;font-size:18px;font-weight:700;margin:0;">Da nhan duoc thanh toan!</p></div>'
    $h += '<div style="padding:38px;">'
    $h += '<p style="font-size:17px;font-weight:700;color:#1a1a1a;margin-bottom:18px;">Cam on ' + $Name + '!</p>'
    $h += '<div style="background:#f8f7f5;border:1px solid #e8e0d0;border-radius:8px;padding:18px;margin:18px 0;">'
    $h += '<p style="font-size:11px;color:#999;text-transform:uppercase;letter-spacing:1px;margin:0 0 10px;">Chi tiet don hang</p>'
    $h += '<table style="width:100%;border-collapse:collapse;">'
    $h += '<tr><td style="color:#555;font-size:14px;padding:4px 0;">Ma don</td><td style="color:#1a1a1a;font-weight:700;font-family:monospace;text-align:right;">#' + $OrderCode + '</td></tr>'
    $h += '<tr><td style="color:#555;font-size:14px;padding:4px 0;">San pham</td><td style="color:#1a1a1a;font-weight:600;text-align:right;font-size:14px;">' + $ProductName + '</td></tr>'
    $h += '<tr><td style="color:#555;font-size:14px;padding:4px 0;">So tien</td><td style="color:#b8963e;font-weight:800;font-size:18px;text-align:right;">' + $amtFmt + 'd</td></tr>'
    $h += '</table></div>'
    $h += '<p style="color:#1a1a1a;font-weight:700;font-size:15px;margin-bottom:8px;">Buoc tiep theo:</p>'
    $h += '<p style="color:#555;line-height:1.8;font-size:15px;">Toi se gui file tai lieu qua <strong>Zalo</strong> cho ban trong vong <strong>5-15 phut</strong>. Neu sau 30 phut chua nhan duoc, nhan tin Zalo cho toi nhe.</p>'
    $h += '<p style="color:#555;font-size:15px;margin-top:22px;">- Quyet</p>'
    $h += '</div><div style="background:#f8f7f5;padding:18px 40px;text-align:center;border-top:1px solid #e8e0d0;">'
    $h += '<p style="font-size:12px;color:#aaa;margin:0;">2026 Quyet Hoang - quyetsinh.com</p>'
    $h += '</div></div></body></html>'
    return @{ subject = $subj; html = $h }
}
