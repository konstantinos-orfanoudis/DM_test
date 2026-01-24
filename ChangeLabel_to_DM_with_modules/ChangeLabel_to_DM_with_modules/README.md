# OIM DbObjects Export Tool

A modular PowerShell tool for extracting DbObjects from OIM Transport XML files and exporting them to DM Objects format with column-level permission filtering.

## 📁 Project Structure

```
.
├── Main.ps1                    # Main orchestration script
├── Modules/
│   ├── XmlParser.psm1         # XML parsing and DbObject extraction
│   ├── ApiClient.psm1         # OIM API authentication and permissions
│   ├── XmlExporter.psm1       # Export to normal XML format
│   └── CsvExporter.psm1       # Export to CSV mode (XML + CSV per table)
└── README.md                   # This file
```

## 🚀 Quick Start

### Normal Mode (Single XML with data)

```powershell
.\Main.ps1 -Path "C:\Input\tagdata.xml" -OutPath "C:\Output"
```

**Output:**
- `000_2026_01_23_AllTables.xml` - Single XML file with schema and data

### CSV Mode (Separate XML + CSV per table)

```powershell
.\Main.ps1 -Path "C:\Input\tagdata.xml" -OutPath "C:\Output" -CSVMode
```

**Output:**
- `000_2026_01_23_Org.xml` - Schema-only XML with `@placeholders@` for Org table
- `000_2026_01_23_Org.csv` - Data CSV for Org table
- `000_2026_01_23_Person.xml` - Schema-only XML for Person table
- `000_2026_01_23_Person.csv` - Data CSV for Person table
- etc.

## 📋 Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-Path` | Yes | - | Path to input TagData XML file |
| `-OutPath` | Yes | - | Output directory path for all exported files |
| `-CSVMode` | No | `false` | Export as separate XML + CSV per table |
| `-IncludeEmptyValues` | No | `false` | Include columns with empty values |
| `-PreviewXml` | No | `false` | Print generated XML to console |
| `-ApiBaseUrl` | No | `http://localhost:8182` | OIM API base URL |
| `-ApiModule` | No | `SupportPlus` | OIM authentication module |
| `-ApiUser` | No | `viadmin` | API username |
| `-ApiPassword` | No | `P@ssword.123` | API password |

## 📚 Module Documentation

### XmlParser.psm1

**Functions:**
- `Get-AllDbObjectsFromChangeContent` - Extracts DbObjects from ChangeContent columns

**Description:**
Parses OIM Transport XML files and extracts embedded DbObject structures, handling HTML-encoded XML and malformed characters.

### ApiClient.psm1

**Functions:**
- `Connect-OimApi` - Authenticates with OIM API
- `Get-ColumnPermissions` - Retrieves column-level permissions
- `Filter-DbObjectsByAllowedColumns` - Filters DbObjects based on permissions

**Description:**
Handles authentication with the OIM API and retrieves column-level permissions for database tables, filtering DbObjects to include only allowed columns.

### XmlExporter.psm1

**Functions:**
- `Export-ToNormalXml` - Exports to standard DM Objects XML format

**Description:**
Generates a single XML file with full schema and data using the DM Objects namespace.

**Output Format:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<Objects xmlns="http://www.intragen.com/xsd/XmlObjectSchema" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Keys>
    <Org>Ident_Org</Org>
  </Keys>
  <Org>
    <Ident_Org>ORG_001</Ident_Org>
    <UID_OrgRoot>RMB-TeamRole</UID_OrgRoot>
    <Description>Test Org</Description>
  </Org>
</Objects>
```

### CsvExporter.psm1

**Functions:**
- `Export-ToCsvMode` - Exports to separate XML schema + CSV data per table
- `ConvertTo-CsvValue` - Properly escapes values for CSV format

**Description:**
Generates separate XML and CSV files for each table. XML files contain schema with placeholders, CSV files contain the actual data.

**XML Output Format:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<Objects>
  <Keys>
    <Org>Ident_Org</Org>
  </Keys>
  <Org>
    <Ident_Org>@Ident_Org@</Ident_Org>
    <UID_OrgRoot>@UID_OrgRoot@</UID_OrgRoot>
    <Description>@Description@</Description>
  </Org>
</Objects>
```

**CSV Output Format:**
```csv
Ident_Org,UID_OrgRoot,Description
ORG_001,RMB-TeamRole,Test Org
ORG_002,RMB-TeamRole,Another Org
```

## 🔧 Advanced Usage

### Custom API Configuration

```powershell
.\Main.ps1 `
  -Path "C:\Input\tagdata.xml" `
  -OutPath "C:\Output" `
  -ApiBaseUrl "http://server:8080" `
  -ApiModule "CustomModule" `
  -ApiUser "admin" `
  -ApiPassword "SecurePassword123"
```

### Include Empty Values

```powershell
.\Main.ps1 `
  -Path "C:\Input\tagdata.xml" `
  -OutPath "C:\Output" `
  -CSVMode `
  -IncludeEmptyValues
```

### Preview Generated XML

```powershell
.\Main.ps1 `
  -Path "C:\Input\tagdata.xml" `
  -OutPath "C:\Output" `
  -CSVMode `
  -PreviewXml
```

## 🔍 How It Works

1. **Parse Input XML** - Extracts DbObjects from `ChangeContent` columns in Transport XML
2. **Authenticate** - Connects to OIM API with provided credentials
3. **Get Permissions** - Retrieves column-level permissions for all tables
4. **Filter Columns** - Removes columns that are not allowed per API permissions
5. **Export** - Generates output files in selected format (Normal XML or CSV Mode)

## 📝 Output File Naming

All exported files use the format: `000_yyyy_MM_dd_TableName.ext`

Examples:
- `000_2026_01_23_AllTables.xml` (Normal mode)
- `000_2026_01_23_Org.xml` (CSV mode schema)
- `000_2026_01_23_Org.csv` (CSV mode data)

## 📁 Output Examples

### Normal Mode Output

Single file in output directory:
```
C:\Output\
└── 000_2026_01_23_AllTables.xml
```

### CSV Mode Output

Multiple files per table:
```
C:\Output\
├── 000_2026_01_23_Org.xml
├── 000_2026_01_23_Org.csv
├── 000_2026_01_23_Person.xml
└── 000_2026_01_23_Person.csv
```

## ⚠️ Notes

- The tool requires access to a running OIM instance with API endpoint
- Column permissions are enforced based on the authenticated user's rights
- CSV values are properly escaped for commas, quotes, and newlines
- XML files use UTF-8 encoding without BOM
- Output directory is created automatically if it doesn't exist
- Timestamp in filenames ensures unique files each day

## 🐛 Troubleshooting

### Authentication Failed
- Verify API endpoint is accessible: `http://localhost:8182`
- Check username and password are correct
- Ensure the OIM service is running

### No DbObjects Found
- Verify input file contains `Column[@Name='ChangeContent']` elements
- Check that ChangeContent columns contain valid DbObject XML
- Try with `-IncludeEmptyValues` to see all data

### Permission Errors
- Ensure authenticated user has sufficient permissions
- Check API endpoint returns valid permission data
- Review filtered column counts in console output

## 📄 License

Internal tool for OIM administration. All rights reserved.
