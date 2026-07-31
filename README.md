# EstraiP7M

Utility Windows (PowerShell + WinForms) per estrarre il payload firmato da buste `.p7m` (CMS/PKCS#7): fatture elettroniche, PDF firmati, e in generale qualsiasi documento inviato in busta crittografica.

## Funzionalità

- **File singolo o cartella**, con opzione di ricorsione nelle sottocartelle.
- **Riconoscimento automatico del tipo di file contenuto**: il payload estratto viene analizzato tramite i suoi magic bytes per determinare l'estensione corretta — PDF, XML (fatture elettroniche), JPEG, PNG, GIF, TIFF, BMP, RTF, ZIP-based (docx/xlsx/pptx/odt) e buste P7M annidate. Se il nome del file originale contiene già un'estensione (es. `fattura.pdf.p7m`) ma il contenuto reale è diverso, vince il contenuto rilevato e viene loggato l'eventuale discrepanza. Se non si riesce a determinare il tipo, si usa come fallback l'estensione dal nome o infine `.pdf`.
- **Output non distruttivo**: i file estratti vengono salvati in una sottocartella `_PDF` accanto a ogni `.p7m` originale, senza toccare i file sorgente.
- **Selezione cartella con dialog Explorer moderno**: barra indirizzi, sidebar Accesso rapido e ricerca — stesso dialog "Apri file" usato dalle app Windows più recenti, in cui è possibile incollare direttamente un percorso.
- **Log a schermo** con esito per ogni file (estratto / saltato / errore) e riepilogo finale.
- **Integrazione da menu contestuale**: può ricevere come argomento un file o una cartella (es. da una voce di menu "Invia a" o da un file `.bat`/registro di sistema).
- **Istanza singola su selezione multipla**: selezionando più file/cartelle e lanciando il comando dal menu contestuale, si apre **una sola finestra** che raccoglie tutti gli elementi, anche se il file manager (Explorer in modalità predefinita, OneCommander) lancia un processo separato per ciascun elemento selezionato. La prima istanza avviata resta in ascolto; le successive inoltrano il proprio elemento e terminano subito senza mostrare finestra.

## Requisiti

- Windows con PowerShell (Windows PowerShell 5.1 o PowerShell 7+).
- Nessuna dipendenza esterna: usa solo assembly .NET già inclusi in Windows (`System.Windows.Forms`, `System.Security`, `System.IO.Compression`).

## Uso

**Versione eseguibile (consigliata per utenti finali):** doppio click su `EstraiP7M.exe`. Non richiede PowerShell configurato né di sbloccare l'esecuzione script (`ExecutionPolicy`); è lo stesso script compilato in un unico `.exe` standalone, senza dipendenze da installare.

**Versione script:**

1. Esegui `EstraiP7M.ps1` (doppio click se l'esecuzione script è abilitata, oppure da PowerShell).
2. Scegli **File singolo** o **Cartella** come sorgente.
3. Sfoglia o incolla il percorso.
4. Se la sorgente è una cartella, spunta **Includi sottocartelle** per la ricerca ricorsiva dei `.p7m`.
5. Spunta **Sovrascrivi** se vuoi rigenerare file già estratti in precedenza.
6. Premi **Estrai**: i file vengono salvati in `_PDF` accanto agli originali, con estensione dedotta dal contenuto.

Uso da riga di comando / menu contestuale (funziona sia con lo script che con l'exe):

```
powershell -File EstraiP7M.ps1 "C:\percorso\fattura.p7m"
EstraiP7M.exe "C:\percorso\cartella"
```

## Compilare l'eseguibile

`EstraiP7M.exe` è generato da `EstraiP7M.ps1` tramite il modulo [ps2exe](https://www.powershellgallery.com/packages/ps2exe). Dopo ogni modifica allo script, ricompila con:

```
powershell -File Build-Exe.ps1
```

Aggiorna il numero di versione nello script `Build-Exe.ps1` (parametro `-version`) in coerenza con `CHANGELOG.md`.

## Struttura del codice

- `EstraiP7M.ps1` — intero script: interfaccia WinForms, riconoscimento del tipo di file (`Get-DetectedExtension`, `Get-ZipInnerExtension`, `Test-BytePrefix`), estrazione della busta CMS/PKCS#7 (`Extract-SingleP7M`, `Extract-Folder`) e gestione eventi UI.
- `EstraiP7M.exe` — build standalone dello script, generata con `Build-Exe.ps1`.
- `Build-Exe.ps1` — script di compilazione (ps2exe) usato per rigenerare l'exe.
