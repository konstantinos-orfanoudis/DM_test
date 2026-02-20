# OIM Export Tool

## Overview

A PowerShell tool that extracts and processes One Identity Manager (OIM) Transport ZIP files, parsing embedded XML and exporting various object types to XML or CSV formats.

Supported object types:
- Database Objects (DBObjects)
- Processes (JobChains)
- Templates
- Scripts
- Table Scripts
- Format Scripts
- CanSee Scripts
- CanEdit Scripts

---

## Project Structure

```
SourceCode/
├── MainPsModule.ps1                          # Entry point — orchestrates the pipeline
├── InputValidator.psm1                       # Validates and merges CLI args with config.json
├── DmDoc.psm1                                # Deployment Manager document builder
├── NLogger.psm1                              # Logging module (wraps NLog.dll)
├── config.json                               # Default configuration file
│
└── Modules/
    ├── Common/
    │   ├── PsModuleLogin.psm1                # OIM connection via PowerShell module
    │   ├── ExtractXMLFromZip.psm1            # ZIP extraction utility
    │   └── ApiLogin.psm1                     # API login (available)
    │
    ├── DBObjects/
    │   ├── DBObjects_Main_PsModule.psm1
    │   ├── DBObjects_XmlParser.psm1
    │   ├── DBObjects_FilterColumnsPsModule.psm1
    │   ├── DBObjects_XmlExporter.psm1
    │   └── DBObjects_CsvExporter.psm1
    │
    ├── Process/
    │   ├── Process_Main_PsModule.psm1
    │   ├── Process_XmlParser.psm1
    │   ├── Export-Process.psm1
    │   └── DmDoc.psm1
    │
    ├── Templates/
    │   ├── Templates_Main_PsModule.psm1
    │   ├── Templates_XmlParser.psm1
    │   └── Templates_Exporter_PsModule.psm1
    │
    ├── Scripts/
    │   ├── Scripts_Main_PsModule.psm1
    │   ├── Scripts_XmlParser.psm1
    │   └── Scripts_Exporter_PsModule.psm1
    │
    ├── TableScripts/
    │   ├── TableScripts_Main_PsModule.psm1
    │   ├── TableScripts_XmlParser.psm1
    │   └── TableScripts_Exporter_PsModule.psm1
    │
    ├── FormatScripts/
    │   ├── FormatScripts_Main_PsModule.psm1
    │   ├── FormatScripts_XmlParser.psm1
    │   └── FormatScripts_Exporter_PsModule.psm1
    │
    ├── CanSeeScripts/
    │   ├── CanSeeScripts_Main_PsModule.psm1
    │   ├── CanSeeScripts_XmlParser.psm1
    │   └── CanSeeScripts_Exporter_PsModule.psm1
    │
    └── CanEditScripts/
        ├── CanEditScripts_Main_PsModule.psm1
        ├── CanEditScripts_XmlParser.psm1
        └── CanEditScripts_Exporter_PsModule.psm1
```

---

## Prerequisites

1. **PowerShell 5.1 or higher**
2. **One Identity Manager — NLog.dll**
   - Typically at: `C:\Program Files\One Identity\One Identity Manager\NLog.dll`
3. **DeploymentManager DLL** (`Intragen.Deployment.OneIdentity.dll`)
   - Provided with the DeploymentManager installation package
4. **OIM Configuration Directory**
   - Must contain a valid OIM connection configuration (used by DeploymentManager)

---

## Setup

### 1. Configure config.json

Edit `config.json` with your environment paths:

```json
{
  "DMConfigDir": "C:\\Intragen\\Deployment\\Config\\Example",
  "OutPath": "C:\\Users\\OneIM\\Desktop\\Outpath",
  "LogPath": "C:\\Users\\OneIM\\Desktop\\Project\\Logs",
  "NLoggerDLL": "C:\\Program Files\\One Identity\\One Identity Manager\\NLog.dll",
  "DMDll": "C:\\Users\\OneIM\\Desktop\\Installation_DeploymentManager\\DeploymentManager-4.0.6-beta\\Intragen.Deployment.OneIdentity.dll",
  "IncludeEmptyValues": false,
  "PreviewXml": false,
  "CSVMode": false
}
```

**Notes:**
- Use double backslashes `\\` for all paths in JSON
- `OutPath` and `LogPath` directories are created automatically if they do not exist
- All other paths must already exist
- Field names are case-sensitive: `DMConfigDir`, `DMDll`, `NLoggerDLL`

### 2. Verify Paths

```powershell
Test-Path "C:\Intragen\Deployment\Config\Example"
Test-Path "C:\Program Files\One Identity\One Identity Manager\NLog.dll"
Test-Path "C:\...\Intragen.Deployment.OneIdentity.dll"
```

---

## Usage

### Basic — uses config.json defaults

```powershell
.\MainPsModule.ps1 -ZipPath "C:\path\to\transport.zip"
```

### Override config.json with CLI parameters

```powershell
.\MainPsModule.ps1 `
  -ZipPath "C:\path\to\transport.zip" `
  -OutPath "C:\CustomOutput" `
  -DMConfigDir "C:\CustomConfig" `
  -DMDll "C:\path\to\Intragen.Deployment.OneIdentity.dll"
```

### Enable switches

```powershell
.\MainPsModule.ps1 `
  -ZipPath "C:\path\to\transport.zip" `
  -CSVMode `
  -PreviewXml `
  -IncludeEmptyValues
```

---

## Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `ZipPath` | String | Yes | Path to the OIM Transport ZIP file |
| `DMConfigDir` | String | No | OIM configuration directory |
| `OutPath` | String | No | Output directory for exported files |
| `LogPath` | String | No | Log file directory path |
| `DMDll` | String | No | Path to `Intragen.Deployment.OneIdentity.dll` |
| `IncludeEmptyValues` | Switch | No | Include columns with empty values in export |
| `PreviewXml` | Switch | No | Print generated XML to the console |
| `CSVMode` | Switch | No | Export schema XML with `@placeholders@` + separate CSV files per table |

Parameters not passed on the CLI fall back to `config.json`, then to built-in defaults.

---

## Configuration Priority

```
CLI Parameters  >  config.json  >  Built-in defaults
```

Example:
```powershell
# config.json has: "OutPath": "C:\\Default"
# CLI overrides it:
.\MainPsModule.ps1 -ZipPath "C:\file.zip" -OutPath "C:\Custom"
# Result: "C:\Custom" is used
```

---

## Output Structure

Exported files are organized under `OutPath` by Transport name and child directory:

```
OutPath/
└── <TransportName>/
    └── <ChildDirectory>/
        ├── DBObjects.xml              # Database objects (XML mode)
        ├── DBObjects_Schema.xml       # Schema template (CSV mode)
        ├── DBObjects_<Table>.csv      # Per-table CSV data (CSV mode)
        ├── Processes/
        │   └── *.xml                  # Process / JobChain exports
        ├── Templates/
        │   └── *.vb                   # Template files
        ├── Scripts/
        │   └── *.vb                   # Generic script files
        ├── TableScripts/
        │   └── *.vb                   # Table-level scripts
        ├── FormatScripts/
        │   └── *.vb                   # Format scripts
        ├── CanSeeScripts/
        │   └── *.vb                   # Visibility (CanSee) scripts
        └── CanEditScripts/
            └── *.vb                   # Edit-permission (CanEdit) scripts
```

---

## Console Output

```
=== OIM Export Tool ===

[1/3] Extracting XML files from ZIP: C:\...\transport.zip
Extracted 2 XML file(s)

[2/3] Validating configuration...
Configuration loaded:
  DMConfigDir:        C:\Intragen\Deployment\Config\Example
  OutPath:            C:\Users\OneIM\Desktop\Outpath
  LogPath:            C:\Users\OneIM\Desktop\Project\Logs
  DMDll:              C:\...\Intragen.Deployment.OneIdentity.dll
  IncludeEmptyValues: False
  PreviewXml:         False
  CSVMode:            False

[3/3] Processing XML files...

Processing file 1 of 2: TagTransport\01_test\TagData.xml
  - Extracting DBObjects...
  - Extracting Processes...
  - Extracting Templates...
  - Extracting Scripts...
  - Extracting Table Scripts...
  - Extracting Format Scripts...
  - Extracting Format CanSee Scripts...
  - Extracting Format CanEdit Scripts...
  ✓ Completed processing: TagTransport\01_test\TagData.xml

=== Export Completed Successfully ===
Processed 2 XML file(s)
Output directory: C:\Users\OneIM\Desktop\Outpath
```

---

## Logging

The tool uses **NLog** for structured logging:

- Log files are written to the directory specified by `LogPath`
- Rolling archive: up to 7 daily log files are kept
- Console output is color-coded (Yellow = progress, Green = success, Red = error)
- `NLoggerDLL` in `config.json` must point to a valid `NLog.dll`

---

## Troubleshooting

### `Missing required parameter(s): DMConfigDir`
Field names in `config.json` are case-sensitive. Check:
- `DMConfigDir` (not `ConfigDir` or `dmconfigdir`)
- `DMDll` (not `DmDll` or `DMdll`)
- `NLoggerDLL` (not `NLoggerDll` or `NloggerDLL`)

### `parameter cannot be found that matches parameter name 'Path'`
Old versions used `-Path`. The current version uses `-ZipPath`. Update any scripts or aliases that call `MainPsModule.ps1`.

### `File not found: C:\...`
Verify all paths in `config.json` exist and use double backslashes `\\`.

### config.json not being read
Ensure `config.json` is in the **same directory** as `MainPsModule.ps1`.

### NLog errors on startup
Verify that `NLoggerDLL` in `config.json` points to the correct `NLog.dll` from your OIM installation.

---

## Development

### Adding a New Module

1. Create a directory under `Modules/` (e.g., `Modules/MyType/`)
2. Create the three standard files:
   - `MyType_Main_PsModule.psm1` — orchestration and parameter passing
   - `MyType_XmlParser.psm1` — XML parsing logic
   - `MyType_Exporter_PsModule.psm1` — export formatting (XML and/or CSV)
3. Import the main module in `MainPsModule.ps1`
4. Call `MyType_Main_PsModule @commonParams` inside the processing loop

### Parameter Naming Convention

| Parameter | Convention |
|---|---|
| ZIP file path | `ZipPath` |
| OIM config dir | `DMConfigDir` |
| DM DLL path | `DMDll` |
| NLog DLL path | `NLoggerDLL` |

---

## Version History

### v3.0 (Current)
- Added TableScripts, FormatScripts, CanSeeScripts, CanEditScripts modules
- Output organized by Transport name and child directory
- NLoggerDLL added as a configurable path in `config.json`
- Cleanup of temp directories in `finally` block

### v2.0
- Standardized all parameter names (`ZipPath`, `DMConfigDir`, `DMDll`)
- Fixed `config.json` reading issues
- Added comprehensive error handling
- Improved logging with color-coded console output

### v1.0
- Initial release with DBObjects, Processes, Templates, Scripts export

---

## License

This tool is provided as-is for use with One Identity Manager.
