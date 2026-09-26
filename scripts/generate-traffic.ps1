# Traffic generator for GCP BigQuery & Observability Lab
$OrderApiUrl = "https://order-api-769996365752.europe-west1.run.app"
Write-Output "=== Starting Traffic Generation against $OrderApiUrl ==="

$users = @("alice", "bob", "charlie", "dana", "elena", "fahad", "george", "hannah")
$ordersCount = 25

Write-Output "Sending $ordersCount domain order events..."
for ($i = 1; $i -le $ordersCount; $i++) {
    $user = $users[$i % $users.Count]
    $amount = [math]::Round((Get-Random -Minimum 15 -Maximum 450) + (Get-Random) / 1000000000, 2)
    $body = @{
        userId = $user
        amount = $amount
    } | ConvertTo-Json

    try {
        $resp = Invoke-RestMethod -Uri "$OrderApiUrl/orders" -Method Post -ContentType "application/json" -Body $body
        Write-Output "[$i/$ordersCount] Order created: $($resp.orderId) for $user ($$amount) -> PubSub Msg: $($resp.pubsubMessageId)"
    } catch {
        Write-Output "[$i/$ordersCount] Error submitting order: $($_.Exception.Message)"
    }
    Start-Sleep -Milliseconds 250
}

Write-Output "`nSending slow requests to generate latency distribution for Trace & Monitoring..."
for ($s = 1; $s -le 3; $s++) {
    $delay = 400 * $s
    try {
        $resp = Invoke-RestMethod -Uri "$OrderApiUrl/slow?ms=$delay" -Method Get
        Write-Output "[Slow $s/3] Delay: $($resp.delayMs)ms completed."
    } catch {
        Write-Output "[Slow $s/3] Error: $($_.Exception.Message)"
    }
}

Write-Output "`nSending controlled test error to trigger log-based metric and alert policy..."
try {
    $resp = Invoke-WebRequest -Uri "$OrderApiUrl/test-error" -Method Get
    Write-Output "Error endpoint returned: $($resp.StatusCode)"
} catch {
    Write-Output "Controlled error received HTTP 500 as expected: $($_.Exception.Message)"
}

Write-Output "`n=== Traffic Generation Completed ==="
