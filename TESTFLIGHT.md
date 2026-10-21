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

## Passaggio Apple ancora da completare

- Registrare l’identificatore di StickPocket nel team Apple del proprietario.
- Creare la relativa scheda App Store Connect.
- Configurare la firma solo per questa app con il collegamento Apple autorizzato.
- Generare e verificare una nuova build firmata con Xcode 26 o successivo.
- Caricarla su TestFlight per la prova interna del proprietario.

Nessuna pubblicazione sull’App Store è inclusa in questa fase di prova.
