function Convert-CLLicenseStatus {
    param([Nullable[int]]$Status)

    switch ($Status) {
        0 { 'Unlicensed' }
        1 { 'Licensed' }
        2 { 'OOB Grace' }
        3 { 'OOT Grace' }
        4 { 'Non-Genuine Grace' }
        5 { 'Notification' }
        6 { 'Extended Grace' }
        default { 'Unknown' }
    }
}

function Get-CLWindowsLicense {
    [CmdletBinding()]
    param()

    $products = Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction SilentlyContinue |
        Where-Object { $_.PartialProductKey -and $_.Name -match 'Windows' }

    foreach ($product in $products) {
        [pscustomobject]@{
            ProductName = $product.Name
            Description = $product.Description
            LicenseStatusCode = $product.LicenseStatus
            LicenseStatusText = Convert-CLLicenseStatus -Status $product.LicenseStatus
            PartialProductKey = $product.PartialProductKey
            GracePeriodRemaining = $product.GracePeriodRemaining
            IsLicensed = $product.LicenseStatus -eq 1
        }
    }
}

Export-ModuleMember -Function Get-CLWindowsLicense