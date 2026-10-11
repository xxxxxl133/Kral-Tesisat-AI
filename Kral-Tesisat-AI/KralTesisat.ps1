```powershell
# KRAL TESISAT - BAKIM MERKEZI
# Guvenlik: Kullanicidan onay almadan dosya silmez.

$ErrorActionPreference = "SilentlyContinue"
$Log = Join-Path $PSScriptRoot "KralTesisat.log"

function LogYaz([string]$Mesaj) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $Mesaj" |
        Add-Content -LiteralPath $Log -Encoding UTF8
}

function Bekle {
    Read-Host "`nDevam etmek icin Enter'a bas"
}

function Baslik {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       KRAL TESISAT - BAKIM MERKEZI" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
}

function OnayAl([string]$Mesaj) {
    $cevap = Read-Host "$Mesaj (E/H)"
    return $cevap -match '^(E|EVET)$'
}

function DiskBilgisi {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
        Select-Object DeviceID,
            @{N="Toplam GB";E={[math]::Round($_.Size / 1GB, 2)}},
            @{N="Bos GB";E={[math]::Round($_.FreeSpace / 1GB, 2)}},
            @{N="Dolu %";E={
                if ($_.Size -gt 0) {
                    [math]::Round((1 - $_.FreeSpace / $_.Size) * 100, 1)
                } else { 0 }
            }} |
        Format-Table -AutoSize
}

function GeciciDosyaTara {
    $klasorler = @(
        $env:TEMP,
        "$env:WINDIR\Temp"
    ) | Select-Object -Unique

    foreach ($klasor in $klasorler) {
        if (-not (Test-Path -LiteralPath $klasor)) { continue }

        $toplam = 0
        $adet = 0

        Get-ChildItem -LiteralPath $klasor -File -Recurse -Force |
            ForEach-Object {
                $toplam += $_.Length
                $adet++
            }

        [pscustomobject]@{
            Klasor = $klasor
            "Dosya sayisi" = $adet
            "Boyut MB" = [math]::Round($toplam / 1MB, 2)
        }
    }
}

function GeciciDosyaTemizle {
    Write-Host "`nGecici dosyalar taraniyor..." -ForegroundColor Cyan
    GeciciDosyaTara | Format-Table -AutoSize

    Write-Host "Not: Kullanimdaki bazi dosyalar silinemeyebilir." -ForegroundColor Yellow

    if (-not (OnayAl "Bu gecici klasorlerdeki dosyalari silmek istiyor musun?")) {
        Write-Host "Iptal edildi."
        return
    }

    $klasorler = @($env:TEMP, "$env:WINDIR\Temp") | Select-Object -Unique
    foreach ($klasor in $klasorler) {
        if (Test-Path -LiteralPath $klasor) {
            Get-ChildItem -LiteralPath $klasor -Force |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    LogYaz "Gecici dosya temizligi denendi."
    Write-Host "Islem bitti. Silinemeyen dosyalar kalmis olabilir." -ForegroundColor Green
}

function KisayolTara {
    $klasorler = @(
        [Environment]::GetFolderPath("Desktop"),
        [Environment]::GetFolderPath("CommonDesktopDirectory"),
        [Environment]::GetFolderPath("Programs"),
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
        Select-Object -Unique

    $wsh = New-Object -ComObject WScript.Shell
    $sonuclar = @()

    foreach ($klasor in $klasorler) {
        Get-ChildItem -LiteralPath $klasor -Filter "*.lnk" -File -Recurse |
            ForEach-Object {
                try {
                    $kisayol = $wsh.CreateShortcut($_.FullName)
                    $hedef = $kisayol.TargetPath

                    if ([string]::IsNullOrWhiteSpace($hedef) -or
                        -not (Test-Path -LiteralPath $hedef)) {
                        $sonuclar += [pscustomobject]@{
                            Kisayol = $_.FullName
                            Hedef = $hedef
                        }
                    }
                } catch {}
            }
    }

    if ($sonuclar.Count -eq 0) {
        Write-Host "Hedefi bulunamayan kisayol tespit edilmedi." -ForegroundColor Green
        return
    }

    Write-Host "`nHedefi bulunamayan kisayollar:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $sonuclar.Count; $i++) {
        Write-Host "$($i + 1). $($sonuclar[$i].Kisayol)"
        Write-Host "   Hedef: $($sonuclar[$i].Hedef)"
    }

    Write-Host "`nBu kontrol bazen ag kisayollarini veya tasinmis uygulamalari da supheli gosterebilir."
    Write-Host "Yalnizca secilen .lnk kisayol dosyasi silinir; uygulama kaldirilmaz."

    if (-not (OnayAl "Listeden secerek kisayol silmek istiyor musun?")) {
        Write-Host "Silme iptal edildi."
        return
    }

    $numara = Read-Host "Silinecek numara (tumunu silmek icin T, iptal icin 0)"
    if ($numara -eq "0") { return }

    if ($numara -eq "T" -or $numara -eq "t") {
        if (-not (OnayAl "Listelenen kisayollarin TAMAMINI silmek istiyor musun?")) {
            return
        }
        foreach ($kayit in $sonuclar) {
            Remove-Item -LiteralPath $kayit.Kisayol -Force -ErrorAction SilentlyContinue
        }
        LogYaz "Supheli kisayol listesindeki kisayollarin silinmesi istendi."
        Write-Host "Islem tamamlandi; silinemeyenler kalmis olabilir."
        return
    }

    $secilen = 0
    if ([int]::TryParse($numara, [ref]$secilen) -and
        $secilen -ge 1 -and $secilen -le $sonuclar.Count) {
        $kayit = $sonuclar[$secilen - 1]
        if (OnayAl "'$($kayit.Kisayol)' kisayolu silinsin mi?") {
            Remove-Item -LiteralPath $kayit.Kisayol -Force
            LogYaz "Kisayol silme istendi: $($kayit.Kisayol)"
            Write-Host "Kisayol silme islemi tamamlandi."
        }
    } else {
        Write-Host "Gecersiz secim."
    }
}

function KaynakKontrol {
    Write-Host "`nEn cok RAM kullanan 10 islem:" -ForegroundColor Cyan
    Get-Process |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 10 ProcessName,
            @{N="RAM MB";E={[math]::Round($_.WorkingSet64 / 1MB, 1)}} |
        Format-Table -AutoSize

    Write-Host "`nBellek bilgisi:" -ForegroundColor Cyan
    Get-CimInstance Win32_OperatingSystem |
        Select-Object @{N="Toplam RAM GB";E={[math]::Round($_.TotalVisibleMemorySize / 1MB, 2)}},
            @{N="Bos RAM GB";E={[math]::Round($_.FreePhysicalMemory / 1MB, 2)}} |
        Format-Table -AutoSize
}

function BaslangicListele {
    $yollar = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach ($yol in $yollar) {
        if (Test-Path $yol) {
            Write-Host "`n$yol" -ForegroundColor Cyan
            Get-ItemProperty $yol |
                Select-Object * -ExcludeProperty PS* |
                Format-List
        }
    }
    Write-Host "Bu bolum yalnizca listeler; kayitlari degistirmez."
}

while ($true) {
    Baslik
    Write-Host "1. Gecici dosyalari tara (silmez)"
    Write-Host "2. Gecici dosyalari temizle (onayli)"
    Write-Host "3. Bozuk / hedefi olmayan kisayollari tara"
    Write-Host "4. Disk bos alanini goster"
    Write-Host "5. RAM kullanimini kontrol et"
    Write-Host "6. Baslangic uygulamalarini listele"
    Write-Host "7. Gorev Yoneticisini ac"
    Write-Host "8. Windows depolama ayarlarini ac"
    Write-Host "0. Cikis"

    $secim = Read-Host "`nSecimin"

    switch ($secim) {
        "1" { GeciciDosyaTara | Format-Table -AutoSize; Bekle }
        "2" { GeciciDosyaTemizle; Bekle }
        "3" { KisayolTara; Bekle }
        "4" { DiskBilgisi; Bekle }
        "5" { KaynakKontrol; Bekle }
        "6" { BaslangicListele; Bekle }
        "7" { Start-Process taskmgr.exe }
        "8" { Start-Process "ms-settings:storagesense" }
        "0" { break }
        default { Write-Host "Gecersiz secim."; Start-Sleep -Seconds 1 }
    }

    if ($secim -eq "0") { break }
}
```