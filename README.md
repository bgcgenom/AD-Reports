# AD Reports

PowerShell scripts for Active Directory reporting and administration.

## Export-ADUsersByOU.ps1

Generates an HTML and CSV report of Active Directory users grouped by Organizational Unit (OU).

### Features

* Interactive Active Directory OU tree selection
* Recursive traversal of child OUs
* HTML report grouped by OU
* CSV export for Excel analysis
* Displays users directly assigned to each OU
* Includes:

  * Display Name
  * SamAccountName
  * Email Address
  * Enabled Status
  * Department
  * Title

### Requirements

* Windows PowerShell 5.1 or PowerShell 7
* RSAT Active Directory PowerShell Module
* Active Directory read permissions

### Usage

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

.\Export-ADUsersByOU.ps1
```

### Output

The script generates:

```text
AD_User_OU_Report\
├── AD_Users_By_OU_YYYYMMDD_HHMM.html
└── AD_Users_By_OU_YYYYMMDD_HHMM.csv
```

### Example Use Cases

* Departmental user audits
* OU cleanup projects
* Security reviews
* Organizational reporting
* Active Directory documentation

### Future Enhancements

* Computer reports by OU
* Group reports by OU
* Disabled account reporting
* Manager hierarchy reporting
* Excel export with formatting
