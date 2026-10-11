```powershell
$ErrorActionPreference = "Continue"
$Log = Join-Path $PSScriptRoot "KralTesisat.log"

function Log-Yaz($Mesaj) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Mesaj" |
        Add-Content -Path $Log -Encoding UTF8
}

function Baslik {
    Clear-Host
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "       KRAL TESISAT - BAKIM" -ForegroundColor Yellow
    Write-Host "====================================" -ForegroundColor Cyan
}

function Disk-Bilgisi {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
        Select-Object DeviceID,
            @{N="Toplam GB";E={[math]::Round($_.Size / 1GB, 1)}},
            @{N="Bos GB";E={[math]::Round($_.FreeSpace / 1GB, 1)}} |
        Format-Table -AutoSize
}

function Gecici-Dosya-Tarama {
    $Klasorler = @($env:TEMP, "$env:WINDIR\Temp")
    foreach ($Klasor in ($Klasorler | Select-Object -Unique)) {
        if (Test-Path $Klasor) {
            $Dosyalar = Get-ChildItem -LiteralPath $Klasor -Force -ErrorAction SilentlyContinue
            $Boyut = ($Dosyalar | ForEach-Object {
                if (-not $_.PSIsContainer) { $_.Length }
                else {
                    (Get-ChildItem -LiteralPath $_.FullName -File -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object Length -Sum).Sum
                }
            } | Measure-Object -Sum).Sum

            [pscustomobject]@{
                Klasor = $Klasor
                "Yaklasik Boyut (MB)" = [math]::Round(($Boyut / 1MB), 2)
            }
        }
    }
}

function Gecici-Dosya-Temizle {
    Write-Host "Yalnizca gecici dosya klasorleri hedeflenecek." -ForegroundColor Yellow
    Gecici-Dosya-Tarama | Format-Table -AutoSize
    $Onay = Read-Host "Gecici dosyalari silmek istiyor musun? E/H"

    if ($Onay -notin @("E", "e", "EVET", "evet")) {
        Write-Host "Iptal edildi." -ForegroundColor Yellow
        return
    }

    foreach ($Klasor in @($env:TEMP, "$env:WINDIR\Temp" | Select-Object -Unique)) {
        if (Test-Path $Klasor) {
            Get-ChildItem -LiteralPath $Klasor -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Log-Yaz "Gecici dosya temizligi denendi."
    Write-Host "Temizlik tamamlandi. Kullanimdaki bazi dosyalar silinmemis olabilir." -ForegroundColor Green
}

function Kaynak-Kullanimi {
    Write-Host "`nEn cok RAM kullanan islemler:" -ForegroundColor Cyan
    Get-Process -ErrorAction SilentlyContinue |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 10 ProcessName,
            @{N="RAM (MB)";E={[math]::Round($_.WorkingSet64 / 1MB, 1)}} |
        Format-Table -AutoSize

    Write-Host "`nCPU ve bellek durumu:" -ForegroundColor Cyan
    Get-CimInstance Win32_OperatingSystem |
        Select-Object @{N="Toplam RAM (GB)";E={[math]::Round($_.TotalVisibleMemorySize / 1MB, 2)}},
            @{N="Bos RAM (GB)";E={[math]::Round($_.FreePhysicalMemory / 1MB, 2)}} |
        Format-Table -AutoSize
}

function Baslangic-Listesi {
    Write-Host "Baslangicta calisabilen kayitlar (yalnizca listeleme):" -ForegroundColor Cyan
    $Yollar = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
    )
    foreach ($Yol in $Yollar) {
        if (Test-Path $Yol) {
            Write-Host "`n$Yol"
            Get-ItemProperty -Path $Yol |
                Select-Object * -ExcludeProperty PS* |
                Format-List
        }
    }
}

while ($true) {
    Baslik
    Write-Host "1. Gecici dosyalari tara (silmez)"
    Write-Host "2. Gecici dosyalari temizle"
    Write-Host "3. Disk bos alanini goster"
    Write-Host "4. RAM kullanimini kontrol et"
    Write-Host "5. Baslangic kayitlarini listele"
    Write-Host "6. Gorev Yoneticisini ac"
    Write-Host "0. Geri cik"
    $Secim = Read-Host "`nSecimin"

    switch ($Secim) {
        "1" { Gecici-Dosya-Tarama | Format-Table -AutoSize; Read-Host "Devam etmek icin Enter" }
        "2" { Gecici-Dosya-Temizle; Read-Host "Devam etmek icin Enter" }
        "3" { Disk-Bilgisi; Read-Host "Devam etmek icin Enter" }
        "4" { Kaynak-Kullanimi; Read-Host "Devam etmek icin Enter" }
        "5" { Baslangic-Listesi; Read-Host "Devam etmek icin Enter" }
        "6" { Start-Process taskmgr.exe }
        "0" { break }
        default { Write-Host "Gecersiz secim."; Start-Sleep -Seconds 1 }
    }

    if ($Secim -eq "0") { break }
}
```