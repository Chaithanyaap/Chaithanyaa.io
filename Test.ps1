# Save as Get-OCISecret-GUI.ps1
# Run this script directly in PowerShell 7 (pwsh)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Default location for your module ---
$defaultLocation = 'Map where you have copied Posh-GSIV'

# Create form
$form = New-Object System.Windows.Forms.Form
$form.Text = "OCI Secret Retriever"
$form.Size = New-Object System.Drawing.Size(640,320)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

# Location input
$lblLocation = New-Object System.Windows.Forms.Label
$lblLocation.Location = New-Object System.Drawing.Point(20,20)
$lblLocation.Size = New-Object System.Drawing.Size(80,20)
$lblLocation.Text = "Location:"
$form.Controls.Add($lblLocation)

$txtLocation = New-Object System.Windows.Forms.TextBox
$txtLocation.Location = New-Object System.Drawing.Point(110,18)
$txtLocation.Size = New-Object System.Drawing.Size(420,22)
$txtLocation.Text = $defaultLocation
$form.Controls.Add($txtLocation)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Location = New-Object System.Drawing.Point(540,16)
$btnBrowse.Size = New-Object System.Drawing.Size(75,24)
$btnBrowse.Text = "Browse..."
$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.SelectedPath = $txtLocation.Text
    if ($dialog.ShowDialog() -eq 'OK') {
        $txtLocation.Text = $dialog.SelectedPath
    }
})
$form.Controls.Add($btnBrowse)

# ServerName input
$lblServer = New-Object System.Windows.Forms.Label
$lblServer.Location = New-Object System.Drawing.Point(20,60)
$lblServer.Size = New-Object System.Drawing.Size(80,20)
$lblServer.Text = "ServerName:"
$form.Controls.Add($lblServer)

$txtServer = New-Object System.Windows.Forms.TextBox
$txtServer.Location = New-Object System.Drawing.Point(110,58)
$txtServer.Size = New-Object System.Drawing.Size(420,22)
$form.Controls.Add($txtServer)

# Button to retrieve secret
$btnGet = New-Object System.Windows.Forms.Button
$btnGet.Location = New-Object System.Drawing.Point(540,56)
$btnGet.Size = New-Object System.Drawing.Size(75,26)
$btnGet.Text = "Get Secret"
$form.Controls.Add($btnGet)

# Status label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(20,100)
$lblStatus.Size = New-Object System.Drawing.Size(590,20)
$lblStatus.Text = "Status: Idle"
$form.Controls.Add($lblStatus)

# Password output
$lblPwd = New-Object System.Windows.Forms.Label
$lblPwd.Location = New-Object System.Drawing.Point(20,140)
$lblPwd.Size = New-Object System.Drawing.Size(80,20)
$lblPwd.Text = "Password:"
$form.Controls.Add($lblPwd)

$txtPwd = New-Object System.Windows.Forms.TextBox
$txtPwd.Location = New-Object System.Drawing.Point(110,138)
$txtPwd.Size = New-Object System.Drawing.Size(420,22)
$txtPwd.UseSystemPasswordChar = $true
$txtPwd.ReadOnly = $true
$form.Controls.Add($txtPwd)

# Show/Hide button
$btnToggle = New-Object System.Windows.Forms.Button
$btnToggle.Location = New-Object System.Drawing.Point(540,136)
$btnToggle.Size = New-Object System.Drawing.Size(75,26)
$btnToggle.Text = "Show"
$btnToggle.Add_Click({
    if ($txtPwd.UseSystemPasswordChar) {
        $txtPwd.UseSystemPasswordChar = $false
        $btnToggle.Text = "Hide"
    } else {
        $txtPwd.UseSystemPasswordChar = $true
        $btnToggle.Text = "Show"
    }
})
$form.Controls.Add($btnToggle)

# Copy button
$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Location = New-Object System.Drawing.Point(110,170)
$btnCopy.Size = New-Object System.Drawing.Size(120,28)
$btnCopy.Text = "Copy Password"
$btnCopy.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtPwd.Text)) {
        [System.Windows.Forms.MessageBox]::Show("No password to copy.","Info",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    } else {
        $txtPwd.Text | Set-Clipboard
        $lblStatus.Text = "Status: Password copied to clipboard."
    }
})
$form.Controls.Add($btnCopy)

# Clear button
$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Location = New-Object System.Drawing.Point(250,170)
$btnClear.Size = New-Object System.Drawing.Size(120,28)
$btnClear.Text = "Clear"
$btnClear.Add_Click({
    $txtPwd.Text = ""
    $lblStatus.Text = "Status: Cleared."
})
$form.Controls.Add($btnClear)

# Close button
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Location = New-Object System.Drawing.Point(540,170)
$btnClose.Size = New-Object System.Drawing.Size(75,28)
$btnClose.Text = "Close"
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

# Status updater
function Set-Status([string]$text) {
    $lblStatus.Text = "Status: $text"
    [System.Windows.Forms.Application]::DoEvents()
}

# Main Get Secret action
$btnGet.Add_Click({
    $location = $txtLocation.Text.Trim()
    $server   = $txtServer.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($server)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter the ServerName (SecretName in OCI).","Input required",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Exclamation) | Out-Null
        return
    }

    try {
        Set-Status "Importing module Posh-GSIV..."
        Import-Module "$location\Posh-GSIV.psd1" -Force -ErrorAction Stop

        Set-Status "Updating OCI config..."
        Update-OciConfig

        Set-Status "Initializing compartment connector..."
        Initialize-CompartmentConnector

        Set-Status "Retrieving secret for $server..."
        $secretObj = Get-OCISecretBundle -SecretName $server -ErrorAction Stop

        # Extract secret content
        $retrieved = $null
        if ($secretObj.SecretBundleContent.Content) {
            try {
                $bytes = [System.Convert]::FromBase64String($secretObj.SecretBundleContent.Content)
                $retrieved = [System.Text.Encoding]::UTF8.GetString($bytes)
            } catch {
                $retrieved = $secretObj.SecretBundleContent.Content
            }
        } else {
            $retrieved = $secretObj | Out-String
        }

        if (-not $retrieved) { throw "Secret content was empty." }

        $txtPwd.Text = $retrieved.Trim()
        Set-Status "Secret retrieved successfully."

    } catch {
        $lblStatus.Text = "Status: ERROR - $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Failed:`n$($_.Exception.Message)","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
})

# Show form
[void] $form.ShowDialog()
