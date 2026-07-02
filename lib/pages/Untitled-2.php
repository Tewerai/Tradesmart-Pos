<?php
/**
 * uploadOffline.php - ZIMRA Demo Sales Generator
 * Fixed AJAX detection
 */

// Always set JSON header for AJAX requests based on the action parameter
if (isset($_GET['action'])) {
    header('Content-Type: application/json');
    error_reporting(E_ALL);
    ini_set('display_errors', 0); // Don't show errors in output
    ini_set('log_errors', 1);
}

set_time_limit(300);

$con = mysqli_connect("localhost", "blueicho_try", "iloveGrace1", "blueicho_try");
date_default_timezone_set("Africa/Johannesburg");

if (mysqli_connect_errno()) {
    if (isset($_GET['action'])) {
        echo json_encode(['success' => false, 'message' => 'Database connection failed']);
        exit;
    }
    die(json_encode(['success' => false, 'message' => 'Database connection failed']));
}

// Configuration
$shopEmail = 'zambuko@gmail.com';
$requestDir = '/tmp/zimra_requests';
$responseDir = '/tmp/zimra_responses';

// Ensure directories exist
if (!is_dir($requestDir)) mkdir($requestDir, 0777, true);
if (!is_dir($responseDir)) mkdir($responseDir, 0777, true);

// Function to queue a ZIMRA request
function queueZimraRequest($action, $args = [], $timeout = 30) {
    global $requestDir, $responseDir;
    
    $responseId = uniqid() . '_' . time();
    $requestFile = $requestDir . '/' . $responseId . '.json';
    $responseFile = $responseDir . '/' . $responseId . '.json';
    
    // Write request to queue
    $request = [
        'action' => $action,
        'args' => $args,
        'response_id' => $responseId,
        'timestamp' => time()
    ];
    
    file_put_contents($requestFile, json_encode($request));
    
    // Wait for response (polling)
    $startTime = time();
    while (!file_exists($responseFile) && (time() - $startTime) < $timeout) {
        usleep(500000); // Wait 0.5 seconds
    }
    
    if (file_exists($responseFile)) {
        $response = json_decode(file_get_contents($responseFile), true);
        unlink($responseFile);
        return $response;
    }
    
    // Timeout - try to clean up
    if (file_exists($requestFile)) unlink($requestFile);
    return ['success' => false, 'message' => 'Request timeout after ' . $timeout . ' seconds', 'action' => $action];
}

// Handle AJAX requests - check by action parameter, not by HTTP_X_REQUESTED_WITH
if (isset($_GET['action'])) {
    $action = $_GET['action'];
    
    switch ($action) {
        case 'get_status':
            $result = queueZimraRequest('status');
            echo json_encode($result);
            break;
            
        case 'open_day':
            $result = queueZimraRequest('open');
            echo json_encode($result);
            break;
            
        case 'close_day':
            $result = queueZimraRequest('close');
            echo json_encode($result);
            break;
            
        case 'generate_demo':
            $numOrders = intval($_GET['num_orders'] ?? 3);
            $result = generateDemoSales($numOrders);
            echo json_encode($result);
            break;
            
        default:
            echo json_encode(['success' => false, 'message' => 'Unknown action: ' . $action]);
    }
    exit;
}

// Function to get random products from shop
function getRandomProducts($con, $shopId, $numProducts = 3) {
    $sql = "SELECT name, `serial id`, price, quantity 
            FROM `retail products` 
            WHERE shopid = '$shopId' AND quantity > 0 
            ORDER BY RAND() 
            LIMIT $numProducts";
    
    $result = mysqli_query($con, $sql);
    $products = [];
    
    while ($row = mysqli_fetch_assoc($result)) {
        $maxQty = min(5, $row['quantity']);
        $products[] = [
            'name' => $row['name'],
            'code' => $row['serial id'],
            'price' => floatval($row['price']),
            'quantity' => intval($row['quantity']),
            'quantity_sold' => rand(1, max(1, $maxQty))
        ];
    }
    
    return $products;
}

// Function to calculate order total
function calculateOrderTotal($products) {
    $total = 0;
    foreach ($products as $product) {
        $total += $product['price'] * $product['quantity_sold'];
    }
    return round($total, 2);
}

// Function to submit receipt to ZIMRA via queue
function submitReceiptToZimra($amount, $orderNumber) {
    return queueZimraRequest('submit', ['amount' => $amount, 'order_number' => $orderNumber], 60);
}

// Function to generate demo sales
function generateDemoSales($numOrders) {
    global $con, $shopEmail;
    
    $allZimraReceipts = [];
    $totalSales = 0;
    $successCount = 0;
    $failCount = 0;
    
    for ($i = 1; $i <= $numOrders; $i++) {
        $numProducts = rand(1, 4);
        $products = getRandomProducts($con, $shopEmail, $numProducts);
        
        if (empty($products)) {
            continue;
        }
        
        $total = calculateOrderTotal($products);
        $totalSales += $total;
        
        $orderNumber = 'DEMO-' . date('YmdHis') . '-' . str_pad($i, 3, '0', STR_PAD_LEFT);
        
        $zimraResult = submitReceiptToZimra($total, $orderNumber);
        
        $orderData = [
            'orderNumber' => $orderNumber,
            'total' => $total,
            'products' => $products,
            'timestamp' => date('Y-m-d H:i:s')
        ];
        
        if (isset($zimraResult['receiptID'])) {
            $successCount++;
            $orderData['zimra'] = [
                'success' => true,
                'receiptID' => $zimraResult['receiptID'],
                'operationID' => $zimraResult['operationID'] ?? ''
            ];
            $allZimraReceipts[] = $orderData;
            
            // Save to database
            $productsSerialized = serialize($products);
            $time = date("h:i A");
            $saleDate = date("l jS \of F Y");
            
            $insertSql = "INSERT INTO `retailers complete orders`
                (shopid, `order-number`, products, time, date, total, Source, cashier)
                VALUES ('$shopEmail', '$orderNumber', '$productsSerialized', '$time', '$saleDate', '$total', 'demo', 'Demo System')";
            mysqli_query($con, $insertSql);
            
            // Update inventory
            foreach ($products as $product) {
                $updateSql = "UPDATE `retail products` 
                              SET quantity = quantity - {$product['quantity_sold']},
                                  `amount sold` = `amount sold` + {$product['quantity_sold']},
                                  `product revenue` = `product revenue` + " . ($product['price'] * $product['quantity_sold']) . "
                              WHERE shopid = '$shopEmail' AND `serial id` = '{$product['code']}'";
                mysqli_query($con, $updateSql);
            }
        } else {
            $failCount++;
            $orderData['zimra'] = [
                'success' => false,
                'error' => $zimraResult['message'] ?? 'Unknown error'
            ];
            $allZimraReceipts[] = $orderData;
        }
        
        usleep(500000); // 0.5 second delay
    }
    
    return [
        'success' => true,
        'total_orders' => $numOrders,
        'success_count' => $successCount,
        'fail_count' => $failCount,
        'total_sales' => $totalSales,
        'receipts' => $allZimraReceipts
    ];
}

// If not an AJAX request (no action parameter), display the HTML interface
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🇿🇼 ZIMRA Demo Sales Generator - TradeSmart</title>
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .card {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
            margin-bottom: 20px;
        }
        .card-header {
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: white;
            padding: 25px 30px;
        }
        .card-header h1 { font-size: 28px; margin-bottom: 5px; }
        .card-header p { opacity: 0.9; font-size: 14px; }
        .card-body { padding: 30px; }
        .status-bar {
            background: #f0f4f8;
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 25px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 15px;
        }
        .status-item { display: flex; align-items: center; gap: 10px; }
        .status-label { font-weight: 600; color: #4a5568; }
        .status-value {
            font-family: 'Courier New', monospace;
            font-weight: 700;
            padding: 5px 12px;
            border-radius: 20px;
            background: white;
        }
        .status-value.closed { background: #e53e3e; color: white; }
        .status-value.opened { background: #38a169; color: white; }
        .status-value.unknown { background: #ed8936; color: white; }
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.3s ease;
            font-size: 14px;
        }
        .btn-primary { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .btn-primary:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(102,126,234,0.4); }
        .btn-success { background: #38a169; color: white; }
        .btn-warning { background: #ed8936; color: white; }
        .btn-danger { background: #e53e3e; color: white; }
        .btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .control-group {
            background: #f7fafc;
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 25px;
        }
        .control-group label { display: block; margin-bottom: 10px; font-weight: 600; color: #2d3748; }
        .control-group input {
            width: 100px;
            padding: 10px;
            border: 2px solid #e2e8f0;
            border-radius: 10px;
            font-size: 16px;
            margin-right: 10px;
        }
        .button-group { display: flex; gap: 10px; flex-wrap: wrap; }
        .progress-section { display: none; margin-bottom: 25px; }
        .progress-bar {
            background: #e2e8f0;
            border-radius: 10px;
            overflow: hidden;
            height: 30px;
        }
        .progress-fill {
            background: linear-gradient(90deg, #38a169, #2f855a);
            height: 100%;
            width: 0%;
            transition: width 0.3s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: 600;
            font-size: 12px;
        }
        .results-section { display: none; }
        .summary-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 25px;
        }
        .stat-card {
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            border-radius: 15px;
            padding: 20px;
            text-align: center;
        }
        .stat-number { font-size: 32px; font-weight: bold; color: #2d3748; }
        .stat-label { font-size: 14px; color: #4a5568; margin-top: 5px; }
        .receipt-list { max-height: 400px; overflow-y: auto; }
        .receipt-item {
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            padding: 15px;
            margin-bottom: 10px;
            transition: all 0.2s ease;
        }
        .receipt-item.success { background: #f0fff4; border-left: 4px solid #38a169; }
        .receipt-item.failed { background: #fff5f5; border-left: 4px solid #e53e3e; }
        .receipt-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
            flex-wrap: wrap;
        }
        .receipt-order { font-weight: bold; color: #2d3748; }
        .receipt-id { font-family: monospace; font-size: 12px; color: #38a169; }
        .receipt-products { font-size: 13px; color: #4a5568; margin-top: 8px; }
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .alert { padding: 15px; border-radius: 10px; margin-bottom: 20px; }
        .alert-success { background: #c6f6d5; color: #22543d; border: 1px solid #9ae6b4; }
        .alert-error { background: #fed7d7; color: #742a2a; border: 1px solid #fc8181; }
        .alert-info { background: #bee3f8; color: #2c5282; border: 1px solid #90cdf4; }
        @media (max-width: 768px) {
            .card-body { padding: 20px; }
            .status-bar { flex-direction: column; align-items: stretch; }
            .button-group { flex-direction: column; }
            .btn { width: 100%; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="card">
            <div class="card-header">
                <h1>🇿🇼 ZIMRA Demo Sales Generator</h1>
                <p>TradeSmart Fiscal Device Integration - Test Environment</p>
            </div>
            <div class="card-body">
                <div class="status-bar">
                    <div class="status-item">
                        <span class="status-label">Shop:</span>
                        <span class="status-value"><?php echo htmlspecialchars($shopEmail); ?></span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">ZIMRA Status:</span>
                        <span class="status-value" id="zimraStatus">Loading...</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Fiscal Day:</span>
                        <span class="status-value" id="fiscalDay">-</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Last Global No:</span>
                        <span class="status-value" id="lastGlobalNo">-</span>
                    </div>
                </div>
                
                <div id="alertContainer"></div>
                
                <div class="control-group">
                    <label>📊 Number of Demo Orders:</label>
                    <input type="number" id="numOrders" value="3" min="1" max="20">
                    <div class="button-group" style="margin-top: 15px;">
                        <button class="btn btn-primary" id="refreshStatusBtn">🔄 Refresh Status</button>
                        <button class="btn btn-success" id="openDayBtn">📅 Open Fiscal Day</button>
                        <button class="btn btn-warning" id="generateBtn">🚀 Generate & Submit Demo Sales</button>
                        <button class="btn btn-danger" id="closeDayBtn">🔚 Close Fiscal Day</button>
                    </div>
                </div>
                
                <div class="progress-section" id="progressSection">
                    <div class="progress-bar">
                        <div class="progress-fill" id="progressFill">0%</div>
                    </div>
                    <p style="margin-top: 10px; text-align: center; font-size: 13px; color: #718096;" id="progressText">Processing...</p>
                </div>
                
                <div class="results-section" id="resultsSection">
                    <h3 style="margin-bottom: 15px;">📋 Demo Sales Results</h3>
                    <div class="summary-stats" id="summaryStats"></div>
                    <h4 style="margin: 20px 0 10px;">🧾 ZIMRA Receipts</h4>
                    <div class="receipt-list" id="receiptList"></div>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        $(document).ready(function() {
            refreshStatus();
            $('#refreshStatusBtn').click(function() { refreshStatus(); });
            $('#openDayBtn').click(function() { openFiscalDay(); });
            $('#generateBtn').click(function() { generateDemoSales($('#numOrders').val()); });
            $('#closeDayBtn').click(function() { closeFiscalDay(); });
        });
        
        function showAlert(message, type) {
            const alertClass = type === 'success' ? 'alert-success' : (type === 'error' ? 'alert-error' : 'alert-info');
            $('#alertContainer').append(`<div class="alert ${alertClass}">${message}</div>`);
            setTimeout(() => $('#alertContainer .alert').first().fadeOut(300, function() { $(this).remove(); }), 5000);
        }
        
        function refreshStatus() {
            $('#zimraStatus').html('<div class="loading"></div>');
            $.ajax({
                url: window.location.href,
                method: 'GET',
                data: { action: 'get_status' },
                dataType: 'json',
                timeout: 30000,
                success: function(response) {
                    if (response.success && response.ready) {
                        let statusClass = 'unknown', statusText = response.fiscalDayStatus;
                        if (response.fiscalDayStatus === 'FiscalDayClosed') { statusClass = 'closed'; statusText = '🔴 Closed'; }
                        else if (response.fiscalDayStatus === 'FiscalDayOpened') { statusClass = 'opened'; statusText = '🟢 Opened'; }
                        $('#zimraStatus').html(`<span class="status-value ${statusClass}">${statusText}</span>`);
                        $('#fiscalDay').text(response.fiscalDayNo || '-');
                        $('#lastGlobalNo').text(response.lastReceiptGlobalNo || '-');
                        showAlert('Status refreshed', 'success');
                    } else {
                        $('#zimraStatus').html('<span class="status-value unknown">⚠️ Offline</span>');
                        showAlert(response.message || 'Failed to get ZIMRA status', 'error');
                    }
                },
                error: function(xhr, status, error) {
                    $('#zimraStatus').html('<span class="status-value unknown">⚠️ Error</span>');
                    showAlert('Connection error: ' + status, 'error');
                }
            });
        }
        
        function openFiscalDay() {
            $('#openDayBtn').prop('disabled', true).html('<div class="loading"></div> Opening...');
            $.ajax({
                url: window.location.href,
                method: 'GET',
                data: { action: 'open_day' },
                dataType: 'json',
                timeout: 30000,
                success: function(response) {
                    if (response.success) {
                        showAlert(`✅ Fiscal Day ${response.fiscalDayNo} opened! Next receipt: #${response.nextReceiptNo}`, 'success');
                        refreshStatus();
                    } else {
                        showAlert(response.message || 'Failed to open fiscal day', 'error');
                    }
                },
                error: function() { showAlert('Error opening fiscal day', 'error'); },
                complete: function() { $('#openDayBtn').prop('disabled', false).html('📅 Open Fiscal Day'); }
            });
        }
        
        function closeFiscalDay() {
            $('#closeDayBtn').prop('disabled', true).html('<div class="loading"></div> Closing...');
            $.ajax({
                url: window.location.href,
                method: 'GET',
                data: { action: 'close_day' },
                dataType: 'json',
                timeout: 30000,
                success: function(response) {
                    if (response.operationID) {
                        showAlert(`✅ Fiscal Day closed! Operation ID: ${response.operationID}`, 'success');
                        refreshStatus();
                    } else {
                        showAlert(response.message || 'Failed to close fiscal day', 'error');
                    }
                },
                error: function() { showAlert('Error closing fiscal day', 'error'); },
                complete: function() { $('#closeDayBtn').prop('disabled', false).html('🔚 Close Fiscal Day'); }
            });
        }
        
        function generateDemoSales(numOrders) {
            $('#resultsSection').hide();
            $('#progressSection').show();
            $('#generateBtn').prop('disabled', true).html('<div class="loading"></div> Generating...');
            let progress = 0;
            const progressInterval = setInterval(() => { progress += 2; if (progress <= 90) { $('#progressFill').css('width', progress + '%'); $('#progressFill').text(progress + '%'); } }, 100);
            $.ajax({
                url: window.location.href,
                method: 'GET',
                data: { action: 'generate_demo', num_orders: numOrders },
                dataType: 'json',
                timeout: 120000,
                success: function(response) {
                    clearInterval(progressInterval);
                    $('#progressFill').css('width', '100%'); $('#progressFill').text('100%'); $('#progressText').text('Complete!');
                    setTimeout(() => {
                        $('#progressSection').hide();
                        if (response.success) {
                            displayResults(response);
                            showAlert(`✅ ${response.success_count} of ${response.total_orders} orders successful!`, 'success');
                            refreshStatus();
                        } else { showAlert('Failed to generate demo sales', 'error'); }
                        $('#progressFill').css('width', '0%'); $('#progressFill').text('0%');
                    }, 1000);
                },
                error: function() { clearInterval(progressInterval); $('#progressSection').hide(); showAlert('Error generating demo sales', 'error'); },
                complete: function() { $('#generateBtn').prop('disabled', false).html('🚀 Generate & Submit Demo Sales'); }
            });
        }
        
        function displayResults(data) {
            const successRate = data.total_orders > 0 ? Math.round((data.success_count / data.total_orders) * 100) : 0;
            $('#summaryStats').html(`
                <div class="stat-card"><div class="stat-number">${data.total_orders}</div><div class="stat-label">Total Orders</div></div>
                <div class="stat-card"><div class="stat-number">${data.success_count}</div><div class="stat-label">✅ Successful</div></div>
                <div class="stat-card"><div class="stat-number">${data.fail_count}</div><div class="stat-label">❌ Failed</div></div>
                <div class="stat-card"><div class="stat-number">$${data.total_sales.toFixed(2)}</div><div class="stat-label">Total Sales</div></div>
                <div class="stat-card"><div class="stat-number">${successRate}%</div><div class="stat-label">Success Rate</div></div>
            `);
            let receiptsHtml = '';
            data.receipts.forEach(function(receipt) {
                const statusClass = receipt.zimra.success ? 'success' : 'failed';
                const statusIcon = receipt.zimra.success ? '✅' : '❌';
                let productsHtml = '';
                receipt.products.forEach(function(product) {
                    productsHtml += `<div>• ${product.name}: ${product.quantity_sold} x $${product.price} = $${(product.price * product.quantity_sold).toFixed(2)}</div>`;
                });
                receiptsHtml += `
                    <div class="receipt-item ${statusClass}">
                        <div class="receipt-header">
                            <span class="receipt-order">${statusIcon} Order: ${receipt.orderNumber}</span>
                            ${receipt.zimra.success ? `<span class="receipt-id">Receipt ID: ${receipt.zimra.receiptID}</span>` : `<span class="receipt-id" style="color:#e53e3e;">Failed: ${receipt.zimra.error || 'Unknown'}</span>`}
                        </div>
                        <div class="receipt-products">${productsHtml}</div>
                        <div style="margin-top: 8px; font-weight: bold;">Total: $${receipt.total.toFixed(2)}</div>
                        <div style="font-size: 11px; color: #718096; margin-top: 5px;">${receipt.timestamp}</div>
                    </div>
                `;
            });
            $('#receiptList').html(receiptsHtml);
            $('#resultsSection').fadeIn();
        }
    </script>
</body>
</html>
<?php mysqli_close($con); ?>