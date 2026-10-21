# Verifica della prima versione

Data: 21 ottobre 2026.

## Eseguito in questo ambiente

| Controllo | Risultato |
| --- | --- |
| Selettore immagini: 9 test automatici Node | 9 superati, 0 falliti |
| Sintassi degli 11 file Swift, tramite parser Tree-sitter Swift | Nessun errore di sintassi rilevato |
| Apertura sintattica del progetto Xcode tramite parser pbxproj | Superata |
| Riferimenti ai 16 file/risorse del progetto | Tutti presenti |
| Impostazione dei target | Solo iPhone, iOS 17 o successivo |
| File plist, schema Xcode e workspace XML | Validamente serializzati |
| Sintassi script di test e generatore Python | Superata |
| Avvio della verifica GitHub Actions | Configurato solo per richiesta manuale; non avviato |
| Progetto su GitHub | Codice e risorse caricati in th1sable/stickpocket-ios |

I test Node coprono selezione di immagini caricate, duplicati, esclusione di
immagini fuori schermo e nascoste, avatar, schemi non supportati, immagini
incorporate, ordinamento e limite di risultati. Il contesto di test fallisce se
il selettore tenta di leggere cookie, testo del corpo pagina o interrogare
genericamente tutti gli elementi. Questi test usano un DOM simulato: non
dimostrano compatibilità con il sito TikTok reale.

## Predisposto ma non eseguito

La suite XCTest include controlli per link TikTok, destinazioni di download,
ritaglio nei limiti dell’immagine, conservazione di una GIF animata byte per byte,
duplicati, riapertura della raccolta, preferiti, rinomina, eliminazione, file
non validi e protezione di un indice corrotto.

Non è stata eseguita perché questo ambiente non dispone di Xcode o di un SDK
iOS. Il percorso remoto è predisposto su GitHub; il suo avvio resta in attesa
della scelta del percorso di compilazione. Il controllo della sintassi Swift
non verifica i tipi, l’esistenza delle API, la compilazione o il comportamento
dell’app.

## Ancora da verificare su Apple

- Compilazione Xcode e test XCTest.
- Avvio dell’interfaccia su simulatore e iPhone, accessibilità e dimensioni testo.
- Importazione da Foto e dai provider File, anche iCloud Drive.
- Login web TikTok, apertura dei commenti e di una propria chat.
- Presenza delle immagini sticker nel DOM web e recupero dei file originali.
- Comportamento quando il login o un download vengono bloccati o scadono.
- Anteprima GIF/WebP, memoria e fluidità su dispositivo.
- Ritaglio di screenshot verticali/orizzontali e immagini con orientamento EXIF.
- Condivisione e salvataggio in Foto con permesso accettato e negato.
- Raccolta dopo riavvio, dispositivo bloccato e poco spazio disponibile.
- Firma, archivio e distribuzione TestFlight.

## Stato di consegna

Progetto sorgente caricato su GitHub. Nessun IPA firmato, nessuna app installata,
nessun link TestFlight, nessuna distribuzione e nessuna verifica Apple effettuata.
