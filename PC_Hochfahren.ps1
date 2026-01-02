# Fritz!Box Zugangsdaten
$IP = "fritz.box"
$FBUID = "scripts"           # Benutzername
$SECRET = "XXXXXXXXX"      # Passwort

# Gerätedetails für Wake-on-LAN
$DeviceName = "PC"
$DeviceIP = "192.168.178.21"
$DeviceInterfaceID = "landevice4983"  # Ersetze durch die tatsächliche Interface-ID des Geräts

# Herausforderung (Challenge) abrufen
$challengeResponse = Invoke-WebRequest -Uri http://$IP/login_sid.lua -UseBasicParsing
$challenge = ($challengeResponse.Content -match "<Challenge>(.*?)</Challenge>") | Out-Null
$challenge = $matches[1]

# Challenge und Passwort verbinden
$CPSTR = "$challenge-$SECRET"

# MD5-Hash berechnen
$utf16Bytes = [System.Text.Encoding]::GetEncoding("UTF-16LE").GetBytes($CPSTR)
$md5 = [System.Security.Cryptography.MD5]::Create().ComputeHash($utf16Bytes)
$md5Hex = -join ($md5 | ForEach-Object { $_.ToString("x2") })

# Antwort generieren
$response = "$challenge-$md5Hex"

# Login-Parameter erstellen
$urlParams = "username=$FBUID&response=$response"

# Session-ID (SID) abrufen
$sidResponse = Invoke-WebRequest -Uri http://$IP/login_sid.lua?$urlParams -UseBasicParsing
$sid = ($sidResponse.Content -match "<SID>(.*?)</SID>") | Out-Null
$sid = $matches[1]

# Prüfen, ob Login erfolgreich war
if ($sid -eq "0000000000000000") {
    Write-Host "Login fehlgeschlagen! Bitte überprüfe Benutzername und Passwort." -ForegroundColor Red
    exit
}

Write-Host "Erfolgreich bei der Fritz!Box angemeldet. SID: $sid" -ForegroundColor Green

# Wake-on-LAN ausführen
$wolBody = @{
    xhr               = 1
    dev_name          = $DeviceName
    internetdetail    = "unlimited"
    allow_pcp_and_upnp = "off"
    dev_ip0           = ($DeviceIP -split "\.")[0]
    dev_ip1           = ($DeviceIP -split "\.")[1]
    dev_ip2           = ($DeviceIP -split "\.")[2]
    dev_ip3           = ($DeviceIP -split "\.")[3]
    dev_ip            = $DeviceIP
    static_dhcp       = "on"
    interface_id1     = "e186"
    interface_id2     = "8a25"
    interface_id3     = "e591"
    interface_id4     = "a364"
    auto_wakeup       = "on"
    back_to_page      = "netDev"
    dev               = $DeviceInterfaceID
    btn_wake          = ""
    sid               = $sid
    lang              = "de"
    page              = "edit_device"
}

$wolResponse = Invoke-WebRequest -Uri http://$IP/data.lua -Method POST -Body $wolBody -ContentType "application/x-www-form-urlencoded" -UseBasicParsing

if ($wolResponse.StatusCode -eq 200) {
    Write-Host "Magic Packet erfolgreich gesendet!" -ForegroundColor Green
} else {
    Write-Host "Fehler beim Senden des Magic Packets. Statuscode: $($wolResponse.StatusCode)" -ForegroundColor Red
}
