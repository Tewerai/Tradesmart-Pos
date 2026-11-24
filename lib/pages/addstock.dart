import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/io_client.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/add_stock_ai_service.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class AddStockPage extends StatefulWidget {
  @override
  _AddStockPageState createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  // Controllers
  TextEditingController nameController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController stockPriceController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController newCategoryController = TextEditingController();

  // State
  String barcodeResult = '';
  String imgPath = '';
  String selectedCategory = 'Electronics';
  String selectedMeasure = 'Units';
  bool isSaving = false;
  bool isFormValid = false;
  bool trackStock = true;
  bool isOtherCategory = false;
  List<String> categories = [
    'Electronics',
    'Drinks',
    'Grocery',
    'Toiletries',
    'Other Category'
  ];
  String shopId = '';
  String password = '';

  // AI state
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ImagePicker _picker = ImagePicker();
  AddStockAiService? _ai;
  bool _aiBusy = false;

  // Bulk-add queue — populated by photo/voice-multiple
  final List<NewStockItem> _pendingItems = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _getShopId();
    nameController.addListener(_validateForm);
    priceController.addListener(_validateForm);
    stockPriceController.addListener(_validateForm);
    quantityController.addListener(_validateForm);
    newCategoryController.addListener(_validateForm);
    _checkPasswordRequirement();
  }

  Future<void> _checkPasswordRequirement() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool requirePassword = prefs.getBool('addPasswordForStock') ?? false;
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
                        setState(() {
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

  Future<void> _loadCategories() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      List<String>? savedCategories = prefs.getStringList('_categories');
      if (savedCategories != null && savedCategories.isNotEmpty) {
        categories = savedCategories + ['Other Category'];
      }
    });
  }

  Future<void> _getShopId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      shopId = prefs.getString('username') ?? '';
      password = prefs.getString('password') ?? '';
    });
    _ai = AddStockAiService(shopId);
  }

  void _validateForm() {
    setState(() {
      isFormValid = nameController.text.isNotEmpty &&
          priceController.text.isNotEmpty &&
          stockPriceController.text.isNotEmpty &&
          quantityController.text.isNotEmpty &&
          (!isOtherCategory || newCategoryController.text.isNotEmpty);
    });
  }

  Future<void> _scanBarcode() async {
    try {
      String result = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Cancel',
        true,
        ScanMode.BARCODE,
      );
      if (result != -1) {
        setState(() {
          barcodeResult = result;
          _validateForm();
        });
      }
    } catch (e) {
      print('Error scanning barcode: $e');
    }
  }

  // ==========================================================================
  // AI: Voice — single item quick-fill OR multi-item queue
  // ==========================================================================
  Future<void> _startVoiceAdd() async {
    if (_ai == null || _aiBusy) return;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _snack('Microphone permission is required.', error: true);
      return;
    }

    final available = await _speech.initialize();
    if (!available) {
      _snack('Speech recognition not available on this device.', error: true);
      return;
    }

    final transcript = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _VoiceListeningSheet(speech: _speech),
    );

    if (transcript == null || transcript.trim().isEmpty) return;

    setState(() => _aiBusy = true);
    try {
      // Try multi-item first; if only one item returned, fill the form directly
      final items = await _ai!.parseVoiceMultipleItems(transcript.trim());

      if (items.isEmpty) {
        _snack('AI found no products in that command.');
        return;
      }

      if (items.length == 1 && items.first.isComplete) {
        // Single complete item → fill form, let user press Save
        _fillForm(items.first);
        _snack('Form filled from voice. Review and save.');
      } else {
        // Multi or incomplete → queue them for review + bulk save
        setState(() {
          _pendingItems
            ..clear()
            ..addAll(items);
        });
        _openBulkReview();
      }
    } catch (e) {
      _snack('Voice AI failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  // ==========================================================================
  // AI: Photo of receipt / handwritten book
  // ==========================================================================
  Future<void> _scanInventoryPhoto() async {
    if (_ai == null || _aiBusy) return;

    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      _snack('Camera permission is required.', error: true);
      return;
    }

    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (choice == null) return;

    final picked = await _picker.pickImage(
      source: choice,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (picked == null) return;

    setState(() => _aiBusy = true);
    try {
      final items = await _ai!.parseInventoryPhoto(File(picked.path));
      if (items.isEmpty) {
        _snack('AI could not find any products in the image.');
        return;
      }
      setState(() {
        _pendingItems
          ..clear()
          ..addAll(items);
      });
      _openBulkReview();
    } catch (e) {
      _snack('Photo AI failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  // ==========================================================================
  // Fill the form from a single AI item
  // ==========================================================================
  void _fillForm(NewStockItem item) {
    setState(() {
      nameController.text = item.name;
      if (item.price != null) priceController.text = item.price!.toString();
      if (item.stockPrice != null) {
        stockPriceController.text = item.stockPrice!.toString();
      }
      if (item.quantity != null) {
        quantityController.text = item.quantity!.toString();
      }
      if (item.barcode != null && item.barcode!.isNotEmpty) {
        barcodeResult = item.barcode!;
      }
    });
    _validateForm();
  }

  // ==========================================================================
  // Bulk review sheet — for photo/multi-voice; saves everything at once
  // ==========================================================================
  void _openBulkReview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => _BulkReviewSheet(
        items: _pendingItems,
        onSave: _bulkSave,
      ),
    );
  }

  Future<int> _bulkSave(List<NewStockItem> items) async {
    int successCount = 0;
    for (final item in items) {
      try {
        if (item.name.isEmpty ||
            item.price == null ||
            item.stockPrice == null ||
            item.quantity == null) {
          continue;
        }
        final ok = await _saveProductRaw(
          name: item.name,
          price: item.price!,
          stockPrice: item.stockPrice!,
          quantity: item.quantity!.toInt(),
          category: item.category ?? selectedCategory,
          measure: selectedMeasure.toLowerCase(),
          barcode: item.barcode?.isNotEmpty == true
              ? item.barcode!
              : 'product_${Random().nextInt(100000)}',
        );
        if (ok) successCount++;
      } catch (e) {
        debugPrint('Bulk save error for ${item.name}: $e');
      }
    }
    return successCount;
  }

  // ==========================================================================
  // Manual save (existing button)
  // ==========================================================================
  Future<void> _saveProduct() async {
    setState(() => isSaving = true);

    String name = nameController.text.trim();
    double price = double.tryParse(priceController.text.trim()) ?? 0.0;
    double stockPrice =
        double.tryParse(stockPriceController.text.trim()) ?? 0.0;
    int quantity =
        trackStock ? int.tryParse(quantityController.text.trim()) ?? 0 : -1;
    String category =
        isOtherCategory ? newCategoryController.text.trim() : selectedCategory;
    String measureLowerCase = selectedMeasure.toLowerCase();

    try {
      final ok = await _saveProductRaw(
        name: name,
        price: price,
        stockPrice: stockPrice,
        quantity: quantity,
        category: category,
        measure: measureLowerCase,
        barcode: barcodeResult.isNotEmpty
            ? barcodeResult
            : 'product_${Random().nextInt(100000)}',
      );

      if (!ok) {
        _snack('Failed to save product');
        return;
      }

      await _saveImageWithProductName(name);

      if (isOtherCategory && !categories.contains(category)) {
        setState(() {
          categories.insert(categories.length - 1, category);
        });
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('_categories',
            categories.where((c) => c != 'Other Category').toList());
      }

      nameController.clear();
      priceController.clear();
      stockPriceController.clear();
      quantityController.clear();
      newCategoryController.clear();
      setState(() {
        barcodeResult = '';
        selectedCategory = 'Electronics';
        selectedMeasure = 'Units';
        trackStock = true;
        isFormValid = false;
        isOtherCategory = false;
      });
      _snack('Product saved successfully');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<bool> _saveProductRaw({
    required String name,
    required double price,
    required double stockPrice,
    required int quantity,
    required String category,
    required String measure,
    required String barcode,
  }) async {
    final requestData = {
      'shopId': shopId,
      'name': name,
      'price': price,
      'stockPrice': stockPrice,
      'quantity': quantity,
      'category': category,
      'measuredIn': measure,
      'barcode': barcode,
      'trackStock': true,
    };

    var client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    var ioClient = IOClient(client);

    final response = await ioClient.post(
      Uri.parse('https://aphel.blueichor.org/apis/saveProduct.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestData),
    );

    if (response.statusCode != 200) return false;
    final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
    if (jsonResponse['success'] != true) return false;

    // Refresh local cache
    try {
      final loginResponse = await ioClient.post(
        Uri.parse('https://aphel.blueichor.org/log2.php'),
        body: {'username': shopId, 'password': password},
      );
      if (loginResponse.statusCode == 200) {
        final jsondata = json.decode(loginResponse.body);
        if (jsondata['success']) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'categories', json.encode(jsondata['categories']));
          await prefs.setString('products', json.encode(jsondata['products']));
          await prefs.setString('prices', json.encode(jsondata['prices']));
          await prefs.setString('codes', json.encode(jsondata['codes']));
          await prefs.setString('measure', json.encode(jsondata['measure']));
          await prefs.setString(
              'quantities', json.encode(jsondata['quantities']));
        }
      }
    } catch (_) {
      // Cache refresh failure should not block the save
    }
    return true;
  }

  // ==========================================================================
  // Image handling (unchanged)
  // ==========================================================================
  Future<void> _addPicture() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => imgPath = pickedFile.path);
        await _saveImageWithProductName(nameController.text.trim());
      }
    } catch (e) {
      print('Error capturing picture: $e');
    }
  }

  Future<void> _saveImageWithProductName(String productName) async {
    try {
      if (imgPath.isNotEmpty && productName.isNotEmpty) {
        final directory = await getApplicationDocumentsDirectory();
        final newImagePath = '${directory.path}/$productName.jpg';
        final imageFile = File(imgPath);
        await imageFile.copy(newImagePath);
        print("Image saved at: $newImagePath");
      }
    } catch (e) {
      print("Error saving image: $e");
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    stockPriceController.dispose();
    quantityController.dispose();
    newCategoryController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Stock'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: _aiBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.mic),
            onPressed: _aiBusy ? null : _startVoiceAdd,
            tooltip: 'Voice add',
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _aiBusy ? null : _scanInventoryPhoto,
            tooltip: 'Scan receipt or handwritten book',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_aiBusy) const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Product Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Price'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: stockPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock Price'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                  const SizedBox(height: 16),
                  isOtherCategory
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: newCategoryController,
                                decoration: const InputDecoration(
                                    labelText: 'New Category'),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel),
                              onPressed: () {
                                setState(() {
                                  isOtherCategory = false;
                                  newCategoryController.clear();
                                  selectedCategory = 'Electronics';
                                });
                                _validateForm();
                              },
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Text('Category: '),
                            DropdownButton<String>(
                              value: selectedCategory,
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedCategory = newValue!;
                                  isOtherCategory =
                                      newValue == 'Other Category';
                                });
                                _validateForm();
                              },
                              items: categories
                                  .map<DropdownMenuItem<String>>(
                                      (String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Measured In: '),
                      DropdownButton<String>(
                        value: selectedMeasure,
                        onChanged: (String? newValue) {
                          setState(() => selectedMeasure = newValue!);
                          _validateForm();
                        },
                        items: <String>[
                          'Units',
                          'Kgs',
                          'Metres',
                          'Centi-Metres',
                          'Pounds'
                        ].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: trackStock,
                        onChanged: (bool? newValue) {
                          setState(() => trackStock = newValue ?? false);
                          _validateForm();
                        },
                      ),
                      const Text('Track Stock'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _addPicture,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Add Picture'),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.25),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scanBarcode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Barcode: $barcodeResult'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isFormValid && !isSaving ? _saveProduct : null,
                    child: isSaving
                        ? const CircularProgressIndicator()
                        : const Text('Save Product'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// Voice listening sheet (same as Update Stock)
// ==========================================================================
class _VoiceListeningSheet extends StatefulWidget {
  final stt.SpeechToText speech;
  const _VoiceListeningSheet({required this.speech});
  @override
  State<_VoiceListeningSheet> createState() => _VoiceListeningSheetState();
}

class _VoiceListeningSheetState extends State<_VoiceListeningSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  String _transcript = '';
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _begin();
  }

  Future<void> _begin() async {
    setState(() => _listening = true);
    await widget.speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _transcript = r.recognizedWords);
        if (r.finalResult) _finish();
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  Future<void> _finish() async {
    await widget.speech.stop();
    if (!mounted) return;
    final text = _transcript.trim();
    Navigator.pop(context, text.isEmpty ? null : text);
  }

  void _cancel() async {
    await widget.speech.stop();
    if (!mounted) return;
    Navigator.pop(context, null);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _transcript.isEmpty ? 'Listening…' : 'Heard:',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final scale = 1.0 + _pulseCtrl.value * 0.35;
                final opacity = 0.4 * (1.0 - _pulseCtrl.value);
                return SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 130 * scale,
                        height: 130 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.withOpacity(opacity),
                        ),
                      ),
                      Container(
                        width: 110,
                        height: 110,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                        ),
                        child: const Icon(Icons.mic,
                            color: Colors.white, size: 52),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _transcript.isEmpty
                    ? 'Try: "Add 5 cokes, price 2, cost 1.20"'
                    : '"$_transcript"',
                key: ValueKey(_transcript),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _transcript.isEmpty ? 13 : 17,
                  color: _transcript.isEmpty ? Colors.grey : null,
                  fontStyle: _transcript.isEmpty ? FontStyle.italic : null,
                  fontWeight: _transcript.isEmpty ? null : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Cancel',
                      style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton.icon(
                  onPressed: _listening ? _finish : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// Bulk review sheet — editable before saving all
// ==========================================================================
class _BulkReviewSheet extends StatefulWidget {
  final List<NewStockItem> items;
  final Future<int> Function(List<NewStockItem>) onSave;
  const _BulkReviewSheet({required this.items, required this.onSave});
  @override
  State<_BulkReviewSheet> createState() => _BulkReviewSheetState();
}

class _BulkReviewSheetState extends State<_BulkReviewSheet> {
  late List<_EditableItem> _edits;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _edits = widget.items.map((i) => _EditableItem.from(i)).toList();
  }

  @override
  void dispose() {
    for (final e in _edits) {
      e.dispose();
    }
    super.dispose();
  }

  int get _validCount => _edits.where((e) => e.toItem() != null).length;

  Future<void> _save() async {
    final valid = _edits
        .map((e) => e.toItem())
        .whereType<NewStockItem>()
        .toList();
    if (valid.isEmpty) return;

    setState(() => _saving = true);
    try {
      final saved = await widget.onSave(valid);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved $saved of ${valid.length} product(s)'),
        backgroundColor: saved > 0 ? Colors.green : Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Review AI Extracted Products',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      '$_validCount of ${_edits.length} ready to save',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.all(12),
              itemCount: _edits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _editCard(_edits[i], i),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_saving || _validCount == 0) ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving
                      ? 'Saving…'
                      : 'Save $_validCount Product${_validCount == 1 ? '' : 's'}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editCard(_EditableItem e, int index) {
    final valid = e.toItem() != null;
    return Card(
      color: valid ? null : Colors.red.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: e.name,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    errorText: e.name.text.trim().isEmpty ? 'Required' : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _edits.removeAt(index);
                  });
                },
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: e.price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Sell price',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: e.stockPrice,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cost price',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: e.quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: e.barcode,
                  decoration: const InputDecoration(
                    labelText: 'Barcode (optional)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _EditableItem {
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController stockPrice;
  final TextEditingController quantity;
  final TextEditingController barcode;

  _EditableItem({
    required this.name,
    required this.price,
    required this.stockPrice,
    required this.quantity,
    required this.barcode,
  });

  factory _EditableItem.from(NewStockItem i) => _EditableItem(
        name: TextEditingController(text: i.name),
        price: TextEditingController(
            text: i.price?.toString() ?? ''),
        stockPrice: TextEditingController(
            text: i.stockPrice?.toString() ?? ''),
        quantity: TextEditingController(
            text: i.quantity?.toString() ?? ''),
        barcode: TextEditingController(text: i.barcode ?? ''),
      );

  NewStockItem? toItem() {
    final n = name.text.trim();
    if (n.isEmpty) return null;
    final p = double.tryParse(price.text.trim());
    final s = double.tryParse(stockPrice.text.trim());
    final q = double.tryParse(quantity.text.trim());
    if (p == null || s == null || q == null) return null;
    return NewStockItem(
      name: n,
      price: p,
      stockPrice: s,
      quantity: q,
      barcode: barcode.text.trim().isEmpty ? null : barcode.text.trim(),
    );
  }

  void dispose() {
    name.dispose();
    price.dispose();
    stockPrice.dispose();
    quantity.dispose();
    barcode.dispose();
  }
}