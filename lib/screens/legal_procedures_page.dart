import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lawlink/screens/procedure_detail_page.dart';

class LegalProceduresPage extends StatelessWidget {
  const LegalProceduresPage({Key? key}) : super(key: key);

  Future<String> _getProcedureStatus(String procedureId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Not Started';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_procedures')
          .doc('${user.uid}_$procedureId')
          .get();

      if (!doc.exists) return 'Not Started';

      final completedSteps = List<int>.from(doc.data()?['completedSteps'] ?? []);
      
      // Get total steps count from the procedure
      final procedureDoc = await FirebaseFirestore.instance
          .collection('legal_procedures')
          .doc(procedureId)
          .get();
      
      if (!procedureDoc.exists) return 'Not Started';
      
      final totalSteps = (procedureDoc.data()?['steps'] as List?)?.length ?? 0;
      
      if (completedSteps.isEmpty) return 'Not Started';
      if (completedSteps.length == totalSteps) return 'Completed';
      return 'In Progress';
    } catch (e) {
      return 'Not Started';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'In Progress':
        return Colors.orange;
      case 'Not Started':
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle;
      case 'In Progress':
        return Icons.hourglass_empty;
      case 'Not Started':
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal Procedures')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('legal_procedures')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No legal procedures found',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: FutureBuilder<String>(
                  future: _getProcedureStatus(doc.id),
                  builder: (context, statusSnapshot) {
                    final status = statusSnapshot.data ?? 'Not Started';
                    final statusColor = _getStatusColor(status);
                    final statusIcon = _getStatusIcon(status);
                    
                    return ListTile(
                      leading: const Icon(Icons.gavel, color: Colors.blue),
                      title: Text(
                        data['title'] ?? 'No title',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['description'] ?? 'No description',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(statusIcon, size: 16, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProcedureDetailPage(
                              procedureId: doc.id,
                              procedureData: data,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
