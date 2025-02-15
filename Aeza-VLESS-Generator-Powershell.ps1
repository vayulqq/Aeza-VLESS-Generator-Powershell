$OutputEncoding = [System.Text.Encoding]::UTF8
$AEZA_API_ENDPOINT = "https://api.aeza-security.net/v2"
$USER_AGENT = "Dart/3.5 (dart:io)"
$IPINFO_API_ENDPOINT = "https://ipinfo.io"
$TRANSLATIONS = @{
    'en' = @{
        'welcome' = '👋 Welcome to the VLESS Config Generator!'
        'email_choice' = '👤 Select the authorization method:'
        'enter_email' = '✉️ Please enter your email address:'
        'invalid_email' = '❌ Invalid email format. Please try again.'
        'email_not_found' = '❌ Email not found. Please try again.'
        'enter_code' = '🔑 Please enter the confirmation code sent to your email:'
        'invalid_code' = '❌ Invalid code. Please try again.'
        'select_location' = '🌍 Please select a location for your VLESS config:'
        'generating' = '⚙️ Generating your VLESS configuration...'
        'success' = '✅ Your VLESS configuration is ready! Use the config below:'
        'error' = '❌ An error occurred. Please try again.'
        'own_email' = '📝 Use My Own Email'
        'random_location' = '🎲 Random Location'
        'cancelled' = '❌ Operation cancelled.'
        'country_detected' = '🌍 Detected country: {0}. Using English language.'
        'exit_option' = '❌ Exit'
        'enter_choice' = 'Enter your choice'
        'copied_to_clipboard' = '✅ VLESS key copied to clipboard!'
        'copy_failed' = '❌ Failed to copy to clipboard. Please copy the key manually.'
    }
    'ru' = @{
        'welcome' = '👋 Добро пожаловать в генератор VLESS конфигураций!'
        'email_choice' = '👤 Выберите способ авторизации:'
        'enter_email' = '✉️ Пожалуйста, введите ваш email адрес:'
        'invalid_email' = '❌ Неверный формат email. Попробуйте снова.'
        'email_not_found' = '❌ Email не найден. Попробуйте снова.'
        'enter_code' = '🔑 Пожалуйста, введите код подтверждения, отправленный на вашу почту:'
        'invalid_code' = '❌ Неверный код. Попробуйте снова.'
        'select_location' = '🌍 Пожалуйста, выберите локацию для вашего VLESS конфига:'
        'generating' = '⚙️ Генерация VLESS конфигурации...'
        'success' = '✅ Ваша VLESS конфигурация готова! Используйте конфиг ниже:'
        'error' = '❌ Произошла ошибка. Пожалуйста, попробуйте снова.'
        'own_email' = '📝 Использовать свою почту'
        'random_location' = '🎲 Случайная локация'
        'cancelled' = '❌ Операция отменена.'
        'country_detected' = '🌍 Определена страна: {0}. Используется русский язык.'
        'exit_option' = '❌ Выйти'
        'enter_choice' = 'Введите ваш выбор'
        'copied_to_clipboard' = '✅ VLESS ключ скопирован в буфер обмена!'
        'copy_failed' = '❌ Не удалось скопировать в буфер обмена. Скопируйте ключ вручную.'
    }
}

class UserData {
    [string]$email
    [string]$device_id
    [string]$api_token
    [string]$language
}

function Get-Country {
    try {
        $response = Invoke-WebRequest -Uri "$IPINFO_API_ENDPOINT/country" -UseBasicParsing
        return $response.Content.Trim()
    } catch {
        Write-Host ($TRANSLATIONS['en']['error'])
        return "US"
    }
}

function Get-Language {
    $country = Get-Country
    if ($country -eq "RU") {
        Write-Host ($TRANSLATIONS['ru']['country_detected'] -f "Russia")
        return 'ru'
    } else {
        Write-Host ($TRANSLATIONS['en']['country_detected'] -f $country)
        return 'en'
    }
}

function Make-Request {
    param (
        [string]$Method,
        [string]$Url,
        [hashtable]$Headers = @{},
        [string]$Body = $null
    )
    $Headers['User-Agent'] = $USER_AGENT
    $Headers['Content-Type'] = 'application/json'

    try {
        if ($Method -in @('POST', 'PUT', 'PATCH') -and $Body) {
            $response = Invoke-WebRequest -Method $Method -Uri $Url -Headers $Headers -Body $Body -UseBasicParsing
        } else {
            $response = Invoke-WebRequest -Method $Method -Uri $Url -Headers $Headers -UseBasicParsing
        }

        if ($response.StatusCode -ne 200) {
            throw "Request failed with status $($response.StatusCode)"
        }
        return $response.Content | ConvertFrom-Json
    } catch {
        Write-Host $TRANSLATIONS[$userData.language]['error']
        throw
    }
}

function Send-ConfirmationCode {
    param (
        [string]$Email
    )
    $body = @{email = $Email} | ConvertTo-Json
    Make-Request -Method 'POST' -Url "$AEZA_API_ENDPOINT/auth" -Body $body
}

function Get-FreeLocations {
    $response = Make-Request -Method 'GET' -Url "$AEZA_API_ENDPOINT/locations"
    return $response.response.PSObject.Properties | Where-Object { $_.Value.free -eq $true } | ForEach-Object { $_.Name.ToUpper() }
}

function Generate-DeviceId {
    return -join ((65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
}

function Email-Choice {
    param (
        [string]$Language
    )
    Write-Host $TRANSLATIONS[$Language]['email_choice']
    Write-Host "1. $($TRANSLATIONS[$Language]['own_email'])"
    Write-Host "0. $($TRANSLATIONS[$Language]['exit_option'])"
    $choice = Read-Host $TRANSLATIONS[$Language]['enter_choice']
    return $choice
}

function Email-Input {
    param (
        [string]$Language
    )
    $email = Read-Host $TRANSLATIONS[$Language]['enter_email']
    if (-not ($email -match "^[^@]+@[^@]+\.[^@]+$")) {
        Write-Host $TRANSLATIONS[$Language]['invalid_email']
        return Email-Input $Language
    }
    return $email
}

function Code-Input {
    param (
        [string]$Language
    )
    $code = Read-Host $TRANSLATIONS[$Language]['enter_code']
    return $code
}

function Location-Choice {
    param (
        [string]$Language,
        [string[]]$Locations
    )
    Write-Host $TRANSLATIONS[$Language]['select_location']
    for ($i = 0; $i -lt $Locations.Length; $i++) {
        Write-Host "$($i + 1). $($Locations[$i])"
    }
    Write-Host "$($Locations.Length + 1). $($TRANSLATIONS[$Language]['random_location'])"
    $choice = Read-Host "Enter your choice"
    if ($choice -eq ($Locations.Length + 1)) {
        return 'random'
    }
    return $Locations[$choice - 1]
}

function Copy-ToClipboard {
    param (
        [string]$Text
    )
    try {
        $Text | Set-Clipboard
        Write-Host $TRANSLATIONS[$userData.language]['copied_to_clipboard']
    } catch {
        Write-Host $TRANSLATIONS[$userData.language]['copy_failed']
    }
}

function Main {
    $userData = [UserData]::new()
    $userData.language = Get-Language

    Write-Host $TRANSLATIONS[$userData.language]['welcome']

    $choice = Email-Choice $userData.language
    if ($choice -eq '0') {
        Write-Host $TRANSLATIONS[$userData.language]['cancelled']
        exit
    } elseif ($choice -eq '1') {
        $userData.email = Email-Input $userData.language
    } else {
        Write-Host $TRANSLATIONS[$userData.language]['cancelled']
        exit
    }

    try {
        Send-ConfirmationCode $userData.email
        while ($true) {
            $code = Code-Input $userData.language
            $userData.device_id = Generate-DeviceId
            try {
                $response = Make-Request -Method 'POST' -Url "$AEZA_API_ENDPOINT/auth-confirm" -Body (@{email = $userData.email; code = $code} | ConvertTo-Json) -Headers @{"Device-Id" = $userData.device_id}
                $userData.api_token = $response.response.token
                break
            } catch {
                Write-Host $TRANSLATIONS[$userData.language]['invalid_code']
            }
        }

        $locations = Get-FreeLocations
        $location = Location-Choice $userData.language $locations
        if ($location -eq 'random') {
            $location = $locations | Get-Random
        }

        $response = Make-Request -Method 'POST' -Url "$AEZA_API_ENDPOINT/vpn/connect" -Body (@{location = $location.ToLower()} | ConvertTo-Json) -Headers @{"Device-Id" = $userData.device_id; "Aeza-Token" = $userData.api_token}
        $vlessKey = $response.response.accessKey
        Write-Host $TRANSLATIONS[$userData.language]['success']
        Write-Host $vlessKey
        Copy-ToClipboard -Text $vlessKey
    } catch {
        Write-Host $TRANSLATIONS[$userData.language]['error']
    }
}

Main
