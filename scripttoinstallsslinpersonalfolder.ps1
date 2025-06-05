# Configuration
$csvPath = "pathtoservers.csv"
$pfxPath = "path to your certificate"
$remoteCertPath = "path to the pfx file"
$pfxPasswordPlain = "****"  # Replace with actual password
$pfxPassword = ConvertTo-SecureString $pfxPasswordPlain -AsPlainText -Force

# Read server list
$servers = Import-Csv -Path $csvPath

foreach ($server in $servers) {
    $serverName = $server.ServerName

    try {
        Write-Host "`n📦 Copying certificate to $serverName..." -ForegroundColor Cyan
        Copy-Item -Path $pfxPath -Destination "\\$serverName\C$\Temp\certificate.pfx" -Force

        Write-Host "🔐 Importing and binding certificate on $serverName..." -ForegroundColor Cyan
        Invoke-Command -ComputerName $serverName -ScriptBlock {
            param($remoteCertPath, $pfxPassword)

            Import-Module WebAdministration

            # Ensure temp dir exists
            if (!(Test-Path "C:\Temp")) {
                New-Item -Path "C:\Temp" -ItemType Directory | Out-Null
            }

            # Import certificate
            $cert = Import-PfxCertificate -FilePath $remoteCertPath -CertStoreLocation "Cert:\LocalMachine\My" -Password $pfxPassword
            $thumbprint = $cert.Thumbprint

            # Check and create HTTPS binding if missing
            $binding = Get-WebBinding -Name "Default Web Site" -Protocol "https" -ErrorAction SilentlyContinue
            if (-not $binding) {
                New-WebBinding -Name "Default Web Site" -Protocol "https" -Port 443
                Write-Host "✅ HTTPS binding created on port 443."
            }

            # Bind the certificate to the HTTPS binding using SslBinding
            $sslBindingPath = "IIS:\SslBindings\0.0.0.0!443"
            if (Test-Path $sslBindingPath) {
                Remove-Item $sslBindingPath -Force
            }

            Get-Item "cert:\LocalMachine\My\$thumbprint" |
                New-Item $sslBindingPath

            Write-Host "✅ [$env:COMPUTERNAME] Certificate bound to HTTPS port 443."

        } -ArgumentList $remoteCertPath, $pfxPassword

    } catch {
        Write-Warning "❌ Failed on ${serverName}: $_"
    }
}
