import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'pages/widgets/historyOrder.dart'; // Assuming this file contains Order and Product classes
import 'package:qr_flutter/qr_flutter.dart'; // Import for QR code generation
import 'dart:ui' as ui; // For ImageByteFormat
import 'package:image/image.dart' as img; // For image manipulation
import 'dart:typed_data'; // For Uint8List
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';

class ViewHistoryPage extends StatefulWidget {
  @override
  _ViewHistoryPageState createState() => _ViewHistoryPageState();
}

class _ViewHistoryPageState extends State<ViewHistoryPage> {
  List<Order> allOrders = []; // Store all orders
  List<Order> filteredOrders = []; // Store filtered orders for display
  List<Order> draftOrders = []; // Store draft orders separately
  
  double totalRevenue = 0.0;
  double totalSales = 0.0;
  double totalCredits = 0.0;
  double totalRefunds = 0.0;
  double totalDiscounts = 0.0; // New: Track total discounts
  int totalOrders = 0;
  int completedSalesCount = 0;
  int creditCount = 0;
  int refundCount = 0;
  int draftCount = 0;
  int discountedOrderCount = 0; // New: Track discounted orders count
  
  bool isLoading = false;
  bool isDownloading = false;
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _device;
  bool _connected = false;
  String? _selectedFilter; // For filtering orders (All, Sales, Credits, Refunds, Drafts)
  String currencySymbol = '\$';
  List<String> codes = [];
  bool _hideTotalOnHomepage = false;

  // Filter options with new Discount filter
  final List<String> filterOptions = [
    'All Orders',
    'Completed Sales',
    'Credits',
    'Refunds',
    'Saved Orders',
    'Discounted Orders' // New filter
  ];

  @override
  void initState() {
    super.initState();
    _checkPasswordRequirement();
    _loadOrders();
    _initBluetooth();
    loadCurrencySymbol();
  }

  // ==================== DISCOUNT HELPER METHODS ====================
  
  bool _hasDiscount(Order order) {
    // Check if order has an applied discount
    if (order.appliedDiscount != null) {
      return true;
    }
    
    // Check if any product has a discount
    for (var product in order.products) {
      if (product.discountAmount != null && product.discountAmount! > 0) {
        return true;
      }
      if (product.discountPercentage != null && product.discountPercentage! > 0) {
        return true;
      }
    }
    return false;
  }

  String _getDiscountDisplay(Order order) {
    if (order.appliedDiscount != null) {
      if (order.appliedDiscount!.type == DiscountType.Percentage) {
        return '${order.appliedDiscount!.value}% off';
      } else {
        return '$currencySymbol${order.appliedDiscount!.value.toStringAsFixed(2)} off';
      }
    }
    
    // Check if products have individual discounts
    double totalDiscount = 0;
    String discountType = '';
    for (var product in order.products) {
      if (product.discountAmount != null && product.discountAmount! > 0) {
        totalDiscount += product.discountAmount!;
        discountType = 'Price discount';
      } else if (product.discountPercentage != null && product.discountPercentage! > 0) {
        discountType = '${product.discountPercentage}% off';
      }
    }
    
    if (totalDiscount > 0) {
      return '$currencySymbol${totalDiscount.toStringAsFixed(2)} total discount';
    }
    
    return discountType.isNotEmpty ? discountType : '';
  }

  double _getDiscountAmount(Order order) {
    if (order.appliedDiscount != null) {
      if (order.appliedDiscount!.type == DiscountType.Percentage) {
        // Calculate percentage discount amount
        double originalTotal = 0;
        for (var product in order.products) {
          originalTotal += product.price * product.quantity;
        }
        return originalTotal * (order.appliedDiscount!.value / 100);
      } else {
        return order.appliedDiscount!.value;
      }
    }
    
    // Sum individual product discounts
    double totalDiscount = 0;
    for (var product in order.products) {
      if (product.discountAmount != null) {
        totalDiscount += product.discountAmount!;
      }
    }
    return totalDiscount;
  }

  double _getOriginalTotal(Order order) {
    double originalTotal = 0;
    for (var product in order.products) {
      originalTotal += product.price * product.quantity;
    }
    return originalTotal;
  }

  // ==================== EXISTING METHODS ====================

  Future<void> loadCurrencySymbol() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currencySymbol = prefs.getString('currencySymbol') ?? '\$';
    });
  }

  Future<void> _checkPasswordRequirement() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool requirePassword = prefs.getBool('addPasswordForUploadStock') ?? false;
    if (requirePassword) {
      _showPasswordDialog();
    }
  }

  Future<void> _showPasswordDialog() async {
    TextEditingController passwordController = TextEditingController();
    int passwordAttempts = 0;

    bool passwordMatched = false;
    while (passwordAttempts < 3 && !passwordMatched) {
      passwordMatched = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Enter Password'),
                content: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            errorText: passwordAttempts != 0
                                ? 'Wrong password, ${3 - passwordAttempts} attempt(s) remaining'
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                  ),
                  TextButton(
                    child: Text('Submit'),
                    onPressed: () async {
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      String savedPassword = prefs.getString('password') ?? '';
                      if (passwordController.text == savedPassword) {
                        Navigator.of(context).pop(true);
                      } else {
                        setState(() {
                          passwordAttempts++;
                        });
                        if (passwordAttempts >= 3) {
                          Navigator.of(context).pop(false);
                        }
                      }
                    },
                  ),
                ],
              );
            },
          ) ??
          false;
    }

    if (!passwordMatched && passwordAttempts >= 3) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _initBluetooth() async {
    _devices = await bluetooth.getBondedDevices();
    bluetooth.onStateChanged().listen((state) {
      setState(() {
        _connected = state == BlueThermalPrinter.CONNECTED;
      });
    });
    await _autoConnectSavedPrinter();
  }

  Future<bool> _isQuickSale(Order order) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> codes =
        (jsonDecode(prefs.getString('codes') ?? '[]') as List<dynamic>)
            .cast<String>();

    for (var product in order.products) {
      if (product.code.isNotEmpty && !codes.contains(product.code)) {
        return true;
      }
    }
    return false;
  }

  /* LOAD ORDERS */
/* LOAD ORDERS */
Future<void> _loadOrders() async {
  final prefs = await SharedPreferences.getInstance();
  bool hideTotal = prefs.getBool('hideTotalOnHomepage') ?? false;
  
  // Load complete orders
  List<String> ordersJson = prefs.getStringList('orders') ?? [];
  List<Order> loadedOrders =
      ordersJson.map((str) => Order.fromJson(json.decode(str))).toList();
  
  // Load draft orders
  List<String> draftOrdersJson = prefs.getStringList('draftOrders') ?? [];
  List<Order> loadedDraftOrders =
      draftOrdersJson.map((str) => Order.fromJson(json.decode(str))).toList();

  double revenue = 0.0;
  double sales = 0.0;
  double credits = 0.0;
  double refunds = 0.0;
  double discounts = 0.0;
  int salesCount = 0;
  int creditCount = 0;
  int refundCount = 0;
  int ordersCount = loadedOrders.length;
  int discountCount = 0;

  for (var order in loadedOrders) {
    // Track discounts (regardless of order type)
    if (_hasDiscount(order)) {
      discountCount++;
      discounts += _getDiscountAmount(order);
    }
    
    // Categorize orders properly
    if (order.isRefunded) {
      // This is a refunded order - count it as refund
      refunds += order.refundAmount;
      refundCount++;
      // Refunds are not revenue
    } else if (order.total < 0) {
      // This is a credit order (negative total)
      credits += order.total.abs();
      creditCount++;
      // Credits are not revenue
    } else {
      // This is a regular sale (positive total)
      sales += order.total;
      salesCount++;
      // Sales contribute to revenue
      revenue += order.total;
    }
  }

  setState(() {
    allOrders = loadedOrders;
    draftOrders = loadedDraftOrders;
    totalRevenue = revenue;
    totalSales = sales;
    totalCredits = credits;
    totalRefunds = refunds;
    totalDiscounts = discounts;
    discountedOrderCount = discountCount;
    completedSalesCount = salesCount;
    creditCount = creditCount;
    refundCount = refundCount;
    totalOrders = ordersCount;
    draftCount = loadedDraftOrders.length;
    codes = (jsonDecode(prefs.getString('codes') ?? '[]') as List<dynamic>)
        .cast<String>();
    _hideTotalOnHomepage = hideTotal;
    
    // Apply current filter
    _applyFilter();
  });
}
  // Apply filter based on selected option
// Apply filter based on selected option
void _applyFilter() {
  if (_selectedFilter == null || _selectedFilter == 'All Orders') {
    filteredOrders = List.from(allOrders);
  } else if (_selectedFilter == 'Completed Sales') {
    // Only regular sales (positive total, not refunded)
    filteredOrders = allOrders.where((order) => 
      !order.isRefunded && order.total > 0
    ).toList();
  } else if (_selectedFilter == 'Credits') {
    // Only credit orders (negative total, not refunded)
    filteredOrders = allOrders.where((order) => 
      !order.isRefunded && order.total < 0
    ).toList();
  } else if (_selectedFilter == 'Refunds') {
    // Only refunded orders
    filteredOrders = allOrders.where((order) => 
      order.isRefunded
    ).toList();
  } else if (_selectedFilter == 'Saved Orders') {
    // Draft orders
    filteredOrders = List.from(draftOrders);
  } else if (_selectedFilter == 'Discounted Orders') {
    // All orders that have discounts (regardless of type)
    filteredOrders = allOrders.where((order) => 
      _hasDiscount(order)
    ).toList();
  }
}
  /* MARK REFUNDED */
  void _markAsRefunded(int index) async {
    Order order = filteredOrders[index];
    int originalIndex = allOrders.indexWhere((o) => o.orderNumber == order.orderNumber);
    
    if (originalIndex != -1) {
      setState(() {
        allOrders[originalIndex].isRefunded = true;
        allOrders[originalIndex].refundAmount = allOrders[originalIndex].total.abs();
      });

      await _saveOrders();
      await _loadOrders(); // Reload to recalculate totals

      Fluttertoast.showToast(
          msg: 'Order marked as refunded',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> ordersJson =
        allOrders.map((order) => json.encode(order.toJson())).toList();
    await prefs.setStringList('orders', ordersJson);
  }

  // Enhanced method to download orders as Excel/CSV with clear categorization
  Future<void> _downloadOrdersAsExcel() async {
    setState(() {
      isDownloading = true;
    });
    final prefs = await SharedPreferences.getInstance();

    try {
      List<List<dynamic>> csvData = [];

      // Add summary section
      csvData.add(['ORDER SUMMARY REPORT']);
      csvData.add(['Generated on:', DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())]);
      csvData.add(['Filter Applied:', _selectedFilter ?? 'All Orders']);
      csvData.add([]);
      csvData.add(['Summary Statistics']);
      csvData.add(['Total Orders (All):', totalOrders]);
      csvData.add(['Draft Orders:', draftCount]);
      csvData.add(['Completed Sales:', '$completedSalesCount ($currencySymbol${totalSales.toStringAsFixed(2)})']);
      csvData.add(['Credit Orders:', '$creditCount ($currencySymbol${totalCredits.toStringAsFixed(2)})']);
      csvData.add(['Refunded Orders:', '$refundCount ($currencySymbol${totalRefunds.toStringAsFixed(2)})']);
      csvData.add(['Discounted Orders:', '$discountedOrderCount ($currencySymbol${totalDiscounts.toStringAsFixed(2)} saved)']);
      csvData.add(['Net Revenue:', '$currencySymbol${totalRevenue.toStringAsFixed(2)}']);
      csvData.add([]);
      csvData.add(['DETAILED ORDER LIST']);
      
      // Add headers with discount columns
      csvData.add([
        'Order Number',
        'Date',
        'Cashier Name',
        'Customer Name',
        'Order Type',
        'Payment Status',
        'Products',
        'Original Amount',
        'Discount Applied',
        'Discount Amount',
        'Final Total',
        'Currency',
        'Quick Sale',
        'Refund Amount (if refunded)',
        'Notes'
      ]);

      // Add order data (export all orders, not just filtered)
      for (var order in allOrders) {
        bool isQuickSale = order.products.any((product) =>
            product.code.isEmpty || !codes.contains(product.code));
        
        bool hasDiscount = _hasDiscount(order);
        String discountDisplay = _getDiscountDisplay(order);
        double discountAmount = _getDiscountAmount(order);
        double originalTotal = _getOriginalTotal(order);

        String productsStr = order.products.map((p) => 
          '${p.name} (Qty: ${p.quantity} x ${currencySymbol}${p.price.toStringAsFixed(2)} = ${currencySymbol}${(p.quantity * p.price).toStringAsFixed(2)}${p.discountAmount != null ? " - Discount: ${currencySymbol}${p.discountAmount!.toStringAsFixed(2)}" : ""}${p.discountPercentage != null ? " - ${p.discountPercentage}% off" : ""})'
        ).join('\n');

        String orderType = 'Sale';
        String paymentStatus = 'Paid';
        String notes = '';
        
        if (order.isRefunded) {
          orderType = 'Refund';
          paymentStatus = 'Refunded';
          notes = 'Original amount: ${currencySymbol}${order.total.abs().toStringAsFixed(2)}';
        } else if (order.total < 0) {
          orderType = 'Credit';
          paymentStatus = 'Unpaid/Credit';
          notes = 'Customer owes: ${currencySymbol}${order.total.abs().toStringAsFixed(2)}';
        } else if (hasDiscount) {
          orderType = 'Discounted Sale';
          paymentStatus = 'Paid (with discount)';
          notes = 'Discount: $discountDisplay, Saved: ${currencySymbol}${discountAmount.toStringAsFixed(2)}';
        }

        csvData.add([
          order.orderNumber,
          DateFormat('yyyy-MM-dd HH:mm:ss').format(order.timestamp),
          order.cashierName ?? 'N/A',
          order.customerName ?? 'N/A',
          orderType,
          paymentStatus,
          productsStr,
          originalTotal.toStringAsFixed(2),
          hasDiscount ? discountDisplay : 'No Discount',
          hasDiscount ? discountAmount.toStringAsFixed(2) : '0.00',
          order.total.abs().toStringAsFixed(2),
          currencySymbol,
          isQuickSale ? 'Yes' : 'No',
          order.isRefunded ? order.refundAmount.toStringAsFixed(2) : 'N/A',
          notes
        ]);
      }

      // Add footer with totals
      csvData.add([]);
      csvData.add(['END OF REPORT']);
      csvData.add(['Total Records:', allOrders.length]);
      csvData.add(['Total Discounts Given:', '$currencySymbol${totalDiscounts.toStringAsFixed(2)}']);
      csvData.add(['Number of Discounted Orders:', discountedOrderCount]);

      String csv = const ListToCsvConverter().convert(csvData);

      // For Android, try to save to Downloads folder first
      String path;
      try {
        if (Platform.isAndroid) {
          // Try to get the Downloads directory
          Directory? downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir != null) {
            // Create a custom directory for your app in Downloads
            final appDir = Directory('${downloadsDir.path}/TradeAppExports');
            if (!await appDir.exists()) {
              await appDir.create(recursive: true);
            }
            path = '${appDir.path}/orders_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
          } else {
            // Fallback to temporary directory
            final tempDir = await getTemporaryDirectory();
            path = '${tempDir.path}/orders_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
          }
        } else {
          // For iOS, use documents directory
          final docDir = await getApplicationDocumentsDirectory();
          path = '${docDir.path}/orders_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
        }
      } catch (e) {
        // Fallback to temporary directory if any error
        print("Error getting storage directory: $e");
        final tempDir = await getTemporaryDirectory();
        path = '${tempDir.path}/orders_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      }
      
      // Write file
      final file = File(path);
      await file.writeAsString(csv, encoding: utf8);

      // Show success toast that file is saved
      Fluttertoast.showToast(
        msg: "File saved to: $path",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.blue,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      // Small delay to let user see the save message
      await Future.delayed(Duration(seconds: 2));

      // Share the file
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Orders Report - Summary: $completedSalesCount Sales, $creditCount Credits, $refundCount Refunds, $discountedOrderCount Discounted',
        subject: 'Orders Data Export - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      );
      
      // Clear orders after successful export
      await clearOrdersFromSharedPreferences(prefs);
      
      setState(() {
        allOrders = [];
        filteredOrders = [];
        totalRevenue = 0.0;
        totalSales = 0.0;
        totalCredits = 0.0;
        totalRefunds = 0.0;
        totalDiscounts = 0.0;
        totalOrders = 0;
        completedSalesCount = 0;
        creditCount = 0;
        refundCount = 0;
        discountedOrderCount = 0;
      });

      Fluttertoast.showToast(
        msg: "Orders exported and cleared successfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );

    } catch (e) {
      print("Error exporting orders: $e");
      Fluttertoast.showToast(
        msg: "Error exporting orders: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } finally {
      setState(() {
        isDownloading = false;
      });
    }
  }

Future<void> uploadSalesOnline(BuildContext context) async {
  setState(() {
    isLoading = true;
  });

  const String uploadUrl = "https://blueichor.org/uploadOffline3.php";
  final prefs = await SharedPreferences.getInstance();
  final String? shopId = prefs.getString('username');

  if (shopId == null) {
    Fluttertoast.showToast(
        msg: "Username not found.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
    setState(() {
      isLoading = false;
    });
    return;
  }

  List<Map<String, dynamic>> ordersData = [];
  List<Order> ordersToKeep = [];

  for (var order in allOrders) {
    // Only upload non-refunded orders with positive total (regular sales)
    // BUT preserve discount information for these orders
    if (!order.isRefunded && order.total > 0) {
      // Create a copy of the order data with all fields including discount
      Map<String, dynamic> orderJson = order.toJson();
      
      // Ensure discount fields are included
      // The order.toJson() should already include discount data if your models are updated
      // But let's make sure they're explicitly set
      orderJson['discount'] = _getDiscountAmount(order);
      orderJson['original_total'] = _getOriginalTotal(order);
      orderJson['has_discount'] = _hasDiscount(order);
      
      ordersData.add(orderJson);
    } else {
      // Keep refunded and credit orders locally
      ordersToKeep.add(order);
    }
  }

  // If there are no orders to upload, show message
  if (ordersData.isEmpty) {
    Fluttertoast.showToast(
        msg: "No orders to upload.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        fontSize: 16.0);
    setState(() {
      isLoading = false;
    });
    return;
  }

  try {
    print('Uploading ${ordersData.length} orders with discount data...');
    
    var response = await http.post(
      Uri.parse(uploadUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'username': shopId,
        'orders': ordersData,
      }),
    );

    print('Upload response status: ${response.statusCode}');
    print('Upload response body: ${response.body}');

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse['success']) {
        // Keep non-uploaded orders (refunds, credits) in local storage
        await clearOrdersFromSharedPreferences(prefs);
        
        // Save the kept orders back to SharedPreferences
        if (ordersToKeep.isNotEmpty) {
          List<String> ordersJsonToKeep = 
              ordersToKeep.map((order) => jsonEncode(order.toJson())).toList();
          await prefs.setStringList('orders', ordersJsonToKeep);
        }

        setState(() {
          allOrders = ordersToKeep;
          _applyFilter();
          totalRevenue = 0.0;
          totalSales = 0.0;
          totalCredits = 0.0;
          totalRefunds = 0.0;
          totalDiscounts = 0.0;
          totalOrders = ordersToKeep.length;
          discountedOrderCount = 0;
        });

        Fluttertoast.showToast(
            msg: "Upload successful! ${ordersData.length} orders uploaded with discount info.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0);
      } else {
        Fluttertoast.showToast(
            msg: "Upload failed: ${jsonResponse['message'] ?? 'Unknown error'}",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0);
      }
    } else {
      Fluttertoast.showToast(
          msg: "Server error: ${response.statusCode}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
    }
  } catch (e) {
    print("Error uploading orders: $e");
    Fluttertoast.showToast(
        msg: "Error uploading orders: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}
  Future<void> clearOrdersFromSharedPreferences(SharedPreferences prefs) async {
    await prefs.remove('orders');
  }

  Future<void> _printLogo() async {
    final prefs = await SharedPreferences.getInstance();
    String? logoPath = prefs.getString('processedLogoPath');
    bool printLogo = prefs.getBool('printLogo') ?? true;

    if (printLogo && logoPath != null && _connected) {
      try {
        var result = await bluetooth.printImage(logoPath);
        if (result == true) {
          showToast("Logo printed successfully.");
        } else {
          showToast("Failed to print logo.");
        }
      } catch (e) {
        showToast("Error printing logo: $e");
      }
      bluetooth.printNewLine();
    } else {
      if (!_connected) {
        showToast("Printer not connected.");
      } else {
        showToast("Logo path not found or logo printing disabled.");
      }
    }
  }

  Future<void> _printOrderReceipt(Order order) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected != null && isConnected) {
      await _printLogo();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      var shopName = prefs.getString('fullname');
      var tel = prefs.getString('tel');
      var address = prefs.getString('address');
      bool printQRCode = prefs.getBool('printReceiptId') ?? true;
      String? cashierName = order.cashierName;

      bluetooth.printCustom(shopName ?? '', 3, 1);
      bluetooth.printCustom(tel ?? '', 3, 1);
      bluetooth.printCustom(address ?? '', 3, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom('-------------------------------', 1, 0);

      bluetooth.printCustom('Order Receipt', 2, 1);
      bluetooth.printNewLine();
      bluetooth.printLeftRight('Order Number', order.orderNumber, 1);
      if (cashierName != null && cashierName.isNotEmpty) {
        bluetooth.printLeftRight('Cashier', cashierName, 1);
      }
      bluetooth.printCustom(
          'Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(order.timestamp)}',
          1,
          1);
      bluetooth.printNewLine();
      bluetooth.printCustom('-------------------------------', 1, 0);
      bluetooth.printNewLine();

      bluetooth.printCustom('Products:', 1, 0);
      bluetooth.printNewLine();

      List<String> codes = (jsonDecode(prefs.getString('codes1') ?? '[]') as List<dynamic>).cast<String>();
      List<String> measures = (jsonDecode(prefs.getString('measure') ?? '[]') as List<dynamic>).cast<String>();

      for (int i = 0; i < order.products.length; i++) {
        Product product = order.products[i];
        double totalValue = product.price * product.quantity;

        int index = codes.indexOf(product.code);
        String quantityText = '${product.quantity}';
        if (index != -1 && measures.length > index) {
          quantityText += ' ${measures[index]}';
        }

        // Show discount info if applicable
        String discountText = '';
        if (product.discountAmount != null && product.discountAmount! > 0) {
          discountText = ' (Disc: $currencySymbol${product.discountAmount!.toStringAsFixed(2)})';
        } else if (product.discountPercentage != null && product.discountPercentage! > 0) {
          discountText = ' (${product.discountPercentage}% off)';
        }

        bluetooth.printCustom(
          "${i + 1}. ${product.name} x $quantityText @ $currencySymbol${product.price} = $currencySymbol${totalValue.toStringAsFixed(2)}$discountText",
          1,
          0,
        );
      }

      bluetooth.printNewLine();
      bluetooth.printCustom('-------------------------------', 1, 0);
      
      // Show discount info if order has discount
      if (_hasDiscount(order)) {
        double originalTotal = _getOriginalTotal(order);
        double discountAmount = _getDiscountAmount(order);
        bluetooth.printCustom('Original Total: $currencySymbol${originalTotal.toStringAsFixed(2)}', 1, 0);
        bluetooth.printCustom('Discount: -$currencySymbol${discountAmount.toStringAsFixed(2)}', 1, 0);
        bluetooth.printCustom('-------------------------------', 1, 0);
      }
      
      bluetooth.printCustom('Total: $currencySymbol${order.total.toStringAsFixed(2)}', 1, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      await Future.delayed(Duration(milliseconds: 500));

      if (printQRCode) {
        Map<String, dynamic> qrData = {
          "invoice": order.orderNumber,
        };

        String qrJson = jsonEncode(qrData);

        try {
          const int qrImageSourceSize = 384;

          final qrPainter = QrPainter(
            data: qrJson,
            version: QrVersions.auto,
            gapless: true,
            color: Colors.black,
            emptyColor: Colors.white,
          );

          final ui.Image qrImage = await qrPainter.toImage(qrImageSourceSize.toDouble());
          final ByteData? byteData =
              await qrImage.toByteData(format: ui.ImageByteFormat.png);
          final Uint8List pngBytes = byteData!.buffer.asUint8List();

          final img.Image? decodedImage = img.decodeImage(pngBytes);
          if (decodedImage != null) {
            final img.Image resizedImage = img.copyResize(decodedImage, width: 250);
            final img.Image grayscaleImage = img.grayscale(resizedImage);
            final Uint8List bmpBytes = Uint8List.fromList(img.encodeBmp(grayscaleImage));

            bluetooth.printImageBytes(bmpBytes);
            bluetooth.printNewLine();
            bluetooth.printNewLine();
          } else {
            showToast("Failed to decode QR code image.");
          }
        } catch (e) {
          showToast("Error generating or printing QR code image: $e");
        }
      }

      bluetooth.printNewLine();
      bluetooth.printCustom('--- End of Receipt ---', 0, 1);
      bluetooth.printNewLine();
      bluetooth.paperCut();
    } else {
      Fluttertoast.showToast(
          msg: "Printer not connected.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  Future<void> _autoConnectSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    String? printerAddress = prefs.getString('printerAddress0');
    if (printerAddress != null) {
      for (BluetoothDevice device in _devices) {
        if (device.address == printerAddress) {
          _device = device;
          try {
            await bluetooth.connect(_device!);
          } catch (e) {
            print("Error auto-connecting: $e");
            showToast("Failed to auto-connect to printer.");
          }
          break;
        }
      }
    }
  }

  // ==================== BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order History'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTotalRevenueCard(),
                _buildTotalOrdersCard(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildSalesSummaryCard(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedFilter,
                hint: Text('Filter Orders'),
                isExpanded: true,
                underline: SizedBox(),
                items: filterOptions.map((String value) {
                  String displayText = value;
                  // Add counts to dropdown items
                  if (value == 'All Orders') {
                    displayText = '$value (${allOrders.length})';
                  } else if (value == 'Completed Sales') {
                    displayText = '$value ($completedSalesCount)';
                  } else if (value == 'Credits') {
                    displayText = '$value ($creditCount)';
                  } else if (value == 'Refunds') {
                    displayText = '$value ($refundCount)';
                  } else if (value == 'Saved Orders') {
                    displayText = '$value ($draftCount)';
                  } else if (value == 'Discounted Orders') {
                    displayText = '$value ($discountedOrderCount)';
                  }
                  
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(displayText),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedFilter = newValue;
                    _applyFilter();
                  });
                },
              ),
            ),
          ),
          // Summary of current filter
          if (_selectedFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing: ${filteredOrders.length} orders',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                return _buildOrderItem(filteredOrders[index], index);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: isDownloading || allOrders.isEmpty
                ? null
                : _downloadOrdersAsExcel,
            tooltip: 'Download Orders as Excel',
            heroTag: 'download',
            backgroundColor: Colors.blue,
            child: isDownloading
                ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : Icon(Icons.download),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: isLoading
                ? null
                : () async {
                    await uploadSalesOnline(context);
                  },
            tooltip: 'Upload Sales Online',
            heroTag: 'upload',
            backgroundColor: Colors.green,
            child: isLoading
                ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : Icon(Icons.cloud_upload),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRevenueCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text('Net Revenue'),
            Text(
              _hideTotalOnHomepage
                  ? 'XX'
                  : '$currencySymbol${totalRevenue.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalOrdersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text('Total Orders'),
            Text('$totalOrders',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSummaryCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text('Sales Summary',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSummaryItem('Sales', totalSales, completedSalesCount, Colors.green),
                _buildSummaryItem('Credits', totalCredits, creditCount, Colors.orange),
                _buildSummaryItem('Refunds', totalRefunds, refundCount, Colors.red),
                _buildSummaryItem('Drafts', 0, draftCount, Colors.blue),
              ],
            ),
            // Add discount summary row
            if (discountedOrderCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryItem('Discounted Orders', 0, discountedOrderCount, Colors.purple),
                    _buildSummaryItem('Total Saved', totalDiscounts, 0, Colors.purple),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, int count, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: color)),
        if (amount > 0)
          Text('$currencySymbol${amount.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text('($count)',
            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildOrderItem(Order order, int index) {
    bool isQuickSale = order.products.any((product) =>
        product.code.isEmpty || !codes.contains(product.code));
    bool hasDiscount = _hasDiscount(order);
    String discountDisplay = _getDiscountDisplay(order);
    double discountAmount = _getDiscountAmount(order);
    double originalTotal = _getOriginalTotal(order);
    
    Color backgroundColor = Colors.white;
    String statusText = '';
    Color statusColor = Colors.green;
    
    if (order.isRefunded) {
      backgroundColor = Colors.grey[200]!;
      statusText = 'REFUNDED';
      statusColor = Colors.grey[600]!;
    } else if (order.total < 0) {
      backgroundColor = Colors.red[100]!;
      statusText = 'CREDIT';
      statusColor = Colors.red;
    } else if (isQuickSale) {
      backgroundColor = Colors.orange[100]!;
      statusText = 'QUICK SALE';
      statusColor = Colors.orange[800]!;
    } else if (hasDiscount) {
      backgroundColor = Colors.purple[50]!;
      statusText = 'DISCOUNT';
      statusColor = Colors.purple;
    } else {
      statusText = 'SALE';
      statusColor = Colors.green;
    }

    String titleText = order.total >= 0 ? 'Order Total' : 'Credits';

    return Card(
      color: backgroundColor,
      child: Stack(
        children: [
          // Status badge
          if (isQuickSale || order.isRefunded || order.total < 0 || hasDiscount)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ExpansionTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hideTotalOnHomepage && order.total >= 0
                      ? '$titleText: XX'
                      : '$titleText: $currencySymbol${order.total.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: (order.total >= 0 && !order.isRefunded) 
                        ? FontWeight.normal 
                        : FontWeight.bold,
                  ),
                ),
                if (hasDiscount)
                  Text(
                    'Discounted: $discountDisplay',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (hasDiscount && !_hideTotalOnHomepage)
                  Text(
                    'Original: $currencySymbol${originalTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              'Order ID: ${order.orderNumber}\n'
              '${_selectedFilter == 'Saved Orders' ? 'Customer: ${order.customerName ?? 'N/A'}\n' : ''}'
              'Cashier: ${order.cashierName ?? 'N/A'}'
            ),
            children: [
              // Order Details
              ListTile(
                title: Text('Order Details'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order ID: ${order.orderNumber}'),
                    Text('Customer: ${order.customerName ?? 'N/A'}'),
                    Text('Cashier: ${order.cashierName ?? 'N/A'}'),
                    if (hasDiscount) ...[
                      SizedBox(height: 4),
                      Text(
                        'Discount: $discountDisplay',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        'Original Total: $currencySymbol${originalTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        'Discounted Total: $currencySymbol${order.total.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Saved: $currencySymbol${discountAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Products List with Discount Info
              ...order.products.map((product) {
                String discountInfo = '';
                String discountedPriceText = '';
                
                if (product.discountAmount != null && product.discountAmount! > 0) {
                  discountInfo = 'Discount: $currencySymbol${product.discountAmount!.toStringAsFixed(2)}';
                  double discountedTotal = product.getTotalWithDiscount();
                  discountedPriceText = 'Discounted: $currencySymbol${discountedTotal.toStringAsFixed(2)}';
                } else if (product.discountPercentage != null && product.discountPercentage! > 0) {
                  discountInfo = 'Discount: ${product.discountPercentage!}%';
                  double discountedTotal = product.getTotalWithDiscount();
                  discountedPriceText = 'Discounted: $currencySymbol${discountedTotal.toStringAsFixed(2)}';
                }
                
                return ListTile(
                  title: Text(product.name),
                  subtitle: product.discountAmount != null || product.discountPercentage != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Original: $currencySymbol${(product.price * product.quantity).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            Text(
                              discountedPriceText,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              discountInfo,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        )
                      : null,
                  trailing: Text(
                    '$currencySymbol${product.price.toStringAsFixed(2)} x ${product.quantity} = $currencySymbol${(product.price * product.quantity).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
              
              // Refund info
              if (order.isRefunded)
                ListTile(
                  title: Text("Refunded", style: TextStyle(color: Colors.red)),
                  subtitle: Text(
                      "Refund Amount: $currencySymbol${order.refundAmount.toStringAsFixed(2)}"),
                ),
                
              // Credit actions
              if (order.total < 0 && !order.isRefunded)
                ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _markAsRefunded(index),
                        child: Text('Refund'),
                      ),
                      ElevatedButton(
                        onPressed: () => _markAsPaid(order),
                        child: Text('Mark as Paid'),
                      ),
                    ],
                  ),
                ),
                
              // Action buttons
              if (_selectedFilter != 'Saved Orders') ...[
                if (order.total >= 0 && !order.isRefunded)
                  ListTile(
                    title: TextButton(
                      child: Text("Mark as Refunded"),
                      onPressed: () => _markAsRefunded(index),
                    ),
                  ),
                if (!order.isRefunded)
                  ListTile(
                    title: TextButton(
                      child: Text("Print Receipt"),
                      onPressed: () => _printOrderReceipt(order),
                    ),
                  ),
              ],
              
              if (_selectedFilter == 'Saved Orders')
                ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _completeDraft(index),
                        child: Text('Complete'),
                      ),
                      ElevatedButton(
                        onPressed: () => _deleteDraft(index),
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== DRAFT METHODS ====================

  void _completeDraft(int index) async {
    Order draftOrder = filteredOrders[index];
    
    // Remove from draft orders
    draftOrders.removeWhere((o) => o.orderNumber == draftOrder.orderNumber);
    await _saveDraftOrders();

    // Add to complete orders
    final prefs = await SharedPreferences.getInstance();
    List<String> completeOrdersJson = prefs.getStringList('orders') ?? [];
    completeOrdersJson.add(jsonEncode(draftOrder.toJson()));
    await prefs.setStringList('orders', completeOrdersJson);

    // Reload all orders
    await _loadOrders();

    Fluttertoast.showToast(
        msg: 'Order Completed',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  void _deleteDraft(int index) async {
    Order draftOrder = filteredOrders[index];
    
    draftOrders.removeWhere((o) => o.orderNumber == draftOrder.orderNumber);
    await _saveDraftOrders();
    
    setState(() {
      _applyFilter();
      draftCount = draftOrders.length;
    });

    Fluttertoast.showToast(
        msg: 'Draft Deleted',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<void> _saveDraftOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> draftOrdersJson =
        draftOrders.map((order) => jsonEncode(order.toJson())).toList();
    await prefs.setStringList('draftOrders', draftOrdersJson);
  }

  void _markAsPaid(Order order) async {
    setState(() {
      order.total = order.total.abs();
    });

    final prefs = await SharedPreferences.getInstance();
    List<String> completeOrdersJson = prefs.getStringList('orders') ?? [];
    completeOrdersJson.add(jsonEncode(order.toJson()));
    await prefs.setStringList('orders', completeOrdersJson);

    await _loadOrders();

    Fluttertoast.showToast(
        msg: 'Order marked as paid',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  void showToast(String message) {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM);
  }

  @override
  void dispose() {
    if (_connected) {
      bluetooth.disconnect();
    }
    super.dispose();
  }
}
