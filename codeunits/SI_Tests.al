codeunit 50201 "SI Tests"
{
    Subtype = Test;

    var
        Handler: Codeunit "SI Handler";

    [Test]
    procedure TestGetDraftedListReturnsJson()
    var
        Result: Text;
    begin
        // Given: Handler is ready
        // When: GetDrafted is called without id parameter
        Result := Handler.GetDrafted('');

        // Then: Result should be valid JSON array
        if Result = '' then
            Error('GetDrafted should return non-empty result');
        if StrPos(Result, '[') = 0 then
            Error('Result should be JSON array');
    end;

    [Test]
    procedure TestGetPostedListReturnsJson()
    var
        Result: Text;
    begin
        // Given: Handler is ready
        // When: GetPosted is called without id parameter
        Result := Handler.GetPosted('');

        // Then: Result should be valid JSON array
        if Result = '' then
            Error('GetPosted should return non-empty result');
        if StrPos(Result, '[') = 0 then
            Error('Result should be JSON array');
    end;

    [Test]
    procedure TestGetDraftedWithInvalidIdReturnsError()
    var
        Result: Text;
    begin
        // Given: An invalid invoice ID
        // When: GetDrafted is called with invalid ID
        Result := Handler.GetDrafted('INVALID-ID-12345');

        // Then: Result should contain error information
        if StrPos(Result, 'error') = 0 then
            Error('Result should contain error indicator');
        if StrPos(Result, 'Invoice not found') = 0 then
            Error('Result should contain error message');
    end;

    [Test]
    procedure TestGetPostedWithInvalidIdReturnsError()
    var
        Result: Text;
    begin
        // Given: An invalid invoice ID
        // When: GetPosted is called with invalid ID
        Result := Handler.GetPosted('INVALID-ID-12345');

        // Then: Result should contain error information
        if StrPos(Result, 'error') = 0 then
            Error('Result should contain error indicator');
        if StrPos(Result, 'Invoice not found') = 0 then
            Error('Result should contain error message');
    end;
}
