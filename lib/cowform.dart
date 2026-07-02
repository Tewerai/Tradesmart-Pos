import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cow Form',
      theme: ThemeData(primarySwatch: Colors.brown),
      home: const CowFormPage(),
    );
  }
}

class CowFormPage extends StatefulWidget {
  const CowFormPage({super.key});

  @override
  State<CowFormPage> createState() => _CowFormPageState();
}

class _CowFormPageState extends State<CowFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _cowNumberController = TextEditingController();
  final _serialController = TextEditingController();
  final _marksController = TextEditingController();
  DateTime? _selectedDate;

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      String cowNumber = _cowNumberController.text;
      String date = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      String serial = _serialController.text;
      String marks = _marksController.text;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saved: $cowNumber, $date, $serial, $marks")),
      );

      // You can replace this with database saving logic
    } else if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a date")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cow Registration")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _cowNumberController,
                decoration: const InputDecoration(
                  labelText: "Cow Number",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter cow number' : null,
              ),
              const SizedBox(height: 15),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Date",
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? "Select Date"
                        : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _serialController,
                decoration: const InputDecoration(
                  labelText: "Serial",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter serial' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _marksController,
                decoration: const InputDecoration(
                  labelText: "Marks",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter marks' : null,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Save", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
