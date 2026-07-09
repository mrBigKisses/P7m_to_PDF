# Changelog

Tutte le modifiche rilevanti allo script sono documentate in questo file.

## [1.1] - 2026-07-09

### Aggiunto
- Riconoscimento automatico del tipo di file contenuto nella busta `.p7m` tramite analisi dei magic bytes del payload (`Get-DetectedExtension`): PDF, XML (con/senza BOM), JPEG, PNG, GIF, TIFF, BMP, RTF, buste P7M annidate e formati ZIP-based (docx/xlsx/pptx/odt), questi ultimi distinti ispezionando i percorsi interni all'archivio (`Get-ZipInnerExtension`).
- Log informativo quando l'estensione dichiarata nel nome del file originale differisce da quella rilevata nel contenuto.
- Versione eseguibile standalone `EstraiP7M.exe` (compilata con `ps2exe`), utilizzabile senza PowerShell configurato; script di build `Build-Exe.ps1` per rigenerarla dopo ogni modifica.

### Modificato
- L'estensione del file estratto è ora decisa con priorità: contenuto rilevato → estensione presente nel nome file → fallback `.pdf`, al posto del solo fallback automatico su `.pdf` quando il nome non conteneva un'estensione riconoscibile.
- Selezione cartella sorgente: sostituito il vecchio dialog `Shell.Application.BrowseForFolder` (ad albero) con il dialog "Apri file" moderno di Windows (barra indirizzi, sidebar, ricerca), forzato alla sola selezione di cartelle. Consente di incollare direttamente un percorso.

## [1.0] - versione iniziale

- Estrazione del payload da buste `.p7m` (CMS/PKCS#7), file singolo o cartella con opzione di ricorsione.
- Output nella sottocartella `_PDF` accanto all'originale, con opzione di sovrascrittura.
- Interfaccia WinForms con log a schermo e riepilogo per sessione.
- Pre-compilazione della sorgente da argomento a riga di comando (menu contestuale).
