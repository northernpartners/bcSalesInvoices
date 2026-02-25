# SalesInvoices

A Business Central AL package for exposing posted and drafted Sales Invoices via a RESTful web service API.

## Features

- **OData GET API** for retrieving sales invoices
- **Dual endpoints** for posted and drafted invoices
- **List and Detail views** with optional filtering
- **JSON responses** with invoice headers and line items
- **Error handling** for invalid requests
- **Cloud-ready** for Business Central Online

## Web Service API

### Base URL
```
[Business Central Instance]/OData/Company('Default')/[ApiPage]
```

### Endpoints

#### 1. List Latest Drafted Invoices (GET)
```
GET .../SalesInvoices_GetDrafted
```

**Response (List):**
```json
[
  {
    "id": "INV-001",
    "invoiceNumber": "INV-001",
    "customerName": "Customer ABC",
    "customerId": "CUST-001",
    "amount": 1500.00,
    "dueDate": "2026-03-31",
    "documentDate": "2026-02-25",
    "status": "Draft",
    "posted": false
  }
]
```

**Query Parameters:**
- `$top=50` - Limit to 50 most recent (default)
- `$filter` - Filter results (supported on customerName, documentDate, etc.)

---

#### 2. Get Drafted Invoice Details (GET)
```
GET .../SalesInvoices_GetDrafted?id=INV-001
```

**Response (Detail with Lines):**
```json
{
  "id": "INV-001",
  "invoiceNumber": "INV-001",
  "customerName": "Customer ABC",
  "customerId": "CUST-001",
  "amount": 1500.00,
  "amountExcludingVat": 1200.00,
  "vat": 300.00,
  "dueDate": "2026-03-31",
  "documentDate": "2026-02-25",
  "status": "Draft",
  "posted": false,
  "description": "Initial invoice draft",
  "currencyCode": "DKK",
  "lines": [
    {
      "lineNumber": 10000,
      "description": "Product A",
      "quantity": 2,
      "unitPrice": 500.00,
      "lineAmount": 1000.00
    },
    {
      "lineNumber": 20000,
      "description": "Service B",
      "quantity": 1,
      "unitPrice": 200.00,
      "lineAmount": 200.00
    }
  ]
}
```

---

#### 3. List Latest Posted Invoices (GET)
```
GET .../SalesInvoices_GetPosted
```

**Response (List):**
Same format as drafted list endpoint, but only returns posted invoices.

---

#### 4. Get Posted Invoice Details (GET)
```
GET .../SalesInvoices_GetPosted?id=INV-001
```

**Response (Detail with Lines):**
Same format as drafted detail endpoint, but only for posted invoices.

---

### Error Responses

When an error occurs, the API returns a JSON error object:

```json
{
  "error": true,
  "code": "Invoice not found",
  "message": "The requested draft invoice does not exist."
}
```

**Common Error Codes:**
- `Invoice not found` - The specified invoice ID doesn't exist or has incorrect status
- `Invalid request` - Malformed request parameters

---

## Building and Deployment

1. **Download symbols**: Run `AL: Download Symbols` from VS Code command palette
2. **Build package**: Run `AL: Package` from command palette
3. **Deploy**: Upload to Business Central environment

## Testing

Unit tests are included in `SI_Tests.al`:
- `TestGetDraftedListReturnsJson` - Validates list endpoint returns valid JSON
- `TestGetPostedListReturnsJson` - Validates list endpoint for posted invoices
- `TestGetDraftedWithInvalidIdReturnsError` - Validates error handling
- `TestGetPostedWithInvalidIdReturnsError` - Validates error handling for posted

## File Structure

```
codeunits/
  SI_Handler.al        # Main handler with GetDrafted/GetPosted procedures
  SI_Tests.al          # Unit test suite
pages/                 # API pages (if needed for direct web service exposure)
briefing/
  tasks.txt            # Project requirements
  todo.md              # Detailed task tracking
  log.md               # Development log
```

## Version

- **Version:** 1.0.0.1
- **Publisher:** Northern Partners ApS
- **Platform:** Business Central 23.0+

## Notes

- The briefing folder is excluded from compilation
- Maximum 50 invoices per request
- Results are sorted by document date (newest first)
- Line items are included in detail responses only
