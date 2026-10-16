// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.API.V2;

using System.Environment;
using System.Reflection;
using System.Security.AccessControl;

page 30253 "APIV2 - Effective Permissions"
{
    APIGroup = 'automation';
    APIPublisher = 'microsoft';
    APIVersion = 'v2.0';
    EntityCaption = 'Effective Permission';
    EntitySetCaption = 'Effective Permissions';
    EntityName = 'effectivePermission';
    EntitySetName = 'effectivePermissions';
    Editable = false;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DataAccessIntent = ReadOnly;
    PageType = API;
    SourceTable = "Effective Permission Buffer";
    ODataKeyFields = "Object Type", "Object ID", Company, "User Name";

    layout
    {
        area(Content)
        {

            repeater(General)
            {
                field(company; Rec.Company)
                {
                    Caption = 'Company';
                }
                field(userName; Rec."User Name")
                {
                    Caption = 'User Name';
                }
                field(objectType; Rec."Object Type")
                {
                    Caption = 'Object Type';
                }
                field(objectID; Rec."Object ID")
                {
                    Caption = 'Object ID';
                }
                field(objectName; Rec."Object Name")
                {
                    Caption = 'Object Name';
                }
                field(readPermission; Rec."Read Permission")
                {
                    Caption = 'Read Permission';
                }
                field(insertPermission; Rec."Insert Permission")
                {
                    Caption = 'Insert Permission';
                }
                field(modifyPermission; Rec."Modify Permission")
                {
                    Caption = 'Modify Permission';
                }
                field(deletePermission; Rec."Delete Permission")
                {
                    Caption = 'Delete Permission';
                }
                field(executePermission; Rec."Execute Permission")
                {
                    Caption = 'Execute Permission';
                }
            }
        }
    }

    var
        MissingFilterErr: Label 'You must filter by either User ID/Name or Object ID when accessing this page.';

    trigger OnOpenPage()
    var
        CompanyRec: Record Company;
        User: Record User;
        TempUser: Record User temporary;
        AllObj: Record AllObj;
#pragma warning disable AL0432
        TempPermission: Record Permission temporary;
#pragma warning restore AL0432
        EffectivePermissionsMgt: Codeunit "Effective Permissions Mgt.";
        TargetCompany: Text[30];
    begin
        if (Rec.GetFilter("User Name") = '') and
          (Rec.GetFilter("User Security ID") = '') and
          (Rec.GetFilter("Object ID") = '') then
            Error(MissingFilterErr);

        CompanyRec.SetFilter(Name, Rec.GetFilter(Company));
        if CompanyRec.FindFirst() then
            TargetCompany := CompanyRec.Name
        else
            TargetCompany := CopyStr(CompanyName(), 1, MaxStrLen(TargetCompany));

        User.SetLoadFields("User Security ID", "User Name");
        User.SetFilter("User Name", Rec.GetFilter("User Name"));
        User.SetFilter("User Security ID", Rec.GetFilter("User Security ID"));
        if not User.FindSet() then
            exit;
        repeat
            TempUser."User Security ID" := User."User Security ID";
            TempUser."User Name" := User."User Name";
            TempUser.Insert();
        until User.Next() = 0;

        AllObj.SetLoadFields("Object Type", "Object ID", "Object Name");
        AllObj.SetFilter("Object Type", Rec.GetFilter("Object Type"));
        AllObj.SetFilter("Object ID", Rec.GetFilter("Object ID"));
        if not AllObj.FindSet() then
            exit;
        repeat
            TempUser.FindSet();
            repeat
                EffectivePermissionsMgt.PopulatePermissionRecordWithEffectivePermissionsForObject(
                    TempPermission, TempUser."User Security ID", TargetCompany, AllObj."Object Type", AllObj."Object ID");

                Rec.Init();
                Rec.Company := TargetCompany;
                Rec."User Name" := TempUser."User Name";
                Rec."User Security ID" := TempUser."User Security ID";
                Rec."Object Type" := AllObj."Object Type";
                Rec."Object ID" := AllObj."Object ID";
                Rec."Object Name" := AllObj."Object Name";
                Rec."Read Permission" := TempPermission."Read Permission";
                Rec."Insert Permission" := TempPermission."Insert Permission";
                Rec."Modify Permission" := TempPermission."Modify Permission";
                Rec."Delete Permission" := TempPermission."Delete Permission";
                Rec."Execute Permission" := TempPermission."Execute Permission";
                if Rec.Insert() then;
            until TempUser.Next() = 0;
        until AllObj.Next() = 0;
    end;
}