<?php
set_time_limit(300); // Extends execution time to 5 minutes
date_default_timezone_set("Africa/Johannesburg");
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

$con = mysqli_connect("localhost", "blueicho_try", "iloveGrace1", "blueicho_try");

if (mysqli_connect_errno()) {
    echo json_encode(['success' => false, 'message' => 'Failed to connect to MySQL: ' . mysqli_connect_error()]);
    exit();
}

// 🔧 ZIMRA Queue Configuration
$requestDir = '/tmp/zimra_requests';
$responseDir = '/tmp/zimra_responses';
if (!is_dir($requestDir)) mkdir($requestDir, 0777, true);
if (!is_dir($responseDir)) mkdir($responseDir, 0777, true);

// 🔧 ZIMRA Queue Function (from demo code)
function queueZimraRequest($action, $args = [], $timeout = 30) {
    global $requestDir, $responseDir;
    
    $responseId = uniqid() . '_' . time();
    $requestFile = $requestDir . '/' . $responseId . '.json';
    $responseFile = $responseDir . '/' . $responseId . '.json';
    
    $request = [
        'action' => $action,
        'args' => $args,
        'response_id' => $responseId,
        'timestamp' => time()
    ];
    
    file_put_contents($requestFile, json_encode($request));
    
    $startTime = time();
    while (!file_exists($responseFile) && (time() - $startTime) < $timeout) {
        usleep(500000); // Wait 0.5 seconds
    }
    
    if (file_exists($responseFile)) {
        $response = json_decode(file_get_contents($responseFile), true);
        unlink($responseFile);
        return $response;
    }
    
    if (file_exists($requestFile)) unlink($requestFile);
    return ['success' => false, 'message' => 'Request timeout after ' . $timeout . ' seconds', 'action' => $action];
}

// 🔧 Submit receipt to ZIMRA wrapper
function submitReceiptToZimra($amount, $orderNumber) {
    return queueZimraRequest('submit', ['amount' => $amount, 'order_number' => $orderNumber], 60);
}

// 📥 Process uploaded order data
$payload = file_get_contents('php://input');
$data = json_decode($payload, true);

if (!$data) {
    echo json_encode(['success' => false, 'message' => 'Invalid or empty JSON payload']);
    mysqli_close($con);
    exit();
}

$shopId = $data['username'] ?? '';
$orders = $data['orders'] ?? [];

if (empty($shopId) || empty($orders)) {
    echo json_encode(['success' => false, 'message' => 'Missing username or orders in payload']);
    mysqli_close($con);
    exit();
}

$updateResults = [];
$lowStockProducts = [];
$zimraReceipts = []; // Track ZIMRA responses

foreach ($orders as $order) {
    $productQuantities = [];

    foreach ($order['products'] as $product) {
        $productName = $product['name'];
        $quantitySold = $product['quantity'];
        $productQuantities[$productName] = ($productQuantities[$productName] ?? 0) + $quantitySold;
    }

    $productsSerialized = serialize($productQuantities);
    $total = $order['total'];
    $cashier = $order['cashierName'] ?? 'Unknown';
    $orderNumber = $order['orderNumber'];
    $time = date("h:i A", strtotime($order["timestamp"]));
    $saleDate = date("l jS \of F Y", strtotime($order["timestamp"]));

    // 🔥 DUPLICATE CHECK
    $checkSql = "SELECT id FROM `retailers complete orders`
                 WHERE shopid = '$shopId' AND `order-number` = '$orderNumber'
                 LIMIT 1";
    $checkResult = mysqli_query($con, $checkSql);

    if (mysqli_num_rows($checkResult) > 0) {
        $updateResults[] = [
            'orderNumber' => $orderNumber,
            'skipped' => true,
            'reason' => 'Duplicate order detected'
        ];
        continue;
    }

    // ✅ INSERT NEW ORDER
    $insertOrderSql = "INSERT INTO `retailers complete orders`
        (shopid, `order-number`, products, time, date, total, Source, cashier)
        VALUES ('$shopId', '$orderNumber', '$productsSerialized', '$time', '$saleDate', '$total', 'offline', '$cashier')";
    
    if (!mysqli_query($con, $insertOrderSql)) {
        $updateResults[] = [
            'orderNumber' => $orderNumber,
            'insert_failed' => true,
            'error' => mysqli_error($con)
        ];
        continue;
    }

    // 🧾 SUBMIT TO ZIMRA (after successful DB insert)
    $zimraResult = submitReceiptToZimra($total, $orderNumber);
    $zimraReceipts[] = [
        'orderNumber' => $orderNumber,
        'zimra_response' => $zimraResult
    ];

    // 📦 PROCESS INVENTORY UPDATES
    foreach ($order['products'] as $product) {
        $productCode = $product['code'];
        $quantitySold = $product['quantity'];
        $price = $product['price'] ?? 0;

        $selectProductSql = "SELECT * FROM `retail products`
                             WHERE shopid = '$shopId' AND `serial id` = '$productCode'";
        $productResult = mysqli_query($con, $selectProductSql);

        if ($productRow = mysqli_fetch_assoc($productResult)) {
            $newQuantity = $productRow['quantity'] - $quantitySold;

            if ($newQuantity < 5) {
                $lowStockProducts[] = [
                    'name' => $productRow['name'],
                    'code' => $productRow['serial id'],
                    'quantity' => $newQuantity
                ];
            }

            $updateProductSql = "UPDATE `retail products` 
                                 SET quantity = '$newQuantity',
                                     `amount sold` = `amount sold` + $quantitySold,
                                     `product revenue` = `product revenue` + " . ($price * $quantitySold) . "
                                 WHERE shopid = '$shopId' AND `serial id` = '$productCode'";

            if (mysqli_query($con, $updateProductSql)) {
                $updateResults[] = ['code' => $productCode, 'updated' => true];
            } else {
                $updateResults[] = [
                    'code' => $productCode,
                    'updated' => false,
                    'error' => mysqli_error($con)
                ];
            }
        } else {
            $updateResults[] = [
                'code' => $productCode,
                'found' => false,
                'message' => 'Quick sale product, no inventory update'
            ];
        }
    }
}

// 📧 LOW STOCK EMAIL
if (!empty($lowStockProducts)) {
    $to = $shopId; // Assumes shopId is a valid email
    $subject = "Low Stock Alert";
    $message = "Dear Shop Owner,\n\nThe following products are running low on stock:\n\n";

    foreach ($lowStockProducts as $item) {
        $message .= "Product: {$item['name']}, Quantity Left: {$item['quantity']}\n";
    }

    $message .= "\nPlease restock soon.\n\nBest regards,\nTradeSmart Team";
    $headers = "From: no-reply@blueichor.org";

    mail($to, $subject, $message, $headers);
}

// ✅ FINAL RESPONSE
echo json_encode([
    'success' => true,
    'message' => 'Orders processed successfully.',
    'productUpdates' => $updateResults,
    'zimraReceipts' => $zimraReceipts, // ← New: ZIMRA submission results
    'lowStockAlerts' => count($lowStockProducts)
]);

mysqli_close($con);
?>