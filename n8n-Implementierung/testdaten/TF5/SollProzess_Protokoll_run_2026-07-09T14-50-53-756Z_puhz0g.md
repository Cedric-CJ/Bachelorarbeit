# Durchlaufprotokoll SollProzess

Erstellt: 2026-07-09T15:04:07.443Z
Run-ID: run_2026-07-09T14-50-53-756Z_puhz0g
Start: 2026-07-09T14:50:53.756Z
Debug-Datei: /home/cedric/Downloads/n8n-debug-cache/SollProzess_run_2026-07-09T14-50-53-756Z_puhz0g.md
Debug-Dateihinweis: Debug-Datei wurde nicht geschrieben, weil n8n Code-Nodes fs/path nicht freigegeben haben. debug_trace wird vollständig im Workflow weitergeführt. Für echte Dateien n8n mit NODE_FUNCTION_ALLOW_BUILTIN=fs,path neu starten oder einen Read/Write-Files-Node ergänzen.
Finaler AF15-Status: nicht korrekt
AF15-Status vor User-Entscheidung: nicht korrekt
Protokollierte Debug-Schritte: 10

## Kurzfassung des Prozesslaufs

- Protokollierte Schritte: 10
- Warnungen im Ablauf: 3
- Fehler im Ablauf: 0
- Schritte mit Prüfbedarf: AF15 – Auftragsbestätigung prüfen (unklar)

## Ablaufprotokoll ab Start

### 1. KP1b – Anfrage-Mails prüfen vorbereiten
- Status: ok
- Zeitpunkt: 2026-07-09T14:50:53.757Z
- Kurzfassung: KP1b Sammelseite vorbereitet.
- Eingangsdaten: {
 "drafts": 2
}
- Ergebnis: {
 "changedDraftCount": 0,
 "validationProblemCount": 0
}

### 2. AF7b – Antwortsammlung vorbereiten
- Status: ok
- Zeitpunkt: 2026-07-09T14:52:03.903Z
- Kurzfassung: AF7 Antwortformular vorbereitet.
- Eingangsdaten: {
 "requests": 2,
 "basis_positionen": 1
}
- Ergebnis: {
 "antworten_deadline": "2026-07-15",
 "template_positionen": 2
}

### 3. AF7c – Lieferantenantworten verarbeiten
- Status: ok
- Zeitpunkt: 2026-07-09T14:54:16.848Z
- Kurzfassung: Lieferantenantworten normalisiert und KI-Input erstellt.
- Eingangsdaten: {
 "antwortmails_count": 2,
 "basis_positionen_count": 1
}
- Ergebnis: {
 "ki_noetig": false,
 "ki_input_keys": [
 "ki_noetig",
 "ki_modus",
 "ki_begruendung",
 "ki_anweisung",
 "kommentar",
 "offene_positionen",
 "basis_positionen",
 "fallback_positionen",
 "angebote_json",
 "antwortmails"
 ],
 "ki_input_antwortmails_count": 2,
 "fallback_angebote": 2
}

### 4. AF7c1 – KI-Input validieren
- Status: ok
- Zeitpunkt: 2026-07-09T14:54:16.910Z
- Kurzfassung: AF7 KI-Input ist plausibel und kann geroutet werden.
- Eingangsdaten: {
 "ki_input_typ": "object",
 "ki_input_keys": [
 "ki_noetig",
 "ki_modus",
 "ki_begruendung",
 "ki_anweisung",
 "kommentar",
 "offene_positionen",
 "basis_positionen",
 "fallback_positionen",
 "angebote_json",
 "antwortmails"
 ],
 "ki_input_meta": {
 "ki_modus": "review",
 "offene_positionen": [],
 "gesendete_anfragen": 0,
 "antwortmails": 2,
 "fallback_positionen": 2,
 "basis_positionen": 1,
 "angebote_json": 0,
 "zeichen_antwortmails": 1451
 }
}
- Ergebnis: {
 "antwortmails_count": 2,
 "antwortmail_zeichen": 1452,
 "positionen_count": 4,
 "ki_noetig": false
}

### 5. AF7c2 – KI überspringen und Fallback nutzen
- Status: uebersprungen
- Zeitpunkt: 2026-07-09T14:54:16.968Z
- Kurzfassung: AF7 KI-Analyse wurde übersprungen; AF7d übernimmt Parser-/Fallback-Angebote.
- Entscheidung: {
 "ki_noetig": false,
 "grund": "Fallback vollständig; KI führt nur Plausibilitätsprüfung und Vollständigkeits-Scoring durch."
}
- Ergebnis: {
 "fallback_angebote": 2,
 "fallback_positionen": [
 1
 ]
}

### 6. AF7d – KI-Angebote übernehmen
- Status: ok
- Zeitpunkt: 2026-07-09T14:54:17.057Z
- Kurzfassung: KI-/Fallback-Angebotsdaten normalisiert; Alternativen und Teilangebote mit Preis werden als verwertbar übernommen.
- Entscheidung: {
 "ki_uebersprungen": true,
 "ai_rows_genutzt": false,
 "fallback_rows": 2
}
- Eingangsdaten: {
 "ai_positionen": 0,
 "fallback_positionen": 2,
 "basis_positionen": 1
}
- Ergebnis: {
 "angebotszeilen": 2,
 "verwertbare_angebote": 2,
 "fehlende_positionen": [],
 "stuecklisten_abgleich": {
 "basis_positionen_count": 1,
 "erkannte_positionen_count": 1,
 "fehlende_positionen": [],
 "unbekannte_positionen": [],
 "materialabweichungen": [],
 "status": "ok"
 }
}

### 7. AF7d2 – Angebotsvollständigkeit prüfen
- Status: ok
- Zeitpunkt: 2026-07-09T14:54:17.130Z
- Kurzfassung: Deterministische Vollständigkeitsprüfung nach AF7d ausgeführt.
- Entscheidung: {
 "klaerung_noetig": false,
 "manuelle_pruefung_noetig": false,
 "vollstaendigkeit_status": "vollstaendig",
 "af7_klaerung_round": 0,
 "af7_max_klaerung_rounds": 2,
 "loop_begrenzt": false
}
- Eingangsdaten: {
 "positionen": 1,
 "angebotszeilen": 2
}
- Ergebnis: {
 "klaerungsgruende": [],
 "warnungen": [
 "Position 1 / Edelstahl-Mueller: Material oder Alternativmaterial fehlt.",
 "Position 1 / Inox-Fachhandel: Material oder Alternativmaterial fehlt."
 ],
 "rueckfragen": 0,
 "stuecklisten_abgleich": {
 "basis_positionen_count": 1,
 "erkannte_positionen_count": 1,
 "fehlende_positionen": [],
 "unbekannte_positionen": [],
 "materialabweichungen": [],
 "status": "ok"
 }
}
- Warnungen: Position 1 / Edelstahl-Mueller: Material oder Alternativmaterial fehlt. | Position 1 / Inox-Fachhandel: Material oder Alternativmaterial fehlt.

### 8. KP3 – Kostenvoranschlag vorbereiten
- Status: ok
- Zeitpunkt: 2026-07-09T14:56:10.867Z
- Kurzfassung: Kostenvoranschlag, Kundenmail-Vorschlag, Materialübersicht und Arbeitszeit-Schätzung wurden für die Freigabe vorbereitet.
- Eingangsdaten: {
 "positionen": 1,
 "kunden_emails": 0,
 "projekt": "[Projekt/Verwendungszweck ergänzen]",
 "positionsquelle": "KP2 Übersicht"
}
- Ergebnis: {
 "beschaffungskosten": 4695,
 "kostenvoranschlag": 6103.5,
 "vorarbeit_stunden": "1,5 bis 2,5",
 "vorort_stunden": "2 bis 3,5"
}

### 9. KP4 – Bestellmails vorbereiten
- Status: ok
- Zeitpunkt: 2026-07-09T14:58:46.453Z
- Kurzfassung: Natürliche Bestellmails ohne interne Positionsformulierungen wurden zur Freigabe vorbereitet.
- Eingangsdaten: {
 "lieferanten": 1
}
- Ergebnis: {
 "bestellmails": 1,
 "bestellwert_gesamt": 4695
}

### 10. AF15 – Auftragsbestätigung prüfen
- Status: unklar
- Zeitpunkt: 2026-07-09T15:02:21.675Z
- Kurzfassung: Auftragsbestätigungen wurden mit den versendeten Bestellungen verglichen. Vollständigkeit und fachliche Abweichungen werden getrennt bewertet.
- Eingangsdaten: {
 "lieferanten": 1
}
- Ergebnis: {
 "fachlicher_status": "unklar",
 "korrekt": 0,
 "abweichend": 0,
 "unklar": 1,
 "daten_vollstaendigkeit_prozent": 0
}
- Warnungen: Inox-Fachhandel: Die Bestätigung enthält nur einen Einzelpreis und keine Belastbarkeit der Positionsdetails.

## AF15 Ergebnis

### Inox-Fachhandel
- Fachlicher Status: unklar
- Datenvollständigkeit: 0 %
- KI-Begründung: Keine spezifischen Positionsdetails oder Belege für den Preis.
- Hinweise/Abweichungen: Pos. 1: Menge nicht belastbar bestätigt – Menge wurde in der Auftragsbestätigung nicht belastbar bestätigt. | Pos. 1: Preis nicht belastbar bestätigt – Preis wurde in der Auftragsbestätigung nicht belastbar bestätigt. | KI unklar – Die Bestätigung enthält nur einen Einzelpreis und keine Belastbarkeit der Positionsdetails. | Unvollständige KI-Erkennung – KI-Vollständigkeit nur 0 %: Keine spezifischen Positionsdetails oder Belege für den Preis. | Warnhinweis – Die Bestätigung enthält nur einen Einzelpreis und keine Belastbarkeit der Positionsdetails.

## Technischer AF15-Soll/Ist-Auszug

# AF15 Protokoll – Auftragsbestätigung
Zeitpunkt: 2026-07-09T15:02:21.675Z
Gesamtstatus vor User-Entscheidung: Klärung erforderlich
Fachlicher Status: unklar
KI-Prüfung automatische Vollständigkeit: 0 %
Hinweis: Die Vollständigkeit bewertet erkannte Datenfelder. Fachliche Abweichungen werden separat ausgewiesen.
Abweichende Lieferanten: 0, unklare Lieferanten: 1
Run-ID: run_2026-07-09T14-50-53-756Z_puhz0g
Debug-Protokoll: /home/cedric/Downloads/n8n-debug-cache/SollProzess_run_2026-07-09T14-50-53-756Z_puhz0g.md
## Lieferantenbewertung

### Inox-Fachhandel
- Status: unklar
- KI-Score: 0 %
- Begründung: Keine spezifischen Positionsdetails oder Belege für den Preis.
- Details: Pos 1: Menge wurde in der Auftragsbestätigung nicht belastbar bestätigt. | Pos 1: Preis wurde in der Auftragsbestätigung nicht belastbar bestätigt. | Die Bestätigung enthält nur einen Einzelpreis und keine Belastbarkeit der Positionsdetails. | KI-Vollständigkeit nur 0 %: Keine spezifischen Positionsdetails oder Belege für den Preis. | Die Bestätigung enthält nur einen Einzelpreis und keine Belastbarkeit der Positionsdetails.

## Warnhinweise
- Inox-Fachhandel: Die Bestätigung enthält nur einen Einzelpreis und keine Belastbarkeit der Positionsdetails.

## User-Entscheidung
- Zeitpunkt: 2026-07-09T15:04:07.443Z
- Entscheidung: Nicht korrekt / Klärung erforderlich
- Interner Entscheidungstyp: klaerung_erforderlich
- Finaler Workflow-Status: nicht korrekt
- Kommentar / Korrektur: TF5: absichtlich falsche Auftragsbestätigung eingegeben:
Position 1:
Rohr 88.9x4, Werkstoff 1.4571 Edelstahl, Norm EN 10217-7.
Bestätigte Menge: 7 Stück.
Bestätigter Positionspreis netto: 420,00 EUR.
Lieferzeit: 5 Werktage.
