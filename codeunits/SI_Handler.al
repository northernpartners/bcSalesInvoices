codeunit 50200 "SI Handler"
{
    trigger OnRun()
    begin
    end;

    /// <summary>
    /// POST endpoint for processing invoice operations.
    /// Used for business logic operations like approve, post, send, etc.
    /// </summary>
    [ServiceEnabled]
    procedure ProcessInvoice(requestBody: Text): Text
    var
        InObj: JsonObject;
        OutObj: JsonObject;
        OutTxt: Text;
    begin
        if not InObj.ReadFrom(requestBody) then
            exit(CreateErrorResponse('Invalid JSON in requestBody.'));

        exit(ProcessInvoiceOperation(InObj));
    end;

    /// <summary>
    /// Processes invoice operations based on the requested action.
    /// </summary>
    local procedure ProcessInvoiceOperation(InObj: JsonObject): Text
    var
        OutObj: JsonObject;
        OutTxt: Text;
        ActionToken: JsonToken;
        Action: Text;
    begin
        // Extract action parameter
        if not InObj.Get('action', ActionToken) or not ActionToken.IsValue() then
            exit(CreateErrorResponse('Missing or invalid "action" field.'));

        Action := ActionToken.AsValue().AsText();

        case Action of
            'getDraftDetails':
                exit(GetDraftInvoiceDetails(InObj));
            'getPostedDetails':
                exit(GetPostedInvoiceDetails(InObj));
            else
                exit(CreateErrorResponse('Unknown action: ' + Action));
        end;
    end;

    /// <summary>
    /// Gets full details of a drafted invoice including all line items.
    /// POST endpoint helper procedure.
    /// </summary>
    local procedure GetDraftInvoiceDetails(InObj: JsonObject): Text
    var
        InvoiceIdToken: JsonToken;
        InvoiceId: Code[20];
        SalesHeader: Record "Sales Header";
    begin
        if not InObj.Get('invoiceId', InvoiceIdToken) or not InvoiceIdToken.IsValue() then
            exit(CreateErrorResponse('Missing or invalid "invoiceId" field.'));

        InvoiceId := CopyStr(InvoiceIdToken.AsValue().AsText(), 1, MaxStrLen(InvoiceId));

        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Invoice);
        SalesHeader.SetRange("No.", InvoiceId);
        SalesHeader.SetRange(Status, SalesHeader.Status::Open);

        if not SalesHeader.FindFirst() then
            exit(CreateErrorResponse('Invoice not found', 'The requested draft invoice does not exist.'));

        exit(CreateInvoiceDetailObject(SalesHeader));
    end;

    /// <summary>
    /// Gets full details of a posted invoice including all line items.
    /// POST endpoint helper procedure.
    /// </summary>
    local procedure GetPostedInvoiceDetails(InObj: JsonObject): Text
    var
        InvoiceIdToken: JsonToken;
        InvoiceId: Code[20];
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
    begin
        if not InObj.Get('invoiceId', InvoiceIdToken) or not InvoiceIdToken.IsValue() then
            exit(CreateErrorResponse('Missing or invalid "invoiceId" field.'));

        InvoiceId := CopyStr(InvoiceIdToken.AsValue().AsText(), 1, MaxStrLen(InvoiceId));

        SalesInvoiceHeader.SetRange("No.", InvoiceId);

        if not SalesInvoiceHeader.FindFirst() then
            exit(CreateErrorResponse('Invoice not found', 'The requested posted invoice does not exist.'));

        exit(CreatePostedInvoiceDetailObject(SalesInvoiceHeader));
    end;

    /// <summary>
    /// Creates a detailed invoice JSON object including all line items for posted invoices.
    /// </summary>
    local procedure CreatePostedInvoiceDetailObject(SalesInvoiceHeader: Record "Sales Invoice Header"): Text
    var
        SalesInvoiceLine: Record "Sales Invoice Line";
        LineArray: JsonArray;
        LineObject: JsonObject;
        Result: JsonObject;
        OutTxt: Text;
    begin
        Result.Add('id', SalesInvoiceHeader."No.");
        Result.Add('invoiceNumber', SalesInvoiceHeader."No.");
        Result.Add('customerName', SalesInvoiceHeader."Bill-to Name");
        Result.Add('customerId', SalesInvoiceHeader."Bill-to Customer No.");
        Result.Add('amount', SalesInvoiceHeader."Amount Including VAT");
        Result.Add('amountExcludingVat', SalesInvoiceHeader.Amount);
        Result.Add('vat', SalesInvoiceHeader."Amount Including VAT" - SalesInvoiceHeader.Amount);
        Result.Add('dueDate', Format(SalesInvoiceHeader."Due Date"));
        Result.Add('documentDate', Format(SalesInvoiceHeader."Document Date"));
        Result.Add('status', 'Released');
        Result.Add('description', SalesInvoiceHeader."Your Reference");
        Result.Add('currencyCode', SalesInvoiceHeader."Currency Code");

        // Add line items
        Clear(LineArray);
        SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        if SalesInvoiceLine.FindSet() then
            repeat
                LineObject.Add('lineNumber', SalesInvoiceLine."Line No.");
                LineObject.Add('description', SalesInvoiceLine.Description);
                LineObject.Add('quantity', SalesInvoiceLine.Quantity);
                LineObject.Add('unitPrice', SalesInvoiceLine."Unit Price");
                LineObject.Add('lineAmount', SalesInvoiceLine."Line Amount");
                LineArray.Add(LineObject);
                Clear(LineObject);
            until SalesInvoiceLine.Next() = 0;

        Result.Add('lines', LineArray);
        Result.WriteTo(OutTxt);
        exit(OutTxt);
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

    /// <summary>
    /// Creates a standardized error response with just a message.
    /// </summary>
    local procedure CreateErrorResponse(ErrorMsg: Text): Text
    var
        Result: JsonObject;
        OutTxt: Text;
    begin
        Result.Add('success', false);
        Result.Add('error', ErrorMsg);
        Result.WriteTo(OutTxt);
        exit(OutTxt);
    end;
}
