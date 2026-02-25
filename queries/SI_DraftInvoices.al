query 50200 "SI Draft Invoices"
{
    APIGroup = 'salesInvoices';
    APIPublisher = 'northernpartners';
    APIVersion = 'v1.0';
    EntityName = 'draftInvoice';
    EntitySetName = 'draftInvoices';
    DataAccessIntent = Read;

    elements
    {
        dataitem(SalesHeader; "Sales Header")
        {
            column(invoiceNumber; "No.")
            {
                Caption = 'Invoice Number';
            }
            column(customerName; "Bill-to Name")
            {
                Caption = 'Customer Name';
            }
            column(customerId; "Bill-to Customer No.")
            {
                Caption = 'Customer ID';
            }
            column(amount; "Amount Including VAT")
            {
                Caption = 'Amount';
            }
            column(amountExcludingVat; Amount)
            {
                Caption = 'Amount Excluding VAT';
            }
            column(vat; "Amount Including VAT" - Amount)
            {
                Caption = 'VAT Amount';
            }
            column(dueDate; "Due Date")
            {
                Caption = 'Due Date';
            }
            column(documentDate; "Document Date")
            {
                Caption = 'Document Date';
            }
            column(status; Status)
            {
                Caption = 'Status';
            }
            column(description; "Your Reference")
            {
                Caption = 'Description';
            }
            column(currencyCode; "Currency Code")
            {
                Caption = 'Currency Code';
            }

            filter(documentType; "Document Type")
            {
            }
            filter(statusFilter; Status)
            {
            }
        }
    }
}
