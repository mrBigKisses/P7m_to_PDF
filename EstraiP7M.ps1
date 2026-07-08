# ============================================================
#  EstraiP7M.ps1  —  STUDIO IO
#  Estrae file PDF (o qualsiasi payload) da buste .p7m
#  Supporta file singolo, cartella, ricorsione sottocartelle
#  Output sempre in sottocartella _PDF accanto all'originale
#
#  Richiede Windows PowerShell 5.1 (.NET Framework): il tipo
#  SignedCms non e' disponibile nell'assembly System.Security
#  sotto PowerShell 7+ (pwsh). Avviare con powershell.exe.
# ============================================================
param(
    [Parameter(Position = 0)]
    [string]$Path
)

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    Add-Type -AssemblyName System.Security -ErrorAction Stop
}
catch {
    Write-Error "Impossibile caricare gli assembly richiesti: $($_.Exception.Message)"
    exit 1
}

if (-not ("System.Security.Cryptography.Pkcs.SignedCms" -as [type])) {
    [System.Windows.Forms.MessageBox]::Show(
        "Questo script richiede Windows PowerShell 5.1 (.NET Framework).`n`n" + `
        "Il tipo SignedCms non e' disponibile nell'assembly System.Security quando " + `
        "eseguito con PowerShell 7+ (pwsh). Avviare lo script con powershell.exe.",
        "Ambiente non supportato",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

[System.Windows.Forms.Application]::EnableVisualStyles()

# ─────────────────────────────────────────────
#  PALETTE & COSTANTI LAYOUT
# ─────────────────────────────────────────────
$clrBg        = [System.Drawing.Color]::FromArgb(245, 245, 243)
$clrPanel     = [System.Drawing.Color]::FromArgb(255, 255, 255)
$clrBorder    = [System.Drawing.Color]::FromArgb(210, 210, 205)
$clrAccent    = [System.Drawing.Color]::FromArgb( 30,  30,  28)
$clrAccentSub = [System.Drawing.Color]::FromArgb( 90,  90,  85)
$clrBtn       = [System.Drawing.Color]::FromArgb( 30,  30,  28)
$clrBtnHover  = [System.Drawing.Color]::FromArgb( 55,  55,  50)
$clrBtnText   = [System.Drawing.Color]::FromArgb(255, 255, 255)
$clrGreen     = [System.Drawing.Color]::FromArgb( 40, 167,  69)
$clrRed       = [System.Drawing.Color]::FromArgb(180,  40,  40)
$clrLogBg     = [System.Drawing.Color]::FromArgb( 22,  22,  20)
$clrLogText   = [System.Drawing.Color]::FromArgb(180, 210, 170)
$clrLogErr    = [System.Drawing.Color]::FromArgb(255, 100,  80)
$clrLogMuted  = [System.Drawing.Color]::FromArgb(100, 110,  95)
$clrBrand     = [System.Drawing.Color]::FromArgb(160, 160, 155)

$fmW   = 780
$fmH   = 620
$mL    = 24   # margine sinistro
$mR    = 24   # margine destro
$mT    = 20   # margine top sezioni

$fntUI   = New-Object System.Drawing.Font("Segoe UI", 9)
$fntSm   = New-Object System.Drawing.Font("Segoe UI", 7.5)
$fntMono = New-Object System.Drawing.Font("Consolas", 8)
$fntH1   = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
$fntBrand1 = New-Object System.Drawing.Font("Segoe UI", 7)

# "Century Gothic" non e' un font di sistema Windows (richiede Office/CorelDraw):
# se assente si ripiega su Segoe UI per non degradare silenziosamente il branding.
function Test-FontInstalled([string]$familyName) {
    $collection = New-Object System.Drawing.Text.InstalledFontCollection
    return [bool]($collection.Families | Where-Object { $_.Name -eq $familyName })
}
$brandFontName = if (Test-FontInstalled "Century Gothic") { "Century Gothic" } else { "Segoe UI" }
$fntBrand2 = New-Object System.Drawing.Font($brandFontName, 7, [System.Drawing.FontStyle]::Bold)

# ─────────────────────────────────────────────
#  FORM PRINCIPALE
# ─────────────────────────────────────────────
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Estrai P7M"
$form.Size            = New-Object System.Drawing.Size($fmW, $fmH)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false
$form.MinimizeBox     = $true
$form.BackColor       = $clrBg
$form.Font            = $fntUI

# ─────────────────────────────────────────────
#  HEADER STRIP
# ─────────────────────────────────────────────
$header = New-Object System.Windows.Forms.Panel
$header.Size      = New-Object System.Drawing.Size($form.ClientSize.Width, 52)
$header.Location  = New-Object System.Drawing.Point(0, 0)
$header.BackColor = $clrAccent
$form.Controls.Add($header)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "ESTRAI P7M"
$lblTitle.Font      = New-Object System.Drawing.Font($brandFontName, 13, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$lblTitle.AutoSize  = $true
$lblTitle.Location  = New-Object System.Drawing.Point($mL, 14)
$header.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text      = "Estrazione payload da buste CMS/PKCS#7"
$lblSub.Font      = New-Object System.Drawing.Font("Segoe UI", 7.5)
$lblSub.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 155)
$lblSub.AutoSize  = $true
# posizionato dopo il titolo (calcolato dopo AutoSize)
$form.Add_Shown({
    $lblSub.Location = New-Object System.Drawing.Point(($lblTitle.Right + 16), 20)
})
$header.Controls.Add($lblSub)

# ─────────────────────────────────────────────
#  HELPER: crea Label sezione
# ─────────────────────────────────────────────
function New-SectionLabel($text, $x, $y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text      = $text.ToUpper()
    $l.Font      = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
    $l.ForeColor = $clrAccentSub
    $l.AutoSize  = $true
    $l.Location  = New-Object System.Drawing.Point($x, $y)
    return $l
}

# ─────────────────────────────────────────────
#  HELPER: crea pulsante primario
# ─────────────────────────────────────────────
function New-PrimaryButton($text, $x, $y, $w, $h) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text      = $text
    $b.Size      = New-Object System.Drawing.Size($w, $h)
    $b.Location  = New-Object System.Drawing.Point($x, $y)
    $b.BackColor = $clrBtn
    $b.ForeColor = $clrBtnText
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderSize  = 0
    $b.FlatAppearance.MouseOverBackColor = $clrBtnHover
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $b.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5)
    return $b
}

function New-SecondaryButton($text, $x, $y, $w, $h) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text      = $text
    $b.Size      = New-Object System.Drawing.Size($w, $h)
    $b.Location  = New-Object System.Drawing.Point($x, $y)
    $b.BackColor = $clrPanel
    $b.ForeColor = $clrAccent
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderColor = $clrBorder
    $b.FlatAppearance.BorderSize  = 1
    $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(235,235,230)
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $b.Font      = $fntUI
    return $b
}

# ─────────────────────────────────────────────
#  SEZIONE 1 — SORGENTE
# ─────────────────────────────────────────────
$yS = 70

$form.Controls.Add((New-SectionLabel "Sorgente" $mL $yS))

# Modalità: file singolo / cartella
$rbFile = New-Object System.Windows.Forms.RadioButton
$rbFile.Text     = "File singolo (.p7m)"
$rbFile.Font     = $fntUI
$rbFile.Location = New-Object System.Drawing.Point($mL, ($yS + 18))
$rbFile.AutoSize = $true
$rbFile.Checked  = $true
$form.Controls.Add($rbFile)

$rbFolder = New-Object System.Windows.Forms.RadioButton
$rbFolder.Text     = "Cartella"
$rbFolder.Font     = $fntUI
$rbFolder.Location = New-Object System.Drawing.Point(200, ($yS + 18))
$rbFolder.AutoSize = $true
$form.Controls.Add($rbFolder)

# TextBox percorso sorgente
$ctrlW = $form.ClientSize.Width - $mL - $mR - 90
$txtSrc = New-Object System.Windows.Forms.TextBox
$txtSrc.Size       = New-Object System.Drawing.Size($ctrlW, 26)
$txtSrc.Location   = New-Object System.Drawing.Point($mL, ($yS + 44))
$txtSrc.BackColor  = $clrPanel
$txtSrc.BorderStyle = "FixedSingle"
$txtSrc.Font       = $fntUI
$txtSrc.ReadOnly   = $false
$txtSrc.ForeColor  = $clrAccent
$form.Controls.Add($txtSrc)

$btnBrowse = New-SecondaryButton "Sfoglia…" ($txtSrc.Right + 8) ($yS + 44) 74 26
$form.Controls.Add($btnBrowse)

# Checkbox ricorsione (visibile solo in modalità cartella)
$chkRecurse = New-Object System.Windows.Forms.CheckBox
$chkRecurse.Text     = "Includi sottocartelle"
$chkRecurse.Font     = $fntUI
$chkRecurse.Location = New-Object System.Drawing.Point($mL, ($yS + 78))
$chkRecurse.AutoSize = $true
$chkRecurse.Checked  = $false
$chkRecurse.Visible  = $false
$form.Controls.Add($chkRecurse)

# ─────────────────────────────────────────────
#  SEZIONE 2 — OPZIONI OUTPUT
# ─────────────────────────────────────────────
$yO = 170

$form.Controls.Add((New-SectionLabel "Output" $mL $yO))

$lblOutNote = New-Object System.Windows.Forms.Label
$lblOutNote.Text      = "I file estratti vengono salvati nella sottocartella  _PDF  accanto ad ogni .p7m originale."
$lblOutNote.Font      = $fntSm
$lblOutNote.ForeColor = $clrAccentSub
$lblOutNote.AutoSize  = $false
$lblOutNote.Size      = New-Object System.Drawing.Size(($form.ClientSize.Width - $mL - $mR), 32)
$lblOutNote.Location  = New-Object System.Drawing.Point($mL, ($yO + 18))
$form.Controls.Add($lblOutNote)

$chkOverwrite = New-Object System.Windows.Forms.CheckBox
$chkOverwrite.Text     = "Sovrascrivi se il file di destinazione esiste già"
$chkOverwrite.Font     = $fntUI
$chkOverwrite.Location = New-Object System.Drawing.Point($mL, ($yO + 50))
$chkOverwrite.AutoSize = $true
$chkOverwrite.Checked  = $false
$form.Controls.Add($chkOverwrite)

# ─────────────────────────────────────────────
#  DIVISORE
# ─────────────────────────────────────────────
$sep = New-Object System.Windows.Forms.Panel
$sep.Size      = New-Object System.Drawing.Size(($form.ClientSize.Width - $mL - $mR), 1)
$sep.Location  = New-Object System.Drawing.Point($mL, 240)
$sep.BackColor = $clrBorder
$form.Controls.Add($sep)

# ─────────────────────────────────────────────
#  BARRA AZIONI
# ─────────────────────────────────────────────
$yA = 250

$btnEstrai = New-PrimaryButton "▶  Estrai" $mL $yA 110 32
$form.Controls.Add($btnEstrai)

$btnClear = New-SecondaryButton "Pulisci log" ($btnEstrai.Right + 10) $yA 100 32
$form.Controls.Add($btnClear)

# Contatori  (aggiornati a runtime)
$lblStats = New-Object System.Windows.Forms.Label
$lblStats.Text      = ""
$lblStats.Font      = $fntSm
$lblStats.ForeColor = $clrAccentSub
$lblStats.AutoSize  = $true
$lblStats.Location  = New-Object System.Drawing.Point(($btnClear.Right + 20), ($yA + 8))
$form.Controls.Add($lblStats)

# ─────────────────────────────────────────────
#  LOG CONSOLE
# ─────────────────────────────────────────────
$yL = 292
$logH = $form.ClientSize.Height - $yL - 36

$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Size      = New-Object System.Drawing.Size(($form.ClientSize.Width - $mL - $mR), $logH)
$txtLog.Location  = New-Object System.Drawing.Point($mL, $yL)
$txtLog.BackColor = $clrLogBg
$txtLog.ForeColor = $clrLogText
$txtLog.Font      = $fntMono
$txtLog.ReadOnly  = $true
$txtLog.BorderStyle = "None"
$txtLog.ScrollBars  = "Vertical"
$form.Controls.Add($txtLog)

# ─────────────────────────────────────────────
#  BRAND FOOTER
# ─────────────────────────────────────────────
$lblAnAppBy = New-Object System.Windows.Forms.Label
$lblAnAppBy.Text      = "an app by"
$lblAnAppBy.Font      = $fntBrand1
$lblAnAppBy.ForeColor = $clrBrand
$lblAnAppBy.AutoSize  = $true
$lblAnAppBy.Location  = New-Object System.Drawing.Point($mL, ($form.ClientSize.Height - 22))
$form.Controls.Add($lblAnAppBy)

$lblStudioIO = New-Object System.Windows.Forms.Label
$lblStudioIO.Text      = "STUDIO IO"
$lblStudioIO.Font      = $fntBrand2
$lblStudioIO.ForeColor = $clrBrand
$lblStudioIO.AutoSize  = $true
$form.Add_Shown({
    $lblStudioIO.Location = New-Object System.Drawing.Point(($lblAnAppBy.Right + 4), ($form.ClientSize.Height - 22))
})
$form.Controls.Add($lblStudioIO)

# ─────────────────────────────────────────────
#  FUNZIONI HELPER LOG
# ─────────────────────────────────────────────
function Log-Line($msg, $color = $null) {
    if ($null -eq $color) { $color = $clrLogText }
    $txtLog.SelectionStart  = $txtLog.TextLength
    $txtLog.SelectionLength = 0
    $txtLog.SelectionColor  = $color
    $txtLog.AppendText("$msg`n")
    $txtLog.ScrollToCaret()
}

function Log-Ok($msg)      { Log-Line $msg $clrGreen }
function Log-Err($msg)     { Log-Line $msg $clrLogErr }
function Log-Muted($msg)   { Log-Line $msg $clrLogMuted }
function Log-Header($msg)  { Log-Line $msg ([System.Drawing.Color]::FromArgb(220,220,200)) }

# ─────────────────────────────────────────────
#  HELPER: rileva l'estensione dal contenuto (magic bytes)
#  Usato solo quando il nome del file non ha gia' un'estensione
#  interna (es. "documento.p7m" invece di "fattura.pdf.p7m").
# ─────────────────────────────────────────────
function Get-ContentExtension([byte[]]$bytes) {
    if ($null -eq $bytes -or $bytes.Length -eq 0) { return $null }

    if ($bytes.Length -ge 4 -and $bytes[0] -eq 0x25 -and $bytes[1] -eq 0x50 -and `
        $bytes[2] -eq 0x44 -and $bytes[3] -eq 0x46) { return ".pdf" }              # %PDF

    if ($bytes.Length -ge 4 -and $bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B -and `
        ($bytes[2] -eq 0x03 -or $bytes[2] -eq 0x05 -or $bytes[2] -eq 0x07)) { return ".zip" }  # PK.. (zip/docx/xlsx/odt)

    if ($bytes.Length -ge 8 -and $bytes[0] -eq 0x89 -and $bytes[1] -eq 0x50 -and `
        $bytes[2] -eq 0x4E -and $bytes[3] -eq 0x47) { return ".png" }

    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8 -and $bytes[2] -eq 0xFF) { return ".jpg" }

    $offset = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $offset = 3 }
    $probeLen = [Math]::Min(64, $bytes.Length - $offset)
    if ($probeLen -gt 0) {
        $text = [System.Text.Encoding]::ASCII.GetString($bytes, $offset, $probeLen).TrimStart()
        if ($text.StartsWith("<?xml") -or $text.StartsWith("<")) { return ".xml" }
    }

    return $null
}

# ─────────────────────────────────────────────
#  CORE — ESTRAZIONE SINGOLO FILE
# ─────────────────────────────────────────────
function Extract-SingleP7M {
    param([string]$p7mPath, [bool]$overwrite)

    $dir    = Split-Path $p7mPath -Parent
    $outDir = Join-Path $dir "_PDF"

    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
        Log-Muted "  → Creata cartella: $outDir"
    }

    # rimuove tutte le estensioni .p7m finali (gestisce anche buste firmate due volte,
    # es. fattura.pdf.p7m.p7m), mantenendo l'estensione interna se presente
    $baseName = [System.IO.Path]::GetFileName($p7mPath)
    while ($baseName.ToLowerInvariant().EndsWith(".p7m")) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($baseName)
    }
    $nameHasExt = [System.IO.Path]::GetExtension($baseName) -ne ""

    if ($nameHasExt) {
        $destPath = Join-Path $outDir $baseName
        if ((Test-Path $destPath) -and (-not $overwrite)) {
            Log-Muted "  ⊘ Saltato (esiste): $baseName"
            return @{ status = "skipped" }
        }
    }

    try {
        $payload = [System.IO.File]::ReadAllBytes($p7mPath)

        # Decodifica CMS; segue eventuali buste annidate (doppia firma)
        for ($i = 0; $i -lt 5; $i++) {
            $cms = New-Object System.Security.Cryptography.Pkcs.SignedCms
            $cms.Decode($payload)
            $decoded = $cms.ContentInfo.Content

            if ($null -eq $decoded -or $decoded.Length -eq 0) {
                Log-Err "  ✖ Busta vuota o firma 'detached' (nessun contenuto incorporato): $([System.IO.Path]::GetFileName($p7mPath))"
                return @{ status = "error" }
            }
            $payload = $decoded

            $isNestedCms = $false
            try {
                $peek = New-Object System.Security.Cryptography.Pkcs.SignedCms
                $peek.Decode($payload)
                $isNestedCms = $true
            } catch { }
            if (-not $isNestedCms) { break }
        }

        if (-not $nameHasExt) {
            $ext = Get-ContentExtension $payload
            if ($null -ne $ext) {
                $baseName = "$baseName$ext"
            } else {
                Log-Muted "  ⚠ Estensione non rilevabile dal contenuto, uso '.pdf' come fallback per: $([System.IO.Path]::GetFileName($p7mPath))"
                $baseName = "$baseName.pdf"
            }
            $destPath = Join-Path $outDir $baseName
            if ((Test-Path $destPath) -and (-not $overwrite)) {
                Log-Muted "  ⊘ Saltato (esiste): $baseName"
                return @{ status = "skipped" }
            }
        }

        [System.IO.File]::WriteAllBytes($destPath, $payload)
        Log-Ok  "  ✔ $([System.IO.Path]::GetFileName($p7mPath))  →  _PDF\$baseName"
        return @{ status = "ok" }
    }
    catch {
        Log-Err "  ✖ Errore: $([System.IO.Path]::GetFileName($p7mPath)) — $($_.Exception.Message)"
        return @{ status = "error" }
    }
}

# ─────────────────────────────────────────────
#  HELPER: scansione ricorsiva sicura dei .p7m
#  A differenza di Directory.GetFiles(..., AllDirectories), non
#  interrompe l'intera scansione se una sottocartella nega l'accesso.
# ─────────────────────────────────────────────
function Get-P7mFilesSafe {
    param([string]$folderPath, [bool]$recurse)

    $result = New-Object System.Collections.Generic.List[string]
    $queue  = New-Object System.Collections.Generic.Queue[string]
    $queue.Enqueue($folderPath)

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()

        try {
            foreach ($f in [System.IO.Directory]::GetFiles($current, "*.p7m")) {
                $result.Add($f)
            }
        } catch {
            Log-Err "  ✖ Impossibile leggere la cartella: $current — $($_.Exception.Message)"
        }

        if ($recurse) {
            try {
                foreach ($d in [System.IO.Directory]::GetDirectories($current)) {
                    $queue.Enqueue($d)
                }
            } catch {
                Log-Err "  ✖ Impossibile enumerare le sottocartelle di: $current — $($_.Exception.Message)"
            }
        }
    }

    return $result
}

# ─────────────────────────────────────────────
#  CORE — ESTRAZIONE BATCH (cartella)
# ─────────────────────────────────────────────
function Extract-Folder {
    param([string]$folderPath, [bool]$recurse, [bool]$overwrite)

    $files = Get-P7mFilesSafe -folderPath $folderPath -recurse $recurse

    if ($files.Count -eq 0) {
        Log-Muted "Nessun file .p7m trovato."
        return @{ ok=0; skipped=0; errors=0 }
    }

    $ok=0; $skip=0; $err=0
    foreach ($f in $files) {
        if ($script:cancelRequested) {
            Log-Muted "Operazione annullata dall'utente."
            break
        }
        $res = Extract-SingleP7M -p7mPath $f -overwrite $overwrite
        switch ($res.status) {
            "ok"      { $ok++ }
            "skipped" { $skip++ }
            "error"   { $err++ }
        }
        [System.Windows.Forms.Application]::DoEvents()
    }
    return @{ ok=$ok; skipped=$skip; errors=$err }
}

# ─────────────────────────────────────────────
#  EVENTI UI
# ─────────────────────────────────────────────

# Toggle visibilità checkbox ricorsione
$rbFile.Add_CheckedChanged({
    $chkRecurse.Visible = $rbFolder.Checked
    $txtSrc.Text = ""
})
$rbFolder.Add_CheckedChanged({
    $chkRecurse.Visible = $rbFolder.Checked
    $txtSrc.Text = ""
})

# Sfoglia
$btnBrowse.Add_Click({
    if ($rbFile.Checked) {
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title  = "Seleziona file P7M"
        $dlg.Filter = "File P7M (*.p7m)|*.p7m|Tutti i file (*.*)|*.*"
        if ($dlg.ShowDialog() -eq "OK") {
            $txtSrc.Text = $dlg.FileName
        }
    } else {
        # Dialog stile Explorer con barra path editabile
        # Flags: BIF_RETURNONLYFSDIRS(1) + BIF_EDITBOX(16) + BIF_NEWDIALOGSTYLE(64) = 81
        $shell  = New-Object -ComObject Shell.Application
        $picked = $shell.BrowseForFolder(0, "Seleziona la cartella contenente i file .p7m", 81, "")
        if ($null -ne $picked) {
            $txtSrc.Text = $picked.Self.Path
        }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    }
})

# Pulisci log
$btnClear.Add_Click({
    $txtLog.Clear()
    $lblStats.Text = ""
})

# ─────────────────────────────────────────────
#  PULSANTE ESTRAI  (con annullamento e UI reattiva)
# ─────────────────────────────────────────────
$script:isRunning       = $false
$script:cancelRequested = $false

function Set-UIBusy([bool]$busy) {
    $btnClear.Enabled     = -not $busy
    $rbFile.Enabled       = -not $busy
    $rbFolder.Enabled     = -not $busy
    $txtSrc.Enabled       = -not $busy
    $btnBrowse.Enabled    = -not $busy
    $chkOverwrite.Enabled = -not $busy
    $chkRecurse.Enabled   = (-not $busy) -and $rbFolder.Checked
    $btnEstrai.Text       = if ($busy) { "■  Annulla" } else { "▶  Estrai" }
}

$btnEstrai.Add_Click({
    if ($script:isRunning) {
        $script:cancelRequested = $true
        $btnEstrai.Enabled = $false
        return
    }

    $src = $txtSrc.Text.Trim()
    if ([string]::IsNullOrEmpty($src)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Seleziona prima un file o una cartella sorgente.",
            "Sorgente mancante",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $overwrite = $chkOverwrite.Checked
    $tstamp    = (Get-Date).ToString("HH:mm:ss")

    $script:isRunning       = $true
    $script:cancelRequested = $false
    Set-UIBusy $true

    Log-Header "────────────────────────────────────────"
    Log-Header "[$tstamp]  Avvio estrazione"

    $ok = 0; $skip = 0; $err = 0
    try {
        if ($rbFile.Checked) {
            if (-not (Test-Path $src)) {
                Log-Err "File non trovato: $src"
                $err = 1
            } else {
                Log-Muted "File: $src"
                $res  = Extract-SingleP7M -p7mPath $src -overwrite $overwrite
                $ok   = if ($res.status -eq "ok")      { 1 } else { 0 }
                $skip = if ($res.status -eq "skipped") { 1 } else { 0 }
                $err  = if ($res.status -eq "error")   { 1 } else { 0 }
            }
        } else {
            if (-not (Test-Path $src -PathType Container)) {
                Log-Err "Cartella non trovata: $src"
                $err = 1
            } else {
                $recurse = $chkRecurse.Checked
                Log-Muted "Cartella: $src"
                Log-Muted "Ricorsiva: $(if ($recurse) {'Si'} else {'No'})"
                $r    = Extract-Folder -folderPath $src -recurse $recurse -overwrite $overwrite
                $ok   = $r.ok; $skip = $r.skipped; $err = $r.errors
            }
        }
    }
    catch {
        Log-Err "✖ Errore imprevisto: $($_.Exception.Message)"
        $err++
    }
    finally {
        # Sommario
        Log-Header "────────────────────────────────────────"
        $summary = "Completato — ✔ $ok estratti  ⊘ $skip saltati  ✖ $err errori"
        if ($err -gt 0) { Log-Err  $summary } else { Log-Ok $summary }
        Log-Line ""

        # Contatore in-form
        $lblStats.Text = "Ultima esecuzione:  ✔ $ok  ⊘ $skip  ✖ $err"
        $lblStats.ForeColor = if ($err -gt 0) { $clrLogErr } else { $clrGreen }

        $script:isRunning       = $false
        $script:cancelRequested = $false
        Set-UIBusy $false
        $btnEstrai.Enabled = $true
    }
})

# ─────────────────────────────────────────────
#  SPLASH LOG INIZIALE
# ─────────────────────────────────────────────
$form.Add_Shown({
    Log-Muted "EstraiP7M  —  STUDIO IO"
    Log-Muted "Pronto. Seleziona un file .p7m o una cartella e premi Estrai."
    Log-Line ""
})

# ─────────────────────────────────────────────
#  PRE-FILL DA ARGOMENTO (menu contestuale)
#  Uso: EstraiP7M.ps1 "C:\path\file.p7m"
#       EstraiP7M.ps1 "C:\path\cartella"
# ─────────────────────────────────────────────
if (-not [string]::IsNullOrWhiteSpace($Path)) {
    $argPath = $Path.Trim('"')
    if (Test-Path $argPath -PathType Leaf) {
        # File: imposta radio + path
        $rbFile.Checked  = $true
        $rbFolder.Checked = $false
        $txtSrc.Text      = $argPath
        $chkRecurse.Visible = $false
    } elseif (Test-Path $argPath -PathType Container) {
        # Cartella: imposta radio + path
        $rbFolder.Checked = $true
        $rbFile.Checked   = $false
        $txtSrc.Text       = $argPath
        $chkRecurse.Visible = $true
    }
}

# ─────────────────────────────────────────────
#  AVVIO
# ─────────────────────────────────────────────
[void]$form.ShowDialog()
