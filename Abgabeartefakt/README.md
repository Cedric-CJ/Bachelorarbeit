# Versioniertes n8n-Abgabeartefakt

Dieses Verzeichnis bündelt den technischen Prüfstand der Bachelorarbeit in einer unveränderlich prüfbaren Abgabefassung.

Version: `1.0.0`  
Git-Tag: `n8n-poc-abgabe-2026-07-16`

Das TAR.GZ-Archiv enthält:

- den Hauptworkflow `SollProzess.json`
- den Fehlerworkflow `SollProzess_Fehlerprotokoll.json`
- das lokale Startskript `start_n8n_lokal.sh`
- die Testdaten und Screenshots zu TF1 bis TF5
- die Durchlauf- und Abbruchprotokolle
- das zusammenfassende Testfallprotokoll
- ein SHA-256-Inhaltsmanifest

Die n8n-Exporte enthalten Credential-Referenzen, aber keine Passwörter oder API-Schlüssel. Nach einem Import müssen SMTP- und Ollama-Credentials in der Zielumgebung neu zugeordnet werden. Lokale Pfade und Mailadressen sind vor einem erneuten Lauf ebenfalls anzupassen.

Zur Prüfung des Archivs kann die in `SHA256SUMS.txt` angegebene SHA-256-Prüfsumme verwendet werden. Das Inhaltsmanifest im Archiv erlaubt zusätzlich die Prüfung jeder technischen Einzeldatei.

Die Workflow-JSON dokumentiert die technisch angelegte Prozesslogik. Die Protokolle belegen nur die in den kontrollierten Testläufen tatsächlich erreichten Pfade. Das Archiv ist deshalb ein reproduzierbares Proof-of-Concept-Artefakt und kein Nachweis eines produktiven Dauerbetriebs.
