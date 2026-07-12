# GitHub-Setup und Weiterentwicklung des n8n-Sollprozesses

Diese Anleitung richtet sich an Personen, die das Repository herunterladen, den n8n-Prototyp lokal testen oder weiterentwickeln möchten. Der Workflow gehört zu einer Bachelorarbeit zur Prozessautomatisierung in der Materialbeschaffung kleiner Handwerksunternehmen. Er ist ein Proof of Concept und keine produktive Beschaffungslösung.

Der Prototyp prüft Prozesslogik, Datenflüsse, Freigaben, Fehlerfälle und die technische Umsetzbarkeit mit n8n. Lieferantenantworten, Kundenentscheidungen und Bestellungen werden kontrolliert getestet. Für den Produktivbetrieb wären zusätzliche Maßnahmen nötig, zum Beispiel Rollenverwaltung, Monitoring, Backup, Datenschutzprüfung und klare Wartungsverantwortung.

## 1. Inhalt des n8n-Ordners

| Datei / Ordner | Zweck |
|---|---|
| `SollProzess.json` | Aktueller n8n-Workflow für den Sollprozess. |
| `SollProzess_Fehlerprotokoll.json` | Separater Error-Workflow für technische Fehlerprotokolle. |
| `testdaten/` | Testdaten, Lieferantenliste, Testfallordner TF1 bis TF5 und CSV-Cache. |
| `testdaten/kp1-csv-cache/` | Lokaler Cache für herunterladbare KP1-Bearbeitungs-CSV-Dateien. |
| `testdaten/Testfallprotokolle.md` | Dokumentation der Testfälle TF1 bis TF5. |
| `Analyse des Sollprozess` | Fachliche und technische Analyse der aktuellen Workflow-JSON. |
| `start_n8n_lokal.sh` | Lokales Startskript für n8n und optional Ollama. |
| `n8n_Schritt-fuer-Schritt-Anleitung.md` | Ausführlichere lokale Aufbauanleitung aus dem Projektkontext. |
| `csv-tools/` | Kleines Hilfswerkzeug zur CSV-Erzeugung im Browser. |

## 2. Voraussetzungen

Benötigt werden:

- eine lokale n8n-Installation oder ein n8n-Docker-Setup
- Node.js, falls n8n lokal ohne Docker betrieben wird
- SMTP-Zugang für den Mailversand
- Ollama für die lokalen KI-Knoten
- Schreibzugriff auf den lokalen Testdatenordner
- Browserzugriff auf die n8n-Oberfläche

Der Workflow nutzt lokale Dateien. Deshalb muss der Testdatenordner auf dem neuen System tatsächlich existieren und für n8n erreichbar sein.

## 3. Repository vorbereiten

Nach dem Download oder Clone des Repositorys in den n8n-Ordner wechseln:

```bash
cd "<repo>/n8n-Implementierung"
```

Die benötigten Ordner prüfen oder anlegen:

```bash
mkdir -p testdaten/kp1-csv-cache
```

Der Ordner `testdaten/` muss mindestens diese Bestandteile enthalten:

- `lieferanten.csv`
- `TF1/` bis `TF5/`
- die jeweiligen Stücklisten und erzeugten Nachweisdateien
- `kp1-csv-cache/`

## 4. Wichtige Umgebungsvariablen

n8n muss auf den Testdatenordner zugreifen können. Für lokale Linux-Systeme kann das zum Beispiel so gesetzt werden:

```bash
export N8N_FILES_DIR="$(pwd)/testdaten"
export N8N_RESTRICT_FILE_ACCESS_TO="$N8N_FILES_DIR;$N8N_FILES_DIR/kp1-csv-cache"
export N8N_BLOCK_ENV_ACCESS_IN_NODE=false
export WEBHOOK_URL="http://<deine-lan-ip>:5678/"
export N8N_EDITOR_BASE_URL="http://<deine-lan-ip>:5678"
```

Wichtig:

- `N8N_FILES_DIR` zeigt auf den lokalen Testdatenordner.
- `N8N_RESTRICT_FILE_ACCESS_TO` muss den Testdatenordner und den Cacheordner erlauben.
- Im lokalen Startskript werden erlaubte Dateiordner mit Semikolon getrennt.
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` ist nötig, damit Expressions wie `$env.N8N_FILES_DIR` funktionieren.
- `WEBHOOK_URL` und `N8N_EDITOR_BASE_URL` müssen zur erreichbaren n8n-Adresse passen.

Wenn n8n nur lokal im Browser genutzt wird, reicht oft `http://127.0.0.1:5678`. Sobald Mail-Links von einem anderen Gerät im LAN geöffnet werden, muss eine erreichbare LAN-IP verwendet werden.

## 5. Lokales Startskript nutzen

Das Skript prüfen und ausführbar machen:

```bash
cd "<repo>/n8n-Implementierung"
chmod +x start_n8n_lokal.sh
./start_n8n_lokal.sh
```

Das Skript setzt zentrale Variablen wie `N8N_FILES_DIR`, `N8N_RESTRICT_FILE_ACCESS_TO`, `WEBHOOK_URL` und `N8N_EDITOR_BASE_URL`. Vor der Nutzung auf einem neuen System sollten die Projektpfade im Skript geprüft werden. Alte absolute Pfade mit `/home/cedric/...` sind lokale Fallbacks aus der Bachelorarbeitsumgebung und müssen bei Bedarf ersetzt werden.

## 6. Workflow importieren und aktivieren

In n8n:

1. `Import from File` wählen.
2. `n8n-Implementierung/SollProzess_Fehlerprotokoll.json` importieren.
3. `n8n-Implementierung/SollProzess.json` importieren.
4. Beide Workflows speichern.
5. Credentials neu zuordnen.
6. In `SollProzess` unter `Settings` den Error Workflow `SollProzess Fehlerprotokoll` auswählen.
7. `SollProzess` aktivieren.

Der Workflow muss aktiv sein, damit der Download-Webhook erreichbar ist:

```text
/webhook/kp1-csv-download
```

Nach dem Import sollten alle Credential-Zuordnungen geprüft werden. Credential-IDs aus einem Export sind auf einem neuen System nicht gültig.

## 7. SMTP-Credential und Mailadressen

Das SMTP-Credential muss in n8n neu angelegt werden:

- Typ: `SMTP`
- empfohlener Name: `SMTP account`
- Host, Port, Benutzername und Passwort passend zum eigenen Mailanbieter setzen

Danach alle Mail-Nodes prüfen:

- neues SMTP-Credential auswählen
- `fromEmail` auf die eigene Absenderadresse setzen
- `toEmail` auf die eigene Testadresse setzen
- keine echten Lieferanten- oder Kundenadressen verwenden, solange getestet wird

Zum Prüfen alter Mailadressen:

```bash
rg -n "fromEmail|toEmail|unicedric|student.htw|gmail" SollProzess.json
```

Für Tests sollte eine eigene Test-Mailadresse oder ein geschützter Mailaccount verwendet werden. Der Workflow sendet mehrere interne Freigabeformulare und simulierte Lieferanten-/Kundenmails.

## 8. Ollama einrichten

Ollama installieren und starten:

```bash
ollama serve
```

Die benötigten Modelle lokal ziehen:

```bash
ollama pull qwen2.5:1.5b-instruct
ollama pull qwen2.5:3b-instruct-q4_K_M
```

In n8n ein neues Ollama-Credential anlegen:

- Typ: `Ollama`
- empfohlener Name: `Ollama account`
- Base URL lokal: `http://127.0.0.1:11434`

Wenn n8n in Docker läuft, ist `127.0.0.1` aus dem Container heraus meist nicht der Host. Dann kann je nach Setup eine dieser Adressen nötig sein:

- `http://host.docker.internal:11434`
- eine feste Docker-Netzwerkadresse
- der Servicename eines Ollama-Containers

Falls andere Modelle verwendet werden, müssen alle 10 Ollama-Model-Nodes im Workflow geprüft und angepasst werden.

## 9. Download-Links und Webhooks

Der KP1-CSV-Download nutzt den Webhook:

```text
/webhook/kp1-csv-download
```

Damit der Link aus der Mail funktioniert:

- der Workflow muss aktiv sein
- `WEBHOOK_URL` muss auf die erreichbare n8n-Adresse zeigen
- `N8N_EDITOR_BASE_URL` sollte ebenfalls korrekt gesetzt sein
- der Ordner `testdaten/kp1-csv-cache/` muss existieren
- n8n muss in diesen Ordner schreiben und daraus lesen dürfen

In der aktuellen Workflow-JSON ist im Node `Übersicht & CSV senden` noch eine feste Basis-URL aus der lokalen Testumgebung enthalten:

```text
http://192.168.178.152:5678
```

Auf einem neuen System muss diese IP angepasst werden. Besser ist eine Umstellung auf `WEBHOOK_URL`, damit die Downloadlinks nicht an eine alte LAN-IP gebunden sind.

Zum Suchen der alten IP:

```bash
rg -n "192\\.168\\.178\\.152|BASE_URL|WEBHOOK_URL" SollProzess.json
```

## 10. Separater Error Trigger und Fehlerprotokolle

Der Fehlerprotokoll-Catcher liegt in einem eigenen Workflow:

```text
SollProzess_Fehlerprotokoll.json
```

Dieser Workflow enthält:

```text
Error Trigger -> Fehlerprotokoll erstellen -> Fehlerprotokoll senden
```

In der lokalen Projektfassung verweist der Hauptworkflow `SollProzess` auf diesen separaten Catcher:

```text
settings.errorWorkflow = fiU8BKrsSdwOGnvI
```

Nach einem Import in eine neue n8n-Instanz kann diese ID anders sein. Deshalb nach dem Import in den Einstellungen von `SollProzess` unter `Error Workflow` den importierten Workflow `SollProzess Fehlerprotokoll` neu auswählen und speichern.

Nach dem Import prüfen:

- Workflow ist aktiv.
- `Error Trigger` ist vorhanden.
- `Fehlerprotokoll erstellen` ist mit `Fehlerprotokoll senden` verbunden.
- SMTP-Credential ist auch im Fehlerprotokoll-Mailknoten gesetzt.
- In den Workflow-Settings von `SollProzess` zeigt `Error Workflow` auf `SollProzess Fehlerprotokoll`.

Hinweis: Error-Trigger-Workflows lassen sich nicht sinnvoll über normale manuelle Testläufe prüfen. Der Error Trigger reagiert auf fehlerhafte automatische Ausführungen. Ein Fehler aus einem manuellen Editor-Lauf, zum Beispiel `Stückliste laden -> No file(s) found`, erscheint deshalb in der Execution-Ansicht, löst aber keinen Fehlerprotokoll-Catcher aus.

Zum gezielten Testen kann der vorhandene produktive CSV-Download-Webhook ohne Pflichtparameter aufgerufen werden:

```bash
curl -i "http://127.0.0.1:5678/webhook/kp1-csv-download?error_test=1"
```

Erwartung:

- `SollProzess` erzeugt eine fehlerhafte Webhook-Execution.
- `SollProzess Fehlerprotokoll` startet danach mit `mode = error`.
- Bei korrekt gesetztem SMTP-Credential wird ein Fehlerprotokoll per Mail versendet.

## 11. Debug-Dateien optional aktivieren

Debug-Dateien sind hilfreich, aber nicht zwingend nötig. Sie sollten nur aktiviert werden, wenn bewusst lokale Debug-Protokolle geschrieben werden sollen.

```bash
export NODE_FUNCTION_ALLOW_BUILTIN=fs,path
export N8N_ALLOW_CODE_FS_DEBUG=true
export N8N_DEBUG_DIR="<debug_ordner>"
```

Der Debug-Ordner muss existieren und für den n8n-Prozess beschreibbar sein. In einer restriktiven Umgebung muss er zusätzlich über `N8N_RESTRICT_FILE_ACCESS_TO` erlaubt werden.

## 12. Docker-Hinweise

Bei Docker muss der Testdatenordner in den Container gemountet werden. Beispiel:

```yaml
volumes:
  - ./n8n-Implementierung/testdaten:/home/node/.n8n-files/testdaten
```

Dazu passende Variablen im Container:

```yaml
environment:
  - N8N_FILES_DIR=/home/node/.n8n-files/testdaten
  - N8N_RESTRICT_FILE_ACCESS_TO=/home/node/.n8n-files/testdaten;/home/node/.n8n-files/testdaten/kp1-csv-cache
  - N8N_BLOCK_ENV_ACCESS_IN_NODE=false
  - WEBHOOK_URL=http://<host-oder-lan-ip>:5678/
  - N8N_EDITOR_BASE_URL=http://<host-oder-lan-ip>:5678
```

Für Ollama im Docker-Betrieb muss die Base URL aus Sicht des n8n-Containers erreichbar sein. `http://127.0.0.1:11434` funktioniert nur, wenn Ollama im selben Container läuft. In den meisten Setups ist eine Host- oder Netzwerkadresse nötig.

## 13. Testfälle ausführen

Die Testfälle sind in `testdaten/Testfallprotokolle.md` dokumentiert.

| Testfall | Zweck |
|---|---|
| TF1 | Normalfall mit vollständiger Stückliste. |
| TF2 | Fehlende Norm in einer Stücklistenposition. |
| TF3 | Kein passender Lieferant für eine Titanposition. |
| TF4 | Zusatzkostenvergleich bei gleichem Stückpreis. |
| TF5 | Auftragsbestätigung mit absichtlicher Abweichung. |

Vor jedem Testlauf:

- alte wartende Executions abbrechen, wenn sie nicht mehr benötigt werden
- passende Stückliste im Node `Stückliste laden` auswählen oder Upload-Pfad nutzen
- Workflow aktivieren
- Haupt-Execution-ID notieren
- `debug_run_id`, Screenshots, Protokolle und erzeugte CSV-Dateien sichern

Die Testfälle dienen der Evaluation des Prototyps. Sie sind kein Nachweis für Produktivreife.

## 14. Weiterentwicklung

Bei Anpassungen am Workflow sollten diese Punkte beachtet werden:

- Human-in-the-loop-Freigaben an KP1 bis KP4 erhalten.
- KI nur für Klassifikation, Texterstellung, Extraktion und Plausibilitätsprüfung nutzen.
- Preisvergleiche, Pflichtfeldprüfungen und Statusentscheidungen möglichst deterministisch in Code-Nodes halten.
- Nach jeder Änderung mindestens den passenden Testfall erneut ausführen.
- Keine produktiven Lieferanten- oder Kundendaten in Testläufen verwenden.
- Lokale absolute Pfade durch `$env.N8N_FILES_DIR` oder andere Variablen ersetzen.
- Mailtexte und Formularfelder auf verständliche Formulierungen prüfen.
- Abbruch- und Fehlerprotokolle erhalten, damit Testläufe nachvollziehbar bleiben.

Sinnvolle erste Weiterentwicklungen:

- feste `BASE_URL` im KP1-CSV-Link vollständig durch `WEBHOOK_URL` ersetzen
- Testdaten und produktive Daten stärker trennen
- Modellknoten fachlich eindeutiger benennen
- Startpfad über Upload und lokalen Testdatenpfad klarer trennen
- Rollen- und Verantwortlichkeitskonzept ergänzen

## 15. Schnellcheck nach dem Import

```bash
cd "<repo>/n8n-Implementierung"
mkdir -p testdaten/kp1-csv-cache
rg -n "192\\.168\\.178\\.152|/home/cedric|unicedric|student.htw|errorWorkflow" SollProzess.json
```

Prüfen:

- Sind alte lokale Pfade noch relevant oder müssen sie ersetzt werden?
- Sind Mailadressen auf Testadressen geändert?
- Ist die feste LAN-IP angepasst?
- Sind SMTP- und Ollama-Credentials neu ausgewählt?
- Ist der Workflow aktiv?
- Zeigt `Error Workflow` im Hauptworkflow auf den importierten `SollProzess Fehlerprotokoll`?
- Funktioniert der KP1-CSV-Downloadlink?
- Kommt bei einem Fehler ein Fehlerprotokoll per Mail an?
