import 'dart:convert';
import 'dart:io'; // Required for File operations
import 'package:blue_thermal_printer/blue_thermal_printer.dart'
    as blue_thermal_printer; // Alias to avoid conflict
import 'widgets/historyOrder.dart'; // Assuming this defines Order, Product, Discount
import 'sell_page.dart'; // Assuming this defines SellPage1
import 'package:flutter/material.dart'; // Keep this for UI widgets
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img; // <--- ADDED ALIAS HERE for image decoding

class PrinterPage extends StatefulWidget {
  const PrinterPage({Key? key}) : super(key: key);

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
  String currencySymbol = '\$'; // Default value

  List<String> _customerNames =
      []; // List to store previously entered customer names
  String?
      _selectedCustomerName; // To hold the selected customer name from dropdown

  // Controllers for the customer details pop-up
  final TextEditingController _customerSurnameController =
      TextEditingController();
  final TextEditingController _customerEmailController =
      TextEditingController();
  final TextEditingController _customerTelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _loadCustomerNames(); // Load existing customer names
    loadCurrencySymbol();
  }

  @override
  void dispose() {
    _textController.dispose();
    _customerSurnameController.dispose();
    _customerEmailController.dispose();
    _customerTelController.dispose();
    // Only disconnect if connected to prevent errors
    if (_connected) {
      bluetooth.disconnect();
    }
    super.dispose();
  }

  Future<void> initPlatformState() async {
    await _printCurrentTotalOrder();
    await _loadPrinterCount();

    List<blue_thermal_printer.BluetoothDevice> devices = []; // Use aliased name
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    measures =
        (jsonDecode(prefs.getString('measure1') ?? '[]') as List<dynamic>)
            .cast<String>();
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
      setState(() {}); // Update state with new device list
    } catch (e) {
      showToast('Error getting bonded devices: $e');
    }
  }

  Future<void> _autoConnectSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int printerCount = prefs.getInt('printerCount') ?? 0;

      if (printerCount == 0) {
        showToast('No saved printers found.');
        return;
      }

      // Refresh bonded devices list before connecting
      await _refreshBondedDevices();

      for (int i = 0; i < printerCount; i++) {
        // Fetch printer address for each saved printer
        String? printerAddress = prefs.getString('printerAddress$i');

        if (printerAddress != null) {
          bool found = false;

          for (blue_thermal_printer.BluetoothDevice device in _devices) {
            // Use aliased name
            print(
                'Checking device: ${device.name} with address ${device.address}'); // Debugging

            if (device.address == printerAddress) {
              _device = device;
              await _connect(); // Connect to the device
              showToast('Connected to ${device.name}');
              found = true;
              break; // Stop after connecting to the first available saved printer
            }
          }

          if (!found) {
            showToast('No matching device found for saved printer $i.');
          }
        } else {
          showToast('No printer address found for printer $i.');
        }
      }
    } catch (e) {
      showToast('Error auto-connecting printer: $e');
    }
  }

  Future<void> _connect() async {
    try {
      if (_device == null) {
        showToast('No device selected.');
        return;
      }

      bool result = await bluetooth.connect(_device!);

      if (!result) {
        showToast('Failed to connect to ${_device!.name}');
      } else {
        showToast('Successfully connected to ${_device!.name}');
      }
    } catch (e) {
      showToast('Error connecting to device: $e');
    }
  }

  Future<void> _loadPrinterCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    printerCount = prefs.getInt('printerCount') ?? 0;
  }

  Future<void> _savePrinterCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('printerCount', printerCount);
  }

  Future<void> _printCurrentTotalOrder() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? ordersJson = prefs.getStringList('orders');

      if (ordersJson == null || ordersJson.isEmpty) {
        print('No orders to print');
        return;
      }

      String lastOrderJson = ordersJson.last;
      Order lastOrder = Order.fromJson(json.decode(lastOrderJson));

      double currentTotal = lastOrder.total;
      print('Current Total Order: \$${currentTotal.toStringAsFixed(2)}');
    } catch (e) {
      print("Error: $e");
    }
  }

  void _disconnect() async {
    await bluetooth.disconnect();
    setState(() => _pressed = true);
  }

  // NOTE: This _loadLogoImage function now reads from device storage
Future<img.Image?> _loadLogoImage() async {
  final prefs = await SharedPreferences.getInstance();
  String? logoPath = prefs.getString('processedLogoPath');
  bool printLogo = prefs.getBool('printLogo') ?? true;

  if (!printLogo) {
    return null;
  }

  if (logoPath == null || logoPath.isEmpty) {
    return null;
  }

  try {
    final File logoFile = File(logoPath);
    if (!await logoFile.exists()) {
      return null;
    }

    final Uint8List bytes = await logoFile.readAsBytes();
    return img.decodeImage(bytes);
  } catch (e) {
    print('Error loading logo: $e');
    return null;
  }
}
  Future<String?> _getActiveCashierName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('currentCashier');
  }

void _tesPrint() async {
  try {
    if (!_connected) {
      showToast("**Printer not connected. Please connect first.**");
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? ordersJson = prefs.getStringList('orders');
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

    if (ordersJson == null || ordersJson.isEmpty) {
      showToast('**No orders to print**');
      return;
    }

    String lastOrderJson = ordersJson.last;
    Order lastOrder = Order.fromJson(json.decode(lastOrderJson));
    String? cashierName = await _getActiveCashierName();

    // Get customer details if available
    String customerTel = '';
    if (customerName.isNotEmpty) {
      await _saveCustomerDetails(customerName, lastOrder.total);
      // Load customer details to get telephone number
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

    // Shop Name - already bold
    bytes += generator.text(shopName ?? 'Shop Name',
        styles: PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true), // Ensure bold
        linesAfter: 1);

    // Shop Address - make bold
    bytes += generator.text(address ?? 'Shop Address',
        styles: PosStyles(align: PosAlign.center, bold: true));

    // Shop Tel - make bold
    bytes += generator.text('Tel: ${tel ?? 'N/A'}',
        styles: PosStyles(align: PosAlign.center, bold: true), linesAfter: 1);

    bytes += generator.hr();

    // Wrapped customer name - assuming _addWrappedCustomerNameRow handles bold internally
    bytes += _addWrappedCustomerNameRow(generator, customerName);

    // Add customer telephone if available
    if (customerTel.isNotEmpty) {
      bytes += generator.row([
        PosColumn(text: 'Customer Tel', width: 6, styles: PosStyles(bold: true)),
        PosColumn(
            text: customerTel,
            width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }

    if (cashierName != null && cashierName.isNotEmpty) {
      bytes += generator.row([
        PosColumn(text: 'Cashier', width: 6, styles: PosStyles(bold: true)), // Make "Cashier" bold
        PosColumn(
            text: cashierName,
            width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true)), // Make cashierName bold
      ]);
    }

    //bytes += generator.feed(1);
    bytes += generator.hr();

    // Invoice Number - make bold
    bytes += generator.text("Invoice: ${lastOrder.orderNumber}",
        styles: const PosStyles(align: PosAlign.left, bold: true));

    final now = DateTime.now();
    final formatter = DateFormat('MM/dd/yyyy H:m');
    final String timestamp = formatter.format(now);
    // Date - make bold
    bytes += generator.text("Date: $timestamp",
        styles: const PosStyles(align: PosAlign.left, bold: true), linesAfter: 1);

    bytes += generator.hr();

    List<String> codes =
        (jsonDecode(prefs.getString('codes1') ?? '[]') as List<dynamic>)
            .cast<String>();
    List<String> measuresFromPrefs =
        (jsonDecode(prefs.getString('measure') ?? '[]') as List<dynamic>)
            .cast<String>();

    // Table Headers - make bold
    bytes += generator.row([
      PosColumn(text: 'Qty', width: 1, styles: PosStyles(bold: true)), // Make bold
      PosColumn(text: 'Item', width: 5, styles: PosStyles(bold: true)), // Make bold
      PosColumn(
          text: 'Price',
          width: 3,
          styles: PosStyles(align: PosAlign.right, bold: true)), // Make bold
      PosColumn(
          text: 'Total',
          width: 3,
          styles: PosStyles(align: PosAlign.right, bold: true)), // Make bold
    ]);

    bytes += generator.hr(ch: '-');

    for (int i = 0; i < lastOrder.products.length; i++) {
      Product product = lastOrder.products[i];
      int index = codes.indexOf(product.code);
      // quantityText is already handled as bold in _addWrappedProductRow
      String quantityText = '${product.quantity}'; // Removed ** as PosColumn style handles it
      if (index != -1 && measuresFromPrefs.length > index) {
        quantityText += ' ${measuresFromPrefs[index]}'; // Removed ** as PosColumn style handles it
      }

      bytes += _addWrappedProductRow(generator, product, quantityText);
    }

    bytes += generator.hr();

    if (discount != null) {
      bytes += generator.feed(1);
      if (discount.type == DiscountType.Percentage) {
        // Discount text - make bold
        bytes += generator.text("Discount: ${discount.value}% off",
            styles: const PosStyles(align: PosAlign.center, bold: true));
      } else {
        // Discount text - make bold
        bytes += generator.text(
            "Discount: $currencySymbol${discount.value.toStringAsFixed(2)} off",
            styles: const PosStyles(align: PosAlign.center, bold: true));
      }
      bytes += generator.feed(1);
    }

    // TOTAL Row - already bold via height/width settings, but explicitly add bold: true for clarity
    bytes += generator.row([
      PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: PosStyles(
              height: PosTextSize.size2,
              width: PosTextSize.size2,
              bold: true)), // Ensure bold
      PosColumn(
          text: '$currencySymbol${lastOrder.total.toStringAsFixed(2)}',
          width: 6,
          styles: PosStyles(
              align: PosAlign.right,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
              bold: true)), // Ensure bold
    ]);

    bytes += generator.hr(ch: '=', linesAfter: 1);

    // Cash Row - make bold
    bytes += generator.row([
      PosColumn(
          text: 'Cash',
          width: 8,
          styles: PosStyles(align: PosAlign.right, width: PosTextSize.size2, bold: true)), // Make "Cash" bold
      PosColumn(
          text: '$currencySymbol${(lastOrder.total + truncatedChange).toStringAsFixed(2)}',
          width: 4,
          styles: PosStyles(align: PosAlign.right, width: PosTextSize.size2, bold: true)), // Make amount bold
    ]);

    // Change Row - make bold
    bytes += generator.row([
      PosColumn(
          text: 'Change',
          width: 8,
          styles: PosStyles(align: PosAlign.right, width: PosTextSize.size2, bold: true)), // Make "Change" bold
      PosColumn(
          text: '$currencySymbol$roundedDownChangeString',
          width: 4,
          styles: PosStyles(align: PosAlign.right, width: PosTextSize.size2, bold: true)), // Make amount bold
    ]);

    bytes += generator.feed(2);
    // Thank you! - already bold
    bytes += generator.text('Thank you!',
        styles: const PosStyles(align: PosAlign.center, bold: true));

    final DateTime nowForFooter = DateTime.now();
    final footerFormatter = DateFormat('MM/dd/yyyy H:m');
    final String footerTimestamp = footerFormatter.format(nowForFooter);
    // Footer Timestamp - make bold
    bytes += generator.text(footerTimestamp,
        styles: const PosStyles(align: PosAlign.center, bold: true), linesAfter: 2);

    if (printQRCode) {
      Map<String, dynamic> qrData = {
        "invoice": lastOrder.orderNumber,
      };
      String qrJson = jsonEncode(qrData);

      bytes += generator.feed(1);
      bytes += generator.qrcode(qrJson, size: QRSize.Size8);
      // QR Code message - make bold
      bytes += generator.text('Scan for invoice details',
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

// Add this helper function to get customer telephone
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

  // --- Customer Management Functions ---

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

    // Check if customer already exists to update totalSpent
    int existingIndex = -1;
    for (int i = 0; i < customersJson.length; i++) {
      Map<String, dynamic> existingCustomer = json.decode(customersJson[i]);
      if (existingCustomer['name'] == name) {
        existingIndex = i;
        // Add to existing total spent
        customerData['totalSpent'] =
            (existingCustomer['totalSpent'] ?? 0.0) + totalSpent;
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
    _loadCustomerNames(); // Refresh the list of customer names
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
      _customerNames =
          names.toSet().toList(); // Use toSet().toList() to get unique names
      if (_customerNames.isNotEmpty &&
          !_customerNames.contains(_selectedCustomerName)) {
        _selectedCustomerName =
            null; // Clear selection if the previously selected customer is no longer available
      }
    });
  }

  void _showSaveOtherDetailsPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // Allows the bottom sheet to take full height if needed
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
                const Text(
                  'Save Other Customer Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller:
                      _textController, // Use the existing controller for name
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      customerName = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _customerSurnameController,
                  decoration: const InputDecoration(
                    labelText: 'Surname',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _customerEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _customerTelController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (customerName.isNotEmpty) {
                      final SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      List<String>? ordersJson = prefs.getStringList('orders');
                      double lastOrderTotal = 0.0;
                      if (ordersJson != null && ordersJson.isNotEmpty) {
                        String lastOrderJson = ordersJson.last;
                        Order lastOrder =
                            Order.fromJson(json.decode(lastOrderJson));
                        lastOrderTotal = lastOrder.total;
                      }
                      await _saveCustomerDetails(customerName, lastOrderTotal);
                      Navigator.pop(context); // Close the bottom sheet
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Print Receipt'),
        ),
        body: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Enter Customer Name',
                ),
                onChanged: (value) {
                  setState(() {
                    customerName = value;
                    if (value.isEmpty) {
                      _selectedCustomerName =
                          null; // Clear selection if user starts typing
                    }
                  });
                },
              ),
            ),
            // Dropdown for previously entered customer names
            if (_customerNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Existing Customer',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCustomerName,
                  items: _customerNames.map((String name) {
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCustomerName = newValue;
                      if (newValue != null) {
                        customerName = newValue;
                        _textController.text =
                            newValue; // Update the text field
                        // Load other details if available for the selected customer
                        _loadSelectedCustomerDetails(newValue);
                      }
                    });
                  },
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 10.0, right: 10.0, top: 10.0),
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
                  const Text(
                    'Device:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  DropdownButton<blue_thermal_printer.BluetoothDevice>(
                    // Use aliased name
                    items: _getDeviceItems(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _device = value);
                      }
                    },
                    value: _device,
                  ),
                  ElevatedButton(
                    onPressed: _pressed
                        ? null
                        : _connected
                            ? _disconnect
                            : _connect,
                    child: Text(_connected ? 'Disconnect' : 'Connect'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 10),
              child: ElevatedButton(
                onPressed: () {
                  initPlatformState();
                },
                child: const Text('Refresh'),
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
                  final SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  prefs.setString('changes', '');
                  prefs.remove('discount');
                  prefs.remove('creditAmount');
                  _disconnect();
                  // Navigate back to the SellingPage
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => SellPage1()),
                    );
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

  List<DropdownMenuItem<blue_thermal_printer.BluetoothDevice>>
      _getDeviceItems() {
    // Use aliased name
    List<DropdownMenuItem<blue_thermal_printer.BluetoothDevice>> items =
        []; // Use aliased name
    if (_devices.isEmpty) {
      items.add(const DropdownMenuItem(
        child: Text('NONE'),
        value: null,
      ));
    } else {
      for (blue_thermal_printer.BluetoothDevice device in _devices) {
        // Use aliased name
        items.add(DropdownMenuItem(
          child: Text(device.name ?? 'Unknown device'),
          value: device,
        ));
      }
    }
    return items;
  }

  // Function to load other details of a selected customer
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
  if (text.isNotEmpty) {
    lines.add(text);
  }
  return lines;
}

List<int> _addWrappedCustomerNameRow(Generator generator, String customerName) {
  final List<int> bytes = [];
  List<String> lines = wrapText(
      customerName.isNotEmpty ? customerName : 'Walk-in Customer', 20);
  for (int j = 0; j < lines.length; j++) {
    bytes.addAll(generator.row([
      PosColumn(text: j == 0 ? 'Customer Name' : '', width: 6),
      PosColumn(
        text: lines[j],
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
  }
  return bytes;
}

List<int> _addWrappedProductRow(
    Generator generator, Product product, String quantityText) {
  final List<int> bytes = [];
  List<String> nameLines = wrapText(product.name, 20);
  double totalValue = product.price * product.quantity;

  for (int j = 0; j < nameLines.length; j++) {
    bytes.addAll(generator.row([
      PosColumn(text: j == 0 ? quantityText : '', width: 1),
      PosColumn(
        text: nameLines[j],
        width: 7,
        styles: PosStyles(bold: true), // <--- Added bold style here
      ),
      PosColumn(
          text: j == 0 ? product.price.toStringAsFixed(2) : '',
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
      PosColumn(
          text: j == 0 ? totalValue.toStringAsFixed(2) : '',
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
    ]));
  }

  return bytes;
}


}