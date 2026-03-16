# nano11-builder

Vollautomatisierte GitHub-Actions-Pipeline, die aus einer Windows-11-ISO eine reduzierte Nano11-ISO baut.

## Enthalten

- GitHub Actions Workflow: `.github/workflows/nano11-ci.yml`
- CI-Wrapper für den interaktiven Nano11-Builder: `scripts/Invoke-Nano11CiBuild.ps1`

## Pipeline-Ablauf

Die Pipeline führt diese Schritte vollautomatisch aus:

1. ISO-Download oder Nutzung einer bereitgestellten ISO
2. Mounten der ISO auf dem Windows-Runner
3. Validierung von `install.wim` oder `install.esd`
4. Ausführen des Nano11-Builders (nicht-interaktiv)
5. Erzeugen einer bootfähigen Nano11-ISO
6. Erzeugen von SHA256 und Metadaten
7. Upload als GitHub-Artefakt und/oder in Azure Storage

## Voraussetzungen

- Windows Runner mit Administratorrechten
- Für Azure-Upload: OpenID Connect oder Service Principal
- Für `publish_target=azure-storage` müssen diese GitHub Secrets gesetzt sein:
	- `AZURE_CLIENT_ID`
	- `AZURE_TENANT_ID`
	- `AZURE_SUBSCRIPTION_ID`

## ADK / oscdimg.exe

Der Workflow unterstützt drei Modi über `install_adk`:

- `auto`: nutzt vorhandenes `oscdimg.exe`, installiert ADK Deployment Tools nur falls nötig
- `always`: installiert ADK Deployment Tools in jedem Lauf
- `never`: erwartet bereits verfügbares `oscdimg.exe`, sonst Fehler

Hinweis: Das Nano11-Skript erwartet `oscdimg.exe` im selben Verzeichnis wie `nano11builder.ps1`. Der Workflow kopiert die gefundene/neu installierte Datei automatisch dorthin.

## Wichtige Workflow-Inputs

- `iso_url`: Direkt-URL zur offiziellen Windows-11-ISO
- `iso_path`: Pfad zu bereits vorhandener ISO auf dem Runner
- `image_index`: Index aus `install.wim`/`install.esd`
- `output_dir`: Ausgabeordner für die finale ISO
- `nano11_script_path`: Skriptpfad im Repo
- `nano11_script_url`: Fallback-URL, falls Skript lokal nicht vorhanden
- `publish_target`: `artifact`, `azure-storage` oder `both`
- `azure_storage_account`, `azure_storage_container`, `azure_blob_prefix`: Zielparameter für Blob Upload

## Starten des Builds

Workflow manuell starten über GitHub Actions mit `workflow_dispatch` und den gewünschten Inputs.

Beispielwerte:

- `iso_url`: `https://example.invalid/win11.iso`
- `image_index`: `1`
- `output_dir`: `C:\\nano11-output`
- `nano11_script_path`: `nano11builder.ps1`
- `publish_target`: `artifact`

## Logging

Jeder Schritt protokolliert mit Zeitstempel in die Action-Logs.

Zusätzlich:

- Build-Log: `C:\nano11-ci\logs\nano11-build.log`
- Metadaten: `nano11-metadata.json` im Ausgabeordner
- Bei Fehlern wird ein Debug-Artefakt mit Logs hochgeladen

## Hinweise zu Nano11

Nano11 ist ein extrem aggressiver Build-Prozess (WinSxS, Windows Update, Defender, viele Dienste und Apps entfernt). Das Ergebnis ist nicht als normal wartbares Windows gedacht, sondern primär für Test-/Lab-/Spezialfälle.
