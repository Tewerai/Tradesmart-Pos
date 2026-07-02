import 'package:flutter/material.dart';

class CashierDetailsPage extends StatelessWidget {
  final String cashierName;
  final String phoneNumber;
  final String email;
  final List<Map<String, dynamic>> logs;

  CashierDetailsPage({
    required this.cashierName,
    required this.phoneNumber,
    required this.email,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cashier Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $cashierName', style: TextStyle(fontSize: 18)),
            Text('Phone: $phoneNumber', style: TextStyle(fontSize: 18)),
            if (email.isNotEmpty) Text('Email: $email', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            Text('Logs:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return ListTile(
                    title: Text('Date: ${log['date']}'),
                    subtitle: Text(
                      'Hours: ${log['hours']} Minutes: ${log['minutes']} Seconds: ${log['seconds']}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
