# EstraiP7M — STUDIO IO

Interfaccia grafica Windows (WinForms) per estrarre il payload contenuto in
buste firmate digitalmente `.p7m` (CMS/PKCS#7), ad esempio fatture,
documenti PDF o file XML firmati.

## Requisiti

- Windows con **Windows PowerShell 5.1** (.NET Framework).
  Lo script usa `System.Security.Cryptography.Pkcs.SignedCms` dall'assembly
  `System.Security`, disponibile solo in Windows PowerShell 5.1. Se avviato
  con PowerShell 7+ (`pwsh`), lo script rileva l'incompatibilità e mostra un
  messaggio di errore invece di bloccarsi in modo inatteso.

## Utilizzo

Avvio interattivo:

```powershell
powershell.exe -File .\EstraiP7M.ps1
```

Avvio con pre-selezione di un file o di una cartella (utile per un'integrazione
nel menu contestuale di Esplora risorse):

```powershell
powershell.exe -File .\EstraiP7M.ps1 "C:\percorso\file.p7m"
powershell.exe -File .\EstraiP7M.ps1 "C:\percorso\cartella"
```

Dalla finestra è possibile:

- Scegliere tra **file singolo** o **cartella** (con opzione ricorsiva per le
  sottocartelle).
- Scegliere se **sovrascrivere** i file già estratti in precedenza.
- Avviare l'estrazione e, durante l'elaborazione di una cartella, **annullare**
  l'operazione in corso (il pulsante "Estrai" diventa "Annulla").

I file estratti vengono salvati in una sottocartella `_PDF` accanto a ogni
`.p7m` originale.

## Comportamento dell'estrazione

- Il nome del file estratto rimuove l'estensione `.p7m` (anche se ripetuta,
  es. `fattura.pdf.p7m.p7m` → `fattura.pdf`) mantenendo l'estensione interna
  se presente nel nome originale.
- Se il nome non contiene un'estensione interna (es. `documento.p7m`),
  l'estensione viene **rilevata dal contenuto reale del file** (firma PDF,
  ZIP/Office, PNG, JPEG o XML); solo se non è possibile determinarla si usa
  `.pdf` come fallback, con una nota nel log.
- Le buste **doppiamente firmate** (CMS annidato) vengono decodificate fino
  a un massimo di 5 livelli.
- Una busta **"detached"** (senza contenuto incorporato) viene segnalata come
  errore invece di produrre un file vuoto.
- La scansione ricorsiva di una cartella **non si interrompe** se una
  sottocartella nega l'accesso: l'errore viene registrato nel log e la
  scansione prosegue con le cartelle restanti.

## Limitazioni

- Lo script estrae il payload firmato ma **non verifica** la validità della
  firma o del certificato del firmatario.
- Il rilevamento dell'estensione dal contenuto copre i formati più comuni
  (PDF, XML, ZIP/Office, PNG, JPEG); un formato non riconosciuto ricade su
  `.pdf`.
