import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as thermal_printer;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class PrinterPage extends StatefulWidget {
  @override
  _PrinterPageState createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  thermal_printer.BlueThermalPrinter _bluetooth = thermal_printer.BlueThermalPrinter.instance;
  List<thermal_printer.BluetoothDevice> devices = [];
  Map<int, thermal_printer.BluetoothDevice> selectedDevices = {};
  bool saveMultiplePrinters = false;

  @override
  void initState() {
    super.initState();
    _checkBluetoothPermissions();
  }

  Future<void> _checkBluetoothPermissions() async {
    var status = await Permission.bluetooth.status;
    if (!status.isGranted) {
      await Permission.bluetooth.request();
    }
    _getConnectedPrinters();
  }

  Future<void> _getConnectedPrinters() async {
    var state = await _bluetooth.isOn;
    if (!state!) {
      return;
    }

    List<thermal_printer.BluetoothDevice> connectedDevices = await _bluetooth.getBondedDevices();
    setState(() {
      devices = connectedDevices;
    });
  }

Future<void> _saveSelectedPrinters() async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Save the count of selected printers
    await prefs.setInt('printerCount', selectedDevices.length);

    int i = 0;
    // Iterate over selected devices in order of selection
    selectedDevices.values.forEach((device) async {
      if (device != null) {
        try {
          // Save the device details with a sequential index based on order of selection
          await prefs.setString('printerName$i', device.name!);
          await prefs.setString('printerAddress$i', device.address!);
          showToast('Device saved: ${i + 1} - ${device.name} (${device.address})');
        } catch (e) {
          showToast('Error saving device ${i + 1}: $e'); // Error when saving each device
        }
        i++;
      }
    });
  } catch (e) {
    showToast('Error accessing SharedPreferences: $e'); // Error when accessing SharedPreferences
  }
}


  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  Future<void> _testPrinter(thermal_printer.BluetoothDevice device) async {
    final isConnected = await _bluetooth.connect(device);
    if (isConnected) {
      await _bluetooth.write("success\n");
      await _bluetooth.disconnect();
    } else {
      print('Printer connection failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Printer Authentication'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Select a Printer:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: Text('Save multiple printers'),
            value: saveMultiplePrinters,
            onChanged: (bool value) {
              setState(() {
                saveMultiplePrinters = value;
                if (!saveMultiplePrinters) {
                  selectedDevices.clear();
                }
              });
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                thermal_printer.BluetoothDevice device = devices[index];
                bool isSelected = selectedDevices.containsKey(index);
                return Card(
                  elevation: 2,
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: isSelected ? Colors.blue.shade100 : null,
                  child: ListTile(
                    title: Text(device.name ?? ''),
                    subtitle: Text('Printer ${selectedDevices.keys.toList().indexOf(index) + 1}: ${device.address ?? ''}'),
                    onTap: () {
                      setState(() {
                        if (saveMultiplePrinters) {
                          if (isSelected) {
                            selectedDevices.remove(index);
                          } else {
                            selectedDevices[index] = device;
                          }
                        } else {
                          selectedDevices.clear();
                          selectedDevices[index] = device;
                        }
                      });
                    },
                    selected: isSelected,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Selected Printers: ${selectedDevices.length}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await _saveSelectedPrinters();
            },
            child: Text('Save and Continue'),
          ),
          ElevatedButton(
            onPressed: selectedDevices.isNotEmpty
                ? () async {
                    thermal_printer.BluetoothDevice firstPrinter = selectedDevices.values.first;
                    await _testPrinter(firstPrinter);
                  }
                : null,
            child: Text('Test First Printer'),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: PrinterPage(),
  ));
}
