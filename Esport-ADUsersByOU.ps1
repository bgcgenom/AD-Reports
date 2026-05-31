Import-Module ActiveDirectory
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ReportTitle = "AD Users by OU"
$OutputFolder = "$env:USERPROFILE\Desktop\AD_User_OU_Report"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmm"
$HtmlPath = Join-Path $OutputFolder "AD_Users_By_OU_$Timestamp.html"
$CsvPath  = Join-Path $OutputFolder "AD_Users_By_OU_$Timestamp.csv"

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

function Select-ADOUFromTree {
    $domain = Get-ADDomain
    $rootDN = $domain.DistinguishedName

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select Starting OU"
    $form.Size = New-Object System.Drawing.Size(700, 600)
    $form.StartPosition = "CenterScreen"

    $tree = New-Object System.Windows.Forms.TreeView
    $tree.Dock = "Fill"
    $tree.HideSelection = $false
    $tree.PathSeparator = "\"

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Dock = "Bottom"
    $okButton.Height = 35
    $okButton.Enabled = $false

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Dock = "Bottom"
    $cancelButton.Height = 35

    $selectedDN = $null

    function Add-ChildOUs {
        param(
            [System.Windows.Forms.TreeNode]$ParentNode,
            [string]$SearchBase
        )

        $childOUs = Get-ADOrganizationalUnit `
            -SearchBase $SearchBase `
            -SearchScope OneLevel `
            -LDAPFilter "(objectClass=organizationalUnit)" `
            -Properties DistinguishedName |
            Sort-Object Name

        foreach ($ou in $childOUs) {
            $node = New-Object System.Windows.Forms.TreeNode
            $node.Text = $ou.Name
            $node.Tag = $ou.DistinguishedName

            # Add dummy child so the node shows expandable
            $hasChildren = Get-ADOrganizationalUnit `
                -SearchBase $ou.DistinguishedName `
                -SearchScope OneLevel `
                -LDAPFilter "(objectClass=organizationalUnit)" `
                -ResultSetSize 1

            if ($hasChildren) {
                [void]$node.Nodes.Add("Loading...")
            }

            [void]$ParentNode.Nodes.Add($node)
        }
    }

    $rootNode = New-Object System.Windows.Forms.TreeNode
    $rootNode.Text = $domain.DNSRoot
    $rootNode.Tag = $rootDN
    [void]$tree.Nodes.Add($rootNode)

    Add-ChildOUs -ParentNode $rootNode -SearchBase $rootDN
    $rootNode.Expand()

    $tree.Add_BeforeExpand({
        param($sender, $e)

        if ($e.Node.Nodes.Count -eq 1 -and $e.Node.Nodes[0].Text -eq "Loading...") {
            $e.Node.Nodes.Clear()
            Add-ChildOUs -ParentNode $e.Node -SearchBase $e.Node.Tag
        }
    })

    $tree.Add_AfterSelect({
        $okButton.Enabled = $true
    })

    $okButton.Add_Click({
        if ($tree.SelectedNode) {
            $script:selectedDN = $tree.SelectedNode.Tag
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        }
    })

    $cancelButton.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })

    $form.Controls.Add($tree)
    $form.Controls.Add($okButton)
    $form.Controls.Add($cancelButton)

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $script:selectedDN
    }

    return $null
}

$StartDN = Select-ADOUFromTree

if (-not $StartDN) {
    Write-Host "No OU selected. Exiting."
    exit
}

$OUs = Get-ADOrganizationalUnit `
    -SearchBase $StartDN `
    -SearchScope Subtree `
    -LDAPFilter "(objectClass=organizationalUnit)" `
    -Properties DistinguishedName |
    Sort-Object DistinguishedName

$AllUsers = @()

$html = @"
<style>
body { font-family: Segoe UI, Arial; font-size: 12px; }
h1 { margin-bottom: 6px; }
h2 { margin-top: 28px; background: #f0f0f0; padding: 8px; border-left: 5px solid #666; }
table { border-collapse: collapse; width: 100%; margin-bottom: 24px; }
th { background: #e6e6e6; text-align: left; }
th, td { border: 1px solid #ccc; padding: 6px 8px; }
tr:nth-child(even) { background: #f7f7f7; }
.summary { margin-bottom: 20px; font-size: 13px; }
.empty { color: #777; font-style: italic; margin-bottom: 24px; }
</style>
<h1>$ReportTitle</h1>
<div class="summary">
<b>Starting OU:</b> $StartDN<br>
<b>Generated:</b> $(Get-Date)<br>
</div>
"@

foreach ($OU in $OUs) {

    $Users = Get-ADUser `
        -SearchBase $OU.DistinguishedName `
        -SearchScope OneLevel `
        -Filter * `
        -Properties DisplayName, SamAccountName, Mail, Enabled, Department, Title |
        Sort-Object DisplayName |
        Select-Object `
            @{Name="ParentOU";Expression={$OU.DistinguishedName}},
            DisplayName,
            SamAccountName,
            Mail,
            Enabled,
            Department,
            Title

    $html += "<h2>$($OU.DistinguishedName)</h2>"

    if ($Users.Count -gt 0) {
        $AllUsers += $Users

        $html += ($Users |
            Select-Object DisplayName, SamAccountName, Mail, Enabled, Department, Title |
            ConvertTo-Html -Fragment)
    }
    else {
        $html += "<div class='empty'>No users directly in this OU.</div>"
    }
}

$FullHtml = ConvertTo-Html -Title $ReportTitle -Body $html

$FullHtml | Out-File -FilePath $HtmlPath -Encoding UTF8
$AllUsers | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

Start-Process $HtmlPath

Write-Host ""
Write-Host "Report complete."
Write-Host "HTML: $HtmlPath"
Write-Host "CSV : $CsvPath"