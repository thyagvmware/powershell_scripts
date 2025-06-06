# Login if needed
Connect-AzAccount

# Import the subscriptions CSV (make sure the file is in the current folder or provide full path)
$subscriptions = Import-Csv -Path "c:\avanade\temp\costing.csv"

# Array to hold all results
$allData = @()

foreach ($sub in $subscriptions) {
    $subscriptionId = $sub.SubscriptionId

    Write-Host "Processing subscription: $subscriptionId"

    # Get subscription name
    $subName = (Get-AzSubscription -SubscriptionId $subscriptionId).Name

    # Cost Management API URI for subscription scope
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.CostManagement/query?api-version=2023-08-01"

    # Get fresh access token (using az cli here)
    $token = az account get-access-token --resource https://management.azure.com/ --query accessToken -o tsv

    # JSON body payload
    $body = @{
        type = "ActualCost"
        timeframe = "Custom"
        timePeriod = @{
            from = "2025-05-01T00:00:00+00:00"
            to   = "2025-05-31T23:59:59+00:00"
        }
        dataSet = @{
            granularity = "Monthly"
            grouping = @(
                @{type = "Dimension"; name = "ServiceName"}
            )
            sorting = @(
                @{direction = "ascending"; name = "BillingMonth"}
            )
            aggregation = @{
                totalCost = @{name = "Cost"; function = "Sum"}
                totalCostUSD = @{name = "CostUSD"; function = "Sum"}
            }
        }
    } | ConvertTo-Json -Depth 5

    # Headers
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }

    try {
        # Call the API
        $response = Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $body

        # Convert rows to objects and add SubscriptionName property
        $data = $response.properties.rows | ForEach-Object {
            $obj = @{}
            for ($i = 0; $i -lt $response.properties.columns.Count; $i++) {
                $colName = $response.properties.columns[$i].name
                $obj[$colName] = $_[$i]
            }
            # Add subscription name at the front
            $obj = @{ SubscriptionName = $subName } + $obj
            New-Object PSObject -Property $obj
        }

        $allData += $data
    }
    catch {
        Write-Warning "Failed for subscription ${subscriptionId} : $_"
    }
}

if ($allData.Count -gt 0) {
    # Export all combined data to CSV
    $allData | Export-Csv -Path "AzureCost_May2025_MultiSubscriptions.csv" -NoTypeInformation -Encoding UTF8
    Write-Host "Export completed: AzureCost_May2025_MultiSubscriptions.csv"
}
else {
    Write-Warning "No data collected from the subscriptions."
}
