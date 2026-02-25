codeunit 50200 "SI Handler"
{
    trigger OnRun()
    begin
    end;

    /// <summary>
    /// Gets a list of the 50 latest drafted (non-posted) sales invoices.
    /// Can be called with optional id parameter to get full details including lines.
    /// </summary>
    /// <param name="id">Optional invoice ID to fetch full details. If empty, returns list of 50 latest.</param>
    /// <returns>JSON text representation of invoice data</returns>
    procedure GetDrafted(id: Code[20]): Text
    var
        SalesHeader: Record "Sales Header";
        InvoiceList: JsonArray;
        InvoiceObject: JsonObject;
        i: Integer;
        OutTxt: Text;
    begin
        if id <> '' then
            exit(GetDraftedDetail(id));

        // List 50 latest drafted invoices (Status = Open means not posted)
        SalesHeader.SetCurrentKey("No.");
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Invoice);
        SalesHeader.SetRange(Status, SalesHeader.Status::Open);
        SalesHeader.Ascending(false);

        Clear(InvoiceList);
        i := 0;
        if SalesHeader.FindSet() then
            repeat
                if i >= 50 then
                    break;

                CreateInvoiceObject(SalesHeader, InvoiceObject);
                InvoiceList.Add(InvoiceObject);
                Clear(InvoiceObject);
                i += 1;
            until SalesHeader.Next() = 0;

        InvoiceList.WriteTo(OutTxt);
        exit(OutTxt);
    end;

    /// <summary>
    /// Gets a list of the 50 latest posted sales invoices.
    /// Can be called with optional id parameter to get full details including lines.
    /// </summary>
    /// <param name="id">Optional invoice ID to fetch full details. If empty, returns list of 50 latest.</param>
    /// <returns>JSON text representation of invoice data</returns>
    procedure GetPosted(id: Code[20]): Text
    var
        SalesHeader: Record "Sales Header";
        InvoiceList: JsonArray;
        InvoiceObject: JsonObject;
        i: Integer;
        OutTxt: Text;
    begin
        if id <> '' then
            exit(GetPostedDetail(id));

        // List 50 latest posted invoices
        SalesHeader.SetCurrentKey("No.");
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Invoice);
        SalesHeader.SetRange(Status, SalesHeader.Status::Released);
        SalesHeader.Ascending(false);

        Clear(InvoiceList);
        i := 0;
        if SalesHeader.FindSet() then
            repeat
                if i >= 50 then
                    break;

                CreateInvoiceObject(SalesHeader, InvoiceObject);
                InvoiceList.Add(InvoiceObject);
                Clear(InvoiceObject);
                i += 1;
            until SalesHeader.Next() = 0;

        InvoiceList.WriteTo(OutTxt);
        exit(OutTxt);
    end;

    /// <summary>
    /// Gets full details of a drafted invoice including all line items.
    /// </summary>
    /// <param name="InvoiceId">The invoice number to retrieve</param>
    /// <returns>JSON text with invoice details and lines, or error message</returns>
    local procedure GetDraftedDetail(InvoiceId: Code[20]): Text
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Invoice);
        SalesHeader.SetRange("No.", InvoiceId);
        SalesHeader.SetRange(Status, SalesHeader.Status::Open);

        if not SalesHeader.FindFirst() then
            exit(CreateErrorResponse('Invoice not found', 'The requested draft invoice does not exist.'));

        exit(CreateInvoiceDetailObject(SalesHeader));
    end;

    /// <summary>
    /// Gets full details of a posted invoice including all line items.
    /// </summary>
    /// <param name="InvoiceId">The invoice number to retrieve</param>
    /// <returns>JSON text with invoice details and lines, or error message</returns>
    local procedure GetPostedDetail(InvoiceId: Code[20]): Text
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Invoice);
        SalesHeader.SetRange("No.", InvoiceId);
        SalesHeader.SetRange(Status, SalesHeader.Status::Released);

        if not SalesHeader.FindFirst() then
            exit(CreateErrorResponse('Invoice not found', 'The requested posted invoice does not exist.'));

        exit(CreateInvoiceDetailObject(SalesHeader));
    end;

    /// <summary>
    /// Creates a basic invoice JSON object with header information only.
    /// </summary>
    local procedure CreateInvoiceObject(SalesHeader: Record "Sales Header"; var Result: JsonObject)
    begin
        Result.Add('id', SalesHeader."No.");
        Result.Add('invoiceNumber', SalesHeader."No.");
        Result.Add('customerName', SalesHeader."Bill-to Name");
        Result.Add('customerId', SalesHeader."Bill-to Customer No.");
        Result.Add('amount', SalesHeader."Amount Including VAT");
        Result.Add('dueDate', Format(SalesHeader."Due Date"));
        Result.Add('documentDate', Format(SalesHeader."Document Date"));
        Result.Add('status', Format(SalesHeader.Status));
    end;

    /// <summary>
    /// Creates a detailed invoice JSON object including all line items.
    /// </summary>
    local procedure CreateInvoiceDetailObject(SalesHeader: Record "Sales Header"): Text
    var
        SalesLine: Record "Sales Line";
        LineArray: JsonArray;
        LineObject: JsonObject;
        Result: JsonObject;
        OutTxt: Text;
    begin
        Result.Add('id', SalesHeader."No.");
        Result.Add('invoiceNumber', SalesHeader."No.");
        Result.Add('customerName', SalesHeader."Bill-to Name");
        Result.Add('customerId', SalesHeader."Bill-to Customer No.");
        Result.Add('amount', SalesHeader."Amount Including VAT");
        Result.Add('amountExcludingVat', SalesHeader.Amount);
        Result.Add('vat', SalesHeader."Amount Including VAT" - SalesHeader.Amount);
        Result.Add('dueDate', Format(SalesHeader."Due Date"));
        Result.Add('documentDate', Format(SalesHeader."Document Date"));
        Result.Add('status', Format(SalesHeader.Status));
        Result.Add('description', SalesHeader."Your Reference");
        Result.Add('currencyCode', SalesHeader."Currency Code");

        // Add line items
        Clear(LineArray);
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindSet() then
            repeat
                LineObject.Add('lineNumber', SalesLine."Line No.");
                LineObject.Add('description', SalesLine.Description);
                LineObject.Add('quantity', SalesLine.Quantity);
                LineObject.Add('unitPrice', SalesLine."Unit Price");
                LineObject.Add('lineAmount', SalesLine."Line Amount");
                LineArray.Add(LineObject);
                Clear(LineObject);
            until SalesLine.Next() = 0;

        Result.Add('lines', LineArray);
        Result.WriteTo(OutTxt);
        exit(OutTxt);
    end;

    /// <summary>
    /// Creates a standardized error response JSON object.
    /// </summary>
    local procedure CreateErrorResponse(ErrorCode: Text; ErrorMessage: Text): Text
    var
        Result: JsonObject;
        OutTxt: Text;
    begin
        Result.Add('error', true);
        Result.Add('code', ErrorCode);
        Result.Add('message', ErrorMessage);
        Result.WriteTo(OutTxt);
        exit(OutTxt);
    end;
}
