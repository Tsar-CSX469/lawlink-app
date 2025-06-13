import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LegalProceduresPage extends StatelessWidget {
  const LegalProceduresPage({Key? key}) : super(key: key);

  // Move this to a getter method since we can't have instance fields with const constructor
  CollectionReference get proceduresRef =>
      FirebaseFirestore.instance.collection('legal_procedures');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal Procedures')),
      body: FutureBuilder<QuerySnapshot>(
        future: proceduresRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['title'] ?? 'No title'),
                subtitle: Text(data['description'] ?? ''),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProcedureDetailPage(data: data),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ProcedureDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const ProcedureDetailPage({required this.data, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<dynamic> steps = data['steps'] ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(data['title'] ?? 'Procedure')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              data['description'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              "Steps:",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...steps.map(
              (step) =>
                  ListTile(leading: const Icon(Icons.check), title: Text(step)),
            ),
            const SizedBox(height: 20),
            if (data['prerequisites'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Prerequisites:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ...List<String>.from(
                    data['prerequisites'],
                  ).map((item) => Text("- $item")),
                ],
              ),
            const SizedBox(height: 20),
            if (data['comments'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Comments:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ...List<String>.from(
                    data['comments'],
                  ).map((item) => Text("• $item")),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
