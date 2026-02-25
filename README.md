# SalesInvoices

A Business Central AL package for exposing posted and drafted Sales Invoices via OData web service APIs.

## Features

- **OData Query API** for retrieving sales invoices (GET requests)
- **Dual endpoints** for posted and drafted invoices
- **List and Detail views** with queryable filtering
- **JSON responses** with invoice headers and line items
- **Error handling** for invalid requests
- **Cloud-ready** for Business Central Online

## Web Service API

### Architecture

The extension uses two complementary approaches:

1. **Query Objects** (GET requests) - For listing and querying invoices
2. **Codeunit** (POST requests) - For business logic operations

---

## GET Endpoints - Query Objects

Query objects expose data as read-only, queryable OData endpoints via GET requests.

### List Draft Invoices (GET)
```
GET /v2.0/{tenant-id}/{environment}/ODataV4/Company('{company-id}')/draftInvoices
```

**Response:**
```json
{
  "value": [
    {
      "invoiceNumber": "INV-001",
      "customerName": "Customer ABC",
      "customerId": "CUST-001",
      "amount": 1500.00,
      "amountExcludingVat": 1200.00,
      "vat": 300.00,
      "dueDate": "2026-03-31",
      "documentDate": "2026-02-25",
      "status": "Open",
      "description": "Initial invoice",
      "currencyCode": "DKK"
    }
  ]
}
```

### List Posted Invoices (GET)
```
GET /v2.0/{tenant-id}/{environment}/ODataV4/Company('{company-id}')/postedInvoices
```

### Get Single Invoice (GET)
```
GET /v2.0/{tenant-id}/{environment}/ODataV4/Company('{company-id}')/draftInvoices('{invoiceNumber}')
```

### Query Parameters (OData Standard)

**Limit results:**
```
?$top=50&$skip=0
```

**Filter by customer:**
```
?$filter=customerName eq 'Customer ABC'
```

**Filter by date range:**
```
?$filter=documentDate ge 2026-01-01 and documentDate le 2026-12-31
```

**Sort by date (newest first):**
```
?$orderby=documentDate desc
```

**Combined example:**
```
GET /ODataV4/Company('{id}')/draftInvoices?$top=50&$orderby=documentDate desc&$filter=status eq 'Open'
```

---

## POST Endpoint - Codeunit

For business logic operations, use the ProcessInvoice action on the codeunit.

### Get Draft Invoice Details (POST)
```
POST /v2.0/{tenant-id}/{environment}/ODataV4/ProcessInvoice
```

**Request Body:**
```json
{
  "action": "getDraftDetails",
  "invoiceId": "INV-001"
}
```

**Response:**
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
  "status": "Open",
  "description": "Initial invoice",
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

### Get Posted Invoice Details (POST)
```
POST /v2.0/{tenant-id}/{environment}/ODataV4/ProcessInvoice
```

**Request Body:**
```json
{
  "action": "getPostedDetails",
  "invoiceId": "INV-001"
}
```

---

## PHP Client Examples

### Get List of Draft Invoices (GET)
```php
$auth = BusinessCentral::auth();
$department = Lists::departmentContact(7);
$company_id = $department['bc_company_id'];

// List latest draft invoices
$query = "Company('$company_id')/draftInvoices?\$top=50&\$orderby=documentDate desc";

$invoices = BusinessCentral::OData(
    auth: $auth,
    method: 'GET',
    environment: $department['bc_environment'],
    query: $query
);
```

### Filter by Customer (GET)
```php
$customer_name = 'Customer ABC';
$query = "Company('$company_id')/draftInvoices?\$filter=customerName eq '$customer_name'";

$invoices = BusinessCentral::OData(
    auth: $auth,
    method: 'GET',
    environment: $department['bc_environment'],
    query: $query
);
```

### Get Full Invoice Details (POST)
```php
$query = 'ProcessInvoice';
$data = [
    'action' => 'getDraftDetails',
    'invoiceId' => 'INV-001'
];

$invoice = BusinessCentral::OData(
    auth: $auth,
    method: 'POST',
    environment: $department['bc_environment'],
    query: $query,
    data: json_encode($data)
);
```

---

## Error Responses

### GET Query Errors
```json
{
  "@odata.error": {
    "code": "BadRequest",
    "message": "Invalid query parameters"
  }
}
```

### POST Operation Errors
```json
{
  "success": false,
  "error": "Invoice not found"
}
```

or

```json
{
  "error": true,
  "code": "Invoice not found",
  "message": "The requested draft invoice does not exist."
}
```

---

## Building and Deployment

1. **Download symbols**: Run `AL: Download Symbols` from VS Code command palette
2. **Build package**: Run `AL: Package` from command palette
3. **Deploy**: Upload to Business Central environment

## File Structure

```
codeunits/
  SI_Handler.al         # POST handler for business logic operations
  SI_Tests.al           # Unit test suite
queries/
  SI_DraftInvoices.al   # GET endpoint for draft invoices
  SI_PostedInvoices.al  # GET endpoint for posted invoices
briefing/
  tasks.txt             # Project requirements
  todo.md               # Task tracking
  log.md                # Development log
  ODATA-GET-POST.md     # Architecture documentation
  AL-concepts.md        # AL language patterns
```

## Version

- **Version:** 1.0.0.1
- **Publisher:** Northern Partners ApS
- **Platform:** Business Central 23.0+
- **Runtime:** AL 11.0

## Notes

- Query objects handle GET requests natively via OData
- Maximum filtering and pagination support through standard OData parameters
- Line items are included in POST detail endpoints only
- Results sorted by document date (newest first)
- Status values: `Open` (draft), `Released` (posted)
