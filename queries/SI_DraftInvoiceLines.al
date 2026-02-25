query 50203 "SI Draft Invoice Lines"
{
    QueryType = API;
    APIGroup = 'salesInvoices';
    APIPublisher = 'northernpartners';
    APIVersion = 'v1.0';
    EntityName = 'draftInvoiceLine';
    EntitySetName = 'draftInvoiceLines';

    elements
    {
        dataitem(SalesLine; "Sales Line")
        {
            column(invoiceNumber; "Document No.")
            {
                Caption = 'Invoice Number';
            }
            column(lineNumber; "Line No.")
            {
                Caption = 'Line Number';
            }
            column(description; Description)
            {
                Caption = 'Description';
            }
            column(quantity; Quantity)
            {
                Caption = 'Quantity';
            }
            column(unitPrice; "Unit Price")
            {
                Caption = 'Unit Price';
            }
            column(lineAmount; "Line Amount")
            {
                Caption = 'Line Amount';
            }
            column(type; Type)
            {
                Caption = 'Type';
            }
            column(itemNo; "No.")
            {
                Caption = 'Item Number';
            }

            filter(documentTypeFilter; "Document Type")
            {
            }
            filter(invoiceFilter; "Document No.")
            {
            }
        }
    }
}
