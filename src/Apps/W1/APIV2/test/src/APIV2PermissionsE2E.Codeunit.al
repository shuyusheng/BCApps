codeunit 139929 "APIV2 - Permissions E2E"
{
    Subtype = Test;
    TestHttpRequestPolicy = AllowAllOutboundRequests;
    TestPermissions = Disabled;

    var
        LibraryPermissions: Codeunit "Library - Permissions";
        LibraryUtility: Codeunit "Library - Utility";
        LibraryGraphMgt: Codeunit "Library - Graph Mgt";
        EnvironmentInfoTestLibrary: Codeunit "Environment Info Test Library";
        Assert: Codeunit "Assert";
        NullGuid: Guid;
        WrongPropertyValueErr: Label 'Incorrect property value for %1.', Comment = '%1 = Property name';

    [Test]
    procedure EffectivePermissionFilterByUserObject()
    var
        TenantPermissionSet: Record "Tenant Permission Set";
        TenantPermission: array[2] of Record "Tenant Permission";
        AccessControl: Record "Access Control";
        AllObj: Record AllObj;
        UriBuilder: Codeunit "Uri Builder";
        Uri: Codeunit Uri;
        ResponseText, ValueText : Text;
    begin
        // [SCENARIO] Effective permission correctly filters response by user and object filters
        EnvironmentInfoTestLibrary.SetTestabilitySoftwareAsAService(false);

        // [GIVEN] A permission set with a wildcard permission
        LibraryPermissions.CreateTenantPermissionSet(TenantPermissionSet, LibraryUtility.GenerateGUID(), NullGuid);

        // [GIVEN] Two permissions for the same permission set
        AllObj.Get(AllObj."Object Type"::Page, Page::"Customer Card");
        TenantPermission[1].Init();
        TenantPermission[1]."App ID" := NullGuid;
        TenantPermission[1]."Role ID" := TenantPermissionSet."Role ID";
        TenantPermission[1]."Object Type" := AllObj."Object Type";
        TenantPermission[1]."Object ID" := AllObj."Object ID";
        TenantPermission[1]."Read Permission" := TenantPermission[1]."Read Permission"::" ";
        TenantPermission[1]."Insert Permission" := TenantPermission[1]."Insert Permission"::" ";
        TenantPermission[1]."Modify Permission" := TenantPermission[1]."Modify Permission"::" ";
        TenantPermission[1]."Delete Permission" := TenantPermission[1]."Delete Permission"::" ";
        TenantPermission[1]."Execute Permission" := TenantPermission[1]."Execute Permission"::Yes;
        TenantPermission[1].Insert();
        TenantPermission[2].Init();
        TenantPermission[2]."App ID" := NullGuid;
        TenantPermission[2]."Role ID" := TenantPermissionSet."Role ID";
        TenantPermission[2]."Object Type" := AllObj."Object Type";
        TenantPermission[2]."Object ID" := Page::"Vendor Card";
        TenantPermission[2]."Read Permission" := TenantPermission[2]."Read Permission"::" ";
        TenantPermission[2]."Insert Permission" := TenantPermission[2]."Insert Permission"::" ";
        TenantPermission[2]."Modify Permission" := TenantPermission[2]."Modify Permission"::" ";
        TenantPermission[2]."Delete Permission" := TenantPermission[2]."Delete Permission"::" ";
        TenantPermission[2]."Execute Permission" := TenantPermission[2]."Execute Permission"::Yes;
        TenantPermission[2].Insert();

        // [GIVEN] The permission set is assigned to the current user in the current company
        AccessControl.Init();
        AccessControl."User Security ID" := UserSecurityId();
        AccessControl."Role ID" := TenantPermissionSet."Role ID";
        AccessControl.Scope := AccessControl.Scope::Tenant;
        AccessControl."Company Name" := CopyStr(CompanyName, 1, MaxStrLen(AccessControl."Company Name"));
        AccessControl.Insert(true);

        // [WHEN] Retrieving effective permissions for the current user and object
        LibraryGraphMgt.EnsureWebServiceExist('EffectivePermissions', Page::"APIV2 - Effective Permissions");
        UriBuilder.Init(LibraryGraphMgt.CreateTargetURL('', Page::"APIV2 - Effective Permissions", 'EffectivePermissions'));
        UriBuilder.AddODataQueryParameter('$filter', 'userName eq ''' + UserId() + ''' and objectType eq ''' + Format(AllObj."Object Type") + ''' and objectID eq ' + Format(AllObj."Object ID"));
        UriBuilder.GetUri(Uri);
        LibraryGraphMgt.GetFromWebService(ResponseText, Uri.GetAbsoluteUri());

        // [THEN] The response should only contain the effective permissions for the filtered user and object
        Assert.IsTrue(LibraryGraphMgt.GetPropertyValueFromJSON(ResponseText, 'value', ResponseText), 'Could not find values collection in response');
        ValueText := LibraryGraphMgt.GetObjectFromCollectionByIndex(ResponseText, 0);
        VerifyPropertyInJSON(ValueText, 'userName', UserId());
        VerifyPropertyInJSON(ValueText, 'objectType', Format(AllObj."Object Type"));
        VerifyPropertyInJSON(ValueText, 'objectID', Format(AllObj."Object ID"));
        VerifyPropertyInJSON(ValueText, 'readPermission', Format(TenantPermission[1]."Read Permission"));
        VerifyPropertyInJSON(ValueText, 'insertPermission', Format(TenantPermission[1]."Insert Permission"));
        VerifyPropertyInJSON(ValueText, 'modifyPermission', Format(TenantPermission[1]."Modify Permission"));
        VerifyPropertyInJSON(ValueText, 'deletePermission', Format(TenantPermission[1]."Delete Permission"));
        VerifyPropertyInJSON(ValueText, 'executePermission', Format(TenantPermission[1]."Execute Permission"));

        asserterror LibraryGraphMgt.GetObjectFromCollectionByIndex(ResponseText, 1);
    end;

    [Test]
    procedure EffectivePermissionErrorOnNoFilter()
    var
        UriBuilder: Codeunit "Uri Builder";
        Uri: Codeunit Uri;
        ResponseText: Text;
    begin
        // [SCENARIO] Effective permission returns an error when no filters are applied
        EnvironmentInfoTestLibrary.SetTestabilitySoftwareAsAService(false);

        // [WHEN] Retrieving effective permissions without any filters
        LibraryGraphMgt.EnsureWebServiceExist('EffectivePermissions', Page::"APIV2 - Effective Permissions");
        UriBuilder.Init(LibraryGraphMgt.CreateTargetURL('', Page::"APIV2 - Effective Permissions", 'EffectivePermissions'));
        UriBuilder.GetUri(Uri);

        // [THEN] An error is returned
        asserterror LibraryGraphMgt.GetFromWebService(ResponseText, Uri.GetAbsoluteUri());
    end;

    local procedure VerifyPropertyInJSON(JSON: Text; PropertyName: Text; ExpectedValue: Text)
    var
        PropertyValue: Text;
    begin
        LibraryGraphMgt.GetObjectIDFromJSON(JSON, PropertyName, PropertyValue);
        Assert.AreEqual(ExpectedValue, PropertyValue, StrSubstNo(WrongPropertyValueErr, PropertyName));
    end;
}