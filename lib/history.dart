import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'pages/widgets/historyOrder.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';

// ─────────────────────────────────────────────────────────────
// CreditRecord model (must match sell_page.dart)
// ─────────────────────────────────────────────────────────────
class CreditRecord {
  final String id;
  final String debtorName;
  final String debtorPhone;
  final String debtorAddress;
  final String? debtorEmail;
  final double amount;
  final DateTime expectedDate;
  final DateTime createdAt;
  final String orderNumber;
  final String cashierName;
  final List<Map<String, dynamic>> products;
  final String? notes;
  bool settled;
  DateTime? settledAt;
  double? amountPaid;

  CreditRecord({
    required this.id,
    required this.debtorName,
    required this.debtorPhone,
    required this.debtorAddress,
    this.debtorEmail,
    required this.amount,
    required this.expectedDate,
    required this.createdAt,
    required this.orderNumber,
    required this.cashierName,
    required this.products,
    this.notes,
    this.settled = false,
    this.settledAt,
    this.amountPaid,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'debtorName': debtorName,
        'debtorPhone': debtorPhone,
        'debtorAddress': debtorAddress,
        'debtorEmail': debtorEmail,
        'amount': amount,
        'expectedDate': expectedDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'orderNumber': orderNumber,
        'cashierName': cashierName,
        'products': products,
        'notes': notes,
        'settled': settled,
        'settledAt': settledAt?.toIso8601String(),
        'amountPaid': amountPaid,
      };

  factory CreditRecord.fromJson(Map<String, dynamic> j) => CreditRecord(
        id: j['id'],
        debtorName: j['debtorName'],
        debtorPhone: j['debtorPhone'],
        debtorAddress: j['debtorAddress'],
        debtorEmail: j['debtorEmail'],
        amount: (j['amount'] as num).toDouble(),
        expectedDate: DateTime.parse(j['expectedDate']),
        createdAt: DateTime.parse(j['createdAt']),
        orderNumber: j['orderNumber'],
        cashierName: j['cashierName'],
        products: List<Map<String, dynamic>>.from(j['products']),
        notes: j['notes'],
        settled: j['settled'] ?? false,
        settledAt: j['settledAt'] != null
            ? DateTime.parse(j['settledAt'])
            : null,
        amountPaid: j['amountPaid'] != null
            ? (j['amountPaid'] as num).toDouble()
            : null,
      );
}

class ViewHistoryPage extends StatefulWidget {
  @override
  _ViewHistoryPageState createState() => _ViewHistoryPageState();
}

class _ViewHistoryPageState extends State<ViewHistoryPage> {
  List<Order> allOrders = [];
  List<Order> filteredOrders = [];
  List<Order> draftOrders = [];

  // Map orderNumber -> CreditRecord (unsettled + settled)
  Map<String, CreditRecord> creditsMap = {};

  double totalRevenue = 0.0;
  double totalSales = 0.0;
  double totalCredits = 0.0; // unsettled outstanding only
  double totalRefunds = 0.0;
  double totalDiscounts = 0.0;
  int totalOrders = 0;
  int completedSalesCount = 0;
  int creditCount = 0;
  int overdueCreditCount = 0;
  int refundCount = 0;
  int draftCount = 0;
  int discountedOrderCount = 0;
  String shopId = '';
  String password = '';
  bool isLoading = false;
  bool isDownloading = false;
  bool zimraEnabled = false;
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _device;
  bool _connected = false;
  String? _selectedFilter;
  String currencySymbol = '\$';
  List<String> codes = [];
  bool _hideTotalOnHomepage = false;

  final List<String> filterOptions = [
    'All Orders',
    'Completed Sales',
    'Credits',
    'Refunds',
    'Saved Orders',
    'Discounted Orders'
  ];

  @override
  void initState() {
    super.initState();
    _checkPasswordRequirement();
    _loadOrders();
    _initBluetooth();
    loadCurrencySymbol();
    _loadZimraStatus();
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────

  bool _isCreditOrder(Order order) {
    return creditsMap.containsKey(order.orderNumber);
  }

  bool _isSettledCredit(Order order) {
    final c = creditsMap[order.orderNumber];
    return c != null && c.settled;
  }

  bool _isOverdueCredit(Order order) {
    final c = creditsMap[order.orderNumber];
    if (c == null || c.settled) return false;
    return DateTime.now().isAfter(c.expectedDate);
  }

  Future<void> _loadZimraStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      zimraEnabled = prefs.getBool('zimraEnabled') ?? false;
    });
  }

  Future<void> _loadCreditsMap() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('credits') ?? [];
    final Map<String, CreditRecord> map = {};
    for (final s in list) {
      try {
        final c = CreditRecord.fromJson(jsonDecode(s));
        map[c.orderNumber] = c;
      } catch (e) {
        print('Bad credit record: $e');
      }
    }
    creditsMap = map;
  }

  bool _hasDiscount(Order order) {
    if (order.appliedDiscount != null) return true;
    for (var product in order.products) {
      if (product.discountAmount != null && product.discountAmount! > 0) {
        return true;
      }
      if (product.discountPercentage != null &&
          product.discountPercentage! > 0) {
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

    double totalDiscount = 0;
    String discountType = '';
    for (var product in order.products) {
      if (product.discountAmount != null && product.discountAmount! > 0) {
        totalDiscount += product.discountAmount!;
        discountType = 'Price discount';
      } else if (product.discountPercentage != null &&
          product.discountPercentage! > 0) {
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
        double originalTotal = 0;
        for (var product in order.products) {
          originalTotal += product.price * product.quantity;
        }
        return originalTotal * (order.appliedDiscount!.value / 100);
      } else {
        return order.appliedDiscount!.value;
      }
    }
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
                    onPressed: () => Navigator.of(context).pop(false),
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
                        setState(() => passwordAttempts++);
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

  // ─────────────────────────────────────────────────────────
  // LOAD ORDERS (credits-aware)
  // ─────────────────────────────────────────────────────────
  Future<void> _loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    bool hideTotal = prefs.getBool('hideTotalOnHomepage') ?? false;

    await _loadCreditsMap();

    List<String> ordersJson = prefs.getStringList('orders') ?? [];
    List<Order> loadedOrders =
        ordersJson.map((str) => Order.fromJson(json.decode(str))).toList();

    List<String> draftOrdersJson = prefs.getStringList('draftOrders') ?? [];
    List<Order> loadedDraftOrders =
        draftOrdersJson.map((str) => Order.fromJson(json.decode(str))).toList();

    double revenue = 0.0;
    double sales = 0.0;
    double credits = 0.0;
    double refunds = 0.0;
    double discounts = 0.0;
    int salesCount = 0;
    int creditsCount = 0;
    int overdueCredits = 0;
    int refundsCount = 0;
    int discountCount = 0;

    for (var order in loadedOrders) {
      if (_hasDiscount(order)) {
        discountCount++;
        discounts += _getDiscountAmount(order);
      }

      final isCredit = _isCreditOrder(order);
      final isSettled = _isSettledCredit(order);

      if (order.isRefunded) {
        refunds += order.refundAmount;
        refundsCount++;
      } else if (isCredit && !isSettled) {
        // Unsettled credit — outstanding, NOT revenue, NOT sale
        final c = creditsMap[order.orderNumber]!;
        credits += c.amount;
        creditsCount++;
        if (DateTime.now().isAfter(c.expectedDate)) {
          overdueCredits++;
        }
      } else {
        // Regular sale OR settled credit → counts as sale
        sales += order.total;
        salesCount++;
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
      creditCount = creditsCount;
      overdueCreditCount = overdueCredits;
      refundCount = refundsCount;
      totalOrders = loadedOrders.length;
      draftCount = loadedDraftOrders.length;
      codes = (jsonDecode(prefs.getString('codes') ?? '[]') as List<dynamic>)
          .cast<String>();
      _hideTotalOnHomepage = hideTotal;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_selectedFilter == null || _selectedFilter == 'All Orders') {
      filteredOrders = List.from(allOrders);
    } else if (_selectedFilter == 'Completed Sales') {
      // Sales that are: not refunded AND (not a credit OR a settled credit)
      filteredOrders = allOrders.where((order) {
        if (order.isRefunded) return false;
        if (_isCreditOrder(order)) return _isSettledCredit(order);
        return true;
      }).toList();
    } else if (_selectedFilter == 'Credits') {
      // Only unsettled credits
      filteredOrders = allOrders
          .where((order) => _isCreditOrder(order) && !_isSettledCredit(order))
          .toList();
    } else if (_selectedFilter == 'Refunds') {
      filteredOrders = allOrders.where((order) => order.isRefunded).toList();
    } else if (_selectedFilter == 'Saved Orders') {
      filteredOrders = List.from(draftOrders);
    } else if (_selectedFilter == 'Discounted Orders') {
      filteredOrders = allOrders.where((order) => _hasDiscount(order)).toList();
    }
  }

  // ─────────────────────────────────────────────────────────
  // SETTLE CREDIT
  // ─────────────────────────────────────────────────────────
  Future<void> _settleCredit(Order order) async {
    final prefs = await SharedPreferences.getInstance();
    final record = creditsMap[order.orderNumber];
    if (record == null) return;

    final list = prefs.getStringList('credits') ?? [];
    final updated = <String>[];
    for (final s in list) {
      final c = CreditRecord.fromJson(jsonDecode(s));
      if (c.orderNumber == record.orderNumber) {
        c.settled = true;
        c.settledAt = DateTime.now();
        c.amountPaid = c.amount;
        updated.add(jsonEncode(c.toJson()));
      } else {
        updated.add(s);
      }
    }
    await prefs.setStringList('credits', updated);

    await _loadOrders();

    Fluttertoast.showToast(
      msg: 'Credit ${order.orderNumber} settled — now counts as a sale',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  // ─────────────────────────────────────────────────────────
  // MARK REFUNDED
  // ─────────────────────────────────────────────────────────
  void _markAsRefunded(int index) async {
    Order order = filteredOrders[index];
    int originalIndex =
        allOrders.indexWhere((o) => o.orderNumber == order.orderNumber);

    if (originalIndex != -1) {
      setState(() {
        allOrders[originalIndex].isRefunded = true;
        allOrders[originalIndex].refundAmount =
            allOrders[originalIndex].total.abs();
      });
      await _saveOrders();
      await _loadOrders();

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

  // ─────────────────────────────────────────────────────────
  // EXPORT
  // ─────────────────────────────────────────────────────────
  Future<void> _downloadOrdersAsExcel() async {
    setState(() => isDownloading = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      List<List<dynamic>> csvData = [];

      csvData.add(['ORDER SUMMARY REPORT']);
      csvData.add([
        'Generated on:',
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())
      ]);
      csvData.add(['Filter Applied:', _selectedFilter ?? 'All Orders']);
      csvData.add([]);
      csvData.add(['Summary Statistics']);
      csvData.add(['Total Orders (All):', totalOrders]);
      csvData.add(['Draft Orders:', draftCount]);
      csvData.add([
        'Completed Sales:',
        '$completedSalesCount ($currencySymbol${totalSales.toStringAsFixed(2)})'
      ]);
      csvData.add([
        'Unsettled Credits:',
        '$creditCount ($currencySymbol${totalCredits.toStringAsFixed(2)}) — Overdue: $overdueCreditCount'
      ]);
      csvData.add([
        'Refunded Orders:',
        '$refundCount ($currencySymbol${totalRefunds.toStringAsFixed(2)})'
      ]);
      csvData.add([
        'Discounted Orders:',
        '$discountedOrderCount ($currencySymbol${totalDiscounts.toStringAsFixed(2)} saved)'
      ]);
      csvData.add([
        'Net Revenue:',
        '$currencySymbol${totalRevenue.toStringAsFixed(2)}'
      ]);
      csvData.add([]);
      csvData.add(['DETAILED ORDER LIST']);

      csvData.add([
        'Order Number',
        'Date',
        'Cashier Name',
        'Customer Name',
        'Order Type',
        'Payment Status',
        'Debtor Phone',
        'Expected Date',
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

      for (var order in allOrders) {
        bool isQuickSale = order.products.any(
            (product) => product.code.isEmpty || !codes.contains(product.code));

        bool hasDiscount = _hasDiscount(order);
        String discountDisplay = _getDiscountDisplay(order);
        double discountAmount = _getDiscountAmount(order);
        double originalTotal = _getOriginalTotal(order);

        String productsStr = order.products
            .map((p) =>
                '${p.name} (Qty: ${p.quantity} x ${currencySymbol}${p.price.toStringAsFixed(2)} = ${currencySymbol}${(p.quantity * p.price).toStringAsFixed(2)}${p.discountAmount != null ? " - Discount: ${currencySymbol}${p.discountAmount!.toStringAsFixed(2)}" : ""}${p.discountPercentage != null ? " - ${p.discountPercentage}% off" : ""})')
            .join('\n');

        final creditRec = creditsMap[order.orderNumber];
        String orderType = 'Sale';
        String paymentStatus = 'Paid';
        String debtorPhone = '';
        String expectedDateStr = '';
        String notes = '';

        if (order.isRefunded) {
          orderType = 'Refund';
          paymentStatus = 'Refunded';
          notes =
              'Original amount: ${currencySymbol}${order.total.abs().toStringAsFixed(2)}';
        } else if (creditRec != null && !creditRec.settled) {
          orderType = 'Credit';
          paymentStatus = DateTime.now().isAfter(creditRec.expectedDate)
              ? 'Unpaid / OVERDUE'
              : 'Unpaid / Credit';
          debtorPhone = creditRec.debtorPhone;
          expectedDateStr = DateFormat('yyyy-MM-dd')
              .format(creditRec.expectedDate);
          notes =
              'Debtor: ${creditRec.debtorName}, owes: ${currencySymbol}${creditRec.amount.toStringAsFixed(2)}';
        } else if (creditRec != null && creditRec.settled) {
          orderType = 'Credit (Settled)';
          paymentStatus = 'Paid (was credit)';
          notes =
              'Settled on: ${creditRec.settledAt != null ? DateFormat('yyyy-MM-dd').format(creditRec.settledAt!) : 'N/A'}';
        } else if (hasDiscount) {
          orderType = 'Discounted Sale';
          paymentStatus = 'Paid (with discount)';
          notes =
              'Discount: $discountDisplay, Saved: ${currencySymbol}${discountAmount.toStringAsFixed(2)}';
        }

        csvData.add([
          order.orderNumber,
          DateFormat('yyyy-MM-dd HH:mm:ss').format(order.timestamp),
          order.cashierName ?? 'N/A',
          order.customerName ?? 'N/A',
          orderType,
          paymentStatus,
          debtorPhone,
          expectedDateStr,
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

      csvData.add([]);
      csvData.add(['END OF REPORT']);
      csvData.add(['Total Records:', allOrders.length]);
      csvData.add([
        'Total Discounts Given:',
        '$currencySymbol${totalDiscounts.toStringAsFixed(2)}'
      ]);
      csvData.add(['Number of Discounted Orders:', discountedOrderCount]);

      String csv = const ListToCsvConverter().convert(csvData);

      String path;
      try {
        if (Platform.isAndroid) {
          Directory? downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir != null) {
            final appDir = Directory('${downloadsDir.path}/TradeAppExports');
            if (!await appDir.exists()) {
              await appDir.create(recursive: true);
            }
            path =
                '${appDir.path}/orders_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
          } else {
            final tempDir = await getTemporaryDirectory();
            path =
                '${tempDir.path}/orders_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
          }
        } else {
          final docDir = await getApplicationDocumentsDirectory();
          path =
              '${docDir.path}/orders_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
        }
      } catch (e) {
        print("Error getting storage directory: $e");
        final tempDir = await getTemporaryDirectory();
        path =
            '${tempDir.path}/orders_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      }

      final file = File(path);
      await file.writeAsString(csv, encoding: utf8);

      Fluttertoast.showToast(
        msg: "File saved to: $path",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.blue,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      await Future.delayed(Duration(seconds: 2));

      await Share.shareXFiles(
        [XFile(path)],
        text:
            'Orders Report - $completedSalesCount Sales, $creditCount Credits, $refundCount Refunds, $discountedOrderCount Discounted',
        subject:
            'Orders Data Export - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      );

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
        overdueCreditCount = 0;
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
      setState(() => isDownloading = false);
    }
  }

  // ─────────────────────────────────────────────────────────
  // UPLOAD
  // ─────────────────────────────────────────────────────────
  Future<void> uploadSalesOnline(BuildContext context) async {
    setState(() => isLoading = true);

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
      setState(() => isLoading = false);
      return;
    }

    bool zimraEnabled = prefs.getBool('zimraEnabled') ?? false;
    String uploadUrl = zimraEnabled
        ? "https://blueichor.org/fiscalize.php"
        : "https://blueichor.org/uploadOffline3.php";

    List<Map<String, dynamic>> ordersData = [];
    List<Order> ordersToKeep = [];

    for (var order in allOrders) {
      final isCredit = _isCreditOrder(order);
      final isSettled = _isSettledCredit(order);

      // Only upload regular sales or settled credits that are not refunded
      if (!order.isRefunded && (!isCredit || isSettled)) {
        Map<String, dynamic> orderJson = order.toJson();
        orderJson['discount'] = _getDiscountAmount(order);
        orderJson['original_total'] = _getOriginalTotal(order);
        orderJson['has_discount'] = _hasDiscount(order);
        ordersData.add(orderJson);
      } else {
        ordersToKeep.add(order);
      }
    }

    if (ordersData.isEmpty) {
      Fluttertoast.showToast(
          msg: "No orders to upload.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0);
      setState(() => isLoading = false);
      return;
    }

    try {
      var response = await http.post(
        Uri.parse(uploadUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'username': shopId,
          'orders': ordersData,
          'zimra_enabled': zimraEnabled,
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          await clearOrdersFromSharedPreferences(prefs);

          if (ordersToKeep.isNotEmpty) {
            List<String> ordersJsonToKeep = ordersToKeep
                .map((order) => jsonEncode(order.toJson()))
                .toList();
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

          String message = zimraEnabled
              ? "Upload successful! ${ordersData.length} orders sent to ZIMRA."
              : "Upload successful! ${ordersData.length} orders saved to database.";

          Fluttertoast.showToast(
              msg: message,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.CENTER,
              backgroundColor: Colors.green,
              textColor: Colors.white,
              fontSize: 16.0);
        } else {
          Fluttertoast.showToast(
              msg:
                  "Upload failed: ${jsonResponse['message'] ?? 'Unknown error'}",
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
      Fluttertoast.showToast(
          msg: "Error uploading orders: $e",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
    } finally {
      setState(() => isLoading = false);
    }

    _refreshData();
  }

  Future<void> clearOrdersFromSharedPreferences(SharedPreferences prefs) async {
    await prefs.remove('orders');
  }

  Future<void> _refreshData() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getString('username') ?? '';
    password = prefs.getString('password') ?? '';
    await _loadOrders();
    setState(() => isLoading = true);

    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        var response = await http.post(
          Uri.parse('https://blueichor.org/log2.php'),
          body: {'username': shopId, 'password': password},
        );

        if (response.statusCode == 200) {
          var jsondata = json.decode(response.body);
          if (jsondata["success"]) {
            final prefs = await SharedPreferences.getInstance();
            prefs.setString('categories', json.encode(jsondata['categories']));
            prefs.setString('products', json.encode(jsondata["products"]));
            prefs.setString('prices', json.encode(jsondata["prices"]));
            prefs.setString('codes', json.encode(jsondata["codes"]));
            prefs.setString('measure', json.encode(jsondata["measure"]));
            prefs.setString('quantities', json.encode(jsondata["quantities"]));
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to refresh data make sure internet connection is available')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
    }

    setState(() => isLoading = false);
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

      List<String> codes =
          (jsonDecode(prefs.getString('codes1') ?? '[]') as List<dynamic>)
              .cast<String>();
      List<String> measures =
          (jsonDecode(prefs.getString('measure') ?? '[]') as List<dynamic>)
              .cast<String>();

      for (int i = 0; i < order.products.length; i++) {
        Product product = order.products[i];
        double totalValue = product.price * product.quantity;

        int index = codes.indexOf(product.code);
        String quantityText = '${product.quantity}';
        if (index != -1 && measures.length > index) {
          quantityText += ' ${measures[index]}';
        }

        String discountText = '';
        if (product.discountAmount != null && product.discountAmount! > 0) {
          discountText =
              ' (Disc: $currencySymbol${product.discountAmount!.toStringAsFixed(2)})';
        } else if (product.discountPercentage != null &&
            product.discountPercentage! > 0) {
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

      if (_hasDiscount(order)) {
        double originalTotal = _getOriginalTotal(order);
        double discountAmount = _getDiscountAmount(order);
        bluetooth.printCustom(
            'Original Total: $currencySymbol${originalTotal.toStringAsFixed(2)}',
            1,
            0);
        bluetooth.printCustom(
            'Discount: -$currencySymbol${discountAmount.toStringAsFixed(2)}',
            1,
            0);
        bluetooth.printCustom('-------------------------------', 1, 0);
      }

      bluetooth.printCustom(
          'Total: $currencySymbol${order.total.toStringAsFixed(2)}', 1, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      await Future.delayed(Duration(milliseconds: 500));

      if (printQRCode) {
        Map<String, dynamic> qrData = {"invoice": order.orderNumber};
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
          final ui.Image qrImage =
              await qrPainter.toImage(qrImageSourceSize.toDouble());
          final ByteData? byteData =
              await qrImage.toByteData(format: ui.ImageByteFormat.png);
          final Uint8List pngBytes = byteData!.buffer.asUint8List();

          final img.Image? decodedImage = img.decodeImage(pngBytes);
          if (decodedImage != null) {
            final img.Image resizedImage =
                img.copyResize(decodedImage, width: 250);
            final img.Image grayscaleImage = img.grayscale(resizedImage);
            final Uint8List bmpBytes =
                Uint8List.fromList(img.encodeBmp(grayscaleImage));

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

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order History'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(
                  zimraEnabled ? Icons.check_circle : Icons.cancel,
                  color: zimraEnabled ? Colors.green : Colors.grey,
                  size: 20,
                ),
                SizedBox(width: 4),
                Text(
                  zimraEnabled ? 'ZIMRA' : 'POS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: zimraEnabled ? Colors.green : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              decoration: BoxDecoration(
                color: zimraEnabled ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: zimraEnabled ? Colors.green : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    zimraEnabled ? Icons.check_circle : Icons.cancel,
                    color: zimraEnabled ? Colors.green : Colors.grey[600],
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    zimraEnabled
                        ? 'ZIMRA Integration: ON - Receipts will be fiscalized'
                        : 'ZIMRA Integration: OFF - Receipts will be saved to database only',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: zimraEnabled ? Colors.green[700] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              zimraEnabled ? 'Uploading to ZIMRA' : 'Uploading to Database',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          FloatingActionButton(
            onPressed: isLoading
                ? null
                : () async {
                    await uploadSalesOnline(context);
                  },
            tooltip: zimraEnabled ? 'Upload Sales to ZIMRA' : 'Upload Sales Online',
            heroTag: 'upload',
            backgroundColor: zimraEnabled ? Colors.green : Colors.blue,
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
                _buildSummaryItem(
                    'Sales', totalSales, completedSalesCount, Colors.green),
                _buildSummaryItem(
                    'Credits', totalCredits, creditCount, Colors.orange),
                _buildSummaryItem(
                    'Refunds', totalRefunds, refundCount, Colors.red),
                _buildSummaryItem('Drafts', 0, draftCount, Colors.blue),
              ],
            ),
            // Overdue warning
            if (overdueCreditCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber,
                          color: Colors.red, size: 16),
                      SizedBox(width: 6),
                      Text(
                        '$overdueCreditCount credit(s) overdue',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            if (discountedOrderCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryItem('Discounted Orders', 0,
                        discountedOrderCount, Colors.purple),
                    _buildSummaryItem(
                        'Total Saved', totalDiscounts, 0, Colors.purple),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, double amount, int count, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: color)),
        if (amount > 0)
          Text('$currencySymbol${amount.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text('($count)',
            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildOrderItem(Order order, int index) {
    bool isQuickSale = order.products.any(
        (product) => product.code.isEmpty || !codes.contains(product.code));
    bool hasDiscount = _hasDiscount(order);
    String discountDisplay = _getDiscountDisplay(order);
    double discountAmount = _getDiscountAmount(order);
    double originalTotal = _getOriginalTotal(order);

    final creditRec = creditsMap[order.orderNumber];
    final isCredit = creditRec != null && !creditRec.settled;
    final isSettledCredit = creditRec != null && creditRec.settled;
    final isOverdue = creditRec != null &&
        !creditRec.settled &&
        DateTime.now().isAfter(creditRec.expectedDate);

    Color backgroundColor = Colors.white;
    String statusText = '';
    Color statusColor = Colors.green;

    if (order.isRefunded) {
      backgroundColor = Colors.grey[200]!;
      statusText = 'REFUNDED';
      statusColor = Colors.grey[600]!;
    } else if (isCredit) {
      backgroundColor = isOverdue ? Colors.red[50]! : Colors.orange[50]!;
      statusText = isOverdue ? 'CREDIT • OVERDUE' : 'CREDIT';
      statusColor = isOverdue ? Colors.red : Colors.orange;
    } else if (isSettledCredit) {
      backgroundColor = Colors.green[50]!;
      statusText = 'CREDIT • SETTLED';
      statusColor = Colors.green;
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

    return Card(
      color: backgroundColor,
      child: Stack(
        children: [
          if (statusText.isNotEmpty)
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
                  _hideTotalOnHomepage && !isCredit
                      ? 'Total: XX'
                      : (isCredit
                          ? 'Credit: $currencySymbol${creditRec!.amount.toStringAsFixed(2)}'
                          : 'Total: $currencySymbol${order.total.abs().toStringAsFixed(2)}'),
                  style: TextStyle(
                    fontWeight: (isCredit || order.isRefunded)
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (hasDiscount && !isCredit)
                  Text(
                    'Discounted: $discountDisplay',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (hasDiscount && !_hideTotalOnHomepage && !isCredit)
                  Text(
                    'Original: $currencySymbol${originalTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                if (isCredit)
                  Text(
                    'Due: ${creditRec.expectedDate.day}/${creditRec.expectedDate.month}/${creditRec.expectedDate.year}'
                    '${isOverdue ? "  •  OVERDUE" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? Colors.red : Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            subtitle: Text(
                'Order ID: ${order.orderNumber}\n'
                '${_selectedFilter == 'Saved Orders' ? 'Customer: ${order.customerName ?? 'N/A'}\n' : ''}'
                'Cashier: ${order.cashierName ?? 'N/A'}'
                '${isCredit ? '\nDebtor: ${creditRec!.debtorName} • ${creditRec.debtorPhone}' : ''}'),
            children: [
              ListTile(
                title: Text('Order Details'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order ID: ${order.orderNumber}'),
                    Text('Customer: ${order.customerName ?? 'N/A'}'),
                    Text('Cashier: ${order.cashierName ?? 'N/A'}'),
                    if (isCredit) ...[
                      SizedBox(height: 6),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? Colors.red[50]
                              : Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isOverdue
                                ? Colors.red[200]!
                                : Colors.orange[200]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Credit Details',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isOverdue
                                        ? Colors.red
                                        : Colors.orange[800])),
                            SizedBox(height: 4),
                            Text('Debtor: ${creditRec.debtorName}'),
                            Text('Phone: ${creditRec.debtorPhone}'),
                            Text('Address: ${creditRec.debtorAddress}'),
                            if (creditRec.debtorEmail != null &&
                                creditRec.debtorEmail!.isNotEmpty)
                              Text('Email: ${creditRec.debtorEmail}'),
                            Text(
                                'Created: ${DateFormat('yyyy-MM-dd HH:mm').format(creditRec.createdAt)}'),
                            Text(
                                'Expected: ${DateFormat('yyyy-MM-dd').format(creditRec.expectedDate)}'
                                '${isOverdue ? "  (OVERDUE)" : ""}',
                                style: TextStyle(
                                    color: isOverdue ? Colors.red : null,
                                    fontWeight: FontWeight.bold)),
                            if (creditRec.notes != null &&
                                creditRec.notes!.isNotEmpty)
                              Text('Notes: ${creditRec.notes}'),
                          ],
                        ),
                      ),
                    ],
                    if (isSettledCredit) ...[
                      SizedBox(height: 6),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Settled Credit',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800])),
                            Text('Debtor: ${creditRec.debtorName}'),
                            Text('Phone: ${creditRec.debtorPhone}'),
                            if (creditRec.settledAt != null)
                              Text(
                                  'Settled: ${DateFormat('yyyy-MM-dd HH:mm').format(creditRec.settledAt!)}'),
                          ],
                        ),
                      ),
                    ],
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
                        'Final Total: $currencySymbol${order.total.abs().toStringAsFixed(2)}',
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

              ...order.products.map((product) {
                String discountInfo = '';
                String discountedPriceText = '';

                if (product.discountAmount != null &&
                    product.discountAmount! > 0) {
                  discountInfo =
                      'Discount: $currencySymbol${product.discountAmount!.toStringAsFixed(2)}';
                  double discountedTotal = product.getTotalWithDiscount();
                  discountedPriceText =
                      'Discounted: $currencySymbol${discountedTotal.toStringAsFixed(2)}';
                } else if (product.discountPercentage != null &&
                    product.discountPercentage! > 0) {
                  discountInfo = 'Discount: ${product.discountPercentage!}%';
                  double discountedTotal = product.getTotalWithDiscount();
                  discountedPriceText =
                      'Discounted: $currencySymbol${discountedTotal.toStringAsFixed(2)}';
                }

                return ListTile(
                  title: Text(product.name),
                  subtitle: product.discountAmount != null ||
                          product.discountPercentage != null
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
                    style: TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),

              if (order.isRefunded)
                ListTile(
                  title: Text("Refunded", style: TextStyle(color: Colors.red)),
                  subtitle: Text(
                      "Refund Amount: $currencySymbol${order.refundAmount.toStringAsFixed(2)}"),
                ),

              // Credit actions
              if (isCredit)
                ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _settleCredit(order),
                        icon: Icon(Icons.check, size: 16),
                        label: Text('Mark as Paid'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _markAsRefunded(index),
                        icon: Icon(Icons.undo, size: 16),
                        label: Text('Refund'),
                      ),
                    ],
                  ),
                ),

              if (_selectedFilter != 'Saved Orders') ...[
                if (!isCredit && !order.isRefunded && !isSettledCredit)
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

  // ─────────────────────────────────────────────────────────
  // DRAFT METHODS
  // ─────────────────────────────────────────────────────────
  void _completeDraft(int index) async {
    Order draftOrder = filteredOrders[index];
    draftOrders.removeWhere((o) => o.orderNumber == draftOrder.orderNumber);
    await _saveDraftOrders();

    final prefs = await SharedPreferences.getInstance();
    List<String> completeOrdersJson = prefs.getStringList('orders') ?? [];
    completeOrdersJson.add(jsonEncode(draftOrder.toJson()));
    await prefs.setStringList('orders', completeOrdersJson);

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