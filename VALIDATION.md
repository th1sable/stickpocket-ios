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
| Build Release iPhone con Xcode 26.6 / SDK iOS 26.5 | Archivio creato con successo, senza firma |
| Test nativi XCTest su iPhone 17 Pro, iOS 26.5 | 7 superati, 0 falliti |
| Selettore immagini Node nella stessa esecuzione CI | 9 superati, 0 falliti |
| Avvio fuori dai test e schermata sul simulatore iPhone 17 Pro | Riuscito; schermata acquisita e controllata visivamente |
| Progetto su GitHub | Codice e risorse in th1sable/stickpocket-ios, pubblico con autorizzazione del proprietario |

I test Node coprono selezione di immagini caricate, duplicati, esclusione di
immagini fuori schermo e nascoste, avatar, schemi non supportati, immagini
incorporate, ordinamento e limite di risultati. Il contesto di test fallisce se
il selettore tenta di leggere cookie, testo del corpo pagina o interrogare
genericamente tutti gli elementi. Questi test usano un DOM simulato: non
dimostrano compatibilità con il sito TikTok reale.

## Test nativi

La suite XCTest include controlli per link TikTok, destinazioni di download,
ritaglio nei limiti dell’immagine, conservazione di una GIF animata byte per byte,
duplicati, riapertura della raccolta, preferiti, rinomina, eliminazione, file
non validi e protezione di un indice corrotto.

Le prime esecuzioni sul simulatore iOS 18.5 hanno compilato il progetto, ma
l’avvio dei test è fallito. Il registro della prima mostra la libreria
libswiftWebKit.dylib mancante, un problema del runtime documentato da Apple:
https://developer.apple.com/forums/thread/785964 .

Il workflow è stato aggiornato a macOS 26 e al simulatore della versione SDK
installata. Nessun test è stato disattivato, e la versione minima dell’app
rimane iOS 17. L’esecuzione aggiornata ha superato tutti i 7 test XCTest il 21 ottobre 2026.
I test verificano la conservazione byte per byte della GIF, i duplicati, la
persistenza della raccolta e dei preferiti, le operazioni di rinomina ed
eliminazione, i limiti degli input e le regole sui link.

## Ancora da verificare su Apple

- Avvio su iPhone reale, interazioni complete, accessibilità e dimensioni testo.
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

Progetto sorgente pubblico su GitHub. Archivio Release iPhone prodotto con
Xcode 26.6, SDK iOS 26.5 e destinazione minima iOS 17, verificati anche nel plist
del pacchetto. UIDeviceFamily contiene solo 1 (iPhone). Archivio privo di firma.

Build Release verificata:
https://github.com/th1sable/stickpocket-ios/actions/runs/39614813338

Test aggiornati:
https://github.com/th1sable/stickpocket-ios/actions/runs/39615484083

Nessun IPA firmato, nessun link TestFlight, nessuna app installata su un iPhone
reale e nessuna distribuzione ad Apple. Il recupero degli sticker dal sito TikTok
resta da provare con un account reale.
