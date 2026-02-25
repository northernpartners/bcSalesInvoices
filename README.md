# SalesInvoices

A Business Central AL package for managing and processing sales invoices via a web service API.

## Features

- RESTful JSON API for easy integration
- Cloud-ready for Business Central Online
- Comprehensive web service operations

## Web Service API

### Endpoint
The package exposes web service via codeunit handlers with defined procedures.

### Request Format

**JSON Input:**
```json
{
  "action": "operation_name",
  "parameters": {
    // operation-specific parameters
  }
}
```

## Configuration

See briefing folder for reference implementations:
- CreateDimension: Simplest example for basic web service
- JournalBatch: More complex example with advanced features

## Building

1. Download symbols: `AL: Download Symbols` from command palette
2. Build: `AL: Package` from command palette

Note: briefing folder is excluded from compilation.
