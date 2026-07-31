# ============================================================
#  Build-Exe.ps1  —  STUDIO IO
#  Compila EstraiP7M.ps1 in un eseguibile standalone (EstraiP7M.exe)
#  usando il modulo ps2exe. Da eseguire dopo ogni modifica allo script,
#  aggiornando -version in coerenza con CHANGELOG.md.
# ============================================================

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
}

Invoke-PS2EXE `
    -inputFile   "$PSScriptRoot\EstraiP7M.ps1" `
    -outputFile  "$PSScriptRoot\EstraiP7M.exe" `
    -noConsole `
    -STA `
    -DPIAware `
    -title       "Estrai P7M" `
    -description "Estrazione payload da buste CMS/PKCS#7 (.p7m)" `
    -company     "Studio IO" `
    -product     "EstraiP7M" `
    -version     "1.2.0.0"
