codeunit 50201 "SI Tests"
{
    Subtype = Test;

    var
        Handler: Codeunit "SI Handler";

    [Test]
    procedure TestProcessInvoiceWithGetDraftDetailsAction()
    var
        RequestBody: Text;
        Result: Text;
    begin
        // Given: A valid request for draft invoice details
        RequestBody := '{"action": "getDraftDetails", "invoiceId": "INVALID-TEST-ID"}';

        // When: ProcessInvoice is called
        Result := Handler.ProcessInvoice(RequestBody);

        // Then: Result should contain error response (no test invoice exists)
        if StrPos(Result, 'error') = 0 then
            Error('Result should contain error field');
    end;

    [Test]
    procedure TestProcessInvoiceWithGetPostedDetailsAction()
    var
        RequestBody: Text;
        Result: Text;
    begin
        // Given: A valid request for posted invoice details
        RequestBody := '{"action": "getPostedDetails", "invoiceId": "INVALID-TEST-ID"}';

        // When: ProcessInvoice is called
        Result := Handler.ProcessInvoice(RequestBody);

        // Then: Result should contain error response (no test invoice exists)
        if StrPos(Result, 'error') = 0 then
            Error('Result should contain error field');
    end;

    [Test]
    procedure TestProcessInvoiceWithInvalidAction()
    var
        RequestBody: Text;
        Result: Text;
    begin
        // Given: A request with invalid action
        RequestBody := '{"action": "invalidAction"}';

        // When: ProcessInvoice is called
        Result := Handler.ProcessInvoice(RequestBody);

        // Then: Result should contain error response
        if StrPos(Result, 'error') = 0 then
            Error('Result should contain error field for invalid action');
    end;

    [Test]
    procedure TestProcessInvoiceWithInvalidJson()
    var
        RequestBody: Text;
        Result: Text;
    begin
        // Given: Invalid JSON
        RequestBody := 'not valid json';

        // When: ProcessInvoice is called
        Result := Handler.ProcessInvoice(RequestBody);

        // Then: Result should contain error response
        if StrPos(Result, 'error') = 0 then
            Error('Result should contain error field for invalid JSON');
    end;
}
