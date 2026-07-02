import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img_lib;

class BluetoothApp extends StatefulWidget {
  @override
  _BluetoothAppState createState() => _BluetoothAppState();
}

class _BluetoothAppState extends State<BluetoothApp> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<BluetoothDevice> devicesList = [];
  BluetoothDevice? connectedDevice;

  @override
  void initState() {
    super.initState();
    flutterBlue.connectedDevices.asStream().listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceToList(device);
      }
    });
    flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceToList(result.device);
      }
    });
    flutterBlue.startScan();
  }

  _addDeviceToList(final BluetoothDevice device) {
    if (!devicesList.contains(device)) {
      setState(() {
        devicesList.add(device);
      });
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect();
    setState(() {
      connectedDevice = device;
    });
  }

  Future<void> sendImageToPrinter(BluetoothDevice device) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? imagePath = prefs.getString('logoPath');
    if (imagePath == null) {
      print("No image path found in SharedPreferences.");
      return;
    }

    File imageFile = File(imagePath);
    Uint8List imageBytes = await imageFile.readAsBytes();
    // Here you would convert the image to a format suitable for your printer.
    // For simplicity, this example skips the conversion process.
    // List<int> bytes = convertImageToPrinterFormat(imageBytes);

    await device.discoverServices().then((services) {
      BluetoothService service = services.firstWhere((service) => true); // Example logic
      BluetoothCharacteristic characteristic = service.characteristics.firstWhere((characteristic) => true); // Example logic
      characteristic.write(imageBytes, withoutResponse: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bluetooth Devices"),
      ),
      body: ListView.builder(
        itemCount: devicesList.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(devicesList[index].name),
            subtitle: Text(devicesList[index].id.toString()),
            onTap: () => connectToDevice(devicesList[index]),
            onLongPress: () => sendImageToPrinter(devicesList[index]), // Simplified for demonstration
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    flutterBlue.stopScan();
    super.dispose();
  }
}
