# Appuntamenti iOS

App iOS per la gestione degli appuntamenti, 100% offline con notifiche native.

## Requisiti

- Xcode 15.0+
- iOS 15.0+
- Account Apple Developer (per la firma e il deployment)

## Struttura

```
Appuntamenti-Vuota/
├── Appuntamenti.xcodeproj/     # Progetto Xcode
├── Appuntamenti/
│   ├── AppDelegate.swift       # App delegate con notifiche locali
│   ├── SceneDelegate.swift     # Scene delegate
│   ├── SplashViewController.swift  # Splash screen
│   ├── MainViewController.swift    # WebView + JS bridge notifiche
│   ├── Info.plist              # Configurazione
│   ├── Assets.xcassets/        # Icone e colori
│   └── WebAssets/              # HTML/CSS/JS dell'app
│       ├── index.html
│       ├── style.css
│       ├── app.js
│       └── data.js             # Array vuoto (dati importabili)
└── exportOptions.plist         # Per esportazione
```

## Import / Export Dati

L'app ora supporta import e export dei dati direttamente dall'interfaccia:

- **📥 Importa** — Seleziona un file `.json`, scegli se aggiungere o sostituire
- **📤 Esporta** — Scarica tutti gli appuntamenti come file `.json`

Il file `appuntamenti_data.json` nella root contiene i 336 appuntamenti originali,
pronto per essere importato nell'app vuota.

## Build

1. Apri `Appuntamenti.xcodeproj` con Xcode
2. Seleziona il tuo Team in *Signing & Capabilities*
3. Seleziona il dispositivo target
4. Premi **Cmd + R** per build e run

## Funzionalità

- ✅ WebView offline con IndexedDB
- ✅ Notifiche locali native iOS (UNUserNotificationCenter)
- ✅ JavaScript bridge compatibile con la versione Android
- ✅ Splash screen con icona personalizzata
- ✅ Supporto iPhone e iPad
- ✅ Import/Export dati in formato JSON
