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
            'createDraft':
                exit(CreateDraftInvoice(InObj));
            else
                exit(CreateErrorResponse('Unknown action: ' + Action));
        end;
    end;

    /// <summary>
    /// Creates a new draft invoice with the provided parameters.
    /// Validates all required fields and returns the new invoice number or error.
    /// </summary>
    local procedure CreateDraftInvoice(InObj: JsonObject): Text
    var
        SalesHeader: Record "Sales Header";
        Customer: Record Customer;
        CustomerIdToken: JsonToken;
        DocumentDateToken: JsonToken;
        DueDateToken: JsonToken;
        CurrencyCodeToken: JsonToken;
        PaymentTermsCodeToken: JsonToken;
        CustomerId: Code[20];
        DocumentDate: Date;
        DueDate: Date;
        CurrencyCode: Code[10];
        PaymentTermsCode: Code[10];
        Result: JsonObject;
        OutTxt: Text;
    begin
        // Validate and extract customerId
        if not InObj.Get('customerId', CustomerIdToken) or not CustomerIdToken.IsValue() then
            exit(CreateErrorResponse('Missing or invalid "customerId" field.'));

        CustomerId := CopyStr(CustomerIdToken.AsValue().AsText(), 1, MaxStrLen(CustomerId));

        // Validate customer exists
        if not Customer.Get(CustomerId) then
            exit(CreateErrorResponse('Customer not found', 'The customer with ID "' + CustomerId + '" does not exist.'));

        // Validate and extract documentDate
        if not InObj.Get('documentDate', DocumentDateToken) or not DocumentDateToken.IsValue() then
            exit(CreateErrorResponse('Missing or invalid "documentDate" field.'));

        if not ParseDateISO(DocumentDateToken.AsValue().AsText(), DocumentDate) then
            exit(CreateErrorResponse('Invalid date format', 'documentDate must be in YYYY-MM-DD format.'));

        // Validate and extract dueDate
        if not InObj.Get('dueDate', DueDateToken) or not DueDateToken.IsValue() then
            exit(CreateErrorResponse('Missing or invalid "dueDate" field.'));

        if not ParseDateISO(DueDateToken.AsValue().AsText(), DueDate) then
            exit(CreateErrorResponse('Invalid date format', 'dueDate must be in YYYY-MM-DD format.'));

        // Validate and extract currencyCode
        if not InObj.Get('currencyCode', CurrencyCodeToken) or not CurrencyCodeToken.IsValue() then
            exit(CreateErrorResponse('Missing or invalid "currencyCode" field.'));

        CurrencyCode := CopyStr(CurrencyCodeToken.AsValue().AsText(), 1, MaxStrLen(CurrencyCode));

        // Extract paymentTermsCode (optional)
        if InObj.Get('paymentTermsCode', PaymentTermsCodeToken) and PaymentTermsCodeToken.IsValue() then
            PaymentTermsCode := CopyStr(PaymentTermsCodeToken.AsValue().AsText(), 1, MaxStrLen(PaymentTermsCode))
        else
            Clear(PaymentTermsCode);

        // Create the invoice
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Invoice;
        SalesHeader."No." := '';
        SalesHeader.Insert(true);

        // Set customer and dates
        SalesHeader.Validate("Sell-to Customer No.", CustomerId);
        SalesHeader.Validate("Document Date", DocumentDate);
        SalesHeader.Validate("Due Date", DueDate);
        SalesHeader.Validate("Currency Code", CurrencyCode);
        SalesHeader.Validate("Payment Terms Code", PaymentTermsCode);
        SalesHeader.Modify(true);

        // Build response
        Result.Add('success', true);
        Result.Add('message', 'Draft invoice created successfully');
        Result.Add('invoiceNumber', SalesHeader."No.");
        Result.Add('customerId', SalesHeader."Sell-to Customer No.");
        Result.Add('customerName', SalesHeader."Sell-to Customer Name");
        Result.Add('documentDate', FormatDateISO(SalesHeader."Document Date"));
        Result.Add('dueDate', FormatDateISO(SalesHeader."Due Date"));
        Result.Add('currencyCode', SalesHeader."Currency Code");
        Result.Add('paymentTermsCode', SalesHeader."Payment Terms Code");
        Result.Add('status', 'Open');
        Result.Add('amount', 0.00);

        Result.WriteTo(OutTxt);
        exit(OutTxt);
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
        Result.Add('dueDate', FormatDateISO(SalesInvoiceHeader."Due Date"));
        Result.Add('documentDate', FormatDateISO(SalesInvoiceHeader."Document Date"));
        Result.Add('status', 'Released');
        Result.Add('description', SalesInvoiceHeader."Your Reference");
        Result.Add('currencyCode', SalesInvoiceHeader."Currency Code");
        Result.Add('paymentTermsCode', SalesInvoiceHeader."Payment Terms Code");
        Result.Add('pdfUrl', GetPostedInvoicePdfUrl(SalesInvoiceHeader."No."));

        // Add line items
        Clear(LineArray);
        SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        if SalesInvoiceLine.FindSet() then
            repeat
                LineObject.Add('lineNumber', SalesInvoiceLine."Line No.");
                LineObject.Add('lineType', Format(SalesInvoiceLine.Type));
                LineObject.Add('itemNumber', SalesInvoiceLine."No.");
                LineObject.Add('description', SalesInvoiceLine.Description);
                LineObject.Add('quantity', SalesInvoiceLine.Quantity);
                LineObject.Add('unitOfMeasureCode', SalesInvoiceLine."Unit of Measure Code");
                LineObject.Add('unitPrice', SalesInvoiceLine."Unit Price");
                LineObject.Add('lineAmount', SalesInvoiceLine."Line Amount");

                // Add line dimensions if requested
                if DimensionArray.Count() > 0 then
                    LineObject.Add('lineDimensions', GetLineDimensions(SalesInvoiceLine."Dimension Set ID", DimensionArray));

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
        Result.Add('dueDate', FormatDateISO(SalesHeader."Due Date"));
        Result.Add('documentDate', FormatDateISO(SalesHeader."Document Date"));
        Result.Add('status', Format(SalesHeader.Status));
        Result.Add('description', SalesHeader."Your Reference");
        Result.Add('currencyCode', SalesHeader."Currency Code");
        Result.Add('paymentTermsCode', SalesHeader."Payment Terms Code");
        Result.Add('pdfUrl', '');

        // Add line items
        Clear(LineArray);
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindSet() then
            repeat
                LineObject.Add('lineNumber', SalesLine."Line No.");
                LineObject.Add('lineType', Format(SalesLine.Type));
                LineObject.Add('itemNumber', SalesLine."No.");
                LineObject.Add('description', SalesLine.Description);
                LineObject.Add('quantity', SalesLine.Quantity);
                LineObject.Add('unitOfMeasureCode', SalesLine."Unit of Measure Code");
                LineObject.Add('unitPrice', SalesLine."Unit Price");
                LineObject.Add('lineAmount', SalesLine."Line Amount");

                // Add line dimensions if requested
                if DimensionArray.Count() > 0 then
                    LineObject.Add('lineDimensions', GetLineDimensions(SalesLine."Dimension Set ID", DimensionArray));

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
    /// Formats a date in ISO 8601 format (YYYY-MM-DD).
    /// </summary>
    local procedure FormatDateISO(InputDate: Date): Text
    begin
        if InputDate = 0D then
            exit('');
        exit(Format(InputDate, 0, '<Year4>-<Month,2>-<Day,2>'));
    end;

    /// <summary>
    /// Parses a date string in ISO 8601 format (YYYY-MM-DD) to a Date value.
    /// </summary>
    local procedure ParseDateISO(DateString: Text; var OutputDate: Date): Boolean
    var
        Year: Integer;
        Month: Integer;
        Day: Integer;
        HyphenPos1: Integer;
        HyphenPos2: Integer;
        YearStr: Text;
        MonthStr: Text;
        DayStr: Text;
        RemainStr: Text;
    begin
        // Find first hyphen
        HyphenPos1 := StrPos(DateString, '-');
        if HyphenPos1 = 0 then
            exit(false);

        // Find second hyphen
        RemainStr := CopyStr(DateString, HyphenPos1 + 1);
        HyphenPos2 := StrPos(RemainStr, '-');
        if HyphenPos2 = 0 then
            exit(false);

        // Extract parts
        YearStr := CopyStr(DateString, 1, HyphenPos1 - 1);
        MonthStr := CopyStr(DateString, HyphenPos1 + 1, HyphenPos2 - 1);
        DayStr := CopyStr(DateString, HyphenPos1 + HyphenPos2 + 1);

        // Parse values
        if not Evaluate(Year, YearStr) or (Year < 1900) or (Year > 2099) then
            exit(false);

        if not Evaluate(Month, MonthStr) or (Month < 1) or (Month > 12) then
            exit(false);

        if not Evaluate(Day, DayStr) or (Day < 1) or (Day > 31) then
            exit(false);

        // Create the date
        OutputDate := DMY2Date(Day, Month, Year);
        exit(true);
    end;

    /// <summary>
    /// Constructs the PDF download URL for a posted invoice.
    /// Returns the OData endpoint URL to download the invoice PDF.
    /// </summary>
    local procedure GetPostedInvoicePdfUrl(InvoiceNumber: Code[20]): Text
    begin
        // URL pattern for downloading a posted Sales Invoice PDF in BC
        // The actual URL will be constructed by the client using their tenant/environment info
        exit('SalesInvoices/SalesInvoiceDocument/' + InvoiceNumber);
    end;

    /// <summary>
    /// Retrieves dimension values for a specific line, filtered by requested dimension codes.
    /// </summary>
    local procedure GetLineDimensions(DimensionSetId: Integer; RequestedDimensions: JsonArray): JsonArray
    var
        DimensionSetEntry: Record "Dimension Set Entry";
        DimensionArray: JsonArray;
        DimensionObject: JsonObject;
    begin
        if DimensionSetId = 0 then
            exit(DimensionArray); // Return empty array if no dimensions

        DimensionSetEntry.SetRange("Dimension Set ID", DimensionSetId);

        if DimensionSetEntry.FindSet() then
            repeat
                // Only include requested dimensions
                if RequestedDimensions.Count() > 0 then begin
                    if IsDimensionInArray(DimensionSetEntry."Dimension Code", RequestedDimensions) then begin
                        Clear(DimensionObject);
                        DimensionObject.Add('code', DimensionSetEntry."Dimension Code");
                        DimensionObject.Add('value', DimensionSetEntry."Dimension Value Code");
                        DimensionArray.Add(DimensionObject);
                    end;
                end;
            until DimensionSetEntry.Next() = 0;

        exit(DimensionArray);
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
