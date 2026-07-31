# Changelog

Tutte le modifiche rilevanti allo script sono documentate in questo file.

## [1.2] - 2026-07-31

### Aggiunto
- **Istanza singola su selezione multipla**: selezionando più file/cartelle in Explorer o OneCommander e lanciando il comando dal menu contestuale, prima si aprivano tante finestre quanti erano gli elementi selezionati. Ora la prima istanza avviata resta in ascolto (mutex con nome noto) e raccoglie tutti gli elementi in un'unica finestra; le istanze successive depositano il proprio percorso in una coda condivisa e terminano subito senza mostrare finestra. Funziona indipendentemente dal fatto che il file manager lanci un processo per elemento (comportamento predefinito di Explorer, e di OneCommander) o un solo processo con tutti gli elementi.
- Nuova modalità "batch multi-elemento": una selezione di più file e/o cartelle confluisce in un'unica esecuzione, con lo stesso riepilogo (estratti/saltati/errori) usato per la modalità cartella.
- Aggiunto valore di registro `MultiSelectModel=Player` sulle voci "Convert P7M to PDF" (Directory e file `.p7m`) come ottimizzazione complementare per Explorer nativo.

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
