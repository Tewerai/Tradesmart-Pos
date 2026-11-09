import 'dart:convert';
import 'dart:io';
import 'package:blue_thermal_printer/blue_thermal_printer.dart'
    as blue_thermal_printer;
import 'widgets/historyOrder.dart';
import 'sell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class PrinterPage extends StatefulWidget {
  // ADDED: Accept the order directly
  final Order? order;
  const PrinterPage({Key? key, this.order}) : super(key: key);

  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  final TextEditingController _textController = TextEditingController();
  blue_thermal_printer.BlueThermalPrinter bluetooth =
      blue_thermal_printer.BlueThermalPrinter.instance;
  late String customerName = '';

  List<blue_thermal_printer.BluetoothDevice> _devices = [];
  blue_thermal_printer.BluetoothDevice? _device;
  bool _connected = false;
  bool _pressed = false;
  List<dynamic> measures = [];
  bool saveMultiplePrinters = false;
  int printerCount = 0;
  String currencySymbol = '\$';

  List<String> _customerNames = [];
  String? _selectedCustomerName;

  final TextEditingController _customerSurnameController = TextEditingController();
  final TextEditingController _customerEmailController = TextEditingController();
  final TextEditingController _customerTelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _loadCustomerNames();
    loadCurrencySymbol();
  }

  @override
  void dispose() {
    _textController.dispose();
    _customerSurnameController.dispose();
    _customerEmailController.dispose();
    _customerTelController.dispose();
    if (_connected) {
      bluetooth.disconnect();
    }
    super.dispose();
  }

  // ADDED: Helper to get the order (either passed in or from local storage)
  Future<Order?> _getCurrentOrder() async {
    if (widget.order != null) {
      return widget.order;
    }
    final prefs = await SharedPreferences.getInstance();
    List<String>? ordersJson = prefs.getStringList('orders');
    if (ordersJson != null && ordersJson.isNotEmpty) {
      return Order.fromJson(json.decode(ordersJson.last));
    }
    return null;
  }

  Future<void> initPlatformState() async {
    await _printCurrentTotalOrder();
    await _loadPrinterCount();

    List<blue_thermal_printer.BluetoothDevice> devices = [];
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    measures = (jsonDecode(prefs.getString('measure1') ?? '[]') as List<dynamic>).cast<String>();
    try {
      devices = await bluetooth.getBondedDevices();
    } on PlatformException {
      showToast('Error getting bonded devices');
    }

    setState(() => _devices = devices);

    bluetooth.onStateChanged().listen((state) {
      setState(() {
        _connected = state == blue_thermal_printer.BlueThermalPrinter.CONNECTED;
        _pressed = false;
      });
    });

    _autoConnectSavedPrinter();
  }

  Future<void> loadCurrencySymbol() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currencySymbol = prefs.getString('currencySymbol') ?? 'R';
    });
  }

  Future<void> _refreshBondedDevices() async {
    try {
      _devices = await bluetooth.getBondedDevices();
      setState(() {});
    } catch (e) {
      showToast('Error getting bonded devices: $e');
    }
  }

  Future<void> _autoConnectSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int printerCount = prefs.getInt('printerCount') ?? 0;

      if (printerCount == 0) {
        return;
      }

      await _refreshBondedDevices();

      for (int i = 0; i < printerCount; i++) {
        String? printerAddress = prefs.getString('printerAddress$i');

        if (printerAddress != null) {
          for (blue_thermal_printer.BluetoothDevice device in _devices) {
            if (device.address == printerAddress) {
              _device = device;
              await _connect();
              break;
            }
          }
        }
      }
    } catch (e) {
      print('Error auto-connecting printer: $e');
    }
  }

  Future<void> _connect() async {
    try {
      if (_device == null) return;
      bool result = await bluetooth.connect(_device!);
      if (!result) {
        showToast('Failed to connect to ${_device!.name}');
      }
    } catch (e) {
      showToast('Error connecting to device: $e');
    }
  }

  Future<void> _loadPrinterCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    printerCount = prefs.getInt('printerCount') ?? 0;
  }

  Future<void> _printCurrentTotalOrder() async {
    try {
      final order = await _getCurrentOrder();
      if (order != null) {
        print('Current Total Order: \$${order.total.toStringAsFixed(2)}');
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  void _disconnect() async {
    await bluetooth.disconnect();
    setState(() => _pressed = true);
  }

  Future<img.Image?> _loadLogoImage() async {
    final prefs = await SharedPreferences.getInstance();
    String? logoPath = prefs.getString('processedLogoPath');
    bool printLogo = prefs.getBool('printLogo') ?? true;

    if (!printLogo || logoPath == null || logoPath.isEmpty) return null;

    try {
      final File logoFile = File(logoPath);
      if (!await logoFile.exists()) return null;
      final Uint8List bytes = await logoFile.readAsBytes();
      return img.decodeImage(bytes);
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getActiveCashierName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('currentCashier');
  }

  bool _productHasDiscount(Product product) {
    return (product.discountAmount != null && product.discountAmount! > 0) ||
           (product.discountPercentage != null && product.discountPercentage! > 0);
  }

  double _getDiscountedPrice(Product product) {
    double discountedPrice = product.price;
    if (product.discountAmount != null && product.discountAmount! > 0) {
      discountedPrice = product.price - product.discountAmount!;
    } else if (product.discountPercentage != null && product.discountPercentage! > 0) {
      discountedPrice = product.price * (1 - (product.discountPercentage! / 100));
    }
    return discountedPrice;
  }

  double _getTotalWithDiscount(Product product) {
    return _getDiscountedPrice(product) * product.quantity;
  }

  void _tesPrint() async {
    try {
      if (!_connected) {
        showToast("**Printer not connected. Please connect first.**");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastOrder = await _getCurrentOrder(); // USE THE NEW HELPER

      if (lastOrder == null) {
        showToast('**No orders to print**');
        return;
      }

      var shopName = prefs.getString('fullname');
      var tel = prefs.getString('tel');
      var address = prefs.getString('address');
      var changeString = prefs.getString('changes') ?? '0';
      double change = double.parse(changeString);
      double truncatedChange = double.parse(change.toStringAsFixed(2));
      String roundedDownChangeString = truncatedChange.toString();
      var discountJson = prefs.getString('discount');
      Discount? discount;
      if (discountJson != null) {
        discount = Discount.fromJson(json.decode(discountJson));
      }
      var currencySymbol = prefs.getString('currencySymbol') ?? '\$';
      bool printQRCode = prefs.getBool('printReceiptId') ?? true;

      String? cashierName = await _getActiveCashierName();

      String customerTel = '';
      if (customerName.isNotEmpty) {
        await _saveCustomerDetails(customerName, lastOrder.total);
        customerTel = await _getCustomerTel(customerName);
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);

      List<int> bytes = [];

      final img.Image? logoImage = await _loadLogoImage();
      if (logoImage != null) {
        bytes += generator.image(logoImage);
        bytes += generator.feed(1);
      }

      bytes += generator.text(shopName ?? 'Shop Name',
          styles: PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2, bold: true),
          linesAfter: 1);

      bytes += generator.text(address ?? 'Shop Address',
          styles: PosStyles(align: PosAlign.center, bold: true));

      bytes += generator.text('Tel: ${tel ?? 'N/A'}',
          styles: PosStyles(align: PosAlign.center, bold: true), linesAfter: 1);

      bytes += generator.hr();

      bytes += _addWrappedCustomerNameRow(generator, customerName);

      if (customerTel.isNotEmpty) {
        bytes += generator.row([
          PosColumn(text: 'Customer Tel', width: 6, styles: PosStyles(bold: true)),
          PosColumn(text: customerTel, width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
      }

      if (cashierName != null && cashierName.isNotEmpty) {
        bytes += generator.row([
          PosColumn(text: 'Cashier', width: 6, styles: PosStyles(bold: true)),
          PosColumn(text: cashierName, width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
      }

      bytes += generator.hr();

      bytes += generator.text("Invoice: ${lastOrder.orderNumber}",
          styles: const PosStyles(align: PosAlign.left, bold: true));

      final now = DateTime.now();
      final formatter = DateFormat('MM/dd/yyyy H:m');
      final String timestamp = formatter.format(now);
      bytes += generator.text("Date: $timestamp",
          styles: const PosStyles(align: PosAlign.left, bold: true), linesAfter: 1);

      bytes += generator.hr();

      List<String> codes = (jsonDecode(prefs.getString('codes1') ?? '[]') as List<dynamic>).cast<String>();
      List<String> measuresFromPrefs = (jsonDecode(prefs.getString('measure') ?? '[]') as List<dynamic>).cast<String>();

      bytes += generator.row([
        PosColumn(text: 'Qty', width: 1, styles: PosStyles(bold: true)),
        PosColumn(text: 'Item', width: 5, styles: PosStyles(bold: true)),
        PosColumn(text: 'Price', width: 3, styles: PosStyles(align: PosAlign.right, bold: true)),
        PosColumn(text: 'Total', width: 3, styles: PosStyles(align: PosAlign.right, bold: true)),
      ]);

      bytes += generator.hr(ch: '-');

      double originalTotal = 0;
      for (var product in lastOrder.products) {
        originalTotal += product.price * product.quantity;
      }

      for (int i = 0; i < lastOrder.products.length; i++) {
        Product product = lastOrder.products[i];
        int index = codes.indexOf(product.code);
        String quantityText = '${product.quantity}';
        if (index != -1 && measuresFromPrefs.length > index) {
          quantityText += ' ${measuresFromPrefs[index]}';
        }
        bytes += _addWrappedProductRow(generator, product, quantityText);
      }

      bytes += generator.hr();

      bool orderHasDiscount = discount != null || lastOrder.products.any((p) => _productHasDiscount(p));
      
      if (orderHasDiscount) {
        bytes += generator.feed(1);
        bytes += generator.text("DISCOUNT SUMMARY", 
            styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
        bytes += generator.hr(ch: '-');
        
        bytes += generator.row([
          PosColumn(text: 'Original Total', width: 6, styles: PosStyles(bold: true)),
          PosColumn(text: '$currencySymbol${originalTotal.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
        
        if (discount != null) {
          if (discount.type == DiscountType.Percentage) {
            bytes += generator.row([
              PosColumn(text: 'Discount', width: 6, styles: PosStyles(bold: true)),
              PosColumn(text: '${discount.value}% off', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
            ]);
          } else {
            bytes += generator.row([
              PosColumn(text: 'Discount', width: 6, styles: PosStyles(bold: true)),
              PosColumn(text: '-$currencySymbol${discount.value.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
            ]);
          }
        } else {
          for (var product in lastOrder.products) {
            if (_productHasDiscount(product)) {
              String discountText = '';
              if (product.discountAmount != null && product.discountAmount! > 0) {
                discountText = '-$currencySymbol${product.discountAmount!.toStringAsFixed(2)}';
              } else if (product.discountPercentage != null && product.discountPercentage! > 0) {
                discountText = '${product.discountPercentage!}% off';
              }
              bytes += generator.row([
                PosColumn(text: product.name, width: 6, styles: const PosStyles(height: PosTextSize.size1, width: PosTextSize.size1)),
                PosColumn(text: discountText, width: 6, styles: const PosStyles(align: PosAlign.right, height: PosTextSize.size1, width: PosTextSize.size1, bold: true)),
              ]);
            }
          }
        }
        bytes += generator.hr(ch: '-');
      }

      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 6, styles: PosStyles(height: PosTextSize.size2, width: PosTextSize.size2, bold: true)),
        PosColumn(text: '$currencySymbol${lastOrder.total.toStringAsFixed(2)}', width: 6, styles: PosStyles(align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2, bold: true)),
      ]);

      bytes += generator.hr(ch: '=', linesAfter: 1);

      bytes += generator.row([
        PosColumn(text: 'Cash', width: 8, styles: PosStyles(align: PosAlign.right, width: PosTextSize.size2, bold: true)),
        PosColumn(text: '$currencySymbol${(lastOrder.total + truncatedChange).toStringAsFixed(2)}', width: 4, styles: PosStyles(align: PosAlign.right, width: PosTextSize.size2, bold: true)),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Change', width: 8, styles: PosStyles(align: PosAlign.right, width: PosTextSize.size2, bold: true)),
        PosColumn(text: '$currencySymbol$roundedDownChangeString', width: 4, styles: PosStyles(align: PosAlign.right, width: PosTextSize.size2, bold: true)),
      ]);

      bytes += generator.feed(2);
      bytes += generator.text('Thank you!',
          styles: const PosStyles(align: PosAlign.center, bold: true));

      final DateTime nowForFooter = DateTime.now();
      final footerFormatter = DateFormat('MM/dd/yyyy H:m');
      final String footerTimestamp = footerFormatter.format(nowForFooter);
      bytes += generator.text(footerTimestamp,
          styles: const PosStyles(align: PosAlign.center, bold: true), linesAfter: 2);

      if (printQRCode) {
        String qrJson = prefs.getString('fiscalQr_${lastOrder.orderNumber}') 
            ?? jsonEncode({"invoice": lastOrder.orderNumber});

        bytes += generator.feed(1);
        bytes += generator.qrcode(qrJson, size: QRSize.Size8);
        bytes += generator.text('Scan to verify', 
            styles: const PosStyles(align: PosAlign.center, bold: true));
        bytes += generator.feed(2);
      }

      bytes += generator.cut();
      bluetooth.writeBytes(Uint8List.fromList(bytes));

      prefs.setString('changes', '');
      prefs.remove('discount');
      prefs.remove('creditAmount');
    } catch (e) {
      print("Error: $e");
      showToast("An error occurred during printing: $e");
    }
  }

  Future<String> _getCustomerTel(String customerName) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> customersJson = prefs.getStringList('customers') ?? [];
    
    for (String jsonString in customersJson) {
      Map<String, dynamic> customerData = json.decode(jsonString);
      if (customerData['name'] == customerName) {
        return customerData['tel'] ?? '';
      }
    }
    return '';
  }

  void showToast(String message) {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM);
  }

  Future<void> _saveCustomerDetails(String name, double totalSpent) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> customersJson = prefs.getStringList('customers') ?? [];

    Map<String, dynamic> customerData = {
      'name': name,
      'surname': _customerSurnameController.text,
      'email': _customerEmailController.text,
      'tel': _customerTelController.text,
      'totalSpent': totalSpent,
    };

    int existingIndex = -1;
    for (int i = 0; i < customersJson.length; i++) {
      Map<String, dynamic> existingCustomer = json.decode(customersJson[i]);
      if (existingCustomer['name'] == name) {
        existingIndex = i;
        customerData['totalSpent'] = (existingCustomer['totalSpent'] ?? 0.0) + totalSpent;
        break;
      }
    }

    if (existingIndex != -1) {
      customersJson[existingIndex] = json.encode(customerData);
    } else {
      customersJson.add(json.encode(customerData));
    }

    await prefs.setStringList('customers', customersJson);
    showToast('Customer details saved!');
    _loadCustomerNames();
  }

  Future<void> _loadCustomerNames() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> customersJson = prefs.getStringList('customers') ?? [];
    List<String> names = [];
    for (String jsonString in customersJson) {
      Map<String, dynamic> customerData = json.decode(jsonString);
      if (customerData.containsKey('name')) {
        names.add(customerData['name']);
      }
    }
    setState(() {
      _customerNames = names.toSet().toList();
      if (_customerNames.isNotEmpty && !_customerNames.contains(_selectedCustomerName)) {
        _selectedCustomerName = null;
      }
    });
  }

  void _showSaveOtherDetailsPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16.0,
            right: 16.0,
            top: 16.0,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Save Other Customer Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _textController,
                  decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder()),
                  onChanged: (value) => setState(() => customerName = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _customerSurnameController,
                  decoration: const InputDecoration(labelText: 'Surname', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _customerEmailController,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _customerTelController,
                  decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (customerName.isNotEmpty) {
                      final SharedPreferences prefs = await SharedPreferences.getInstance();
                      List<String>? ordersJson = prefs.getStringList('orders');
                      double lastOrderTotal = 0.0;
                      if (ordersJson != null && ordersJson.isNotEmpty) {
                        String lastOrderJson = ordersJson.last;
                        Order lastOrder = Order.fromJson(json.decode(lastOrderJson));
                        lastOrderTotal = lastOrder.total;
                      }
                      await _saveCustomerDetails(customerName, lastOrderTotal);
                      Navigator.pop(context);
                    } else {
                      showToast('Customer Name cannot be empty.');
                    }
                  },
                  child: const Text('Save Customer Details'),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReceiptPreview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastOrder = await _getCurrentOrder(); // USE THE NEW HELPER

      if (lastOrder == null) {
        showToast('No orders to preview');
        return;
      }
      
      String previewContent = await _buildReceiptPreviewContent(lastOrder);
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: Container(
              width: 350,
              height: 500,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Receipt Preview',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          previewContent,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print("Error building preview: $e");
      showToast("Error building preview: $e");
    }
  }

  Future<String> _buildReceiptPreviewContent(Order lastOrder) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var shopName = prefs.getString('fullname') ?? 'Shop Name';
    var tel = prefs.getString('tel') ?? 'N/A';
    var address = prefs.getString('address') ?? 'Shop Address';
    var changeString = prefs.getString('changes') ?? '0';
    double change = double.parse(changeString);
    double truncatedChange = double.parse(change.toStringAsFixed(2));
    String roundedDownChangeString = truncatedChange.toString();
    var discountJson = prefs.getString('discount');
    Discount? discount;
    if (discountJson != null) {
      discount = Discount.fromJson(json.decode(discountJson));
    }
    var currencySymbol = prefs.getString('currencySymbol') ?? '\$';
    bool printQRCode = prefs.getBool('printReceiptId') ?? true;
    String? cashierName = await _getActiveCashierName();
    
    String customerTel = '';
    if (customerName.isNotEmpty) {
      customerTel = await _getCustomerTel(customerName);
    }

    StringBuffer content = StringBuffer();
    
    content.writeln('=' * 32);
    content.writeln(shopName.toUpperCase());
    content.writeln(address);
    content.writeln('Tel: $tel');
    content.writeln('-' * 32);
    
    content.writeln('Customer: ${customerName.isNotEmpty ? customerName : "Walk-in Customer"}');
    if (customerTel.isNotEmpty) content.writeln('Customer Tel: $customerTel');
    if (cashierName != null && cashierName.isNotEmpty) content.writeln('Cashier: $cashierName');
    
    content.writeln('-' * 32);
    
    content.writeln('Invoice: ${lastOrder.orderNumber}');
    final now = DateTime.now();
    final formatter = DateFormat('MM/dd/yyyy H:m');
    content.writeln('Date: ${formatter.format(now)}');
    content.writeln('-' * 32);
    
    content.writeln('Qty Item          Price   Total');
    content.writeln('-' * 32);
    
    List<String> codes = (jsonDecode(prefs.getString('codes1') ?? '[]') as List<dynamic>).cast<String>();
    List<String> measuresFromPrefs = (jsonDecode(prefs.getString('measure') ?? '[]') as List<dynamic>).cast<String>();
    
    double originalTotal = 0;
    for (var product in lastOrder.products) {
      originalTotal += product.price * product.quantity;
    }
    
    for (int i = 0; i < lastOrder.products.length; i++) {
      Product product = lastOrder.products[i];
      int index = codes.indexOf(product.code);
      String quantityText = '${product.quantity}';
      if (index != -1 && measuresFromPrefs.length > index) {
        quantityText += ' ${measuresFromPrefs[index]}';
      }
      
      bool hasDiscount = _productHasDiscount(product);
      double displayPrice = product.price;
      double displayTotal = product.price * product.quantity;
      
      if (hasDiscount) {
        displayPrice = _getDiscountedPrice(product);
        displayTotal = _getTotalWithDiscount(product);
      }
      
      String priceStr = displayPrice.toStringAsFixed(2);
      String totalStr = displayTotal.toStringAsFixed(2);
      
      String productNameDisplay = product.name;
      if (hasDiscount) {
        if (product.discountPercentage != null && product.discountPercentage! > 0) {
          productNameDisplay += ' (${product.discountPercentage!}% off)';
        } else if (product.discountAmount != null && product.discountAmount! > 0) {
          productNameDisplay += ' (-$currencySymbol${product.discountAmount!.toStringAsFixed(2)})';
        }
      }
      
      List<String> nameLines = wrapText(productNameDisplay, 18);
      for (int j = 0; j < nameLines.length; j++) {
        if (j == 0) {
          String line = '${quantityText.padRight(4)} ${nameLines[j].padRight(14)} ${priceStr.padLeft(6)} ${totalStr.padLeft(6)}';
          content.writeln(line);
        } else {
          String line = '     ${nameLines[j].padRight(14)} ${" ".padLeft(6)} ${" ".padLeft(6)}';
          content.writeln(line);
        }
      }
    }
    
    content.writeln('-' * 32);
    
    bool hasAnyDiscount = discount != null || lastOrder.products.any((p) => _productHasDiscount(p));
    if (hasAnyDiscount) {
      content.writeln('DISCOUNT SUMMARY');
      content.writeln('Original Total: $currencySymbol${originalTotal.toStringAsFixed(2)}');
      
      if (discount != null) {
        if (discount.type == DiscountType.Percentage) {
          content.writeln('Discount: ${discount.value}% off');
        } else {
          content.writeln('Discount: -$currencySymbol${discount.value.toStringAsFixed(2)}');
        }
      } else {
        for (var product in lastOrder.products) {
          if (_productHasDiscount(product)) {
            String discountText = '';
            if (product.discountAmount != null && product.discountAmount! > 0) {
              discountText = '-$currencySymbol${product.discountAmount!.toStringAsFixed(2)}';
            } else if (product.discountPercentage != null && product.discountPercentage! > 0) {
              discountText = '${product.discountPercentage!}% off';
            }
            content.writeln('  ${product.name}: $discountText');
          }
        }
      }
      content.writeln('-' * 32);
    }
    
    content.writeln('TOTAL: ${" " * 10}$currencySymbol${lastOrder.total.toStringAsFixed(2)}');
    content.writeln('=' * 32);
    content.writeln('Cash: ${" " * 10}$currencySymbol${(lastOrder.total + truncatedChange).toStringAsFixed(2)}');
    content.writeln('Change: ${" " * 8}$currencySymbol$roundedDownChangeString');
    content.writeln();
    content.writeln('Thank you!');
    content.writeln(formatter.format(DateTime.now()));
    
    if (printQRCode) {
      content.writeln();
      String qrJson = prefs.getString('fiscalQr_${lastOrder.orderNumber}') 
            ?? jsonEncode({"invoice": lastOrder.orderNumber});
      content.writeln('[QR Code: $qrJson]');
    }
    
    content.writeln('=' * 32);
    
    return content.toString();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Print Receipt')),
        body: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(hintText: 'Enter Customer Name'),
                onChanged: (value) {
                  setState(() {
                    customerName = value;
                    if (value.isEmpty) _selectedCustomerName = null;
                  });
                },
              ),
            ),
            if (_customerNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Select Existing Customer', border: OutlineInputBorder()),
                  value: _selectedCustomerName,
                  items: _customerNames.map((String name) {
                    return DropdownMenuItem<String>(value: name, child: Text(name));
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCustomerName = newValue;
                      if (newValue != null) {
                        customerName = newValue;
                        _textController.text = newValue;
                        _loadSelectedCustomerDetails(newValue);
                      }
                    });
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 10.0),
              child: ElevatedButton(
                onPressed: _showSaveOtherDetailsPopup,
                child: const Text('Save Other Details'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text('Device:', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<blue_thermal_printer.BluetoothDevice>(
                    items: _getDeviceItems(),
                    onChanged: (value) {
                      if (value != null) setState(() => _device = value);
                    },
                    value: _device,
                  ),
                  ElevatedButton(
                    onPressed: _pressed ? null : _connected ? _disconnect : _connect,
                    child: Text(_connected ? 'Disconnect' : 'Connect'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 10),
              child: ElevatedButton(
                onPressed: () => initPlatformState(),
                child: const Text('Refresh'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 10),
              child: ElevatedButton(
                onPressed: _showReceiptPreview,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
                child: const Text('Preview Receipt', style: TextStyle(color: Colors.white)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 10),
              child: ElevatedButton(
                onPressed: _connected ? _tesPrint : null,
                child: const Text('Print Receipt'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: ElevatedButton(
                onPressed: () async {
                  final SharedPreferences prefs = await SharedPreferences.getInstance();
                  prefs.setString('changes', '');
                  prefs.remove('discount');
                  prefs.remove('creditAmount');
                  _disconnect();
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SellPage1()));
                  }
                },
                child: const Text('Back to Selling Page'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<blue_thermal_printer.BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<blue_thermal_printer.BluetoothDevice>> items = [];
    if (_devices.isEmpty) {
      items.add(const DropdownMenuItem(child: Text('NONE'), value: null));
    } else {
      for (blue_thermal_printer.BluetoothDevice device in _devices) {
        items.add(DropdownMenuItem(child: Text(device.name ?? 'Unknown device'), value: device));
      }
    }
    return items;
  }

  Future<void> _loadSelectedCustomerDetails(String name) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> customersJson = prefs.getStringList('customers') ?? [];
    for (String jsonString in customersJson) {
      Map<String, dynamic> customerData = json.decode(jsonString);
      if (customerData['name'] == name) {
        _customerSurnameController.text = customerData['surname'] ?? '';
        _customerEmailController.text = customerData['email'] ?? '';
        _customerTelController.text = customerData['tel'] ?? '';
        break;
      }
    }
  }

  List<String> wrapText(String text, int maxLength) {
    List<String> lines = [];
    while (text.length > maxLength) {
      lines.add(text.substring(0, maxLength));
      text = text.substring(maxLength);
    }
    if (text.isNotEmpty) lines.add(text);
    return lines;
  }

  List<int> _addWrappedCustomerNameRow(Generator generator, String customerName) {
    final List<int> bytes = [];
    List<String> lines = wrapText(customerName.isNotEmpty ? customerName : 'Walk-in Customer', 20);
    for (int j = 0; j < lines.length; j++) {
      bytes.addAll(generator.row([
        PosColumn(text: j == 0 ? 'Customer Name' : '', width: 6),
        PosColumn(text: lines[j], width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    return bytes;
  }

  List<int> _addWrappedProductRow(Generator generator, Product product, String quantityText) {
    final List<int> bytes = [];
    bool hasDiscount = _productHasDiscount(product);
    
    double displayPrice = product.price;
    double displayTotal = product.price * product.quantity;
    String priceDisplay = displayPrice.toStringAsFixed(2);
    String totalDisplay = displayTotal.toStringAsFixed(2);
    
    if (hasDiscount) {
      displayPrice = _getDiscountedPrice(product);
      displayTotal = _getTotalWithDiscount(product);
      priceDisplay = displayPrice.toStringAsFixed(2);
      totalDisplay = displayTotal.toStringAsFixed(2);
    }
    
    String productNameDisplay = product.name;
    if (hasDiscount) {
      if (product.discountPercentage != null && product.discountPercentage! > 0) {
        productNameDisplay += ' (${product.discountPercentage!}% off)';
      } else if (product.discountAmount != null && product.discountAmount! > 0) {
        productNameDisplay += ' (-$currencySymbol${product.discountAmount!.toStringAsFixed(2)})';
      }
    }
    
    List<String> nameLines = wrapText(productNameDisplay, 18);
    
    for (int j = 0; j < nameLines.length; j++) {
      String qtyDisplay = (j == 0) ? quantityText : '';
      bytes.addAll(generator.row([
        PosColumn(text: qtyDisplay, width: 2, styles: const PosStyles(bold: true, align: PosAlign.left)),
        PosColumn(text: nameLines[j], width: 6, styles: PosStyles(bold: true, align: PosAlign.left)),
        PosColumn(text: (j == 0) ? priceDisplay : '', width: 2, styles: PosStyles(align: PosAlign.right)),
        PosColumn(text: (j == 0) ? totalDisplay : '', width: 2, styles: PosStyles(align: PosAlign.right)),
      ]));
    }
    
    if (hasDiscount) {
      double originalTotal = product.price * product.quantity;
      double discountedTotal = displayTotal;
      double savings = originalTotal - discountedTotal;
      
      if (savings > 0) {
        bytes.addAll(generator.row([
          PosColumn(text: '', width: 2),
          PosColumn(text: '  (Saved: $currencySymbol${savings.toStringAsFixed(2)})', width: 6, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: '', width: 2),
          PosColumn(text: '', width: 2),
        ]));
      }
    }
    return bytes;
  }
}