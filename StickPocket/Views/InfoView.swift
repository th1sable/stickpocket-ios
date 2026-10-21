import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Come funziona") {
                    Label("Apri un video o una tua chat TikTok.", systemImage: "1.circle")
                    Label("Porta lo sticker sullo schermo e scegli le immagini visibili.", systemImage: "2.circle")
                    Label("Seleziona il file, controlla l’anteprima e salvalo.", systemImage: "3.circle")
                    Text("Se il file non è disponibile, fai uno screenshot in TikTok, importalo da Foto e ritaglialo.")
                }
                Section("Originali e animazioni") {
                    Text("I file importati sono conservati senza modificarli. GIF e WebP mantengono i dati originali. La riproduzione dipende dal supporto del formato in iOS.")
                    Text("Il ritaglio è disponibile per immagini ferme. Uno screenshot di uno sticker animato rimane un’immagine ferma.")
                    Text("Condividi invia il file: la trasformazione in un pacchetto sticker di WhatsApp o nella tastiera iPhone non è automatica.")
                }
                Section("I tuoi dati") {
                    Text("La raccolta resta su questo iPhone ed è esclusa dal backup iCloud. Non ci sono account StickPocket, statistiche o server dell’app.")
                    Text("Disinstallando l’app perdi la raccolta. Per conservarne una copia, condividi gli originali in File o salvali in Foto.")
                    Text("Aprendo TikTok ti colleghi direttamente a TikTok e agli eventuali servizi di accesso che scegli. StickPocket non legge password, codici di accesso o contenuti testuali delle chat.")
                    Text("La sessione web è temporanea. Chiudendo la schermata TikTok o terminando l’app potresti dover accedere di nuovo.")
                }
                Section("Disponibilità") {
                    Text("TikTok può limitare l’accesso web, il login o il download delle immagini. StickPocket non supera questi limiti e non garantisce il recupero di ogni sticker.")
                    Text("App indipendente, non affiliata a TikTok. Conserva e condividi soltanto contenuti che puoi utilizzare.")
                }
                Section { Text("StickPocket · 0.1.0\nPrima versione di sviluppo").foregroundStyle(.secondary) }
            }.navigationTitle("Da sapere").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}
