import 'package:flutter/material.dart';
import 'package:lawlink/add_act_page.dart';

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        body: const Center(child: Text('Test')),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // Test if AddActPage can be instantiated
            const AddActPage();
          },
          child: const Icon(Icons.add),
        ),
      ),
    ),
  );
}
