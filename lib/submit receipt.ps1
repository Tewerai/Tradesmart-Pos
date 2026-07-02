submit receipt # Complete ZIMRA FDMS API - Submit Receipt Script

$DeviceID = "31868"
$PfxPath = "C:\Users\user\zimra-fdms-integration\device_identity.pfx"
$PfxPassword = "1234"

# Load certificate
Write-Host "Loading certificate..." -ForegroundColor Cyan
$Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$Cert.Import($PfxPath, $PfxPassword, 'DefaultKeySet')
Write-Host "✓ Certificate loaded: $($Cert.Subject)" -ForegroundColor Green

# Headers
$Headers = @{
    'accept' = 'application/json'
    'DeviceModelName' = 'Server'
    'DeviceModelVersion' = 'v1'
    'Content-Type' = 'application/json'
}

# Step 1: Check current fiscal day status
Write-Host "`nChecking fiscal day status..." -ForegroundColor Cyan
$StatusURL = "https://fdmsapitest.zimra.co.zw/Device/v1/$DeviceID/GetStatus"

try {
    $Status = Invoke-RestMethod -Uri $StatusURL -Headers $Headers -Method Get -Certificate $Cert
    Write-Host "Fiscal Day Status: $($Status.fiscalDayStatus)" -ForegroundColor Green
    
    if ($Status.fiscalDayStatus -ne "FiscalDayOpened") {
        Write-Host "ERROR: Fiscal day must be opened to submit receipts. Current status: $($Status.fiscalDayStatus)" -ForegroundColor Red
        exit
    }
} catch {
    Write-Error "Failed to get status: $_"
    exit
}

# Step 2: Prepare receipt data
$SubmitReceiptURL = "https://fdmsapitest.zimra.co.zw/Device/v1/$DeviceID/SubmitReceipt"
$CurrentDateTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"

# Function to generate hash according to spec section 13.2.1
function Generate-ReceiptHash {
    param(
        [hashtable]$Receipt
    )
    
    # Fields in exact order per spec
    $parts = @()
    
    # 1. deviceID
    $parts += "31868"
    
    # 2. receiptType (uppercase)
    $parts += $Receipt.receiptType.ToUpper()
    
    # 3. receiptCurrency (uppercase)
    $parts += $Receipt.receiptCurrency.ToUpper()
    
    # 4. receiptGlobalNo
    $parts += $Receipt.receiptGlobalNo.ToString()
    
    # 5. receiptDate (ISO 8601)
    $parts += $Receipt.receiptDate
    
    # 6. receiptTotal in cents (multiply by 100)
    $totalCents = [math]::Round($Receipt.receiptTotal * 100)
    $parts += $totalCents.ToString()
    
    # 7. receiptTaxes concatenated
    foreach ($tax in $Receipt.receiptTaxes) {
        # taxCode
        $parts += $tax.taxCode
        
        # taxPercent (with 2 decimals)
        if ($tax.taxPercent -match '\.') {
            $parts += $tax.taxPercent.ToString("0.00")
        } else {
            $parts += $tax.taxPercent.ToString() + ".00"
        }
        
        # taxAmount in cents
        $taxCents = [math]::Round($tax.taxAmount * 100)
        $parts += $taxCents.ToString()
        
        # salesAmountWithTax in cents
        $salesCents = [math]::Round($tax.salesAmountWithTax * 100)
        $parts += $salesCents.ToString()
    }
    
    # Join all parts with no separator
    $stringToHash = $parts -join ""
    
    Write-Host "`nString to hash: $stringToHash" -ForegroundColor Gray
    
    # Generate SHA256 hash
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToHash))
    $hashBase64 = [Convert]::ToBase64String($hashBytes)
    
    return $hashBase64
}

# Create receipt data
$ReceiptData = @{
    receiptType = "FiscalInvoice"
    receiptCurrency = "USD"
    receiptGlobalNo = 1
    receiptCounter = 1
    invoiceNo = "INV-2026-001"
    receiptDate = $CurrentDateTime
    receiptLinesTaxInclusive = $true
    receiptLines = @(
        @{
            receiptLineType = "Sale"
            receiptLineNo = 1
            receiptLineHSCode = "12345678"
            receiptLineName = "Test Product"
            receiptLinePrice = 10.00
            receiptLineQuantity = 2
            receiptLineTotal = 20.00
            taxCode = "A"
            taxPercent = 15.50
            taxID = 517
        }
    )
    receiptTaxes = @(
        @{
            taxCode = "A"
            taxPercent = 15.50
            taxID = 517
            taxAmount = 2.68  # 20 * (15.5/115.5) = 2.68
            salesAmountWithTax = 20.00
        }
    )
    receiptPayments = @(
        @{
            moneyTypeCode = "Cash"
            paymentAmount = 20.00
        }
    )
    receiptTotal = 20.00
    receiptPrintForm = "Receipt48"
    username = "testuser"
    userNameSurname = "Test User"
}

# Validate calculations
Write-Host "`nValidating receipt calculations..." -ForegroundColor Cyan

# Check RCPT019: receiptTotal = sum of receiptLineTotal
$sumLines = ($ReceiptData.receiptLines | Measure-Object -Property receiptLineTotal -Sum).Sum
if ($ReceiptData.receiptTotal -eq $sumLines) {
    Write-Host "✓ RCPT019: receiptTotal ($($ReceiptData.receiptTotal)) = sum of lines ($sumLines)" -ForegroundColor Green
} else {
    Write-Host "✗ RCPT019: receiptTotal ($($ReceiptData.receiptTotal)) != sum of lines ($sumLines)" -ForegroundColor Red
}

# Check RCPT039: receiptTotal = sum of payments
$sumPayments = ($ReceiptData.receiptPayments | Measure-Object -Property paymentAmount -Sum).Sum
if ($ReceiptData.receiptTotal -eq $sumPayments) {
    Write-Host "✓ RCPT039: receiptTotal ($($ReceiptData.receiptTotal)) = sum of payments ($sumPayments)" -ForegroundColor Green
} else {
    Write-Host "✗ RCPT039: receiptTotal ($($ReceiptData.receiptTotal)) != sum of payments ($sumPayments)" -ForegroundColor Red
}

# Check RCPT038: receiptTotal = sum of salesAmountWithTax
$sumSalesWithTax = ($ReceiptData.receiptTaxes | Measure-Object -Property salesAmountWithTax -Sum).Sum
if ($ReceiptData.receiptTotal -eq $sumSalesWithTax) {
    Write-Host "✓ RCPT038: receiptTotal ($($ReceiptData.receiptTotal)) = sum of salesAmountWithTax ($sumSalesWithTax)" -ForegroundColor Green
} else {
    Write-Host "✗ RCPT038: receiptTotal ($($ReceiptData.receiptTotal)) != sum of salesAmountWithTax ($sumSalesWithTax)" -ForegroundColor Red
}

# Generate hash
$hash = Generate-ReceiptHash -Receipt $ReceiptData
Write-Host "`nGenerated Hash: $hash" -ForegroundColor Green

# Create signature (for testing, using hash as signature - in production, sign with private key)
$signature = $hash  # In production, this should be the actual cryptographic signature

# Build complete request body
$RequestBody = @{
    receipt = $ReceiptData
}

# Add signature
$RequestBody.receipt.receiptDeviceSignature = @{
    hash = $hash
    signature = $signature
}

# Convert to JSON
$JsonBody = $RequestBody | ConvertTo-Json -Depth 10

Write-Host "`nSending receipt to FDMS..." -ForegroundColor Cyan
Write-Host "Request body:" -ForegroundColor Gray
Write-Host $JsonBody -ForegroundColor Gray

# Step 3: Submit receipt
try {
    $Response = Invoke-RestMethod -Uri $SubmitReceiptURL -Headers $Headers -Method Post -Body $JsonBody -Certificate $Cert -ContentType "application/json"
    
    Write-Host "`n✓ Receipt submitted successfully!" -ForegroundColor Green
    Write-Host "Operation ID: $($Response.operationID)" -ForegroundColor Cyan
    Write-Host "Receipt ID: $($Response.receiptID)" -ForegroundColor Cyan
    Write-Host "Server Date: $($Response.serverDate)" -ForegroundColor Cyan
    Write-Host "Server Signature: $($Response.receiptServerSignature.signature)" -ForegroundColor Gray
}
catch {
    Write-Host "`n✗ Failed to submit receipt" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    
    if ($_.Exception.Response) {
        $Stream = $_.Exception.Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($Stream)
        $ResponseBody = $Reader.ReadToEnd()
        
        Write-Host "Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
        Write-Host "Response Body: $ResponseBody" -ForegroundColor Yellow
        
        # Try to parse error details
        try {
            $ErrorDetails = $ResponseBody | ConvertFrom-Json
            if ($ErrorDetails.errors) {
                Write-Host "`nValidation Errors:" -ForegroundColor Red
                $ErrorDetails.errors | ForEach-Object {
                    Write-Host "  - $($_.message)" -ForegroundColor Red
                }
            }
            elseif ($ErrorDetails.errorCode) {
                Write-Host "Error Code: $($ErrorDetails.errorCode)" -ForegroundColor Red
                Write-Host "Message: $($ErrorDetails.title)" -ForegroundColor Red
            }
        }
        catch {
            # Not JSON or different format
        }
    }
}