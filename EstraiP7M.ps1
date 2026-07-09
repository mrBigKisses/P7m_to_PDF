# ============================================================
#  EstraiP7M.ps1  —  STUDIO IO
#  Estrae file PDF (o qualsiasi payload) da buste .p7m
#  Supporta file singolo, cartella, ricorsione sottocartelle
#  Output sempre in sottocartella _PDF accanto all'originale
# ============================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.IO.Compression

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
$fntBrand2 = New-Object System.Drawing.Font("Century Gothic", 7, [System.Drawing.FontStyle]::Bold)

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
$lblTitle.Font      = New-Object System.Drawing.Font("Century Gothic", 13, [System.Drawing.FontStyle]::Bold)
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
#  RICONOSCIMENTO TIPO FILE DA CONTENUTO (magic bytes)
# ─────────────────────────────────────────────
function Test-BytePrefix {
    param([byte[]]$Bytes, [byte[]]$Signature, [int]$Offset = 0)
    if ($Bytes.Length -lt ($Offset + $Signature.Length)) { return $false }
    for ($i = 0; $i -lt $Signature.Length; $i++) {
        if ($Bytes[$Offset + $i] -ne $Signature[$i]) { return $false }
    }
    return $true
}

function Get-ZipInnerExtension {
    param([byte[]]$Bytes)
    try {
        $ms  = New-Object System.IO.MemoryStream(,$Bytes)
        $zip = New-Object System.IO.Compression.ZipArchive($ms, [System.IO.Compression.ZipArchiveMode]::Read)
        $names = $zip.Entries | ForEach-Object { $_.FullName }
        $zip.Dispose()
        $ms.Dispose()
        if ($names -match "^word/")     { return "docx" }
        if ($names -match "^xl/")       { return "xlsx" }
        if ($names -match "^ppt/")      { return "pptx" }
        if ($names -contains "mimetype"){ return "odt" }
        return "zip"
    }
    catch { return "zip" }
}

function Get-DetectedExtension {
    param([byte[]]$Bytes)

    if ($null -eq $Bytes -or $Bytes.Length -lt 4) { return $null }

    if (Test-BytePrefix $Bytes @(0x25,0x50,0x44,0x46))                                   { return "pdf" }
    if ((Test-BytePrefix $Bytes @(0x50,0x4B,0x03,0x04)) -or
        (Test-BytePrefix $Bytes @(0x50,0x4B,0x05,0x06)) -or
        (Test-BytePrefix $Bytes @(0x50,0x4B,0x07,0x08)))                                 { return Get-ZipInnerExtension $Bytes }
    if (Test-BytePrefix $Bytes @(0xFF,0xD8,0xFF))                                        { return "jpg" }
    if (Test-BytePrefix $Bytes @(0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A))                { return "png" }
    if (Test-BytePrefix $Bytes @(0x47,0x49,0x46,0x38))                                   { return "gif" }
    if ((Test-BytePrefix $Bytes @(0x49,0x49,0x2A,0x00)) -or
        (Test-BytePrefix $Bytes @(0x4D,0x4D,0x00,0x2A)))                                 { return "tif" }
    if (Test-BytePrefix $Bytes @(0x42,0x4D))                                             { return "bmp" }
    if (Test-BytePrefix $Bytes @(0x7B,0x5C,0x72,0x74,0x66))                               { return "rtf" }

    # XML (con o senza BOM UTF-8)
    $offset = if (Test-BytePrefix $Bytes @(0xEF,0xBB,0xBF)) { 3 } else { 0 }
    $probeLen = [Math]::Min(200, $Bytes.Length - $offset)
    if ($probeLen -gt 0) {
        $head = [System.Text.Encoding]::ASCII.GetString($Bytes, $offset, $probeLen).TrimStart()
        if ($head.StartsWith("<?xml", [StringComparison]::OrdinalIgnoreCase) -or $head.StartsWith("<")) {
            return "xml"
        }
    }

    # busta CMS/PKCS7 annidata (doppia firma)
    if (Test-BytePrefix $Bytes @(0x30,0x82)) { return "p7m" }

    return $null
}

# ─────────────────────────────────────────────
#  CORE — ESTRAZIONE SINGOLO FILE
# ─────────────────────────────────────────────
function Extract-SingleP7M {
    param([string]$p7mPath, [bool]$overwrite)

    $dir     = Split-Path $p7mPath -Parent
    $outDir  = Join-Path $dir "_PDF"

    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
        Log-Muted "  → Creata cartella: $outDir"
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($p7mPath)
        $cms   = New-Object System.Security.Cryptography.Pkcs.SignedCms
        $cms.Decode($bytes)
        $payload = $cms.ContentInfo.Content
    }
    catch {
        Log-Err "  ✖ Errore: $([System.IO.Path]::GetFileName($p7mPath)) — $($_.Exception.Message)"
        return @{ status = "error" }
    }

    # nome output: rimuove .p7m; l'estensione si deduce dal contenuto reale del payload,
    # con fallback sull'estensione presente nel nome (es. fattura.pdf.p7m) e infine su .pdf
    $origBase  = [System.IO.Path]::GetFileNameWithoutExtension($p7mPath)   # "fattura.pdf" o "fattura"
    $nameExt   = [System.IO.Path]::GetExtension($origBase).TrimStart(".")
    $baseNoExt = [System.IO.Path]::GetFileNameWithoutExtension($origBase)

    $detectedExt = Get-DetectedExtension $payload

    if ($detectedExt -and $nameExt -and ($nameExt.ToLower() -ne $detectedExt.ToLower())) {
        Log-Muted "  ℹ Contenuto rilevato come .$detectedExt (il nome indicava .$nameExt)"
    }

    if ($detectedExt) {
        $finalExt = $detectedExt
    } elseif ($nameExt) {
        $finalExt = $nameExt
    } else {
        Log-Muted "  ℹ Tipo di file non riconosciuto — uso estensione di fallback .pdf"
        $finalExt = "pdf"
    }

    $baseName = "$baseNoExt.$finalExt"
    $destPath = Join-Path $outDir $baseName

    if ((Test-Path $destPath) -and (-not $overwrite)) {
        Log-Muted "  ⊘ Saltato (esiste): $baseName"
        return @{ status = "skipped" }
    }

    try {
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
#  CORE — ESTRAZIONE BATCH (cartella)
# ─────────────────────────────────────────────
function Extract-Folder {
    param([string]$folderPath, [bool]$recurse, [bool]$overwrite)

    $depth = if ($recurse) { "AllDirectories" } else { "TopDirectoryOnly" }
    $files = [System.IO.Directory]::GetFiles($folderPath, "*.p7m", $depth)

    if ($files.Count -eq 0) {
        Log-Muted "Nessun file .p7m trovato."
        return @{ ok=0; skipped=0; errors=0 }
    }

    $ok=0; $skip=0; $err=0
    foreach ($f in $files) {
        $res = Extract-SingleP7M -p7mPath $f -overwrite $overwrite
        switch ($res.status) {
            "ok"      { $ok++ }
            "skipped" { $skip++ }
            "error"   { $err++ }
        }
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
        # Dialog "Apri file" moderno di Windows (barra indirizzi, sidebar, ricerca),
        # forzato alla sola selezione cartella: il filtro esclude ogni file reale,
        # quindi si può navigare o incollare un percorso e premere Apri.
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title            = "Seleziona la cartella contenente i file .p7m"
        $dlg.CheckFileExists  = $false
        $dlg.CheckPathExists  = $true
        $dlg.ValidateNames    = $false
        $dlg.Multiselect      = $false
        $dlg.FileName         = "Seleziona questa cartella"
        $dlg.Filter           = "Cartelle|*.$([guid]::NewGuid().ToString('N'))"
        if ($dlg.ShowDialog() -eq "OK") {
            if (Test-Path $dlg.FileName -PathType Container) {
                $txtSrc.Text = $dlg.FileName
            } else {
                $txtSrc.Text = [System.IO.Path]::GetDirectoryName($dlg.FileName)
            }
        }
    }
})

# Pulisci log
$btnClear.Add_Click({
    $txtLog.Clear()
    $lblStats.Text = ""
})

# ─────────────────────────────────────────────
#  PULSANTE ESTRAI
# ─────────────────────────────────────────────
$btnEstrai.Add_Click({
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

    Log-Header "────────────────────────────────────────"
    Log-Header "[$tstamp]  Avvio estrazione"

    if ($rbFile.Checked) {
        if (-not (Test-Path $src)) {
            Log-Err "File non trovato: $src"
            return
        }
        Log-Muted "File: $src"
        $res = Extract-SingleP7M -p7mPath $src -overwrite $overwrite
        $ok    = if ($res.status -eq "ok")      { 1 } else { 0 }
        $skip  = if ($res.status -eq "skipped") { 1 } else { 0 }
        $err   = if ($res.status -eq "error")   { 1 } else { 0 }
    } else {
        if (-not (Test-Path $src -PathType Container)) {
            Log-Err "Cartella non trovata: $src"
            return
        }
        $recurse = $chkRecurse.Checked
        Log-Muted "Cartella: $src"
        Log-Muted "Ricorsiva: $(if ($recurse) {'Si'} else {'No'})"
        $r   = Extract-Folder -folderPath $src -recurse $recurse -overwrite $overwrite
        $ok  = $r.ok; $skip = $r.skipped; $err = $r.errors
    }

    # Sommario
    Log-Header "────────────────────────────────────────"
    $summary = "Completato — ✔ $ok estratti  ⊘ $skip saltati  ✖ $err errori"
    if ($err -gt 0) { Log-Err  $summary } else { Log-Ok $summary }
    Log-Line ""

    # Contatore in-form
    $lblStats.Text = "Ultima esecuzione:  ✔ $ok  ⊘ $skip  ✖ $err"
    $lblStats.ForeColor = if ($err -gt 0) { $clrLogErr } else { $clrGreen }
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
if ($args.Count -gt 0) {
    $argPath = $args[0].Trim('"')
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
