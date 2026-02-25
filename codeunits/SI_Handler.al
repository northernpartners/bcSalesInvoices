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
    /// Gets full details of a drafted invoice including all line items and optional dimensions.
    /// POST endpoint helper procedure.
    /// </summary>
    local procedure GetDraftInvoiceDetails(InObj: JsonObject): Text
    var
        InvoiceIdToken: JsonToken;
        DimensionsToken: JsonToken;
        InvoiceId: Code[20];
        SalesHeader: Record "Sales Header";
        DimensionArray: JsonArray;
    begin
        if not InObj.Get('invoiceId', InvoiceIdToken) or not InvoiceIdToken.IsValue() then
            exit(CreateErrorResponse('Missing or invalid "invoiceId" field.'));

        InvoiceId := CopyStr(InvoiceIdToken.AsValue().AsText(), 1, MaxStrLen(InvoiceId));

        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Invoice);
        SalesHeader.SetRange("No.", InvoiceId);
        SalesHeader.SetRange(Status, SalesHeader.Status::Open);

        if not SalesHeader.FindFirst() then
            exit(CreateErrorResponse('Invoice not found', 'The requested draft invoice does not exist.'));

        // Extract optional dimensions array
        if InObj.Get('dimensions', DimensionsToken) and DimensionsToken.IsArray() then
            DimensionArray := DimensionsToken.AsArray()
        else
            Clear(DimensionArray);

        exit(CreateInvoiceDetailObject(SalesHeader, DimensionArray));
    end;

    /// <summary>
    /// Gets full details of a posted invoice including all line items and optional dimensions.
    /// POST endpoint helper procedure.
    /// </summary>
    local procedure GetPostedInvoiceDetails(InObj: JsonObject): Text
    var
        InvoiceIdToken: JsonToken;
        DimensionsToken: JsonToken;
        InvoiceId: Code[20];
        SalesInvoiceHeader: Record "Sales Invoice Header";
        DimensionArray: JsonArray;
    begin
        if not InObj.Get('invoiceId', InvoiceIdToken) or not InvoiceIdToken.IsValue() then
            exit(CreateErrorResponse('Missing or invalid "invoiceId" field.'));

        InvoiceId := CopyStr(InvoiceIdToken.AsValue().AsText(), 1, MaxStrLen(InvoiceId));

        SalesInvoiceHeader.SetRange("No.", InvoiceId);

        if not SalesInvoiceHeader.FindFirst() then
            exit(CreateErrorResponse('Invoice not found', 'The requested posted invoice does not exist.'));

        // Extract optional dimensions array
        if InObj.Get('dimensions', DimensionsToken) and DimensionsToken.IsArray() then
            DimensionArray := DimensionsToken.AsArray()
        else
            Clear(DimensionArray);

        exit(CreatePostedInvoiceDetailObject(SalesInvoiceHeader, DimensionArray));
    end;

    /// <summary>
    /// Creates a detailed invoice JSON object including all line items and optional dimensions for posted invoices.
    /// </summary>
    local procedure CreatePostedInvoiceDetailObject(SalesInvoiceHeader: Record "Sales Invoice Header"; DimensionArray: JsonArray): Text
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

        // Add dimensions if requested
        if DimensionArray.Count() > 0 then
            Result.Add('dimensions', GetInvoiceDimensions(SalesInvoiceHeader."No.", 'SalesInvoiceHeader', DimensionArray));

        Result.WriteTo(OutTxt);
        exit(OutTxt);
    end;

    /// <summary>
    /// Creates a detailed invoice JSON object including all line items and optional dimensions.
    /// </summary>
    local procedure CreateInvoiceDetailObject(SalesHeader: Record "Sales Header"; DimensionArray: JsonArray): Text
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

        // Add dimensions if requested
        if DimensionArray.Count() > 0 then
            Result.Add('dimensions', GetInvoiceDimensions(SalesHeader."No.", 'SalesHeader', DimensionArray));

        Result.WriteTo(OutTxt);
        exit(OutTxt);
    end;

    /// <summary>
    /// Retrieves dimension values for an invoice, filtered by requested dimension codes.
    /// </summary>
    local procedure GetInvoiceDimensions(DocumentNo: Code[20]; TableId: Text; RequestedDimensions: JsonArray): JsonArray
    var
        SalesHeader: Record "Sales Header";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        DimensionSetEntry: Record "Dimension Set Entry";
        DimensionSetId: Integer;
        DimToken: JsonToken;
        DimensionArray: JsonArray;
        DimensionObject: JsonObject;
    begin
        // Get the Dimension Set ID from the appropriate table
        case TableId of
            'SalesHeader':
                begin
                    SalesHeader.Get(SalesHeader."Document Type"::Invoice, DocumentNo);
                    DimensionSetId := SalesHeader."Dimension Set ID";
                end;
            'SalesInvoiceHeader':
                begin
                    SalesInvoiceHeader.Get(DocumentNo);
                    DimensionSetId := SalesInvoiceHeader."Dimension Set ID";
                end;
            else
                exit(DimensionArray); // Return empty array if table not recognized
        end;

        // Query Dimension Set Entry for the document's dimension set
        DimensionSetEntry.SetRange("Dimension Set ID", DimensionSetId);

        if DimensionSetEntry.FindSet() then
            repeat
                // If specific dimensions requested, only include those
                if RequestedDimensions.Count() > 0 then begin
                    if IsDimensionInArray(DimensionSetEntry."Dimension Code", RequestedDimensions) then begin
                        Clear(DimensionObject);
                        DimensionObject.Add('code', DimensionSetEntry."Dimension Code");
                        DimensionObject.Add('value', DimensionSetEntry."Dimension Value Code");
                        DimensionArray.Add(DimensionObject);
                    end;
                end else begin
                    // If no specific dimensions, include all
                    Clear(DimensionObject);
                    DimensionObject.Add('code', DimensionSetEntry."Dimension Code");
                    DimensionObject.Add('value', DimensionSetEntry."Dimension Value Code");
                    DimensionArray.Add(DimensionObject);
                end;
            until DimensionSetEntry.Next() = 0;

        exit(DimensionArray);
    end;

    /// <summary>
    /// Checks if a dimension code exists in the requested dimensions array.
    /// </summary>
    local procedure IsDimensionInArray(DimensionCode: Code[20]; DimensionArray: JsonArray): Boolean
    var
        i: Integer;
        DimToken: JsonToken;
    begin
        for i := 0 to DimensionArray.Count() - 1 do begin
            DimensionArray.Get(i, DimToken);
            if DimToken.IsValue() and (DimToken.AsValue().AsText() = DimensionCode) then
                exit(true);
        end;
        exit(false);
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
