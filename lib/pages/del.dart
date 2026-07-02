
import 'dart:convert';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'widgets/historyOrder.dart';
import 'sell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

class PrinterPage extends StatefulWidget {
  const PrinterPage({Key? key}) : super(key: key);

  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  final TextEditingController _textController = TextEditingController();
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  late String customerName = '';

  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _device;
  bool _connected = false;
  bool _pressed = false;
  List<dynamic> measures = [];
  bool saveMultiplePrinters = false;
  int printerCount = 0;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    await _printCurrentTotalOrder();
    await _loadPrinterCount();
    
    List<BluetoothDevice> devices = [];
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
        _connected = state == BlueThermalPrinter.CONNECTED;
        _pressed = false;
      });
    });

    _autoConnectSavedPrinter();
  }

  Future<void> _autoConnectSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    String? printerAddress = prefs.getString('printerAddress');

    if (printerAddress != null) {
      for (BluetoothDevice device in _devices) {
        if (device.address == printerAddress) {
          _device = device;
          _connect();
          break;
        }
      }
    }
  }

  Future<void> _loadPrinterCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    printerCount = prefs.getInt('printerCount') ?? 0;
  }

  Future<void> _saveSelectedPrinter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_device != null) {
      if (saveMultiplePrinters) {
        printerCount++;
        await prefs.setString('printerName$printerCount', _device!.name ?? '');
        await prefs.setString('printerAddress$printerCount', _device!.address ?? '');
      } else {
        await prefs.setString('printerName', _device!.name ?? '');
        await prefs.setString('printerAddress', _device!.address ?? '');
      }
    }
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

  void _connect() async {
    if (_device == null) {
      showToast('No device selected.');
      return;
    }
    setState(() => _pressed = true);

    final result = await bluetooth.connect(_device!);
    if (!result) {
      showToast('Failed to connect');
      setState(() => _pressed = false);
    }
  }

  void _disconnect() async {
    await bluetooth.disconnect();
    setState(() => _pressed = true);
  }

  void _printLogo() async {
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

  Future<String?> _getActiveCashierName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('currentCashier');
  }

  void _tesPrint() async {
    try {
      _printLogo();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? ordersJson = prefs.getStringList('orders');
      var shopName = prefs.getString('fullname');
      var tel = prefs.getString('tel');
      var address = prefs.getString('address');
      var changeString = prefs.getString('changes') ?? '0';
      double change = double.parse(changeString);
      double truncatedChange = double.parse(change.toStringAsFixed(2));
      String roundedDownChangeString = truncatedChange.toString();
      double roundedDownChangeDouble = truncatedChange;

      var discountJson = prefs.getString('discount');
      Discount? discount;
      if (discountJson != null) {
        discount = Discount.fromJson(json.decode(discountJson));
      }

      bool printQRCode = prefs.getBool('printReceiptId') ?? true;

      if (ordersJson == null || ordersJson.isEmpty) {
        showToast('No orders to print');
        return;
      }

      String lastOrderJson = ordersJson.last;
      Order lastOrder = Order.fromJson(json.decode(lastOrderJson));

      String? cashierName = await _getActiveCashierName();

      if (_connected) {
        bluetooth.printCustom(shopName ?? '', 3, 1);
        bluetooth.printCustom(tel ?? '', 3, 1);
        bluetooth.printCustom(address ?? '', 3, 1);
        bluetooth.printNewLine();
        bluetooth.printCustom('-------------------------------', 1, 0);

        bluetooth.printLeftRight('Customer Name', customerName, 1);

        if (cashierName != null && cashierName.isNotEmpty) {
          bluetooth.printLeftRight('Cashier', cashierName, 1);
          bluetooth.printNewLine();
        }

        bluetooth.printCustom('-------------------------------', 1, 0);
        bluetooth.printNewLine();
        bluetooth.printCustom("Invoice: ${lastOrder.orderNumber}", 1, 0);
        bluetooth.printCustom("Date: ${DateFormat('yyyy-MM-dd – kk:mm').format(lastOrder.timestamp)}", 1, 0);
        bluetooth.printNewLine();
        bluetooth.printCustom('-------------------------------', 1, 0);

        List<String> codes = (jsonDecode(prefs.getString('codes1') ?? '[]') as List<dynamic>).cast<String>();
        List<String> measures = (jsonDecode(prefs.getString('measure1') ?? '[]') as List<dynamic>).cast<String>();

        for (int i = 0; i < lastOrder.products.length; i++) {
          Product product = lastOrder.products[i];
          double totalValue = product.price * product.quantity;
          int index = codes.indexOf(product.code);
          String quantityText = '${product.quantity}';

          if (index != -1 && measures.length > index && measures[index] == 'kgs') {
            quantityText += ' kgs';
          } else if (index != -1 && measures.length > index && measures[index] == 'metres') {
            quantityText += ' m';
          } else if (index != -1 && measures.length > index && measures[index] == 'centimetres') {
            quantityText += ' cm';
          } else if (index != -1 && measures.length > index && measures[index] == 'lbs') {
            quantityText += ' lbs';
          }

          bluetooth.printCustom("${i + 1}. ${product.name} x $quantityText @ \$${product.price} = \$${totalValue.toStringAsFixed(2)}", 1, 0);
        }

        if (discount != null) {
          if (discount.type == DiscountType.Percentage) {
            bluetooth.printNewLine();
            bluetooth.printCustom("Discount: ${discount.value}% off", 1, 1);
          } else {
            bluetooth.printNewLine();
            bluetooth.printCustom("Discount: \$${discount.value.toStringAsFixed(2)} off", 1, 1);
          }
        }

        bluetooth.printCustom('-------------------------------', 1, 0);
        bluetooth.printCustom("Total: \$${lastOrder.total.toStringAsFixed(2)}", 2, 1);
        bluetooth.printCustom("Change: \$$roundedDownChangeString", 2, 1);
        bluetooth.printCustom('-------------------------------', 1, 0);
        bluetooth.printNewLine();

        if (printQRCode) {
          bluetooth.printQRcode(lastOrder.orderNumber, 200, 200, 1);
          bluetooth.printNewLine();
        }

        bluetooth.printCustom('Thank you for shopping with us!', 1, 1);
        bluetooth.printCustom('-------------------------------', 1, 0);
        bluetooth.printNewLine();
        bluetooth.printNewLine();
        bluetooth.paperCut();
      } else {
        showToast("Printer not connected.");
      }
    } catch (e) {
      showToast("Error: $e");
    }
  }

  void showToast(String message) {
    Fluttertoast.showToast(msg: message, toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM);
  }
    onItemChanged(String value) {
    customerName = value;

    setState(() {
      customerName = value;
    });
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
                onChanged: (value) {},
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
                  DropdownButton<BluetoothDevice>(
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
                  final SharedPreferences prefs = await SharedPreferences.getInstance();
                  prefs.setString('changes', '');
                  prefs.remove('discount');
                  prefs.remove('creditAmount');
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

  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devices.isEmpty) {
      items.add(const DropdownMenuItem(
        child: Text('NONE'),
        value: null,
      ));
    } else {
      for (BluetoothDevice device in _devices) {
        items.add(DropdownMenuItem(
          child: Text(device.name ?? 'Unknown device'),
          value: device,
        ));
      }
    }
    return items;
  }
}

