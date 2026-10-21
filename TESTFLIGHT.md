# Prova di StickPocket 0.1.0

Prima versione di sviluppo per iPhone con iOS 17 o successivo.
L’archivio senza firma presente in GitHub non si installa sul dispositivo.
Prima dell’invito TestFlight servono la firma Apple e il caricamento della build.

## Note per il tester

1. Apri **Aggiungi sticker → Scegli da Foto** o **Importa da File** e scegli
   un’immagine. Prova anche una GIF animata originale.
2. Apri lo sticker nella raccolta: controlla l’animazione, rinominalo, aggiungilo
   ai preferiti e prova **Condividi originale**. Chiudi e riapri l’app per
   verificare che la raccolta sia ancora disponibile.
3. Importa uno screenshot e prova **Ritaglia**. Viene salvata una nuova copia
   PNG; uno screenshot non conserva l’animazione dello sticker.
4. Apri **Dai commenti TikTok**, incolla un link video, apri i commenti e porta
   uno sticker sullo schermo. Tocca **Scegli immagini visibili**, scegli
   l’immagine e controlla l’anteprima prima di salvarla.
5. Prova **Dai miei messaggi** soltanto con una tua chat. Accedi direttamente
   nella pagina TikTok e ripeti la selezione dello sticker visibile.

TikTok potrebbe limitare il login web o il download. Questo percorso non è
ancora stato verificato su un account reale. Se fallisce, usa Foto/File: non
è garantito il recupero dell’originale da ogni commento o messaggio.

Condividere un file con WhatsApp non lo trasforma automaticamente in uno
sticker della sua tastiera. La prima versione non crea pacchetti WhatsApp.

## Dati della prova

Non servono credenziali TikTok per provare Foto, File e la raccolta.
Gli sticker importati restano sul dispositivo e sono esclusi dal backup iCloud.
La disinstallazione dell’app cancella la raccolta: esporta i file da conservare.
Per segnalare un problema basta descrivere il passaggio e il messaggio d’errore;
non inviare password, codici di accesso o screenshot di chat private.

## Configurazione Apple e Codemagic

Il 21 ottobre 2026 sono stati registrati l’identificatore `com.luigi.stickpocket`
e la scheda App Store Connect di StickPocket (Apple ID `6825385363`).
Il profilo dedicato è `StickPocket TestFlight`. Il workflow manuale
`stickpocket-testflight` in `codemagic.yaml` usa la connessione Apple e il
certificato già conservati in Codemagic. Le chiavi private non sono nel repository.

La compilazione usa Xcode 26.6 e un Mac mini M2, con limite di 20 minuti.
Il numero di build deriva da `PROJECT_BUILD_NUMBER`. L’esportazione è riservata
ai test interni; il caricamento non invia l’app alla verifica pubblica App Store.
Il gruppo interno è `StickPocket - Prova personale`.

Primo avvio della compilazione firmata:
https://codemagic.io/app/6ad8cd6aeef817f487130a29/build/6ad8d0288a524d15d6a5b17f

Attendere il successo della compilazione, del caricamento e dell’elaborazione
Apple prima di considerare la build disponibile sul dispositivo.

Nessuna pubblicazione sull’App Store è inclusa in questa fase di prova.
