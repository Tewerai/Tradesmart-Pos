import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;  // For image processing
import 'dart:ui' as ui;  // For Flutter's Image class (if needed elsewhere)
import 'dart:convert';

import 'cashierlogs.dart';

class StoreInfoPage extends StatefulWidget {
  @override
  _StoreInfoPageState createState() => _StoreInfoPageState();
}

class _StoreInfoPageState extends State<StoreInfoPage> {
  File? _logo;
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopTelController = TextEditingController();
  List<String> cashiers = [];
  String? activeCashier;
  List<CashierShift> cashierShifts = [];

  @override
  void initState() {
    super.initState();
    _checkPasswordRequirement();
    _loadPreferences();
    _loadCashierShifts();
    _addListener();
  }

  Future<void> _checkPasswordRequirement() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool requirePassword = prefs.getBool('addPasswordForStoreInfo') ?? false;
    if (requirePassword) {
      _showPasswordDialog();
    }
  }

  Future<void> _showPasswordDialog() async {
    TextEditingController passwordController = TextEditingController();
    int passwordAttempts = 0;
    bool passworGot = true;

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
                          passworGot = false;
                          passwordAttempts++;
                        });
                        if (passwordAttempts >= 3) {
                          Navigator.of(context).pop();
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

  void _addListener() {
    _shopNameController.addListener(() {
      _updatePreference('fullname', _shopNameController.text);
    });

    _shopAddressController.addListener(() {
      _updatePreference('address', _shopAddressController.text);
    });

    _shopTelController.addListener(() {
      _updatePreference('tel', _shopTelController.text);
    });
  }

  Future<void> _updatePreference(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final String? address = prefs.getString('address');
    final String? fullname = prefs.getString('fullname');
    final String? tel = prefs.getString('tel');
    final String? processedLogoPath = prefs.getString('processedLogoPath');
    final String? currentCashier = prefs.getString('currentCashier');
    final String? allCashiersJson = prefs.getString('allcashiers');

    setState(() {
      _shopAddressController.text = address ?? '';
      _shopTelController.text = tel ?? '';
      _shopNameController.text = fullname ?? '';
      if (processedLogoPath != null) {
        _logo = File(processedLogoPath);
      }
      activeCashier = currentCashier;
      if (allCashiersJson != null) {
        cashiers = List<String>.from(jsonDecode(allCashiersJson));
      }
    });
  }

  Future<void> _saveCashiers() async {
    final prefs = await SharedPreferences.getInstance();
    final String cashiersJson = jsonEncode(cashiers);
    await prefs.setString('allcashiers', cashiersJson);
  }

  Future<void> _pickLogo() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final File newImage = await File(pickedFile.path).copy('$path/logo.png');

      final processedLogo = await _processLogo(newImage);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('processedLogoPath', processedLogo.path);

      setState(() {
        _logo = processedLogo;
      });
    }
  }

Future<File> _processLogo(File originalImageFile) async {
  try {
    // Read the image using the image package
    img.Image? originalImage = img.decodeImage(await originalImageFile.readAsBytes());
    
    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

    // Resize the image (thermal printers typically need small images)
    final int desiredWidth = 200;  // Adjust based on your printer's paper width
    final int desiredHeight = (originalImage.height * desiredWidth / originalImage.width).round();
    
    img.Image resizedImage = img.copyResize(
      originalImage,
      width: desiredWidth,
      height: desiredHeight,
    );

    // Convert to grayscale (better for thermal printing)
    img.grayscale(resizedImage);

    // Increase contrast (thermal printers work best with high contrast)
    img.adjustColor(resizedImage, contrast: 1.5);

    // Save the processed image
    final directory = await getApplicationDocumentsDirectory();
    final String processedImagePath = '${directory.path}/processed_logo.png';
    final File processedImageFile = File(processedImagePath);
    await processedImageFile.writeAsBytes(img.encodePng(resizedImage));

    return processedImageFile;
  } catch (e) {
    print('Error processing logo: $e');
    rethrow;
  }
}
  @override
  void dispose() {
    _shopNameController.removeListener(() {});
    _shopAddressController.removeListener(() {});
    _shopTelController.removeListener(() {});

    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopTelController.dispose();
    super.dispose();
  }

  Future<void> _showAddCashierDialog() async {
    TextEditingController _cashierNameController = TextEditingController();
    TextEditingController _cashierPhoneController = TextEditingController();
    TextEditingController _cashierPasswordController = TextEditingController();
    String _selectedType = 'Cashier';
    TextEditingController _cashierEmailController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _cashierNameController,
                  decoration: InputDecoration(labelText: 'Cashier Name'),
                ),
                TextField(
                  controller: _cashierPhoneController,
                  decoration: InputDecoration(labelText: 'Phone Number'),
                ),
                TextField(
                  controller: _cashierPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Set Password'),
                ),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: ['Admin', 'Cashier'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    _selectedType = newValue!;
                  },
                  decoration: InputDecoration(labelText: 'Type'),
                ),
                TextField(
                  controller: _cashierEmailController,
                  decoration: InputDecoration(labelText: 'Email (Optional)'),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final cashierName = _cashierNameController.text;
                    final cashierPassword = _cashierPasswordController.text;

                    await prefs.setString('cashier_$cashierName', cashierPassword);

                    setState(() {
                      cashiers.add(cashierName);
                    });
                    _saveCashiers();
                    Navigator.pop(context);
                  },
                  child: Text('Save'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setActiveCashier(String cashier) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPassword = prefs.getString('cashier_$cashier');

    bool isAuthenticated = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            TextEditingController _passwordController = TextEditingController();
            return AlertDialog(
              title: Text('Enter Password for $cashier'),
              content: TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    if (_passwordController.text == savedPassword) {
                      Navigator.of(context).pop(true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Incorrect password. Try again.')),
                      );
                      Navigator.of(context).pop(false);
                    }
                  },
                ),
              ],
            );
          },
        ) ??
        false;

    if (isAuthenticated) {
      setState(() {
        activeCashier = cashier;
        cashierShifts.add(CashierShift(
          name: cashier,
          shiftStart: DateTime.now(),
          day: DateTime.now().toIso8601String().split('T').first,
          hours: 0,
          sales: 0,
        ));
      });
      await prefs.setString('currentCashier', cashier);
      _saveCashierShifts();
    }
  }

  Future<void> _deactivateCashier() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      CashierShift? currentShift = cashierShifts
          .firstWhere((shift) => shift.name == activeCashier && shift.shiftEnd == null, orElse: () => CashierShift(name: '', shiftStart: DateTime.now(), day: '', hours: 0, sales: 0));
      if (currentShift.name.isNotEmpty) {
        currentShift.shiftEnd = DateTime.now();
        currentShift.hours =
            currentShift.shiftEnd!.difference(currentShift.shiftStart).inHours.toDouble();
      }
      activeCashier = null;
    });
    await prefs.remove('currentCashier');
    _saveCashierShifts();
  }

  Future<String?> _getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('password');
  }

  Future<bool> _showPasswordPrompt() async {
    TextEditingController _passwordController = TextEditingController();
    bool isAuthenticated = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Password'),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(labelText: 'Password'),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () async {
                String? savedPassword = await _getPassword();
                if (_passwordController.text == savedPassword) {
                  isAuthenticated = true;
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    return isAuthenticated;
  }

  Future<void> _saveCashierShifts() async {
    final prefs = await SharedPreferences.getInstance();
    final String shiftsJson = jsonEncode(cashierShifts.map((shift) => shift.toJson()).toList());
    await prefs.setString('cashierShifts', shiftsJson);
  }

  Future<void> _loadCashierShifts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? shiftsJson = prefs.getString('cashierShifts');
    if (shiftsJson != null) {
      List<dynamic> jsonList = jsonDecode(shiftsJson);
      setState(() {
        cashierShifts = jsonList.map((json) => CashierShift.fromJson(json)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Store Info'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          children: [
            if (_logo != null) Image.file(_logo!),
            TextButton(
              child: Text('Upload Logo'),
              onPressed: _pickLogo,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: Colors.blue,
              ),
            ),
            TextFormField(
              controller: _shopNameController,
              decoration: InputDecoration(labelText: 'Shop Name'),
            ),
            TextFormField(
              controller: _shopAddressController,
              decoration: InputDecoration(labelText: 'Shop Address'),
            ),
            TextFormField(
              controller: _shopTelController,
              decoration: InputDecoration(labelText: 'Tel'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: cashiers.length,
                itemBuilder: (context, index) {
                  final cashier = cashiers[index];
                  final isActive = cashier == activeCashier;
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 4.0),
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green[100] : Colors.white,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Text(
                          cashier,
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isActive ? Colors.red : Colors.green,
                            ),
                            child: Text(isActive ? 'Deactivate' : 'Activate'),
                            onPressed: () async {
                              if (isActive) {
                                _deactivateCashier();
                              } else {
                                await _setActiveCashier(cashier);
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                cashiers.removeAt(index);
                                if (cashier == activeCashier) {
                                  activeCashier = null;
                                  SharedPreferences.getInstance().then((prefs) {
                                    prefs.remove('currentCashier');
                                  });
                                }
                              });
                              _saveCashiers();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _showAddCashierDialog,
              child: Text('Add Cashier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() => runApp(MaterialApp(home: StoreInfoPage()));