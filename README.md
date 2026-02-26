# SalesInvoices

A Business Central AL package for exposing posted and drafted Sales Invoices via OData web service APIs.

## Features

- **OData Query API** for retrieving sales invoices (GET requests)
- **GET endpoints** for listing draft and posted invoices
- **POST endpoint** for retrieving full invoice details with nested line items
- **JSON responses** with complete invoice data
- **Queryable filtering** with standard OData parameters
- **Error handling** for invalid requests
- **Cloud-ready** for Business Central Online

## Web Service API

### Architecture

The extension uses two complementary approaches:

1. **Query Objects** (GET requests) - For listing and querying invoices (headers only)
2. **Codeunit** (POST requests) - For retrieving full invoice details with nested line items

---

## GET Endpoints - Query Objects

Query objects expose invoice headers as read-only, queryable OData endpoints via GET requests.

### List Draft Invoices
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
      "currencyCode": "DKK",
      "paymentTermsCode": "NET30"
    }
  ]
}
```

**Query Parameters (OData Standard):**
```
?$top=50&$skip=0                                    # Pagination
?$filter=customerName eq 'Customer ABC'             # Filter by customer
?$filter=documentDate ge 2026-01-01                 # Filter by date
?$orderby=documentDate desc                         # Sort by date (newest first)
```

### List Posted Invoices
```
GET /v2.0/{tenant-id}/{environment}/ODataV4/Company('{company-id}')/postedInvoices
```

**Response:** Same structure as draft invoices (headers only)

## POST Endpoint - Codeunit

The `ProcessInvoice` action returns full invoice details with nested line items and optional dimension values.

### Get Invoice Details (POST)

**Endpoint:**
```
POST /v2.0/{tenant-id}/{environment}/ODataV4/ProcessInvoice
```

**Request Body - Draft Invoice (without dimensions):**
```json
{
  "action": "getDraftDetails",
  "invoiceId": "INV-001"
}
```

**Request Body - Draft Invoice (with dimensions):**
```json
{
  "action": "getDraftDetails",
  "invoiceId": "INV-001",
  "dimensions": ["ACTPERIOD", "CONTRACT"]
}
```

**Request Body - Posted Invoice:**
```json
{
  "action": "getPostedDetails",
  "invoiceId": "INV-001",
  "dimensions": ["ACTPERIOD", "CONTRACT"]
}
```

**Response (with nested line items and dimensions):**
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
  "paymentTermsCode": "NET30",
  "pdfUrl": "SalesInvoices/SalesInvoiceDocument/INV-001",
  "lines": [
    {
      "lineNumber": 10000,
      "lineType": "Item",
      "itemNumber": "PROD-001",
      "description": "Product A",
      "quantity": 2,
      "unitOfMeasureCode": "PCS",
      "unitPrice": 500.00,
      "lineAmount": 1000.00,
      "lineDimensions": [
        {
          "code": "ACTPERIOD",
          "value": "2026-Q1"
        },
        {
          "code": "CONTRACT",
          "value": "LINE-123"
        }
      ]
    },
    {
      "lineNumber": 20000,
      "lineType": "G/L Account",
      "itemNumber": "6100",
      "description": "Service B",
      "quantity": 1,
      "unitOfMeasureCode": "HR",
      "unitPrice": 200.00,
      "lineAmount": 200.00,
      "lineDimensions": [
        {
          "code": "ACTPERIOD",
          "value": "2026-Q1"
        }
      ]
    }
  ],
  "dimensions": [
    {
      "code": "ACTPERIOD",
      "value": "2026-Q1"
    },
    {
      "code": "CONTRACT",
      "value": "PROJ-123"
    }
  ]
}
```

**Response Notes:**
- For **draft invoices**: `pdfUrl` is empty (PDFs only exist for posted invoices)
- For **posted invoices**: `pdfUrl` contains a reference path to download the PDF
- **Line fields**: Each line includes `lineType`, `itemNumber`, and `unitOfMeasureCode`
- **Line dimensions**: If dimensions are requested, each line includes a `lineDimensions` array with the line-level dimensions

**Request Parameters:**
- `action` (required): `getDraftDetails` or `getPostedDetails`
- `invoiceId` (required): Invoice number to retrieve
- `dimensions` (optional): Array of dimension codes to include. If omitted, dimensions are not returned. If included, only requested dimensions are returned.

**Response Fields:**
- `pdfUrl`: For posted invoices, a reference path to download the PDF. Empty for draft invoices.
- `dimensions`: Only included if requested in the `dimensions` parameter. Contains header-level dimensions.
- `lines[].lineDimensions`: Only included if dimensions are requested. Contains line-level dimensions.
- All other fields are always included.

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
    'invoiceId' => 'INV-001',
    'dimensions' => ['ACTPERIOD', 'CONTRACT']
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
4. **Register Webservices**: In BC Admin Center → Web Service Registrations, add:
   - Query 50200 "SI Draft Invoices" (Service Name: `draftInvoices`)
   - Query 50201 "SI Posted Invoices" (Service Name: `postedInvoices`)
   - Codeunit 50200 "SI Handler" (Service Name: `SalesInvoices`)
5. **Enable OData**: Ensure OData v4 is enabled on your BC tenant

## File Structure

```
codeunits/
  SI_Handler.al              # POST handler for invoice details
queries/
  SI_DraftInvoices.al        # GET endpoint for draft invoices
  SI_PostedInvoices.al       # GET endpoint for posted invoices
briefing/
  tasks.txt                  # Project requirements
  todo.md                    # Task tracking
  log.md                     # Development log
  endpoints.md               # API endpoint documentation
```

## Version

- **Version:** 1.0.0.1
- **Publisher:** Northern Partners ApS
- **Platform:** Business Central 23.0+
- **Runtime:** AL 11.0

## Notes

- Query objects handle GET requests natively via OData (headers only)
- POST endpoint returns complete invoice with nested line items array
- POST endpoint supports optional `dimensions` parameter (array of dimension codes) for retrieving document dimensions
- Maximum filtering and pagination support through standard OData parameters ($filter, $orderby, $top, $skip)
- Results sorted by document date (newest first)
- Status values: `Open` (draft), `Released` (posted)
- Dimension codes available: `ACTPERIOD`, `CONTRACT` (or any custom dimensions configured in your BC tenant)
