import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/stock.dart';
import '../services/stock_api.dart';
import 'services/deepseek_service.dart';

class UpdateStockPage extends StatefulWidget {
  const UpdateStockPage({super.key});
  @override
  State<UpdateStockPage> createState() => _UpdateStockPageState();
}

class _RowState {
  bool editing = false;
  late final TextEditingController name;
  late final TextEditingController qtyDelta;
  late final TextEditingController price;
  late final TextEditingController stockPrice;

  _RowState(StockProduct p) {
    name = TextEditingController(text: p.name);
    qtyDelta = TextEditingController();
    price = TextEditingController(text: p.price.toString());
    stockPrice = TextEditingController(text: p.stockPrice.toString());
  }

  void dispose() {
    name.dispose();
    qtyDelta.dispose();
    price.dispose();
    stockPrice.dispose();
  }
}

class _UpdateStockPageState extends State<UpdateStockPage> {
  StockApi? _api;
  DeepSeekService? _ai;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _aiBusy = false;
  String? _error;
  List<StockProduct> _products = [];
  final Map<int, _RowState> _rows = {};
  String password = '';

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _checkPasswordRequirement();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    for (final r in _rows.values) {
      r.dispose();
    }
    _speech.stop();
    super.dispose();
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

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final shopid = prefs.getString('username') ?? '';
    _api = StockApi(shopid);
    _ai = DeepSeekService(shopid);
    await _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api!.list();
      _setProducts(list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setProducts(List<StockProduct> list) {
    for (final r in _rows.values) {
      r.dispose();
    }
    _rows.clear();
    for (final p in list) {
      _rows[p.id] = _RowState(p);
    }
    setState(() => _products = list);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final list = value.trim().isEmpty
            ? await _api!.list()
            : await _api!.search(value.trim());
        _setProducts(list);
      } catch (e) {
        _snack('Search failed: $e', error: true);
      }
    });
  }

  void _toggleEdit(StockProduct p, bool edit) {
    final row = _rows[p.id];
    if (row == null) return;
    if (edit) {
      row.name.text = p.name;
      row.price.text = p.price.toString();
      row.stockPrice.text = p.stockPrice.toString();
      row.qtyDelta.clear();
    }
    setState(() => row.editing = edit);
  }

  Future<void> _delete(StockProduct p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${p.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api!.delete(p.id);
      _snack('Product deleted.');
      await _load();
    } catch (e) {
      _snack('Delete failed: $e', error: true);
    }
  }

  Future<void> _openSoldSheet(StockProduct p) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => _SoldSheet(api: _api!, product: p),
    );
  }

  // ==========================================================================
  // AI: Voice
  // ==========================================================================
  Future<void> _startVoiceCommand() async {
    if (_ai == null || _aiBusy) return;

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
      final items = await _ai!.parseTextCommand(transcript.trim(), _products);
      if (!mounted) return;
      await _showReviewAndApply(items, source: 'Voice');
    } catch (e) {
      _snack('AI failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  // ==========================================================================
  // AI: Receipt photo
  // ==========================================================================
  Future<void> _scanReceipt() async {
    if (_ai == null || _aiBusy) return;

    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;

    setState(() => _aiBusy = true);
    try {
      final items = await _ai!.parseReceiptImage(File(picked.path));
      if (!mounted) return;
      await _showReviewAndApply(items, source: 'Receipt');
    } catch (e) {
      _snack('Receipt scan failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  // ==========================================================================
  // AI: Review popup + apply
  // ==========================================================================
  Future<void> _showReviewAndApply(List<StockUpdateItem> items,
      {required String source}) async {
    if (items.isEmpty) {
      _snack('AI found no updates to apply.');
      return;
    }

    // Fresh full product list for matching (search may have filtered _products)
    List<StockProduct> all;
    try {
      all = await _api!.list();
    } catch (e) {
      _snack('Could not load products for matching: $e', error: true);
      return;
    }

    final matches = <_MatchResult>[];
    for (final item in items) {
      matches.add(_MatchResult(
        item: item,
        product: _matchProduct(item.product, all),
      ));
    }

    final payloads = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AiReviewSheet(
        results: matches,
        source: source,
      ),
    );

    if (payloads == null || payloads.isEmpty) return;

    setState(() => _saving = true);
    try {
      final count = await _api!.batchUpdate(payloads);
      _snack('$source applied: $count product(s) updated.');
      await _load();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  StockProduct? _matchProduct(String aiName, List<StockProduct> all) {
    final lower = aiName.toLowerCase().trim();
    if (lower.isEmpty) return null;

    for (final p in all) {
      if (p.name.toLowerCase() == lower) return p;
    }
    for (final p in all) {
      final pn = p.name.toLowerCase();
      if (pn.contains(lower) || lower.contains(pn)) return p;
    }
    final aiTokens = lower
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1)
        .toSet();
    StockProduct? best;
    int bestScore = 0;
    for (final p in all) {
      final pTokens = p.name
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((t) => t.length > 1)
          .toSet();
      final overlap = aiTokens.intersection(pTokens).length;
      if (overlap > bestScore) {
        bestScore = overlap;
        best = p;
      }
    }
    return bestScore > 0 ? best : null;
  }

  // ==========================================================================
  // Existing manual Update All
  // ==========================================================================
  Future<void> _updateAll() async {
    if (_saving) return;
    final editing = _rows.entries.where((e) => e.value.editing).toList();
    if (editing.isEmpty) {
      _snack('Nothing to update — tap Edit on a row first.');
      return;
    }

    setState(() => _saving = true);
    final updates = <Map<String, dynamic>>[];
    try {
      for (final entry in editing) {
        final id = entry.key;
        final row = entry.value;
        final product = _products.firstWhere((p) => p.id == id);

        final currentQty = product.quantity;
        final delta = double.tryParse(row.qtyDelta.text.trim()) ?? 0;
        final newName =
            row.name.text.trim().isEmpty ? product.name : row.name.text.trim();
        final newPrice =
            double.tryParse(row.price.text.trim()) ?? product.price;
        final newStock =
            double.tryParse(row.stockPrice.text.trim()) ?? product.stockPrice;

        double finalQty;
        if (currentQty < 0) {
          final override = await _askYesNo(
            'Current quantity for "$newName" is ${currentQty.toStringAsFixed(0)}. '
            'Treat ${delta.toStringAsFixed(0)} as the new total?',
          );
          finalQty = override ? delta : currentQty + delta;
        } else {
          finalQty = currentQty + delta;
        }

        String? reason;
        if (delta < 0 && currentQty >= 0) {
          final isLoss = await _askSoldOrLost(newName);
          if (isLoss) reason = 'loss';
        }

        updates.add({
          'id': id,
          'name': newName,
          'quantity': finalQty,
          'price': newPrice,
          'stock_price': newStock,
          'previousQua': currentQty,
          'difference': delta,
          if (reason != null) 'reason': reason,
        });
      }

      final count = await _api!.batchUpdate(updates);
      _snack('Updated $count product(s).');
      await _load();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _askYesNo(String message) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Quantity'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, add')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, override')),
        ],
      ),
    );
    return r ?? false;
  }

  Future<bool> _askSoldOrLost(String name) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('How was "$name" reduced?'),
        content:
            const Text('Negative quantity entered. Choose how it left inventory.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Sold')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lost'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Stock'),
        actions: [
          IconButton(
            icon: _aiBusy
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.mic),
            onPressed: _aiBusy ? null : _startVoiceCommand,
            tooltip: 'Voice update',
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _aiBusy ? null : _scanReceipt,
            tooltip: 'Scan receipt',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Reload',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_aiBusy)
            const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search products…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _updateAll,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving…' : 'Update All Products'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(child: Text('No products found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = _products[i];
        final row = _rows[p.id]!;
        return _ProductCard(
          product: p,
          row: row,
          onEdit: () => _toggleEdit(p, true),
          onCancel: () => _toggleEdit(p, false),
          onDelete: () => _delete(p),
          onDoubleTap: () => _openSoldSheet(p),
        );
      },
    );
  }
}

// ==========================================================================
// Product card (unchanged)
// ==========================================================================
class _ProductCard extends StatelessWidget {
  final StockProduct product;
  final _RowState row;
  final VoidCallback onEdit, onCancel, onDelete, onDoubleTap;

  const _ProductCard({
    required this.product,
    required this.row,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Card(
        elevation: row.editing ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: row.editing
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: row.editing ? _editView(context) : _viewMode(context),
        ),
      ),
    );
  }

  Widget _viewMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(product.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          _chip('Available', product.quantity.toStringAsFixed(0),
              product.quantity < 0 ? Colors.red : Colors.blue),
          const SizedBox(width: 8),
          _chip('Sell', '\$${product.price.toStringAsFixed(2)}', Colors.green),
          const SizedBox(width: 8),
          _chip('Stock', '\$${product.stockPrice.toStringAsFixed(2)}',
              Colors.orange),
        ]),
        const SizedBox(height: 4),
        Text('Double-tap for sold details',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _editView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(
            child: Text('Editing',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: onCancel,
              tooltip: 'Cancel'),
        ]),
        const SizedBox(height: 4),
        TextField(
          controller: row.name,
          decoration: const InputDecoration(
            labelText: 'Product name',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: row.qtyDelta,
          keyboardType:
              const TextInputType.numberWithOptions(signed: true, decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
          ],
          decoration: InputDecoration(
            labelText: 'Quantity change (+/-)',
            helperText: 'Current: ${product.quantity.toStringAsFixed(0)}',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: row.price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Sell price',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: row.stockPrice,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Stock price',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// Voice listening sheet — Siri-style
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
              width: 40, height: 4,
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
                  width: 180, height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 130 * scale, height: 130 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(opacity),
                        ),
                      ),
                      Container(
                        width: 110, height: 110,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
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
                    ? 'Try: "Add 5 cokes" or "Set bread price to 2.50"'
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
// AI review sheet — confirm before applying
// ==========================================================================
class _MatchResult {
  final StockUpdateItem item;
  final StockProduct? product;
  _MatchResult({required this.item, required this.product});
}

class _AiReviewSheet extends StatefulWidget {
  final List<_MatchResult> results;
  final String source;
  const _AiReviewSheet({required this.results, required this.source});
  @override
  State<_AiReviewSheet> createState() => _AiReviewSheetState();
}

class _AiReviewSheetState extends State<_AiReviewSheet> {
  late final List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.results
        .map((r) => r.product != null) // pre-select matched only
        .toList();
  }

  List<Map<String, dynamic>> _buildPayloads() {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < widget.results.length; i++) {
      if (!_selected[i]) continue;
      final r = widget.results[i];
      final p = r.product;
      if (p == null) continue;
      final newQty = r.item.resolveQuantity(p.quantity) ?? p.quantity;
      out.add({
        'id': p.id,
        'name': p.name,
        'quantity': newQty,
        'price': r.item.price ?? p.price,
        'stock_price': r.item.stockPrice ?? p.stockPrice,
      });
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selected.where((s) => s).length;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40, height: 4,
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
                      Text('${widget.source} — Review Updates',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        '$selectedCount of ${widget.results.length} selected',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.all(12),
                itemCount: widget.results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _row(i),
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
                    onPressed: selectedCount == 0
                        ? null
                        : () => Navigator.pop(context, _buildPayloads()),
                    icon: const Icon(Icons.check_circle),
                    label: Text('Apply $selectedCount Update${selectedCount == 1 ? '' : 's'}'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(int i) {
    final r = widget.results[i];
    final p = r.product;
    final matched = p != null;

    return Card(
      color: matched ? null : Colors.red.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _selected[i],
              onChanged: matched
                  ? (v) => setState(() => _selected[i] = v ?? false)
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        matched ? p.name : r.item.product,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (matched)
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 18)
                    else
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 18),
                  ]),
                  if (!matched)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'No matching product in stock — skipped',
                        style: TextStyle(
                            fontSize: 12, color: Colors.red[700]),
                      ),
                    ),
                  if (matched) ...[
                    if (r.item.quantityChange != null ||
                        r.item.quantitySet != null) ...[
                      const SizedBox(height: 6),
                      _changeLine(
                        'Quantity',
                        p.quantity.toStringAsFixed(0),
                        (r.item.resolveQuantity(p.quantity) ?? p.quantity)
                            .toStringAsFixed(0),
                        _deltaLabel(r.item),
                      ),
                    ],
                    if (r.item.price != null) ...[
                      const SizedBox(height: 4),
                      _changeLine(
                        'Price',
                        '\$${p.price.toStringAsFixed(2)}',
                        '\$${r.item.price!.toStringAsFixed(2)}',
                        null,
                      ),
                    ],
                    if (r.item.stockPrice != null) ...[
                      const SizedBox(height: 4),
                      _changeLine(
                        'Cost',
                        '\$${p.stockPrice.toStringAsFixed(2)}',
                        '\$${r.item.stockPrice!.toStringAsFixed(2)}',
                        null,
                      ),
                    ],
                  ],
                  if (matched &&
                      r.item.quantityChange == null &&
                      r.item.quantitySet == null &&
                      r.item.price == null &&
                      r.item.stockPrice == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'No changes requested for this product',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _deltaLabel(StockUpdateItem item) {
    if (item.quantityChange != null) {
      final d = item.quantityChange!;
      return d >= 0 ? '+${d.toStringAsFixed(0)}' : d.toStringAsFixed(0);
    }
    return null;
  }

  Widget _changeLine(String label, String from, String to, String? badge) {
    return Row(children: [
      SizedBox(
        width: 70,
        child: Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ),
      Text(from,
          style: const TextStyle(
              fontSize: 13, decoration: TextDecoration.lineThrough)),
      const SizedBox(width: 6),
      const Icon(Icons.arrow_forward, size: 12),
      const SizedBox(width: 6),
      Text(to,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold)),
      if (badge != null) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: badge.startsWith('-')
                ? Colors.red.withOpacity(0.15)
                : Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: badge.startsWith('-') ? Colors.red : Colors.green,
            ),
          ),
        ),
      ],
    ]);
  }
}

// ==========================================================================
// Sold-today bottom sheet (unchanged)
// ==========================================================================
class _SoldSheet extends StatefulWidget {
  final StockApi api;
  final StockProduct product;
  const _SoldSheet({required this.api, required this.product});
  @override
  State<_SoldSheet> createState() => _SoldSheetState();
}

class _SoldSheetState extends State<_SoldSheet> {
  DateTime _date = DateTime.now();
  double? _soldCount;
  bool _soldLoading = false;
  bool _fullOrder = false;
  List<OrderDetailRow> _orders = [];
  bool _ordersLoading = false;
  bool _showInDepth = false;

  @override
  void initState() {
    super.initState();
    _fetchSold();
  }

  Future<void> _fetchSold() async {
    setState(() => _soldLoading = true);
    try {
      final n = await widget.api.soldCount(widget.product.name, _date);
      if (!mounted) return;
      setState(() { _soldCount = n; _soldLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _soldCount = null; _soldLoading = false; });
    }
  }

  Future<void> _fetchOrders() async {
    setState(() => _ordersLoading = true);
    try {
      final rows = await widget.api.orderDetails(
          widget.product.name, _date, fullOrder: _fullOrder);
      if (!mounted) return;
      setState(() { _orders = rows; _ordersLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _orders = []; _ordersLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(widget.product.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(DateFormat('yyyy-MM-dd').format(_date)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) {
                  setState(() => _date = picked);
                  _fetchSold();
                  if (_showInDepth) _fetchOrders();
                }
              },
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.trending_up, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _soldLoading
                        ? const LinearProgressIndicator()
                        : Text(
                            _soldCount == null
                                ? 'Could not load'
                                : '${_soldCount!.toStringAsFixed(0)} sold on '
                                    '${DateFormat('yyyy-MM-dd').format(_date)}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            if (!_showInDepth)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.list_alt),
                  label: const Text('View In-Depth'),
                  onPressed: () {
                    setState(() => _showInDepth = true);
                    _fetchOrders();
                  },
                ),
              )
            else ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _fullOrder,
                onChanged: (v) {
                  setState(() => _fullOrder = v == true);
                  _fetchOrders();
                },
                title: const Text('View full order (all products)'),
              ),
              const SizedBox(height: 4),
              if (_ordersLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_orders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No orders for this product on this date.',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Order#')),
                      DataColumn(label: Text('Time')),
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Qty')),
                    ],
                    rows: <DataRow>[
                      for (final o in _orders)
                        DataRow(
                          color: o.highlight
                              ? MaterialStateProperty.all(
                                  Colors.yellow.withOpacity(0.25))
                              : null,
                          cells: [
                            DataCell(Text(o.orderNumber)),
                            DataCell(Text(o.time)),
                            DataCell(Text(o.productName,
                                style: o.highlight
                                    ? const TextStyle(
                                        fontWeight: FontWeight.bold)
                                    : null)),
                            DataCell(Text(o.quantity.toStringAsFixed(0))),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}