import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class FiscalDayPage extends StatefulWidget {
  const FiscalDayPage({Key? key}) : super(key: key);

  @override
  State<FiscalDayPage> createState() => _FiscalDayPageState();
}

class _FiscalDayPageState extends State<FiscalDayPage> {
  // ---- Config ----
  static const String fiscalServiceUrl =
      'https://zimra-fiscalisation.blueichor.org';
  static const String sharedSecret = '16b98824b46b9ff18661dcdb1cad8';

  bool zimraEnabled = false;
  bool isLoading = false;
  bool isOpening = false;
  bool isClosing = false;
  bool isChecking = false;

  String currentStatus = 'Unknown';
  String? lastAction;
  String? lastActionTime;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      zimraEnabled = prefs.getBool('zimraEnabled') ?? false;
      lastAction = prefs.getString('fiscalLastAction');
      lastActionTime = prefs.getString('fiscalLastActionTime');
    });
    // Auto-check status on load
    if (zimraEnabled) {
      _checkStatus();
    }
  }

  Future<void> _saveLastAction(String action) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    await prefs.setString('fiscalLastAction', action);
    await prefs.setString('fiscalLastActionTime', now);
    setState(() {
      lastAction = action;
      lastActionTime = now;
    });
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ---- Check Status Endpoint ----
  Future<void> _checkStatus() async {
    if (!zimraEnabled) return;

    setState(() => isChecking = true);

    try {
      final url = Uri.parse('$fiscalServiceUrl/status');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Fiscal-Token': sharedSecret,
        },
      ).timeout(const Duration(seconds: 30));

      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (response.statusCode == 200 && decoded['success'] == true) {
        final statusData = decoded['status'];
        setState(() {
          currentStatus = statusData['fiscalDayStatus'] ?? 'Unknown';
        });
      } else {
        setState(() => currentStatus = 'Error: ${decoded['message']}');
      }
    } catch (e) {
      setState(() => currentStatus = 'Connection Error');
    } finally {
      setState(() => isChecking = false);
    }
  }

  Future<void> _callEndpoint(String endpoint, {required String label}) async {
    if (!zimraEnabled) {
      _toast('ZIMRA is disabled. Turn it on to use fiscal day actions.',
          Colors.orange);
      return;
    }

    setState(() {
      isLoading = true;
      if (endpoint == '/open-day') isOpening = true;
      if (endpoint == '/close-day') isClosing = true;
    });

    try {
      final url = Uri.parse('$fiscalServiceUrl$endpoint');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Fiscal-Token': sharedSecret,
        },
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 60));

      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (response.statusCode == 200 && decoded['success'] == true) {
        _toast('$label successful', Colors.green);
        await _saveLastAction(label);
        await _checkStatus(); // Auto-refresh status after success
      } else {
        final msg = decoded['message'] ?? 'HTTP ${response.statusCode}';
        final explain = decoded['explain'];
        _toast('$label failed: $msg', Colors.red);
        if (explain != null) {
          _showExplainDialog('$label failed', explain.toString());
        }
        await _checkStatus(); // Auto-refresh on failure too
      }
    } catch (e) {
      _toast('$label error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isOpening = false;
          isClosing = false;
        });
      }
    }
  }

  void _showExplainDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      backgroundColor: color,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  Future<void> _handleOpenDay() async {
    final ok = await _confirm(
      'Open Fiscal Day',
      'This will start a new fiscal day with ZIMRA.\n\n'
          'Do this at the start of your business day, before taking sales.',
    );
    if (!ok) return;
    await _callEndpoint('/open-day', label: 'Open day');
  }

  Future<void> _handleCloseDay() async {
    final ok = await _confirm(
      'Close Fiscal Day',
      'This will close the current fiscal day with ZIMRA.\n\n'
          'Do this at the end of your business day, after all sales are uploaded.\n\n'
          'You will NOT be able to submit new receipts until you open a new day.',
    );
    if (!ok) return;
    await _callEndpoint('/close-day', label: 'Close day');
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiscal Day'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isChecking ? null : _checkStatus,
            tooltip: 'Check Status',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(
                  zimraEnabled ? Icons.check_circle : Icons.cancel,
                  color: zimraEnabled ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  zimraEnabled ? 'ZIMRA' : 'OFF',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: zimraEnabled ? Colors.green : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadState,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Live Status Card ----
            Card(
              color: currentStatus == 'FiscalDayOpened'
                  ? Colors.green[50]
                  : currentStatus == 'FiscalDayClosed'
                      ? Colors.grey[200]
                      : Colors.orange[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: currentStatus == 'FiscalDayOpened'
                      ? Colors.green
                      : currentStatus == 'FiscalDayClosed'
                          ? Colors.grey
                          : Colors.orange,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Current ZIMRA Status',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    if (isChecking)
                      const CircularProgressIndicator()
                    else
                      Text(
                        currentStatus,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: currentStatus == 'FiscalDayOpened'
                              ? Colors.green[800]
                              : currentStatus == 'FiscalDayClosed'
                                  ? Colors.grey[800]
                                  : Colors.orange[800],
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: isChecking ? null : _checkStatus,
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Refresh Status'),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ---- Info banner ----
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Open the fiscal day at the start of business, and close it at the end of the day. '
                      'Closing a day finalises all submitted receipts with ZIMRA.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ---- Open Day card ----
            _buildActionCard(
              title: 'Open Fiscal Day',
              subtitle:
                  'Begins a new fiscal day. Required before submitting receipts.',
              icon: Icons.wb_sunny_outlined,
              color: Colors.green,
              buttonLabel: 'OPEN DAY',
              isLoading: isOpening,
              onPressed: isLoading ? null : _handleOpenDay,
            ),

            const SizedBox(height: 16),

            // ---- Close Day card ----
            _buildActionCard(
              title: 'Close Fiscal Day',
              subtitle:
                  'Ends the current fiscal day. No further receipts can be submitted until a new day is opened.',
              icon: Icons.nightlight_round,
              color: Colors.deepOrange,
              buttonLabel: 'CLOSE DAY',
              isLoading: isClosing,
              onPressed: isLoading ? null : _handleCloseDay,
            ),

            const SizedBox(height: 24),

            // ---- Last action ----
            if (lastAction != null)
              Card(
                color: Colors.grey[100],
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('Last action: $lastAction'),
                  subtitle: Text(lastActionTime ?? ''),
                ),
              ),

            const SizedBox(height: 24),

            // ---- Troubleshooting tip ----
            const Text(
              'Tips:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              '• If a sale fails with "FiscalDayOpened", the day is already open — you can continue selling.\n'
              '• If a sale fails with "FiscalDayNotOpened", open the day first.\n'
              '• ZIMRA usually processes a close-day request within a few seconds.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String buttonLabel,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(icon, size: 18),
                label: Text(isLoading ? 'WORKING…' : buttonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}