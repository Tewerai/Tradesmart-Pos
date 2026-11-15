import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock.dart';
import '../services/stock_api.dart';

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
    qtyDelta = TextEditingController(); // blank = delta input
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
  bool _loading = true;
  String? _error;
  List<StockProduct> _products = [];
  final Map<int, _RowState> _rows = {};

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    for (final r in _rows.values) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final shopid = prefs.getString('username') ?? '';
    _api = StockApi(shopid);
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
      // Reset editors to current values (except qty delta which stays empty)
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
      builder: (_) => _SoldSheet(
        api: _api!,
        product: p,
      ),
    );
  }

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
        final newName = row.name.text.trim().isEmpty ? product.name : row.name.text.trim();
        final newPrice = double.tryParse(row.price.text.trim()) ?? product.price;
        final newStock = double.tryParse(row.stockPrice.text.trim()) ?? product.stockPrice;

        // 1) If current is negative: ask override vs add
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

        // 2) If delta is negative and current >= 0: ask Sold/Lost
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
        content: const Text('Negative quantity entered. Choose how it left inventory.'),
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
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Reload',
          ),
        ],
      ),
      body: Column(
        children: [
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
// One product card
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
              ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          _chip('Stock', '\$${product.stockPrice.toStringAsFixed(2)}', Colors.orange),
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
            tooltip: 'Cancel',
          ),
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
          keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
// Sold-today bottom sheet
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
    setState(() { _soldLoading = true; });
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
    setState(() { _ordersLoading = true; });
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
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                              ? MaterialStateProperty.all(Colors.yellow.withOpacity(0.25))
                              : null,
                          cells: [
                            DataCell(Text(o.orderNumber)),
                            DataCell(Text(o.time)),
                            DataCell(Text(o.productName,
                                style: o.highlight
                                    ? const TextStyle(fontWeight: FontWeight.bold)
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