# OIM Export Tool - Complete Project

## Overview

This PowerShell tool extracts and processes One Identity Manager (OIM) Transport files (ZIP format) and exports various object types including:
- Database Objects (DBObjects)
- Processes (JobChains)
- Templates
- Scripts

## Project Structure

```
ChangeLabel_to_DM_with_modules/
├── MainPsModule.ps1                      # Main entry point
├── InputValidator.psm1                   # Configuration validation
├── ExtractXMLFromZip.psm1               # ZIP extraction module
├── PsModuleLogin.psm1                   # OIM connection module
├── config.json                          # Configuration file
│
└── Modules/
    ├── DBObjects/
    │   ├── DBObjects_Main_PsModule.psm1
    │   ├── DBObjects_XmlParser.psm1
    │   ├── DBObjects_FilterColumnsPsModule.psm1
    │   └── DBObjects_XmlExporter.psm1
    │
    ├── Process/
    │   ├── Process_Main_PsModule.psm1
    │   ├── Process_XmlParser.psm1
    │   └── Export-Process.psm1
    │
    ├── Templates/
    │   ├── Templates_Main_PsModule.psm1
    │   ├── Templates_XmlParser.psm1
    │   └── Templates_Exporter_PsModule.psm1
    │
    └── Scripts/
        ├── Scripts_Main_PsModule.psm1
        ├── Scripts_XmlParser.psm1
        └── Scripts_Exporter_PsModule.psm1
```

## Prerequisites

1. **PowerShell 5.1 or higher**
2. **One Identity Manager DeploymentManager DLL**
   - Location: `C:\...\DeploymentManager\Intragen.Deployment.OneIdentity.dll`
3. **OIM Configuration Directory**
   - Must contain valid OIM connection configuration

## Setup

### 1. Extract the ZIP file

Extract the complete_project.zip to your desired location:
```
C:\Users\OneIM\Desktop\Git\DM_test\ChangeLabel_to_DM_with_modules\
```

### 2. Configure config.json

Edit `config.json` with your paths:

```json
{
  "DMConfigDir": "C:\\Users\\OneIM\\Desktop\\Test_XMLtoDM\\Config\\Example",
  "OutPath": "C:\\Users\\OneIM\\Desktop\\Test_XMLtoDM",
  "LogPath": "C:\\Users\\OneIM\\Desktop\\Test_XMLtoDM\\Logs\\export.log",
  "DMDll": "C:\\Users\\OneIM\\Desktop\\DeploymentManager_4.0.6_beta\\Intragen.Deployment.OneIdentity.dll",
  "IncludeEmptyValues": false,
  "PreviewXml": false,
  "CSVMode": false
}
```

**Important:**
- Use double backslashes `\\` in JSON
- All paths must exist (except OutPath and LogPath, which will be created)
- Field names are case-sensitive: `DMConfigDir`, `DMDll`

### 3. Verify Paths

```powershell
# Check if config directory exists
Test-Path "C:\Users\OneIM\Desktop\Test_XMLtoDM\Config\Example"

# Check if DM DLL exists
Test-Path "C:\Users\OneIM\Desktop\DeploymentManager_4.0.6_beta\Intragen.Deployment.OneIdentity.dll"
```

## Usage

### Basic Usage (uses config.json)

```powershell
.\MainPsModule.ps1 -ZipPath "C:\path\to\transport.zip"
```

### With Parameters (overrides config.json)

```powershell
.\MainPsModule.ps1 `
  -ZipPath "C:\path\to\transport.zip" `
  -OutPath "C:\CustomOutput" `
  -DMConfigDir "C:\CustomConfig"
```

### With Switches

```powershell
.\MainPsModule.ps1 `
  -ZipPath "C:\path\to\transport.zip" `
  -CSVMode `
  -PreviewXml
```

## Parameters

### Required
- **ZipPath** - Path to the OIM Transport ZIP file

### Optional (uses config.json if not specified)
- **DMConfigDir** - OIM configuration directory
- **OutPath** - Output directory for exported files
- **LogPath** - Log file path
- **DMDll** - Path to DeploymentManager DLL

### Switches
- **IncludeEmptyValues** - Include empty column values in export
- **PreviewXml** - Display generated XML in console
- **CSVMode** - Export as CSV instead of XML

## Expected Output

```
=== OIM Export Tool ===

[1/3] Extracting XML files from ZIP: C:\...\transport.zip
Found 2 XML file(s) in child directories of TagTransport
Extracted 2 XML file(s)

[2/3] Validating configuration...
Configuration loaded:
  DMConfigDir:        C:\Users\OneIM\Desktop\Test_XMLtoDM\Config\Example
  OutPath:            C:\Users\OneIM\Desktop\Test_XMLtoDM
  LogPath:            C:\Users\OneIM\Desktop\Test_XMLtoDM\Logs\export.log
  DMDll:              C:\Users\OneIM\Desktop\DeploymentManager_4.0.6_beta\...
  IncludeEmptyValues: False
  PreviewXml:         False
  CSVMode:            False

[3/3] Processing XML files...
Processing file 1 of 2: TagTransport\01_test\TagData.xml
  - Extracting DBObjects...
  - Extracting Processes...
  - Extracting Templates...
  - Extracting Scripts...

Export completed successfully!
Output directory: C:\Users\OneIM\Desktop\Test_XMLtoDM
```

## Output Files

The tool creates the following structure in the output directory:

```
OutPath/
├── DBObjects.xml              # Database objects export
├── Templates/
│   └── *.vb                   # Template files
├── Scripts/
│   └── *.vb                   # Script files
└── Processes/
    └── *.xml                  # Process exports
```

## Troubleshooting

### Error: "Missing required parameter(s): DMConfigDir"

**Solution:** Check your config.json field names:
- Must be `DMConfigDir` (not `ConfigDir`)
- Must be `DMDll` (not `DmDll` or `DMdll`)

### Error: "parameter cannot be found that matches parameter name 'Path'"

**Solution:** Make sure all files from this ZIP are copied correctly. The old files had `-Path` parameter, new files use `-ZipPath`.

### Error: "File not found: C:\..."

**Solution:** Verify all paths in config.json exist and use double backslashes `\\`.

### Config.json not being read

**Solution:** Ensure config.json is in the same directory as MainPsModule.ps1 and has correct field names.

## Configuration Priority

Parameters are applied in this order (highest to lowest priority):

1. **Command Line Parameters** - Directly passed to script
2. **config.json** - Values from configuration file
3. **Defaults** - Built-in default values

Example:
```powershell
# If config.json has: "OutPath": "C:\\Test"
# And you run: .\MainPsModule.ps1 -ZipPath "C:\file.zip" -OutPath "C:\\Custom"
# Result: Uses "C:\Custom" (CLI overrides config)
```

## Development

### Parameter Naming Convention

All parameters use consistent naming:
- `ZipPath` - Path to ZIP file (not `Path`)
- `DMConfigDir` - Configuration directory (not `ConfigDir`)
- `DMDll` - DeploymentManager DLL path

### Adding New Modules

1. Create module directory under `Modules/`
2. Create `*_Main_PsModule.psm1` (main processing)
3. Create `*_XmlParser.psm1` (XML parsing)
4. Import in `MainPsModule.ps1`
5. Call from processing loop

## Version History

### v2.0 (Current)
- Standardized all parameter names to use `ZipPath` and `DMConfigDir`
- Fixed config.json reading issues
- Added comprehensive error handling
- Improved logging with color-coded output
- Added parameter splatting for cleaner code

### v1.0
- Initial release with basic export functionality

## Support

For issues or questions:
1. Check the TROUBLESHOOTING section
2. Verify config.json format and field names
3. Ensure all required DLLs and paths exist
4. Check PowerShell version (must be 5.1+)

## License

This tool is provided as-is for use with One Identity Manager.
