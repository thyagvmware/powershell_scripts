# Path to the CSV file containing server names
$csvPath = "C:\Avanade\temp\certs_extract\servers_certs.csv"

# Output CSV path
$outputCsv = "C:\Avanade\temp\certs_extract\certstatus_v1.csv"

# Read the list of servers
$servers = Import-Csv -Path $csvPath

# Create an array to collect results
$results = @()

# Loop through each server and fetch certificates

$WarningPreference = 'SilentlyContinue'  # Suppress all warning messages
foreach ($server in $servers) {
    $serverName = $server.Name
    Write-Host "Checking certificates on $serverName..." -ForegroundColor Cyan

    try {
        $certs = Invoke-Command -ComputerName $serverName -ScriptBlock {
            Get-ChildItem -Path Cert:\LocalMachine\My | ForEach-Object {
                [PSCustomObject]@{
                    ServerName = $env:COMPUTERNAME
                    Subject     = $_.Subject
                    Thumbprint  = $_.Thumbprint
                    NotBefore   = $_.NotBefore
                    NotAfter    = $_.NotAfter
                    FriendlyName= $_.FriendlyName
                    Issuer      = $_.Issuer
                }
            }
        } -ErrorAction Stop

        $results += $certs
    } catch {
        Write-Warning "Failed to connect to ${serverName}: $_"
        $results += [PSCustomObject]@{
            ServerName = $serverName
            Subject     = "ERROR"
            Thumbprint  = "N/A"
            NotBefore   = "N/A"
            NotAfter    = "N/A"
            FriendlyName= "Connection failed"
            Issuer      = "N/A"
        }
    }
}

# Export results to CSV
$results | Export-Csv -Path $outputCsv -NoTypeInformation

Write-Host "`nCertificate collection complete. Report saved to $outputCsv" -ForegroundColor Green
