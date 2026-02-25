# Building & Deployment Guide

## Prerequisites

- VS Code with AL Language extension
- Business Central development environment access
- Proper permissions for AL development

## Symbol Download

Before building the package, you must download symbols from your Business Central environment:

1. **Using Command Palette:**
   - Press `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux)
   - Search for "AL: Download Symbols"
   - Select the Business Central environment and tenant

2. **Manual Steps:**
   - Symbols are downloaded to `.alpackages/` folder
   - This folder should be created automatically
   - Ensure `.alpackages/` is listed in .gitignore

## Building the Package

### Development Build
```
Command Palette → AL: Package
```

This creates an .app file in the project root.

### Package Output
- Output file: `Northern Partners ApS_SalesInvoices_<version>.app`
- Location: Project root directory

## Deployment

Deploy the generated .app file to your Business Central environment:

1. Navigate to the Business Central Admin Center
2. Upload the .app file
3. Follow the deployment process for your environment

## Troubleshooting

### Missing Symbols
If you get errors about missing objects, re-download symbols:
- Delete `.alpackages/` folder
- Re-run "AL: Download Symbols"

### Build Errors
- Ensure all AL files are in the correct folders (codeunits/, pages/, etc.)
- Check that briefing/ folder is properly excluded
- Verify app.json syntax

## Notes

- The briefing/ folder is excluded from compilation
- Reference implementations in briefing/CreateDimension and briefing/JournalBatch
- Use the idRanges 50200-50249 for new objects
