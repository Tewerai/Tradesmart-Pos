/**
 * Close fiscal day as per API spec v7.2 section 4.10
 */
public function closeDay($fiscalDayNo = null, $receiptCounter = null, $counters = [])
{
    // Get current status to validate
    $status = $this->getStatus();
    
    // Validate fiscal day can be closed
    if (!in_array($status['fiscalDayStatus'] ?? '', ['FiscalDayOpened', 'FiscalDayCloseFailed'])) {
        throw new Exception("Cannot close day. Current status: " . ($status['fiscalDayStatus'] ?? 'unknown'));
    }
    
    // Use provided or status values
    $fiscalDayNo = $fiscalDayNo ?? $status['fiscalDayNo'] ?? null;
    if (!$fiscalDayNo) {
        throw new Exception("Fiscal day number is required");
    }
    
    $receiptCounter = $receiptCounter ?? $status['lastReceiptCounter'] ?? null;
    if (!$receiptCounter) {
        throw new Exception("Receipt counter is required");
    }
    
    // Filter out zero value counters (spec says zero counters must not be submitted)
    $filteredCounters = array_values(array_filter($counters, function($c) {
        return isset($c['fiscalCounterValue']) && abs($c['fiscalCounterValue']) > 0.0001;
    }));
    
    // Generate device signature for fiscal day report
    $signature = $this->generateFiscalDaySignature(
        $fiscalDayNo,
        $status['fiscalDayOpened'] ?? date('Y-m-d\TH:i:s'),
        $filteredCounters
    );
    
    // Prepare request data exactly as per spec
    $data = [
        'deviceID' => (int)$this->deviceId,
        'fiscalDayNo' => (int)$fiscalDayNo,
        'fiscalDayCounters' => $filteredCounters,
        'fiscalDayDeviceSignature' => $signature,
        'receiptCounter' => (int)$receiptCounter
    ];
    
    $endpoint = "/Device/v1/{$this->deviceId}/CloseDay";
    
    $this->log("Closing fiscal day #{$fiscalDayNo}", $data);
    
    return $this->makeRequest($endpoint, 'POST', $data);
}

/**
 * Generate fiscal day device signature as per API spec v7.2 section 13.3.1
 */
private function generateFiscalDaySignature($fiscalDayNo, $fiscalDayOpened, $counters)
{
    // Sort counters exactly as spec requires:
    // 1. By fiscalCounterType ascending
    // 2. By fiscalCounterCurrency ascending  
    // 3. By fiscalCounterTaxID ascending OR fiscalCounterMoneyType ascending
    usort($counters, function($a, $b) {
        // Type
        $cmp = strcmp($a['fiscalCounterType'] ?? '', $b['fiscalCounterType'] ?? '');
        if ($cmp !== 0) return $cmp;
        
        // Currency
        $cmp = strcmp($a['fiscalCounterCurrency'] ?? '', $b['fiscalCounterCurrency'] ?? '');
        if ($cmp !== 0) return $cmp;
        
        // TaxID or MoneyType
        $valA = $a['fiscalCounterTaxID'] ?? $a['fiscalCounterMoneyType'] ?? '';
        $valB = $b['fiscalCounterTaxID'] ?? $b['fiscalCounterMoneyType'] ?? '';
        return strcmp($valA, $valB);
    });
    
    // Build signature string exactly as spec requires
    $signatureString = $this->deviceId;
    $signatureString .= $fiscalDayNo;
    $signatureString .= date('Y-m-d', strtotime($fiscalDayOpened)); // Only date part
    
    // Add counters
    foreach ($counters as $counter) {
        $signatureString .= strtoupper($counter['fiscalCounterType']);
        $signatureString .= strtoupper($counter['fiscalCounterCurrency']);
        
        if (isset($counter['fiscalCounterTaxPercent'])) {
            // Format tax percent with 2 decimals
            $taxPercent = number_format($counter['fiscalCounterTaxPercent'], 2, '.', '');
            $signatureString .= $taxPercent;
        } elseif (isset($counter['fiscalCounterMoneyType'])) {
            $signatureString .= strtoupper($counter['fiscalCounterMoneyType']);
        }
        
        // Value in cents (no decimal)
        $valueInCents = (int)round($counter['fiscalCounterValue'] * 100);
        $signatureString .= $valueInCents;
    }
    
    $this->log("Fiscal day signature string:", $signatureString);
    
    // Generate SHA-256 hash
    $hash = hash('sha256', $signatureString, true);
    
    // Sign with private key
    $privateKey = openssl_pkey_get_private("file://{$this->keyPath}");
    if (!$privateKey) {
        throw new Exception("Failed to load private key");
    }
    
    $signature = '';
    $success = openssl_sign($hash, $signature, $privateKey, OPENSSL_ALGO_SHA256);
    openssl_free_key($privateKey);
    
    if (!$success) {
        throw new Exception("Failed to generate fiscal day signature");
    }
    
    return [
        'hash' => base64_encode($hash),
        'signature' => base64_encode($signature)
    ];
}