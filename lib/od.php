<?php
/**
 * ZIMRA FDMS API Client for PHP
 * Handles GetStatus, OpenDay, SubmitReceipt, and CloseDay endpoints with proper signatures
 */

class ZimraClient
{
    private $deviceId;
    private $certPath;
    private $keyPath;
    private $baseUrl;
    private $deviceModelName;
    private $deviceModelVersion;
    private $logFile;
    private $debug;
    
    /**
     * Constructor
     */
    public function __construct(
        $deviceId = '31868',
        $certPath = __DIR__ . '/certs/device_cert.pem',
        $keyPath = __DIR__ . '/certs/device_key.pem',
        $baseUrl = 'https://fdmsapitest.zimra.co.zw',
        $debug = false
    ) {
        $this->deviceId = $deviceId;
        $this->certPath = $certPath;
        $this->keyPath = $keyPath;
        $this->baseUrl = rtrim($baseUrl, '/');
        $this->deviceModelName = 'Server';
        $this->deviceModelVersion = 'v1';
        $this->debug = $debug;
        $this->logFile = __DIR__ . '/logs/zimra.log';
        
        // Create logs directory if it doesn't exist
        $logDir = dirname($this->logFile);
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
        
        $this->verifyCertificates();
    }
    
    /**
     * Verify certificate files exist
     */
    private function verifyCertificates()
    {
        if (!file_exists($this->certPath)) {
            throw new Exception("Certificate file not found: {$this->certPath}");
        }
        if (!file_exists($this->keyPath)) {
            throw new Exception("Private key file not found: {$this->keyPath}");
        }
        
        // Verify private key is valid
        $key = openssl_pkey_get_private("file://{$this->keyPath}");
        if (!$key) {
            throw new Exception("Invalid private key file");
        }
        openssl_free_key($key);
    }
    
    /**
     * Log debug messages
     */
    private function log($message, $data = null)
    {
        if (!$this->debug) {
            return;
        }
        
        $logEntry = date('Y-m-d H:i:s') . " - " . $message;
        if ($data !== null) {
            $logEntry .= "\n" . print_r($data, true);
        }
        $logEntry .= "\n------------------------\n";
        
        file_put_contents($this->logFile, $logEntry, FILE_APPEND);
    }
    
    /**
     * Make API request with client certificate
     */
    private function makeRequest($endpoint, $method = 'GET', $data = null)
    {
        $url = $this->baseUrl . $endpoint;
        
        $this->log("Making {$method} request to: {$url}", $data);
        
        $ch = curl_init();
        
        $headers = [
            'Accept: application/json',
            'DeviceModelName: ' . $this->deviceModelName,
            'DeviceModelVersion: ' . $this->deviceModelVersion
        ];
        
        if ($method === 'POST' && $data) {
            $headers[] = 'Content-Type: application/json';
        }
        
        $jsonData = $data ? json_encode($data, JSON_UNESCAPED_SLASHES) : null;
        
        curl_setopt_array($ch, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_SSLCERT => $this->certPath,
            CURLOPT_SSLKEY => $this->keyPath,
            CURLOPT_SSLKEYTYPE => 'PEM',
            CURLOPT_SSLVERSION => CURL_SSLVERSION_TLSv1_2,
            CURLOPT_VERBOSE => $this->debug
        ]);
        
        if ($method === 'POST' && $jsonData) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonData);
            $this->log("Request body:", json_decode($jsonData, true));
        }
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        
        if ($this->debug) {
            $info = curl_getinfo($ch);
            $this->log("cURL Info", $info);
        }
        
        curl_close($ch);
        
        if ($error) {
            $this->log("cURL Error: $error");
            throw new Exception("cURL Error: $error");
        }
        
        $this->log("Response (HTTP {$httpCode}):", $response);
        
        $result = json_decode($response, true);
        
        if ($httpCode >= 400) {
            $errorMsg = "HTTP {$httpCode}";
            if (isset($result['title'])) {
                $errorMsg .= ": " . $result['title'];
            }
            if (isset($result['detail'])) {
                $errorMsg .= " - " . $result['detail'];
            }
            if (isset($result['errorCode'])) {
                $errorMsg .= " [{$result['errorCode']}]";
            }
            throw new Exception($errorMsg, $httpCode);
        }
        
        return $result;
    }
    
    /**
     * Get fiscal day status
     */
    public function getStatus()
    {
        $endpoint = "/Device/v1/{$this->deviceId}/GetStatus";
        return $this->makeRequest($endpoint, 'GET');
    }
    
public function openDay($fiscalDayNo = null)
{
    $openedDateTime = date('Y-m-d\TH:i:s');
    $data = ['fiscalDayOpened' => $openedDateTime];
    if ($fiscalDayNo !== null) {
        $data['fiscalDayNo'] = (int)$fiscalDayNo;
    }
    
    // Store in session for later use when closing
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
    $_SESSION['last_fiscal_day_opened'] = $openedDateTime;
    $_SESSION['last_fiscal_day_no'] = $fiscalDayNo;
    
    $endpoint = "/Device/v1/{$this->deviceId}/OpenDay";
    return $this->makeRequest($endpoint, 'POST', $data);
}
    
    /**
     * Generate receipt device signature as per API spec section 13.2.1
     */
    public function generateReceiptSignature($receipt)
    {
        // Build string in exact order specified by the API
        $signatureString = $this->deviceId;
        $signatureString .= strtoupper($receipt['receiptType']);
        $signatureString .= strtoupper($receipt['receiptCurrency']);
        $signatureString .= $receipt['receiptGlobalNo'];
        $signatureString .= $receipt['receiptDate']; // Format: YYYY-MM-DDTHH:mm:ss
        
        // Receipt total in cents (multiply by 100, remove decimals)
        $signatureString .= (int)round($receipt['receiptTotal'] * 100);
        
        // Add receipt taxes in order
        foreach ($receipt['receiptTaxes'] as $tax) {
            $signatureString .= strtoupper($tax['taxCode'] ?? '');
            $signatureString .= number_format($tax['taxPercent'] ?? 0, 2, '.', '');
            $signatureString .= (int)round($tax['taxAmount'] * 100);
            $signatureString .= (int)round($tax['salesAmountWithTax'] * 100);
        }
        
        $this->log("Receipt signature string:", $signatureString);
        
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
            throw new Exception("Failed to generate signature");
        }
        
        return [
            'hash' => base64_encode($hash),
            'signature' => base64_encode($signature)
        ];
    }
    
    /**
     * Validate receipt data before submission
     */
    public function validateReceipt($receipt)
    {
        $errors = [];
        
        // Check required fields
        $required = ['receiptType', 'receiptCurrency', 'receiptGlobalNo', 'receiptCounter', 
                     'invoiceNo', 'receiptDate', 'receiptLines', 'receiptTaxes', 
                     'receiptPayments', 'receiptTotal'];
        
        foreach ($required as $field) {
            if (!isset($receipt[$field])) {
                $errors[] = "Missing required field: {$field}";
            }
        }
        
        // Validate totals
        $linesTotal = 0;
        foreach ($receipt['receiptLines'] as $line) {
            $linesTotal += $line['receiptLineTotal'];
        }
        
        if (abs($linesTotal - $receipt['receiptTotal']) > 0.01) {
            $errors[] = "Receipt total mismatch: lines sum {$linesTotal} vs total {$receipt['receiptTotal']}";
        }
        
        // Validate tax calculations
        foreach ($receipt['receiptTaxes'] as $tax) {
            if ($receipt['receiptLinesTaxInclusive']) {
                $expectedTax = $linesTotal * ($tax['taxPercent'] / (100 + $tax['taxPercent']));
                if (abs($expectedTax - $tax['taxAmount']) > 0.01) {
                    $errors[] = "Tax calculation mismatch for {$tax['taxPercent']}%";
                }
            }
        }
        
        return $errors;
    }
    
    /**
     * Submit a receipt
     */
    public function submitReceipt($receiptData)
    {
        // Generate device signature
        $signature = $this->generateReceiptSignature($receiptData);
        $receiptData['receiptDeviceSignature'] = $signature;
        
        $data = ['receipt' => $receiptData];
        $endpoint = "/Device/v1/{$this->deviceId}/SubmitReceipt";
        
        $this->log("Submitting receipt:", $receiptData);
        
        return $this->makeRequest($endpoint, 'POST', $data);
    }
    
    /**
     * Generate fiscal day device signature as per API spec section 13.3.1
     */
/**
 * Generate fiscal day device signature as per API spec section 13.3.1
 */
private function generateFiscalDaySignature($fiscalDayNo, $fiscalDayDate, $counters)
{
    // 1. Filter out zero-value counters as required 
    $activeCounters = array_filter($counters, function($counter) {
        return isset($counter['fiscalCounterValue']) && $counter['fiscalCounterValue'] != 0;
    });

    // 2. Sort counters as required by spec [cite: 436]
    usort($activeCounters, function($a, $b) {
        $typeCompare = strcmp($a['fiscalCounterType'], $b['fiscalCounterType']);
        if ($typeCompare !== 0) return $typeCompare;
        
        $currencyCompare = strcmp($a['fiscalCounterCurrency'], $b['fiscalCounterCurrency']);
        if ($currencyCompare !== 0) return $currencyCompare;
        
        if (isset($a['fiscalCounterTaxPercent']) && isset($b['fiscalCounterTaxPercent'])) {
            return $a['fiscalCounterTaxPercent'] <=> $b['fiscalCounterTaxPercent'];
        }
        
        $moneyA = $a['fiscalCounterMoneyType'] ?? '';
        $moneyB = $b['fiscalCounterMoneyType'] ?? '';
        return strcmp($moneyA, $moneyB);
    });

    // 3. Build counter string
    $counterString = '';
    foreach ($activeCounters as $counter) {
        $counterString .= strtoupper($counter['fiscalCounterType']);
        $counterString .= strtoupper($counter['fiscalCounterCurrency']);
        
        if (isset($counter['fiscalCounterTaxPercent'])) {
            // Format to 2 decimal places [cite: 415]
            $counterString .= number_format($counter['fiscalCounterTaxPercent'], 2, '.', '');
        } elseif (isset($counter['fiscalCounterMoneyType'])) {
            $counterString .= strtoupper($counter['fiscalCounterMoneyType']);
        }
        
        // Value formatting: use number_format to 2 decimals and remove the dot [cite: 415]
        $counterString .= number_format($counter['fiscalCounterValue'], 2, '', '');
    }

    // 4. Build full string for hashing: deviceID || fiscalDayNo || fiscalDayDate || counters [cite: 434]
    // Ensure fiscalDayDate is YYYY-MM-DD
    $formattedDate = date('Y-m-d', strtotime($fiscalDayDate));
    $signatureString = $this->deviceId . $fiscalDayNo . $formattedDate . $counterString;

    $this->log("Concatenated Fiscal Day String: " . $signatureString);

    // 5. Generate SHA-256 hash [cite: 375, 377]
    $hash = hash('sha256', $signatureString, true);
    
    // 6. Sign with private key [cite: 376, 377]
    $privateKey = openssl_pkey_get_private("file://{$this->keyPath}");
    if (!$privateKey) {
        throw new Exception("Failed to load private key");
    }
    
    $signature = '';
    $success = openssl_sign($signatureString, $signature, $privateKey, OPENSSL_ALGO_SHA256);
    openssl_free_key($privateKey);

    if (!$success) {
        throw new Exception("Failed to generate signature");
    }

    return [
        'hash' => base64_encode($hash),
        'signature' => base64_encode($signature)
    ];
}

/**
 * Close fiscal day
 */
public function closeDay($fiscalDayNo = null, $receiptCounter = null, $counters = null)
{
    $status = $this->getStatus();
    
    $fiscalDayNo = $fiscalDayNo ?? $status['lastFiscalDayNo'];
    $receiptCounter = $receiptCounter ?? $status['lastReceiptGlobalNo'];
    
    // Use the date the day was opened [cite: 434]
    $fiscalDayDate = isset($_SESSION['last_fiscal_day_opened']) 
        ? substr($_SESSION['last_fiscal_day_opened'], 0, 10) 
        : date('Y-m-d');

    // Only send non-zero counters in the payload [cite: 245]
    $filteredCounters = array_filter($counters, function($c) {
        return $c['fiscalCounterValue'] != 0;
    });

    $signature = $this->generateFiscalDaySignature($fiscalDayNo, $fiscalDayDate, $filteredCounters);

    $data = [
        'fiscalDayNo' => (int)$fiscalDayNo,
        'receiptCounter' => (int)$receiptCounter,
        'fiscalDayCounters' => array_values($filteredCounters),
        'fiscalDayDeviceSignature' => $signature
    ];

    $endpoint = "/Device/v1/{$this->deviceId}/CloseDay";
    return $this->makeRequest($endpoint, 'POST', $data);
}
    
    /**
     * Get certificate info for debugging
     */
    public function getCertificateInfo()
    {
        $cert = file_get_contents($this->certPath);
        $info = openssl_x509_parse($cert);
        return $info;
    }
}
?>