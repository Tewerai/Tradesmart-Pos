import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Import JSON support
import 'package:http/http.dart' as http;

void main() => runApp(MaterialApp(home: ExpensePage()));

class ExpensePage extends StatefulWidget {
  @override
  _ExpensePageState createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final _expenseNameController = TextEditingController();
  final _expensePriceController = TextEditingController();
  List<Map<String, dynamic>> expenses = [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    String? expensesJson = prefs.getString('expenses');
    if (expensesJson != null) {
      List<dynamic> jsonList = json.decode(expensesJson);
      expenses = List<Map<String, dynamic>>.from(jsonList);
      for (var i = 0; i < expenses.length; i++) {
        if (expenses[i]['price'] == null || expenses[i]['price'] == '') {
          expenses[i]['price'] = 0;
        }
      }
      setState(() {
        expenses = expenses;
      });
    }
  }

  Future<void> _saveExpense() async {
    final prefs = await SharedPreferences.getInstance();
    String name = _expenseNameController.text;
    String price = _expensePriceController.text;
    if (price == '') price = '0';
    String date = DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now());

    Map<String, dynamic> newExpense = {
      'name': name,
      'price': price,
      'date': date,
    };

    setState(() {
      expenses.add(newExpense);
    });

    // Serialize and save the updated expenses list to SharedPreferences
    String expensesJson = json.encode(expenses);
    await prefs.setString('expenses', expensesJson);

    print('expesnejson : $expensesJson');

    // Clear the text fields after saving
    _expenseNameController.clear();
    _expensePriceController.clear();
  }

  double _calculateTotalExpenses() {
    return expenses.fold(
        0, (total, item) => total + double.parse(item['price']));
  }

  Future<void> _uploadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    // Fetch username and fullname from SharedPreferences
    String? username = prefs.getString('username');
    String? fullname = prefs.getString('fullname');
    String? expensesJson = prefs.getString('expenses');

    if (expensesJson != null && username != null && fullname != null) {
      try {
        final response = await http.post(
          Uri.parse(
              'https://blueichor.org/uploadExpenses.php'), // Ensure this is your actual endpoint
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'expenses': json.decode(expensesJson),
            'shopId': username, // Use username as shopId
            'shopName': fullname, // Use fullname as shopName
          }),
        );
        if (response.statusCode == 200) {
          // Clear the expenses after successful upload
          await prefs
              .remove('expenses'); // Clear expenses from SharedPreferences
          setState(() {
            expenses.clear(); // Clear the local list of expenses
          });
          print('Expenses uploaded and cleared successfully');
        } else {
          // Error handling
          print('Server error: ${response.body}');
        }
      } catch (e) {
        print('HTTP Error: $e');
      }
    } else {
      print('Missing data: Expenses, Username, or Fullname');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expense Tracker'),
      ),
      body: SingleChildScrollView(
        // Wrap with SingleChildScrollView for better responsiveness
        padding: EdgeInsets.all(8.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Expenses Cost: \$${_calculateTotalExpenses().toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            TextFormField(
              controller: _expenseNameController,
              decoration: InputDecoration(labelText: 'Expense Name'),
            ),
            TextFormField(
              controller: _expensePriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Expense Price'),
            ),
            SizedBox(height: 50), // Increase space above the button
            ElevatedButton(
              onPressed: _saveExpense,
              child: Text('Add Expense'),
            ),
            SizedBox(height: 20), // Space before the list if needed
            expenses.isNotEmpty // Only display the list if there are expenses
                ? ListView.builder(
                    shrinkWrap: true, // Necessary within SingleChildScrollView
                    physics:
                        NeverScrollableScrollPhysics(), // Disable scrolling within the ListView
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(expenses[index]['name']),
                        subtitle: Text(
                            'Price:\$ ${expenses[index]['price']} Date: ${expenses[index]['date']}'),
                      );
                    },
                  )
                : SizedBox(height: 20), // Placeholder space if no expenses
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadExpenses,
        tooltip: 'Upload Expense',
        child: Icon(Icons.cloud_upload),
      ),
    );
  }
}
