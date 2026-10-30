namespace System.Security.AccessControl;

using System.Azure.Identity;
using System.Environment;
using System.Reflection;
using System.Security.User;

report 8314 "Effective Permissions Overview"
{
    ApplicationArea = All;
    Caption = 'Effective Permissions Overview (Excel)';
    DefaultRenderingLayout = ExcelLayout;
    UsageCategory = ReportsAndAnalysis;
    AllowScheduling = true;

    dataset
    {
        dataitem(EffectivePermission; "Effective Permission Buffer")
        {
            RequestFilterFields = "User Name", "Object Type", "Object ID", "Read Permission", "Insert Permission", "Modify Permission", "Delete Permission";

            column(Company; Company)
            {
                IncludeCaption = true;
            }
            column(UserName; "User Name")
            {
                IncludeCaption = true;
            }
            column(ObjectType; "Object Type")
            {
                IncludeCaption = true;
            }
            column(ObjectID; "Object ID")
            {
                IncludeCaption = true;
            }
            column(ObjectName; "Object Name")
            {
                IncludeCaption = true;
            }
            column(ReadPermission; "Read Permission")
            {
                IncludeCaption = true;
            }
            column(InsertPermission; "Insert Permission")
            {
                IncludeCaption = true;
            }
            column(ModifyPermission; "Modify Permission")
            {
                IncludeCaption = true;
            }
            column(DeletePermission; "Delete Permission")
            {
                IncludeCaption = true;
            }
            column(ExecutePermission; "Execute Permission")
            {
                IncludeCaption = true;
            }

            trigger OnPreDataItem()
            begin
                LoadData();
            end;
        }
    }

    requestpage
    {
        AboutTitle = 'About Effective Permissions Overview';
        AboutText = 'Audit the effective permissions each user has across objects in your system, as well as which assigned permission set contributed to each effective permission. Effective permissions show the final access to objects and data, helping you verify access and troubleshoot permission issues.';
        SaveValues = true;

        layout
        {
            area(Content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    field(RequestCompanyFilter; CompanyFilter)
                    {
                        ApplicationArea = All;
                        Caption = 'Company';
                        TableRelation = Company;
                        ToolTip = 'Specifies the company for which effective permissions will be calculated.';
                    }
                    // Used to set a report header across multiple languages
                    field(RequestEffectivePermissionsFilterHeading; EffectivePermissionsFilterHeading)
                    {
                        ApplicationArea = All;
                        Caption = 'Effective Permissions Filter';
                        ToolTip = 'Specifies the effective permissions filters applied to this report.';
                        Visible = false;
                    }
                    field(RequestCompanyFilterHeading; CompanyFilterHeading)
                    {
                        ApplicationArea = All;
                        Caption = 'Company Filter';
                        ToolTip = 'Specifies the company filter applied to this report.';
                        Visible = false;
                    }
                }
            }
        }

        trigger OnClosePage()
        begin
            UpdateRequestPageFilterValues();
        end;
    }

    rendering
    {
        layout(ExcelLayout)
        {
            Caption = 'Effective Permissions Overview Excel';
            Type = Excel;
            LayoutFile = './System/Permissions/EffectivePermissionsOverview.xlsx';
            Summary = 'Built in layout for the Effective Permissions Overview Excel report.';
        }
    }

    labels
    {
        EffectPermOverviewLbl = 'Effective Permissions Overview';
        EffectPermsOverviewPrintLbl = 'Effective Perms. (Print)', MaxLength = 31, Comment = 'Excel worksheet name.';
        EffectPermOverviewAnalysisLbl = 'Effective Perms. (Analysis)', MaxLength = 31, Comment = 'Excel worksheet name.';
        DataRetrievedLbl = 'Data retrieved:';
        // About the report labels
        AboutTheReportLbl = 'About the report';
        EnvironmentLbl = 'Environment';
        CompanyLbl = 'Company';
        UserLbl = 'User';
        RunOnLbl = 'Run on';
        ReportNameLbl = 'Report name';
        DocumentationLbl = 'Documentation';
    }

    var
        TempUser: Record User temporary;
        EffectivePermissionsMgt: Codeunit "Effective Permissions Mgt.";
        CompanyFilter: Text[30];
        EffectivePermissionsFilter: Text;
        EffectivePermissionsFilterHeading: Text;
        CompanyFilterHeading: Text;

    trigger OnInitReport()
    begin
        CompanyFilter := CopyStr(CompanyName(), 1, MaxStrLen(CompanyFilter));
    end;

    trigger OnPreReport()
    begin
        EffectivePermissionsMgt.DisallowViewingEffectivePermissionsForNonAdminUsers(UserSecurityId());

        UpdateRequestPageFilterValues();
    end;

    procedure SetCompanyFilter(NewCompanyFilter: Text[30])
    begin
        CompanyFilter := NewCompanyFilter;
    end;

    local procedure LoadUsers()
    var
        User: Record User;
        UserProperty: Record "User Property";
        EnvironmentInfo: Codeunit "Environment Information";
        UserSelection: Codeunit "User Selection";
        AzureADUserManagement: Codeunit "Azure AD User Management";
        IsSaaS: Boolean;
    begin
        IsSaaS := EnvironmentInfo.IsSaaS();
        TempUser.Reset();
        TempUser.DeleteAll();
        UserProperty.SetLoadFields("Authentication Object ID");
        UserSelection.FilterSystemUserAndGroupUsers(User);
        User.SetLoadFields("User Security ID", "User Name");
        if User.FindSet() then begin
            repeat
                if IsSaaS then begin
                    if not AzureADUserManagement.IsUserDelegated(User."User Security ID") then begin
                        if (not UserProperty.Get(User."User Security ID")) or (UserProperty."Authentication Object ID" = '') then begin
                            continue;
                        end;
                    end;
                end;
                TempUser."User Security ID" := User."User Security ID";
                TempUser."User Name" := User."User Name";
                TempUser.Insert();
            until User.Next() = 0;
        end;
    end;

    local procedure LoadData()
    var
        AllObj: Record AllObj;
        TempPermission: Record Permission temporary;
    begin
        LoadUsers();
        TempUser.Reset();
        TempUser.SetFilter("User Name", EffectivePermission.GetFilter("User Name"));
        if TempUser.IsEmpty() then begin
            exit;
        end;

        AllObj.SetLoadFields("Object Type", "Object ID", "Object Name");
        if EffectivePermission.GetFilter("Object Type") <> '' then
            EffectivePermission.CopyFilter("Object Type", AllObj."Object Type");
        AllObj.SetFilter("Object ID", EffectivePermission.GetFilter("Object ID"));
        if not AllObj.FindSet() then begin
            exit;
        end;
        repeat
            TempUser.FindSet();
            repeat
                EffectivePermissionsMgt.PopulatePermissionRecordWithEffectivePermissionsForObject(
                    TempPermission, TempUser."User Security ID", CompanyFilter, AllObj."Object Type", AllObj."Object ID");

                EffectivePermission.Init();
                EffectivePermission.Company := CompanyFilter;
                EffectivePermission."User Name" := TempUser."User Name";
                EffectivePermission."User Security ID" := TempUser."User Security ID";
                EffectivePermission."Object Type" := AllObj."Object Type";
                EffectivePermission."Object ID" := AllObj."Object ID";
                EffectivePermission."Object Name" := AllObj."Object Name";
                EffectivePermission."Read Permission" := TempPermission."Read Permission";
                EffectivePermission."Insert Permission" := TempPermission."Insert Permission";
                EffectivePermission."Modify Permission" := TempPermission."Modify Permission";
                EffectivePermission."Delete Permission" := TempPermission."Delete Permission";
                EffectivePermission."Execute Permission" := TempPermission."Execute Permission";
                if EffectivePermission.Insert() then begin
                end;
            until TempUser.Next() = 0;
        until AllObj.Next() = 0;
        if EffectivePermission.FindFirst() then begin
        end;
    end;

    // Ensures Layout Filter Headings are up to date
    local procedure UpdateRequestPageFilterValues()
    begin
        EffectivePermissionsFilter := EffectivePermission.GetFilters();
        if EffectivePermissionsFilter <> '' then
            EffectivePermissionsFilterHeading := EffectivePermission.TableCaption + ': ' + EffectivePermissionsFilter
        else
            EffectivePermissionsFilterHeading := '';
        if CompanyFilter <> '' then
            CompanyFilterHeading := EffectivePermission.FieldCaption(Company) + ': ' + CompanyFilter;
    end;
}