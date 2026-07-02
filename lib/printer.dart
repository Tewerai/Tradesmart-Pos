// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'pages/sell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Order {
  final List<Product> products;
  final double total;
  final DateTime timestamp; // New field for timestamp

  Order({required this.products, required this.total, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'products': products.map((product) => product.toJson()).toList(),
        'total': total,
        'timestamp':
            timestamp.toIso8601String(), // Convert DateTime to a String
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        products: List<Product>.from(
            json["products"].map((x) => Product.fromJson(x))),
        total: json["total"].toDouble(),
        timestamp: DateTime.parse(
            json["timestamp"]), // Convert String back to DateTime
      );
}

class Product {
  final String name;
  final String code;
  final double price;
  final int quantity;

  Product(
      {required this.name,
      required this.code,
      required this.price,
      required this.quantity});

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'price': price,
        'quantity': quantity,
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'],
      code: json['code'],
      price: json['price'].toDouble(),
      quantity: json['quantity'],
    );
  }
}

class PrinterPage extends StatefulWidget {
  const PrinterPage({Key? key}) : super(key: key);

  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  final TextEditingController _textController = TextEditingController();
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _device;
  bool _connected = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    List<BluetoothDevice> devices = [];
    try {
      devices = await bluetooth.getBondedDevices();
    } on PlatformException {
      showToast('Error getting bonded devices');
    }

    setState(() => _devices = devices);

    // Listen to printer connection state
    bluetooth.onStateChanged().listen((state) {
      setState(() {
        _connected = state == BlueThermalPrinter.CONNECTED;
        _pressed = false; // Allows reconnection attempts
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
  String? logoPath = prefs.getString('logoPath');
  if (logoPath != null && _connected) {
    try {
      // Attempt to print the image
      var result = await bluetooth.printImage(logoPath);
      // You might need to check the result if the method returns any indication of success or failure
      if (result == true) {
        showToast("Logo printed successfully.");
      } else {
        // If the method returns a result that indicates failure, handle it accordingly
        showToast("Failed to print logo.");
      }
    } catch (e) {
      // If an exception occurs, show it as a toast message
      showToast("Error printing logo: $e");
    }
    bluetooth.printNewLine();
  } else {
    if (!_connected) {
      showToast("Printer not connected.");
    } else {
      showToast("Logo path not found.");
    }
  }
}

void showToast(String message) {
  Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white);
}

void _tesPrint() async {
  final prefs = await SharedPreferences.getInstance();
  List<String>? ordersJson = prefs.getStringList('orders');
  var shopName = prefs.getString('fullname');
  var tel = prefs.getString('tel');
  var address = prefs.getString('address');
var changeString = prefs.getString('changes') ?? '0'; // Assume this is the string you have
double change = double.parse(changeString); // Convert to double

// To ensure rounding down, you might adjust the number slightly if precise truncation is needed
double truncatedChange = double.parse(change.toStringAsFixed(2));

// If you need it as a string
String roundedDownChangeString = truncatedChange.toString();

// If you need to keep it as a double
double roundedDownChangeDouble = truncatedChange;
  if (ordersJson == null || ordersJson.isEmpty) {
    showToast('No orders to print');
    return;
  }

  String lastOrderJson = ordersJson.last;
  Order lastOrder = Order.fromJson(json.decode(lastOrderJson));

  if (_connected) {
    bluetooth.printCustom(shopName!, 3, 1);
    bluetooth.printCustom(tel!, 3, 1);
    bluetooth.printCustom(address!, 3, 1);
    bluetooth.printNewLine();
    bluetooth.printCustom("Date: ${DateFormat('yyyy-MM-dd – kk:mm').format(lastOrder.timestamp)}", 2, 1);
    bluetooth.printNewLine();

    // Iterate over the products with their index
    for (int i = 0; i < lastOrder.products.length; i++) {
      Product product = lastOrder.products[i];
      double totalValue = product.price * product.quantity; // Calculate total value for the product

      // Print each product with its index, quantity, and total value
      bluetooth.printCustom("${i + 1}. ${product.name} x${product.quantity} @ \$${product.price} = \$${totalValue.toStringAsFixed(2)}", 1, 0);
    }

    bluetooth.printNewLine();
    bluetooth.printCustom("Total: \$${lastOrder.total.toStringAsFixed(2)}", 2, 1);
    bluetooth.printCustom("Change: $roundedDownChangeString", 2, 1);
    bluetooth.printNewLine();
    bluetooth.printCustom("Thank You!", 2, 1);
    bluetooth.paperCut();
  }
   await prefs.setString('changes', '');

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
                // If you need to do something with the value
              },
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
              onPressed: () {
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



// Ensure to close the bluetooth connection when the widget is disposed
@override
void dispose() {
  bluetooth.disconnect();
  super.dispose();
}

}
