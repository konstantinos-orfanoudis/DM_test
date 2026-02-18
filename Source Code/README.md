# OIM Export Tool - Complete Guide

## Overview

This PowerShell tool extracts and processes One Identity Manager (OIM) Transport files (ZIP format) and exports various object types including:
- Database Objects (DBObjects)
- Processes (JobChains)
- Templates
- Scripts

**New in v2.2:** Encrypted password support for secure password storage in config.json

## Project Structure

```
ChangeLabel_to_DM_with_modules/
├── MainPsModule.ps1                      # Main entry point
├── InputValidator.psm1                   # Configuration validation
├── PasswordEncryption.psm1              # Password encryption/decryption
├── Encrypt-Password.ps1                 # Helper script to encrypt passwords
├── DmDoc.psm1                           # Deployment Manager document builder
├── config.json                          # Configuration file
│
└── Modules/
    ├── Common/                          # Shared modules
    │   ├── PsModuleLogin.psm1          # OIM connection module (with password support)
    │   └── ExtractXMLFromZip.psm1      # ZIP extraction module
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

### 1. Extract the Project

Extract the ZIP file to your desired location:
```
C:\Users\OneIM\Desktop\Git\DM_test\ChangeLabel_to_DM_with_modules\
```

### 2. Configure config.json

Edit `config.json` with your paths:

**Without Password (for unencrypted DM configurations):**

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

**With Encrypted Password (for encrypted DM configurations):**

```json
{
  "DMConfigDir": "C:\\Users\\OneIM\\Desktop\\Test_XMLtoDM\\Config\\Example",
  "OutPath": "C:\\Users\\OneIM\\Desktop\\Test_XMLtoDM",
  "LogPath": "C:\\Users\\OneIM\\Desktop\\Test_XMLtoDM\\Logs\\export.log",
  "DMDll": "C:\\Users\\OneIM\\Desktop\\DeploymentManager_4.0.6_beta\\Intragen.Deployment.OneIdentity.dll",
  "DMPassword": "[E]01000000d08c9ddf0115d1118c7a00c04fc297eb...",
  "IncludeEmptyValues": false,
  "PreviewXml": false,
  "CSVMode": false
}
```

### 3. (Optional) Encrypt Your Password

If your Deployment Manager configuration requires a password, you can encrypt it:

```powershell
# Run the encryption helper script
.\Encrypt-Password.ps1

# Or provide password directly
.\Encrypt-Password.ps1 -Password "YourPassword123"
```

The script will output an encrypted password starting with `[E]` that you can copy to config.json.

## Password Support for Encrypted Configurations

When Deployment Manager configurations are password-protected, the tool can automatically handle password entry using encrypted passwords.

### Why Use Encrypted Passwords?

✅ **Security:**
- Password is **encrypted** in config.json (not plain text)
- Uses Windows DPAPI (Data Protection API)
- Can commit config.json to Git safely (after encrypting password)

✅ **Convenience:**
- No manual password entry needed
- Automated scripts work seamlessly
- One-time setup per machine

⚠️ **Machine-Specific:**
- Encrypted on Machine A → Only works on Machine A
- Encrypted by User1 → Only works for User1
- Must re-encrypt on different machines/users

### Three Ways to Provide Passwords

#### Method 1: Encrypted in config.json (Recommended for Automation)

**Step 1: Encrypt Your Password**

```powershell
.\Encrypt-Password.ps1
# Enter password when prompted
# Copy the encrypted output
```

**Step 2: Add to config.json**

```json
{
  "DMPassword": "[E]01000000d08c9ddf0115d1118c7a00c04fc297eb01000000..."
}
```

**Step 3: Run the tool**

```powershell
.\MainPsModule.ps1 -ZipPath "C:\path\to\transport.zip"
```

Expected output:
```
Decrypting encrypted password...
✓ Password decrypted successfully
✓ Connection established successfully
```

**Advantages:**
- ✅ Password encrypted at rest
- ✅ No manual password entry
- ✅ Works in automated scripts
- ✅ Can commit config.json (after encryption)

**Limitations:**
- ⚠️ Machine + user specific
- ⚠️ Must re-encrypt on each target machine

#### Method 2: Plain Text (Development Only - Not Recommended)

**config.json:**

```json
{
  "DMPassword": "PlainTextPassword"
}
```

⚠️ **Warning:** This stores password in plain text!
- Only use for development/testing
- Never commit config.json with plain text passwords
- Tool will warn you when using plain text passwords

### Password Priority Order

The tool checks for passwords in this order (highest to lowest):

1. **CLI Parameter** - `.\MainPsModule.ps1 -DMPassword "..."`
2. **config.json** - `"DMPassword": "..."`

### How Encryption Works

```
┌─────────────────────────────────────────────────────────────┐
│ Encryption (One-Time Setup)                                 │
├─────────────────────────────────────────────────────────────┤
│ User runs: .\Encrypt-Password.ps1                           │
│      ↓                                                      │
│ Enter password: "MyPassword123"                            │
│      ↓                                                      │
│ ConvertTo-EncryptedBlock (Windows DPAPI)                   │
│      ↓                                                      │
│ Output: [E]01000000d08c9ddf0115d1118c7a00c04fc297eb...    │
│      ↓                                                      │
│ Copy to config.json                                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Decryption (Every Run)                                      │
├─────────────────────────────────────────────────────────────┤
│ Tool reads config.json                                      │
│      ↓                                                      │
│ Detects [E] prefix → password is encrypted                 │
│      ↓                                                      │
│ ConvertFrom-EncryptedBlock (Windows DPAPI)                 │
│      ↓                                                      │
│ Plain text password (in memory only)                       │
│      ↓                                                      │
│ Pass to: Invoke-QDeploy -Password $plainPassword           │
│      ↓                                                      │
│ ✓ Connected!                                                │
└─────────────────────────────────────────────────────────────┘
```

### Encryption for Different Environments

**Development → Testing → Production:**

```powershell
# On Development Machine
.\Encrypt-Password.ps1 -Password "DevPassword"
# Copy to dev/config.json

# On Testing Machine
.\Encrypt-Password.ps1 -Password "TestPassword"
# Copy to test/config.json

# On Production Machine
.\Encrypt-Password.ps1 -Password "ProdPassword"
# Copy to prod/config.json
```

**Each environment has:**
- ✅ Same password (logically)
- ✅ Different encrypted strings (machine-specific)
- ✅ Secure storage

### Security Best Practices

#### ✅ Do This

1. **Encrypt Passwords**
   ```powershell
   # Always encrypt before storing
   .\Encrypt-Password.ps1 -Password "YourPassword"
   ```

2. **Add .gitignore (if using plain text temporarily)**
   ```
   config.json
   ```

3. **Create config.json.template**
   ```json
   {
     "DMPassword": "CHANGE_ME_OR_RUN_Encrypt-Password.ps1",
     ...
   }
   ```

4. **Document for Team**
   - Add instructions in team wiki
   - Share Encrypt-Password.ps1 script
   - Note machine-specific requirement

#### ❌ Don't Do This

- ❌ Don't commit plain text passwords
- ❌ Don't share encrypted passwords across machines (won't work!)
- ❌ Don't email passwords (encrypted or not)
- ❌ Don't use same encrypted string on different machines

## Usage

### Basic Usage (uses config.json)

```powershell
.\MainPsModule.ps1 -ZipPath "C:\path\to\transport.zip"
```

### With Password Override

```powershell
# Using encrypted password
$encrypted = Get-Content "encrypted_password.txt"
.\MainPsModule.ps1 -ZipPath "C:\path\to\transport.zip" -DMPassword $encrypted

# Using plain text (not recommended)
.\MainPsModule.ps1 -ZipPath "C:\path\to\transport.zip" -DMPassword "PlainPassword"
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
- **DMPassword** - Password for encrypted configurations (plain text or encrypted with [E] prefix)

### Switches
- **IncludeEmptyValues** - Include empty column values in export
- **PreviewXml** - Display generated XML in console
- **CSVMode** - Export as CSV instead of XML

## Expected Output

### With Encrypted Password

```
OIM Export Tool

[1/3] Extracting XML files from ZIP: C:\...\transport.zip
Found 2 XML file(s) in child directories of TagTransport
Extracted 2 XML file(s)

[2/3] Validating configuration...
Configuration loaded:
  DMConfigDir:        C:\Users\OneIM\Desktop\Test_XMLtoDM\Config\Example
  OutPath:            C:\Users\OneIM\Desktop\Test_XMLtoDM
  LogPath:            C:\Users\OneIM\Desktop\Test_XMLtoDM\Logs\export.log
  DMDll:              C:\Users\OneIM\Desktop\DeploymentManager_4.0.6_beta\...
  DMPassword:         ***ENCRYPTED***

[3/3] Processing XML files...
  Loading DeploymentManager DLL: ...
  Connecting with config: ...
  Decrypting encrypted password...
  ✓ Password decrypted successfully
  Connecting with password...
  ✓ Connection established successfully

Processing DBObjects...
Processing Processes...
Processing Templates...
Processing Scripts...

✓ Export completed successfully!
```

### Without Password

```
OIM Export Tool

[1/3] Extracting XML files from ZIP: C:\...\transport.zip
Found 2 XML file(s) in child directories of TagTransport
Extracted 2 XML file(s)

[2/3] Validating configuration...
Configuration loaded:
  DMConfigDir:        C:\Users\OneIM\Desktop\Test_XMLtoDM\Config\Example
  OutPath:            C:\Users\OneIM\Desktop\Test_XMLtoDM
  DMPassword:         <not in config>

[3/3] Processing XML files...
  Loading DeploymentManager DLL: ...
  Connecting with config: ...
  Connecting without password...
  ✓ Connection established successfully

Processing DBObjects...
...
```

## Troubleshooting

### Issue: "Failed to decrypt password"

**Symptoms:**
```
Decrypting encrypted password...
ERROR: Failed to decrypt password
Password decryption failed. Ensure password was encrypted on this machine by this user.
```

**Cause:** Password was encrypted on a different machine or by a different user.

**Solution:**
1. Re-encrypt password on the current machine:
   ```powershell
   .\Encrypt-Password.ps1 -Password "YourPassword"
   ```
2. Update config.json with new encrypted value
3. Run tool again

### Issue: "Password in plain text" warning

**Symptoms:**
```
Using plain text password
⚠ Consider encrypting with: ConvertTo-EncryptedBlock
```

**Cause:** Password in config.json is not encrypted.

**Solution:**
1. Encrypt password:
   ```powershell
   .\Encrypt-Password.ps1 -Password "YourCurrentPlainTextPassword"
   ```
2. Replace plain text password in config.json with encrypted value

### Issue: Encrypted password doesn't work after Windows update

**Cause:** Windows updates or profile changes can invalidate DPAPI encryption.

**Solution:**
1. Re-encrypt password:
   ```powershell
   .\Encrypt-Password.ps1 -Password "YourPassword"
   ```
2. Update config.json

## Configuration Reference

### Complete config.json Example

```json
{
  "DMConfigDir": "C:\\Users\\OneIM\\Desktop\\Test_XMLtoDM\\Config\\Example",
  "OutPath": "C:\\Users\\OneIM\\Desktop\\Test_XMLtoDM",
  "LogPath": "C:\\Users\\OneIM\\Desktop\\Test_XMLtoDM\\Logs\\export.log",
  "DMDll": "C:\\Users\\OneIM\\Desktop\\DeploymentManager_4.0.6_beta\\Intragen.Deployment.OneIdentity.dll",
  "DMPassword": "[E]01000000d08c9ddf0115d1118c7a00c04fc297eb01000000...",
  "IncludeEmptyValues": false,
  "PreviewXml": false,
  "CSVMode": false
}
```

### Configuration Fields

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| `DMConfigDir` | Yes | Path to DM configuration directory | `C:\\Config\\Example` |
| `OutPath` | No | Output directory (default: current dir) | `C:\\Output` |
| `LogPath` | No | Log file path (default: OutPath\\Logs\\export.log) | `C:\\Logs\\export.log` |
| `DMDll` | Yes | Path to DeploymentManager DLL | `C:\\DM\\Intragen.Deployment.OneIdentity.dll` |
| `DMPassword` | No | Password (encrypted or plain text) | `[E]encrypted...` or `PlainText` |
| `IncludeEmptyValues` | No | Include empty columns (default: false) | `true` or `false` |
| `PreviewXml` | No | Preview XML in console (default: false) | `true` or `false` |
| `CSVMode` | No | Export as CSV (default: false) | `true` or `false` |

## Version History

### v2.2 (Current)
- ✅ Added **encrypted password** support via `ConvertTo-EncryptedBlock`/`ConvertFrom-EncryptedBlock`
- ✅ Created `PasswordEncryption.psm1` module
- ✅ Created `Encrypt-Password.ps1` helper script
- ✅ Password priority: CLI > config.json
- ✅ Automatic decryption when `[E]` prefix detected
- ✅ Updated `InputValidator.psm1` with password support
- ✅ Updated `PsModuleLogin.psm1` with decryption logic
- ✅ Machine + user specific encryption (Windows DPAPI)

### v2.1
- Fixed logging integration
- Improved error handling
- Enhanced debug output

### v2.0
- Standardized parameter names to use `ZipPath` and `DMConfigDir`
- Fixed config.json reading issues
- Added comprehensive error handling
- Improved logging with color-coded output
- Added parameter splatting for cleaner code

### v1.0
- Initial release with basic export functionality

## Quick Reference

### Encrypt Password
```powershell
.\Encrypt-Password.ps1
# or
.\Encrypt-Password.ps1 -Password "MyPassword"
```

### config.json with Encrypted Password
```json
{
  "DMPassword": "[E]encrypted_string_here..."
}
```

### Run Tool
```powershell
.\MainPsModule.ps1 -ZipPath "transport.zip"
```

## Support

For issues or questions:
1. Check the **Troubleshooting** section
2. Check the **Password Support** section for encrypted configurations
3. Verify config.json format and field names
4. Check password encryption/decryption
5. Ensure paths are absolute and correct

## License

Internal Intragen tool - All rights reserved