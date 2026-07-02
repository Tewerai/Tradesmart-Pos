import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedLanguage = 'English';
  bool _receiveNotifications = true;
  bool _checkForUpdates = true;
  String _selectedDisplayOption = 'Clear Selling'; // Default display option

  bool _printLogo = true; // Default value for print logo
  bool _printReceiptId = true; // Default value for print receipt ID
  String _additionalNotes = ''; // Default value for additional notes
  String _printPosition = 'below'; // Default print position
  bool _hideTotalOnHomepage = false; // Default value

  bool _addPasswordForStock = false; // Default value for add password for stock
  bool _addPasswordForStoreInfo =
      false; // Default value for add password for stock
  bool _addPasswordForSettings =
      false; // Default value for add password for stock
  bool _addPasswordForUploadStock =
      false; // Default value for add password for upload stock
  bool _useHamburgerDisplay = false; // New setting for Hamburger Display
  String _selectedCurrencySymbol = ''; // Default currency symbol
  final TextEditingController _currencyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _currencyController.dispose(); // Dispose of the controller
    super.dispose();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedDisplayOption = prefs.getString('ui') ?? _selectedDisplayOption;
      _printLogo = prefs.getBool('printLogo') ?? _printLogo;
      _printReceiptId = prefs.getBool('printReceiptId') ?? _printReceiptId;
      _additionalNotes = prefs.getString('additionalNotes') ?? _additionalNotes;
      _printPosition = prefs.getString('printPosition') ?? _printPosition;
      _addPasswordForStock =
          prefs.getBool('addPasswordForStock') ?? _addPasswordForStock;
      _addPasswordForStoreInfo =
          prefs.getBool('addPasswordForStoreInfo') ?? _addPasswordForStoreInfo;
      _addPasswordForSettings =
          prefs.getBool('addPasswordForSettings') ?? _addPasswordForSettings;
      _addPasswordForUploadStock = prefs.getBool('addPasswordForUploadStock') ??
          _addPasswordForUploadStock;
      // Load the hamburger display setting
      _useHamburgerDisplay = prefs.getBool('useHamburgerDisplay') ?? false;
      // Load currency symbol
      //_selectedCurrencySymbol = prefs.getString('currencySymbol') ?? _selectedCurrencySymbol;
      _currencyController.text = _selectedCurrencySymbol;
      _hideTotalOnHomepage =
          prefs.getBool('hideTotalOnHomepage') ?? _hideTotalOnHomepage;
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('ui', _selectedDisplayOption);
    await prefs.setBool('printLogo', _printLogo);
    await prefs.setBool('printReceiptId', _printReceiptId);
    await prefs.setString('additionalNotes', _additionalNotes);
    await prefs.setString('printPosition', _printPosition);
    await prefs.setBool('addPasswordForStock', _addPasswordForStock);
    await prefs.setBool('addPasswordForStoreInfo', _addPasswordForStoreInfo);
    await prefs.setBool('addPasswordForSettings', _addPasswordForSettings);
    await prefs.setBool(
        'addPasswordForUploadStock', _addPasswordForUploadStock);
    // Save the hamburger display setting
    await prefs.setBool('useHamburgerDisplay', _useHamburgerDisplay);
    // currency symbol
    await prefs.setString('currencySymbol', _currencyController.text);
    await prefs.setBool('hideTotalOnHomepage', _hideTotalOnHomepage);
  }

  Future<void> _showPasswordDialog(Function(bool) onPasswordCorrect) async {
    TextEditingController passwordController = TextEditingController();
    int _passwordAttempts = 0;

    bool passwordMatched = false;
    while (_passwordAttempts < 3 && !passwordMatched) {
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
                          ),
                        ),
                        if (_passwordAttempts > 0)
                          Text(
                            'Wrong password, ${3 - _passwordAttempts} attempt(s) remaining',
                            style: TextStyle(color: Colors.red),
                          ),
                      ],
                    );
                  },
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop(false); // Set false on cancel
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
                          _passwordAttempts++;
                        });
                        if (_passwordAttempts >= 3) {
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

      if (passwordMatched == false) {
        break;
      }
    }

    if (passwordMatched) {
      onPasswordCorrect(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text(
                'Language',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String?>(
                value: _selectedLanguage,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedLanguage = newValue ?? '';
                  });
                },
                items: <String?>['English', 'Spanish', 'French', 'German']
                    .map<DropdownMenuItem<String?>>((String? value) {
                  return DropdownMenuItem<String?>(
                    value: value,
                    child: Text(value ?? ''),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              Text(
                'Notifications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                title: Text('Receive Notifications'),
                value: _receiveNotifications,
                onChanged: (value) {
                  setState(() {
                    _receiveNotifications = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Receipt Customization',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                title: Text('Print Logo'),
                value: _printLogo,
                onChanged: (value) {
                  setState(() {
                    _printLogo = value!;
                    _saveSettings();
                  });
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Password Management',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                title: Text('Print Receipt ID'),
                value: _printReceiptId,
                onChanged: (value) {
                  setState(() {
                    _printReceiptId = value!;
                    _saveSettings();
                  });
                },
              ),
              SizedBox(height: 20),
              Text(
                'Additional Notes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextFormField(
                initialValue: _additionalNotes,
                decoration: InputDecoration(
                  hintText: 'Enter additional notes here',
                ),
                onChanged: (value) {
                  setState(() {
                    _additionalNotes = value;
                    _saveSettings();
                  });
                },
              ),
              SizedBox(height: 20),
              Text(
                'Print Position',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _printPosition,
                onChanged: (String? newValue) {
                  setState(() {
                    _printPosition = newValue ?? _printPosition;
                    _saveSettings();
                  });
                },
                items: <String>['above', 'below']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              CheckboxListTile(
                title: Text('Add Password for Stock'),
                value: _addPasswordForStock,
                onChanged: (value) async {
                  if (value != _addPasswordForStock) {
                    await _showPasswordDialog((isCorrect) {
                      if (isCorrect) {
                        setState(() {
                          _addPasswordForStock = !_addPasswordForStock;
                          _saveSettings();
                        });
                      }
                    });
                  }
                },
              ),
              SizedBox(height: 20),
              Text(
                'Currency Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextFormField(
                controller: _currencyController, // Use the controller
                decoration: InputDecoration(
                  hintText: 'Enter currency symbol (e.g., \$, €, ₹)',
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedCurrencySymbol = value;
                  });
                },
              ),
              CheckboxListTile(
                title: Text('Add Password for Upload Stock'),
                value: _addPasswordForUploadStock,
                onChanged: (value) async {
                  if (value != _addPasswordForUploadStock) {
                    await _showPasswordDialog((isCorrect) {
                      if (isCorrect) {
                        setState(() {
                          _addPasswordForUploadStock =
                              !_addPasswordForUploadStock;
                          _saveSettings();
                        });
                      }
                    });
                  }
                },
              ),
              SizedBox(height: 20),
              CheckboxListTile(
                title: Text('Add Password for Settings'),
                value: _addPasswordForSettings,
                onChanged: (value) async {
                  if (value != _addPasswordForSettings) {
                    await _showPasswordDialog((isCorrect) {
                      if (isCorrect) {
                        setState(() {
                          _addPasswordForSettings = !_addPasswordForSettings;
                          _saveSettings();
                        });
                      }
                    });
                  }
                },
              ),
              SizedBox(height: 20),
              CheckboxListTile(
                title: const Text('Use Hamburger Display'),
                value: _useHamburgerDisplay,
                onChanged: (value) {
                  setState(() {
                    _useHamburgerDisplay = value!;
                    _saveSettings();
                  });
                },
              ),
              SizedBox(height: 20),
              CheckboxListTile(
                title: Text('Hide Total on Homepage'),
                value: _hideTotalOnHomepage,
                onChanged: (value) {
                  setState(() {
                    _hideTotalOnHomepage = value!;
                    _saveSettings();
                  });
                },
              ),
              SizedBox(height: 20),
              CheckboxListTile(
                title: Text('Add Password for Store Info'),
                value: _addPasswordForStoreInfo,
                onChanged: (value) async {
                  if (value != _addPasswordForStoreInfo) {
                    await _showPasswordDialog((isCorrect) {
                      if (isCorrect) {
                        setState(() {
                          _addPasswordForStoreInfo = !_addPasswordForStoreInfo;
                          _saveSettings();
                        });
                      }
                    });
                  }
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Handle save action
                  _saveSettings();
                  Navigator.pop(context); // Go back to previous screen
                },
                child: Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

