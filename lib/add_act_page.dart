import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddActPage extends StatefulWidget {
  const AddActPage({super.key});
  @override
  AddActPageState createState() => AddActPageState();
}

class AddActPageState extends State<AddActPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance.collection('acts').add({
          'title': _titleController.text,
          'number': _numberController.text,
          'enactmentDate': _dateController.text,
          'sections': [],
          'relatedKeywords': [],
        });
        Navigator.pop(context); // Return to previous screen
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding act: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Act'),
        backgroundColor: Colors.blue.shade50,
        titleTextStyle: const TextStyle(
          color: Colors.blue,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.blue),
        elevation: 0,
        actions: [
          // Light/Dark mode toggle
          IconButton(
            icon: const Icon(Icons.light_mode),
            tooltip: 'Toggle Dark Mode',
            onPressed: () {
              // Show Coming Soon alert
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text(
                        'Coming Soon!',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: const Text(
                        'Dark mode functionality will be available in the next update!',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'OK',
                            style: TextStyle(color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(labelText: 'Act Number'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the act number';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(labelText: 'Enactment Date'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the enactment date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Submit Act'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
