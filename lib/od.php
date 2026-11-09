<?php
/**
 * ZIMRA Fiscal Device Integration - Complete Single File API
 * Handles: Order processing, inventory, ZIMRA receipts, signatures, retry queue
 * 
 * API Endpoint: POST /zimra_api.php
 * Payload: { "username": "shop@email.com", "orders": [...] }
 */

// ============================================
// CONFIGURATION
// ============================================
define('DEVICE_ID', 31868);
define('USER_ID', 1);
define('ZIMRA_API_BASE', 'https://fdmsapitest.zimra.co.zw'); // Test environment
// define('ZIMRA_API_BASE', 'https://fdmsapi.zimra.co.zw'); // Production environment

set_time_limit(300);
date_default_timezone_set("Africa/Johannesburg");
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// Database connection
$con = mysqli_connect("localhost", "blueicho_try", "iloveGrace1", "blueicho_try");

if (mysqli_connect_errno()) {
    sendResponse(false, 'Database connection failed: ' . mysqli_connect_error());
}

// ============================================
// HELPER FUNCTIONS
// ============================================

function sendResponse($success, $message, $data = []) {
    $response = array_merge(['success' => $success, 'message' => $message], $data);
    echo json_encode($response, JSON_PRETTY_PRINT);
    exit();
}

function logMessage($message, $data = null) {
    $logFile = '/home/blueicho/shaneo/zimra_logs/api_' . date('Y-m-d') . '.log';
    $logDir = dirname($logFile);
    if (!is_dir($logDir)) mkdir($logDir, 0777, true);
    
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[$timestamp] $message";
    if ($data !== null) $logEntry .= " - " . json_encode($data);
    file_put_contents($logFile, $logEntry . PHP_EOL, FILE_APPEND);
}

function toCents($amount) {
    return (int) round($amount * 100);
}

function formatTaxPct($pct) {
    if ($pct === null) return "";
    return number_format((float)$pct, 2, '.', '');
}

function concatTaxes($receiptTaxes) {
    usort($receiptTaxes, function($a, $b) {
        if ($a['taxID'] != $b['taxID']) return $a['taxID'] - $b['taxID'];
        return strcmp($a['taxCode'] ?? '', $b['taxCode'] ?? '');
    });
    
    $result = '';
    foreach ($receiptTaxes as $tax) {
        $code = $tax['taxCode'] ?? '';
        $pct = formatTaxPct($tax['taxPercent'] ?? null);
        $taxCents = toCents($tax['taxAmount']);
        $salesCents = toCents($tax['salesAmountWithTax']);
        $result .= $code . $pct . $taxCents . $salesCents;
    }
    return $result;
}

// ============================================
// DATABASE TABLE INITIALIZATION
// ============================================

function initTables($con) {
    $tables = [
        "CREATE TABLE IF NOT EXISTS `zimra_retry_queue` (
            id INT AUTO_INCREMENT PRIMARY KEY,
            order_number VARCHAR(100),
            shopid VARCHAR(255),
            amount DECIMAL(10,2),
            attempts INT DEFAULT 0,
            last_error TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_shop_order (shopid, order_number)
        )",
        
        "CREATE TABLE IF NOT EXISTS `receipt_hash_chain` (
            id INT AUTO_INCREMENT PRIMARY KEY,
            device_id INT NOT NULL,
            fiscal_day_no INT NOT NULL,
            global_no INT NOT NULL,
            receipt_hash TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_receipt (device_id, fiscal_day_no, global_no)
        )",
        
        "CREATE TABLE IF NOT EXISTS `app_state` (
            device_id INT PRIMARY KEY,
            current_fiscal_day_no INT DEFAULT 1,
            last_global_no INT DEFAULT 0,
            last_counter INT DEFAULT 0,
            fiscal_day_status VARCHAR(50),
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )",
        
        "CREATE TABLE IF NOT EXISTS `fiscal_day_activities` (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT,
            device_id INT,
            fiscal_day_no INT,
            global_no INT,
            counter INT,
            previous_hash TEXT,
            products TEXT,
            total_amount DECIMAL(10,2),
            tax_amount DECIMAL(10,2),
            status VARCHAR(50),
            receipt_id VARCHAR(100),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )"
    ];
    
    foreach ($tables as $sql) {
        mysqli_query($con, $sql);
    }
}

// ============================================
// DATABASE FUNCTIONS
// ============================================

function getDeviceConfig($con, $deviceId) {
    $sql = "SELECT * FROM zimra_client WHERE device_id = $deviceId LIMIT 1";
    $result = mysqli_query($con, $sql);
    return ($result && mysqli_num_rows($result) > 0) ? mysqli_fetch_assoc($result) : null;
}

function getAppState($con, $deviceId) {
    $sql = "SELECT * FROM app_state WHERE device_id = $deviceId LIMIT 1";
    $result = mysqli_query($con, $sql);
    return ($result && mysqli_num_rows($result) > 0) ? mysqli_fetch_assoc($result) : null;
}

function updateAppState($con, $deviceId, $lastGlobalNo, $lastCounter) {
    $sql = "UPDATE app_state SET last_global_no = $lastGlobalNo, last_counter = $lastCounter, updated_at = NOW() WHERE device_id = $deviceId";
    return mysqli_query($con, $sql);
}

function getPreviousHash($con, $deviceId, $fiscalDayNo, $nextGlobalNo) {
    $previousGlobalNo = $nextGlobalNo - 1;
    
    $sql = "SELECT receipt_hash FROM receipt_hash_chain 
            WHERE device_id = $deviceId 
            AND fiscal_day_no = $fiscalDayNo 
            AND receipt_global_no = $previousGlobalNo";
    
    logMessage("Getting previous hash", [
        'device_id' => $deviceId,
        'fiscal_day_no' => $fiscalDayNo,
        'previous_global_no' => $previousGlobalNo,
        'sql' => $sql
    ]);
    
    $result = mysqli_query($con, $sql);
    
    if (!$result) {
        logMessage("Get previous hash query failed", ['error' => mysqli_error($con)]);
        return null;
    }
    
    if (mysqli_num_rows($result) > 0) {
        $row = mysqli_fetch_assoc($result);
        logMessage("Found previous hash", ['hash' => substr($row['receipt_hash'], 0, 30) . '...']);
        return $row['receipt_hash'];
    }
    
    logMessage("No previous hash found", [
        'global_no' => $previousGlobalNo,
        'exists_in_chain' => false
    ]);
    
    return null;
}

function saveReceiptHash($con, $deviceId, $fiscalDayNo, $globalNo, $receiptHash) {
    $sql = "INSERT INTO receipt_hash_chain (device_id, fiscal_day_no, receipt_global_no, receipt_hash) 
            VALUES ($deviceId, $fiscalDayNo, $globalNo, '$receiptHash')
            ON DUPLICATE KEY UPDATE receipt_hash = '$receiptHash'";
    return mysqli_query($con, $sql);
}

function createActivity($con, $deviceId, $fiscalDayNo, $globalNo, $counter, $previousHash, $products, $total, $tax, $status, $receiptId = null, $orderNumber = null, $receiptDate = null, $verificationCode = null, $qrCodeUrl = null) {
    $productsJson = mysqli_real_escape_string($con, json_encode($products));
    $prevHashSql = $previousHash ? "'" . mysqli_real_escape_string($con, $previousHash) . "'" : "NULL";
    $receiptIdSql = $receiptId ? "'" . mysqli_real_escape_string($con, $receiptId) . "'" : "NULL";
    $orderNumberSql = $orderNumber ? "'" . mysqli_real_escape_string($con, $orderNumber) . "'" : "NULL";
    $receiptDateSql = $receiptDate ? "'" . mysqli_real_escape_string($con, $receiptDate) . "'" : "NULL";
    $verificationCodeSql = $verificationCode ? "'" . mysqli_real_escape_string($con, $verificationCode) . "'" : "NULL";
    $qrCodeUrlSql = $qrCodeUrl ? "'" . mysqli_real_escape_string($con, $qrCodeUrl) . "'" : "NULL";
    
    $sql = "INSERT INTO fiscal_day_activities (
        user_id, device_id, fiscal_day_no, global_no, counter, previous_hash, 
        products, total_amount, tax_amount, status, receipt_id, order_number, 
        receipt_date, verification_code, qr_code_url
    ) VALUES (
        " . USER_ID . ", $deviceId, $fiscalDayNo, $globalNo, $counter, $prevHashSql, 
        '$productsJson', $total, $tax, '$status', $receiptIdSql, $orderNumberSql, 
        $receiptDateSql, $verificationCodeSql, $qrCodeUrlSql
    )";
    
    return mysqli_query($con, $sql);
}

// ============================================
// ZIMRA API CALLS
// ============================================

function zimraApiCall($con, $endpoint, $payload, $isPublic = false) {
    $url = ZIMRA_API_BASE . "/Device/v1/" . DEVICE_ID . "/$endpoint";
    
    if ($endpoint === 'submitReceipt') {
        $payload = ['receipt' => $payload];
    }
    
    $jsonPayload = json_encode($payload);
    logMessage("API Request", ['url' => $url, 'payload' => $jsonPayload]);

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonPayload);
    
    $deviceConfig = getDeviceConfig($con, DEVICE_ID);
    
    $headers = [
        'Content-Type: application/json',
        'DeviceModelName: ' . ($deviceConfig['device_model_name'] ?? 'ZIMRA-FD-001'),
        'DeviceModelVersion: 1.0'
    ];
    
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    
    if (!$isPublic && $deviceConfig && !empty($deviceConfig['cert_path'])) {
        curl_setopt($ch, CURLOPT_SSLCERT, $deviceConfig['cert_path']);
        curl_setopt($ch, CURLOPT_SSLKEY, $deviceConfig['key_path']);
    }
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);
    
    logMessage("API Response", ['http_code' => $httpCode, 'response' => $response]);
    
    if ($curlError) {
        return ['success' => false, 'message' => "cURL error: $curlError"];
    }
    
    $result = json_decode($response, true);
    
    if ($httpCode == 200) {
        return array_merge(['success' => true, 'http_code' => $httpCode], $result ?: []);
    }
    
    return ['success' => false, 'http_code' => $httpCode, 'message' => $result['message'] ?? "HTTP $httpCode", 'response' => $response];
}

function getZimraStatus($con) {
    return zimraApiCall($con, 'getStatus', ['deviceID' => DEVICE_ID], false);
}

function openZimraDay($con) {
    $result = zimraApiCall($con, 'openDay', [
        'deviceID' => DEVICE_ID,
        'fiscalDayOpenedDateTime' => date('Y-m-d\TH:i:s')
    ], false);
    
    if ($result['success'] && isset($result['fiscalDayNo'])) {
        mysqli_query($con, "UPDATE app_state SET current_fiscal_day_no = " . $result['fiscalDayNo'] . ", fiscal_day_status = 'FiscalDayOpened' WHERE device_id = " . DEVICE_ID);
    }
    return $result;
}

// ============================================
// SIGNATURE GENERATION
// ============================================

function generateReceiptSignature($deviceId, $receiptData, $receiptTaxes, $receiptCounter, $privateKeyPath, $previousHash = null) {
    $totalCents = (int) round($receiptData['receiptTotal'] * 100);
    
    $taxesStr = '';
    usort($receiptTaxes, function($a, $b) {
        if ($a['taxID'] != $b['taxID']) return $a['taxID'] - $b['taxID'];
        $codeA = $a['taxCode'] ?? '';
        $codeB = $b['taxCode'] ?? '';
        return strcmp($codeA, $codeB);
    });
    
    foreach ($receiptTaxes as $tax) {
        $code = $tax['taxCode'] ?? '';
        $pct = number_format((float)($tax['taxPercent'] ?? 0), 2, '.', '');
        $taxCents = (int) round($tax['taxAmount'] * 100);
        $salesCents = (int) round($tax['salesAmountWithTax'] * 100);
        $taxesStr .= $code . $pct . $taxCents . $salesCents;
    }
    
    $sigString = (int)$deviceId
        . strtoupper($receiptData['receiptType'])
        . strtoupper($receiptData['receiptCurrency'])
        . (int)$receiptData['receiptGlobalNo']
        . $receiptData['receiptDate']
        . $totalCents
        . $taxesStr;
    
    if ($receiptCounter > 1 && $previousHash) {
        $sigString .= $previousHash;
    }
    logMessage("DEBUG: Signature string", ['sig_string' => $sigString, 'length' => strlen($sigString)]);
    
    $hash = hash('sha256', $sigString, true);
    $hashB64 = base64_encode($hash);
    
    $privateKeyContent = file_get_contents($privateKeyPath);
    $privateKey = openssl_pkey_get_private($privateKeyContent);
    
    if (!$privateKey) {
        throw new Exception("Failed to load private key: " . openssl_error_string());
    }
    
    openssl_sign($sigString, $signature, $privateKey, OPENSSL_ALGO_SHA256);
    $signatureB64 = base64_encode($signature);
    
    openssl_free_key($privateKey);
    
    return [
        'hash' => $hashB64,
        'signature' => $signatureB64
    ];
}

// ============================================
// SUBMIT RECEIPT TO ZIMRA
// ============================================

function submitReceiptToZimra($con, $amount, $orderNumber, $shopId, $orderData = []) {
    try {
        $checkExistingSql = "SELECT receipt_id FROM fiscal_day_activities 
                             WHERE device_id = " . DEVICE_ID . " 
                             AND order_number = '$orderNumber' 
                             AND status = 'submitted'
                             AND receipt_id IS NOT NULL
                             LIMIT 1";
        $checkResult = mysqli_query($con, $checkExistingSql);
        
        if ($checkResult && mysqli_num_rows($checkResult) > 0) {
            $existing = mysqli_fetch_assoc($checkResult);
            logMessage("Order already submitted, skipping duplicate", ['order' => $orderNumber, 'receiptID' => $existing['receipt_id']]);
            return ['success' => true, 'receiptID' => $existing['receipt_id'], 'already_submitted' => true];
        }
        
        $currentState = getAppState($con, DEVICE_ID);
        if (!$currentState) {
            return ['success' => false, 'message' => 'No app state found. Open a fiscal day first.'];
        }
        
        $fiscalDayNo = $currentState['current_fiscal_day_no'];
        $nextGlobalNo = $currentState['last_global_no'] + 1;
        $nextCounter = $currentState['last_counter'] + 1;
        
        $lastReceiptSql = "SELECT receipt_date FROM fiscal_day_activities 
                           WHERE device_id = " . DEVICE_ID . " 
                           AND fiscal_day_no = $fiscalDayNo
                           ORDER BY global_no DESC LIMIT 1";
        $lastResult = mysqli_query($con, $lastReceiptSql);
        $lastReceiptDate = null;
        if ($lastResult && mysqli_num_rows($lastResult) > 0) {
            $lastRow = mysqli_fetch_assoc($lastResult);
            $lastReceiptDate = $lastRow['receipt_date'];
        }
        
        $receiptDate = date('Y-m-d\TH:i:s');
        if ($lastReceiptDate && $receiptDate <= $lastReceiptDate) {
            $receiptDate = date('Y-m-d\TH:i:s', strtotime($lastReceiptDate . ' +1 second'));
        }
        
        $previousHash = ($nextCounter > 1) ? getPreviousHash($con, DEVICE_ID, $fiscalDayNo, $nextGlobalNo) : null;
        
        $deviceConfig = getDeviceConfig($con, DEVICE_ID);
        if (!$deviceConfig) {
            return ['success' => false, 'message' => 'Device not found in database'];
        }
        
        // BUILD RECEIPT LINES WITH DISCOUNT HANDLING
        $lineItems = [];
        $receiptTaxesMap = [];
        $lineNo = 1;
        $totalReceiptAmount = 0;
        
        // Check for discount information - LOG THIS
        $hasDiscount = isset($orderData['has_discount']) ? $orderData['has_discount'] : false;
        $discountAmount = isset($orderData['discount']) ? floatval($orderData['discount']) : 0;
        $originalTotal = isset($orderData['original_total']) ? floatval($orderData['original_total']) : $amount;
        
        logMessage("Discount data received", [
            'order' => $orderNumber,
            'has_discount' => $hasDiscount,
            'discount_amount' => $discountAmount,
            'original_total' => $originalTotal,
            'orderData_keys' => array_keys($orderData)
        ]);
        
        if (isset($orderData['products']) && is_array($orderData['products']) && count($orderData['products']) > 0) {
            foreach ($orderData['products'] as $product) {
                $quantity = floatval($product['quantity']);
                $price = floatval($product['price']);
                $lineTotal = $quantity * $price;
                
                // Check for product-specific discount
                $productDiscount = isset($product['discountAmount']) ? floatval($product['discountAmount']) : 0;
                $productDiscountPercentage = isset($product['discountPercentage']) ? floatval($product['discountPercentage']) : 0;
                
                logMessage("Product discount check", [
                    'name' => $product['name'],
                    'price' => $price,
                    'discountAmount' => $productDiscount,
                    'discountPercentage' => $productDiscountPercentage
                ]);
                
                // Apply discount if present
                $effectivePrice = $price;
                if ($productDiscount > 0) {
                    $effectivePrice = $price - $productDiscount;
                } elseif ($productDiscountPercentage > 0) {
                    $effectivePrice = $price * (1 - $productDiscountPercentage / 100);
                }
                
                // If order has overall discount and product doesn't have individual discount
                if ($hasDiscount && $discountAmount > 0 && $productDiscount == 0 && $productDiscountPercentage == 0) {
                    // Distribute discount proportionally
                    $proportion = $lineTotal / $originalTotal;
                    $productDiscountShare = $discountAmount * $proportion;
                    $effectivePrice = $price - ($productDiscountShare / $quantity);
                }
                
                $discountedLineTotal = $effectivePrice * $quantity;
                $totalReceiptAmount += $discountedLineTotal;
                
                $taxPercent = 15.5;
                $taxCode = "A";
                $taxID = 517;
                
                if (isset($product['tax_type'])) {
                    if ($product['tax_type'] == 'zero') {
                        $taxPercent = 0;
                        $taxCode = "Z";
                        $taxID = 518;
                    } elseif ($product['tax_type'] == 'exempt') {
                        $taxPercent = null;
                        $taxCode = "E";
                        $taxID = 519;
                    }
                }
                
                $lineItems[] = [
                    "receiptLineType" => "Sale",
                    "receiptLineNo" => $lineNo++,
                    "receiptLineHSCode" => $product['code'] ?? "61091000",
                    "receiptLineName" => substr($product['name'], 0, 200),
                    "receiptLinePrice" => $effectivePrice,
                    "receiptLineQuantity" => $quantity,
                    "receiptLineTotal" => $discountedLineTotal,
                    "taxCode" => $taxCode,
                    "taxPercent" => $taxPercent,
                    "taxID" => $taxID
                ];
                
                $key = $taxID;
                if (!isset($receiptTaxesMap[$key])) {
                    $receiptTaxesMap[$key] = [
                        "taxCode" => $taxCode,
                        "taxID" => $taxID,
                        "taxPercent" => $taxPercent,
                        "taxAmount" => 0,
                        "salesAmountWithTax" => 0,
                        "totalLineAmount" => 0
                    ];
                }
                $receiptTaxesMap[$key]['totalLineAmount'] += $discountedLineTotal;
            }
        } else {
            $totalReceiptAmount = (float)$amount;
            $lineItems[] = [
                "receiptLineType" => "Sale",
                "receiptLineNo" => 1,
                "receiptLineHSCode" => "61091000",
                "receiptLineName" => "Order: " . $orderNumber,
                "receiptLinePrice" => $totalReceiptAmount,
                "receiptLineQuantity" => 1,
                "receiptLineTotal" => $totalReceiptAmount,
                "taxCode" => "A",
                "taxPercent" => 15.5,
                "taxID" => 517
            ];
            $receiptTaxesMap[517] = [
                "taxCode" => "A",
                "taxID" => 517,
                "taxPercent" => 15.5,
                "taxAmount" => 0,
                "salesAmountWithTax" => 0,
                "totalLineAmount" => $totalReceiptAmount
            ];
        }
        
        $receiptTaxes = [];
        $calculatedTotal = 0;
        
        foreach ($receiptTaxesMap as $key => $taxGroup) {
            $lineTotal = $taxGroup['totalLineAmount'];
            
            if ($taxGroup['taxPercent'] === null || $taxGroup['taxPercent'] == 0) {
                $taxAmount = 0;
                $salesAmountWithTax = $lineTotal;
            } else {
                $taxAmount = round($lineTotal * ($taxGroup['taxPercent'] / (100 + $taxGroup['taxPercent'])), 2);
                $salesAmountWithTax = $lineTotal;
            }
            
            $calculatedTotal += $salesAmountWithTax;
            
            $receiptTax = [
                "taxCode" => $taxGroup['taxCode'],
                "taxID" => $taxGroup['taxID'],
                "taxPercent" => $taxGroup['taxPercent'],
                "taxAmount" => $taxAmount,
                "salesAmountWithTax" => $salesAmountWithTax
            ];
            
            if ($taxGroup['taxPercent'] === null) {
                unset($receiptTax['taxPercent']);
            }
            
            $receiptTaxes[] = $receiptTax;
        }
        
        $finalTotal = $calculatedTotal;
        
        $receiptData = [
            "receiptType" => "FISCALINVOICE",
            "receiptCurrency" => "USD",
            "receiptGlobalNo" => $nextGlobalNo,
            "receiptDate" => $receiptDate,
            "receiptTotal" => $finalTotal
        ];
        
        $signature = generateReceiptSignature(
            DEVICE_ID, $receiptData, $receiptTaxes, $nextCounter, 
            $deviceConfig['key_path'], $previousHash
        );
        
        $receipt = [
            "receiptType" => "FISCALINVOICE",
            "receiptCurrency" => "USD",
            "receiptCounter" => $nextCounter,
            "receiptGlobalNo" => $nextGlobalNo,
            "invoiceNo" => "INV" . str_pad($nextGlobalNo, 6, '0', STR_PAD_LEFT),
            "receiptDate" => $receiptDate,
            "receiptLinesTaxInclusive" => true,
            "receiptLines" => $lineItems,
            "receiptTaxes" => $receiptTaxes,
            "receiptPayments" => [[
                "moneyTypeCode" => "Cash",
                "paymentAmount" => $finalTotal
            ]],
            "receiptTotal" => $finalTotal,
            "receiptPrintForm" => "Receipt48",
            "receiptDeviceSignature" => $signature,
            "username" => $shopId,
            "userNameSurname" => $orderData['cashier'] ?? 'System'
        ];
        
        $receipt["buyer"] = [
            "buyerRegisterName" => "John Moyo",
            "buyerTradeName" => "Moyo Enterprises",
            "buyerTIN" => "1001234567",
            "VATNumber" => "VG1001234",
            "buyerAddress" => [
                "province" => "Harare",
                "city" => "Harare",
                "street" => "45 Samora Machel Ave",
                "houseNo" => "45"
            ],
            "buyerContacts" => [
                "phoneNo" => "+263712345678",
                "email" => "john.moyo@example.com"
            ]
        ];
        
        logMessage("Submitting receipt", [
            'order' => $orderNumber, 
            'total_amount' => $finalTotal, 
            'global_no' => $nextGlobalNo, 
            'counter' => $nextCounter,
            'has_discount' => $hasDiscount,
            'discount_amount' => $discountAmount,
            'line_items' => count($lineItems)
        ]);
        
        $result = zimraApiCall($con, 'submitReceipt', $receipt, false);
        
        if ($result['success'] && isset($result['receiptID'])) {
            saveReceiptHash($con, DEVICE_ID, $fiscalDayNo, $nextGlobalNo, $signature['hash']);
            
            $verificationHash = md5($signature['hash']);
            $verificationCodeRaw = strtoupper(substr($verificationHash, 0, 16));
            $verificationCode = implode('-', str_split($verificationCodeRaw, 4));
            
            $qrBaseUrl = "https://fdmstest.zimra.co.zw/";
            $deviceIdPadded = str_pad(DEVICE_ID, 10, '0', STR_PAD_LEFT);
            $receiptDateFormatted = date('dmY', strtotime($receiptDate));
            $globalNoPadded = str_pad($nextGlobalNo, 10, '0', STR_PAD_LEFT);
            $qrData = strtoupper(substr(md5($signature['hash']), 0, 16));
            $qrCodeUrl = $qrBaseUrl . $deviceIdPadded . $receiptDateFormatted . $globalNoPadded . $qrData;
            
            $productsData = [];
            foreach ($lineItems as $item) {
                $productsData[] = [
                    'name' => $item['receiptLineName'],
                    'qty' => $item['receiptLineQuantity'],
                    'price' => $item['receiptLinePrice'],
                    'total' => $item['receiptLineTotal']
                ];
            }
            
            $totalTax = 0;
            foreach ($receiptTaxes as $tax) {
                $totalTax += $tax['taxAmount'];
            }
            
            createActivity($con, DEVICE_ID, $fiscalDayNo, $nextGlobalNo, $nextCounter, 
                $previousHash, $productsData, 
                $finalTotal, $totalTax, 'submitted', $result['receiptID'], 
                $orderNumber, $receiptDate, $verificationCode, $qrCodeUrl);
            
            updateAppState($con, DEVICE_ID, $nextGlobalNo, $nextCounter);
            
            logMessage("Receipt submitted successfully", [
                'receiptID' => $result['receiptID'],
                'global_no' => $nextGlobalNo,
                'total_amount' => $finalTotal,
                'tax_amount' => $totalTax
            ]);
            
            return ['success' => true, 'receiptID' => $result['receiptID'], 'operationID' => $result['operationID'] ?? null];
        }
        
        return ['success' => false, 'message' => $result['message'] ?? 'Submission failed'];
        
    } catch (Exception $e) {
        logMessage("Submit exception", ['error' => $e->getMessage()]);
        return ['success' => false, 'message' => $e->getMessage()];
    }
}

// ============================================
// PROCESS RETRY QUEUE
// ============================================

function processRetryQueue($con) {
    $retryProcessed = 0;
    $retrySuccess = 0;
    
    $sql = "SELECT * FROM zimra_retry_queue WHERE attempts < 3 ORDER BY created_at LIMIT 10";
    $result = mysqli_query($con, $sql);
    
    if (!$result) {
        logMessage("Retry query failed", ['error' => mysqli_error($con)]);
        return ['retry_processed' => 0, 'retry_success' => 0];
    }
    
    while ($item = mysqli_fetch_assoc($result)) {
        $attemptNum = $item['attempts'] + 1;
        
        logMessage("Processing retry", ['order' => $item['order_number'], 'amount' => $item['amount'], 'attempt' => $attemptNum]);
        
        $zimraResult = submitReceiptToZimra($con, $item['amount'], $item['order_number'], $item['shopid'], ['retry' => true]);
        
        if ($zimraResult['success']) {
            $retrySuccess++;
            $retryProcessed++;
            mysqli_query($con, "DELETE FROM zimra_retry_queue WHERE id = " . $item['id']);
            logMessage("Retry successful", ['order' => $item['order_number'], 'receiptID' => $zimraResult['receiptID']]);
        } else {
            $retryProcessed++;
            $errorMsg = mysqli_real_escape_string($con, substr($zimraResult['message'] ?? 'Unknown error', 0, 500));
            mysqli_query($con, "UPDATE zimra_retry_queue SET attempts = attempts + 1, last_error = '$errorMsg' WHERE id = " . $item['id']);
            logMessage("Retry failed", ['order' => $item['order_number'], 'attempt' => $attemptNum, 'message' => $zimraResult['message']]);
        }
        
        usleep(500000);
    }
    
    return ['retry_processed' => $retryProcessed, 'retry_success' => $retrySuccess];
}

// ============================================
// PROCESS INVENTORY WITH DISCOUNT HANDLING
// ============================================

function updateInventory($con, $shopId, $products, &$lowStockProducts) {
    foreach ($products as $product) {
        $productCode = mysqli_real_escape_string($con, $product['code']);
        $quantitySold = floatval($product['quantity']);
        $price = floatval($product['price'] ?? 0);
        
        // Check for product-specific discount
        $productDiscount = isset($product['discountAmount']) ? floatval($product['discountAmount']) : 0;
        $productDiscountPercentage = isset($product['discountPercentage']) ? floatval($product['discountPercentage']) : 0;
        
        // Calculate effective price after discount
        $effectivePrice = $price;
        if ($productDiscount > 0) {
            $effectivePrice = $price - $productDiscount;
        } elseif ($productDiscountPercentage > 0) {
            $effectivePrice = $price * (1 - $productDiscountPercentage / 100);
        }
        
        logMessage("Inventory update", [
            'code' => $productCode,
            'price' => $price,
            'effective_price' => $effectivePrice,
            'discount_amount' => $productDiscount,
            'discount_percentage' => $productDiscountPercentage
        ]);
        
        $sql = "SELECT * FROM `retail products` WHERE shopid = '$shopId' AND `serial id` = '$productCode'";
        $result = mysqli_query($con, $sql);
        
        if ($row = mysqli_fetch_assoc($result)) {
            $newQuantity = floatval($row['quantity']) - $quantitySold;
            $currentAmountSold = floatval($row['amount sold']) + $quantitySold;
            $currentRevenue = floatval($row['product revenue']) + ($effectivePrice * $quantitySold);
            
            // Calculate total discount given on this product
            $productTotalDiscount = ($price - $effectivePrice) * $quantitySold;
            $currentDiscount = isset($row['discount']) ? floatval($row['discount']) : 0;
            $newDiscount = $currentDiscount + $productTotalDiscount;
            
            if ($newQuantity < 5 && $newQuantity >= 0) {
                $lowStockProducts[] = [
                    'name' => $row['name'], 
                    'code' => $productCode, 
                    'quantity' => $newQuantity
                ];
            }
            
            $updateSql = "UPDATE `retail products` SET 
                          quantity = '$newQuantity', 
                          `amount sold` = '$currentAmountSold', 
                          `product revenue` = '$currentRevenue',
                          `discount` = '$newDiscount'
                          WHERE shopid = '$shopId' AND `serial id` = '$productCode'";
            
            if (!mysqli_query($con, $updateSql)) {
                logMessage("Inventory update failed", [
                    'product' => $productCode, 
                    'error' => mysqli_error($con),
                    'discount_applied' => $productTotalDiscount
                ]);
            }
        }
    }
}

// ============================================
// SEND LOW STOCK EMAIL
// ============================================

function sendLowStockEmail($shopId, $products) {
    if (empty($products)) return;
    
    $subject = "Low Stock Alert - " . date('Y-m-d');
    $message = "Dear Shop Owner,\n\nThe following products are running low:\n\n";
    foreach ($products as $item) {
        $message .= "• {$item['name']} (Code: {$item['code']}) - {$item['quantity']} left\n";
    }
    $message .= "\nPlease restock soon.\n\nTradeSmart Team";
    
    mail($shopId, $subject, $message, "From: no-reply@blueichor.org\r\nReply-To: support@blueichor.org\r\n");
}

// ============================================
// MAIN PROCESSING
// ============================================

// Initialize tables
initTables($con);

// Get and validate input
$payload = file_get_contents('php://input');
$data = json_decode($payload, true);

if (!$data || !isset($data['username']) || !isset($data['orders'])) {
    sendResponse(false, 'Invalid payload. Required: username, orders');
}

$shopId = mysqli_real_escape_string($con, $data['username']);
$orders = $data['orders'];

logMessage("Processing orders", ['shop' => $shopId, 'count' => count($orders)]);

// Log the first order to see what's being sent
if (count($orders) > 0) {
    logMessage("First order data", [
        'order' => $orders[0],
        'has_has_discount' => isset($orders[0]['has_discount']),
        'has_discount' => isset($orders[0]['has_discount']) ? $orders[0]['has_discount'] : 'NOT SET',
        'has_discount_value' => isset($orders[0]['discount']) ? $orders[0]['discount'] : 'NOT SET'
    ]);
}

// Check ZIMRA status and open day if needed
$status = getZimraStatus($con);
$zimraReady = false;
$zimraDayOpened = false;

if ($status['success'] && isset($status['fiscalDayStatus'])) {
    if ($status['fiscalDayStatus'] === 'FiscalDayOpened') {
        $zimraReady = true;
        logMessage("ZIMRA fiscal day already open");
    } elseif ($status['fiscalDayStatus'] === 'FiscalDayClosed') {
        logMessage("Attempting to open fiscal day");
        $openResult = openZimraDay($con);
        if ($openResult['success']) {
            $zimraReady = true;
            $zimraDayOpened = true;
            logMessage("Fiscal day opened", $openResult);
        }
    }
}

// Process orders
$results = [];
$lowStockProducts = [];
$zimraReceipts = [];
$totalProcessed = 0;
$zimraSuccess = 0;
$zimraFailed = 0;
$totalDiscounts = 0;
$discountedOrders = 0;

foreach ($orders as $order) {
    $orderNumber = mysqli_real_escape_string($con, $order['orderNumber']);
    $cashier = mysqli_real_escape_string($con, $order['cashierName'] ?? 'Unknown');
    $total = floatval($order['total']);
    $timestamp = $order['timestamp'] ?? date('Y-m-d H:i:s');
    
    // Extract discount information - check multiple possible field names
    $hasDiscount = false;
    $discountAmount = 0;
    $originalTotal = $total;
    
    // Check for discount in various possible locations
    if (isset($order['has_discount'])) {
        $hasDiscount = $order['has_discount'];
        logMessage("Found has_discount in order", ['value' => $hasDiscount]);
    } elseif (isset($order['appliedDiscount'])) {
        $hasDiscount = true;
        logMessage("Found appliedDiscount in order");
    }
    
    if (isset($order['discount'])) {
        $discountAmount = floatval($order['discount']);
        logMessage("Found discount in order", ['value' => $discountAmount]);
    } elseif (isset($order['discountAmount'])) {
        $discountAmount = floatval($order['discountAmount']);
        logMessage("Found discountAmount in order", ['value' => $discountAmount]);
    }
    
    if (isset($order['original_total'])) {
        $originalTotal = floatval($order['original_total']);
        logMessage("Found original_total in order", ['value' => $originalTotal]);
    } elseif (isset($order['originalTotal'])) {
        $originalTotal = floatval($order['originalTotal']);
        logMessage("Found originalTotal in order", ['value' => $originalTotal]);
    }
    
    // If discount is present but not flagged, flag it
    if ($discountAmount > 0 && !$hasDiscount) {
        $hasDiscount = true;
        logMessage("Discount detected by amount, setting has_discount to true");
    }
    
    if ($hasDiscount && $discountAmount > 0) {
        $totalDiscounts += $discountAmount;
        $discountedOrders++;
        logMessage("Processing discounted order", [
            'order' => $orderNumber,
            'discount' => $discountAmount,
            'original_total' => $originalTotal,
            'final_total' => $total
        ]);
    }
    
    // Calculate product quantities
    $productQtys = [];
    foreach ($order['products'] as $product) {
        $name = $product['name'];
        $productQtys[$name] = ($productQtys[$name] ?? 0) + floatval($product['quantity']);
    }
    
    // Check duplicate
    $checkSql = "SELECT id FROM `retailers complete orders` WHERE shopid = '$shopId' AND `order-number` = '$orderNumber'";
    if (mysqli_num_rows(mysqli_query($con, $checkSql)) > 0) {
        $results[] = ['orderNumber' => $orderNumber, 'skipped' => true, 'reason' => 'Duplicate'];
        continue;
    }
    
    // Insert order with discount fields
    $productsSerialized = mysqli_real_escape_string($con, serialize($productQtys));
    $time = date("h:i A", strtotime($timestamp));
    $date = date("l jS \of F Y", strtotime($timestamp));
    $discountValue = $hasDiscount ? $discountAmount : 0;
    $originalTotalValue = $hasDiscount ? $originalTotal : $total;
    
    logMessage("Inserting order", [
        'order' => $orderNumber,
        'discount' => $discountValue,
        'original_total' => $originalTotalValue,
        'final_total' => $total
    ]);
    
    $insertSql = "INSERT INTO `retailers complete orders` 
                  (shopid, `order-number`, products, time, date, total, Source, cashier, discount, original_total) 
                  VALUES (
                      '$shopId', 
                      '$orderNumber', 
                      '$productsSerialized', 
                      '$time', 
                      '$date', 
                      $total, 
                      'online', 
                      '$cashier',
                      $discountValue,
                      $originalTotalValue
                  )";
    
    if (!mysqli_query($con, $insertSql)) {
        $results[] = ['orderNumber' => $orderNumber, 'error' => mysqli_error($con)];
        continue;
    }
    
    $totalProcessed++;
    
    // Submit to ZIMRA with discount data
    if ($zimraReady) {
        $zimraResult = submitReceiptToZimra($con, $total, $orderNumber, $shopId, [
            'cashier' => $cashier, 
            'products' => $order['products'],
            'has_discount' => $hasDiscount,
            'discount' => $discountAmount,
            'original_total' => $originalTotalValue
        ]);
        
        $receiptEntry = [
            'orderNumber' => $orderNumber, 
            'amount' => $total, 
            'has_discount' => $hasDiscount,
            'discount_amount' => $discountAmount,
            'zimra_response' => $zimraResult
        ];
        
        if ($zimraResult['success']) {
            $zimraSuccess++;
            $receiptEntry['status'] = 'success';
            $receiptEntry['receiptID'] = $zimraResult['receiptID'];
            logMessage("ZIMRA success", ['order' => $orderNumber, 'receiptID' => $zimraResult['receiptID']]);
        } else {
            $zimraFailed++;
            $receiptEntry['status'] = 'failed';
            $receiptEntry['error'] = $zimraResult['message'];
            mysqli_query($con, "INSERT INTO zimra_retry_queue (order_number, shopid, amount, last_error) VALUES ('$orderNumber', '$shopId', $total, '" . mysqli_real_escape_string($con, $zimraResult['message']) . "')");
            logMessage("ZIMRA failed, queued", ['order' => $orderNumber, 'error' => $zimraResult['message']]);
        }
        
        $zimraReceipts[] = $receiptEntry;
    } else {
        mysqli_query($con, "INSERT INTO zimra_retry_queue (order_number, shopid, amount, last_error) VALUES ('$orderNumber', '$shopId', $total, 'ZIMRA not ready')");
        $zimraFailed++;
        $zimraReceipts[] = [
            'orderNumber' => $orderNumber, 
            'amount' => $total, 
            'has_discount' => $hasDiscount,
            'discount_amount' => $discountAmount,
            'status' => 'queued'
        ];
    }
    
    // Update inventory with discount handling
    updateInventory($con, $shopId, $order['products'], $lowStockProducts);
}

// Process retry queue
$retryStats = processRetryQueue($con);

// Send low stock email
sendLowStockEmail($shopId, $lowStockProducts);

// Cleanup old retry entries (7+ days)
mysqli_query($con, "DELETE FROM zimra_retry_queue WHERE created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)");

// Send response
sendResponse(true, 'Orders processed', [
    'summary' => [
        'total_orders' => count($orders),
        'processed' => $totalProcessed,
        'zimra_success' => $zimraSuccess,
        'zimra_failed' => $zimraFailed,
        'retry_processed' => $retryStats['retry_processed'],
        'retry_success' => $retryStats['retry_success'],
        'zimra_day_opened' => $zimraDayOpened,
        'total_discounts_given' => $totalDiscounts,
        'discounted_orders' => $discountedOrders
    ],
    'zimra_initial_status' => $status,
    'zimra_receipts' => $zimraReceipts,
    'low_stock_products' => $lowStockProducts,
    'warning' => $zimraFailed > 0 ? "$zimraFailed receipt(s) failed. Retry queue active." : null
]);

mysqli_close($con);
?>