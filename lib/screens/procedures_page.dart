import 'package:flutter/material.dart';

class ProceduresPage extends StatefulWidget {
  const ProceduresPage({super.key});

  @override
  State<ProceduresPage> createState() => _ProceduresPageState();
}

class _ProceduresPageState extends State<ProceduresPage> {
  final List<Map<String, dynamic>> _procedures = [
    {
      'title': 'Filing a Consumer Complaint',
      'description': 'Steps to file a complaint about consumer rights violations.',
      'icon': Icons.receipt_long,
      'color': Colors.blue,
      'steps': [
        'Collect evidence of the issue (receipts, photos)',
        'Contact the business in writing',
        'If unresolved, file a complaint with the Consumer Affairs Authority',
        'Follow up on your complaint',
        'If needed, seek legal assistance'
      ]
    },
    {
      'title': 'Small Claims Process',
      'description': 'How to file and pursue a small claims case.',
      'icon': Icons.balance,
      'color': Colors.green,
      'steps': [
        'Determine if your claim qualifies as a small claim',
        'Prepare documents and evidence',
        'File the claim at your local court',
        'Pay the filing fee',
        'Serve notice to the defendant',
        'Attend the hearing'
      ]
    },
    {
      'title': 'Property Registration',
      'description': 'Steps to register property ownership legally.',
      'icon': Icons.home,
      'color': Colors.purple,
      'steps': [
        'Verify property ownership status',
        'Obtain a lawyer to draft deed',
        'Conduct a title search',
        'Pay stamp duty and registration fees',
        'Submit documents to Land Registry',
        'Collect registration certificate'
      ]
    },
    {
      'title': 'Marriage Registration',
      'description': 'Legal process for registering a marriage.',
      'icon': Icons.favorite,
      'color': Colors.red,
      'steps': [
        'Submit notice of marriage to the Registrar',
        'Provide required identification documents',
        'Pay registration fee',
        'Choose a wedding date within 3 months of notice',
        'Have the ceremony performed by a registrar',
        'Obtain marriage certificate'
      ]
    },
    {
      'title': 'Business Registration',
      'description': 'Steps to legally register a new business.',
      'icon': Icons.business,
      'color': Colors.orange,
      'steps': [
        'Select a unique business name',
        'Determine business structure (sole proprietorship, LLC, etc.)',
        'Complete registration forms',
        'Submit forms to the Department of Registrar of Companies',
        'Pay registration fees',
        'Obtain business registration certificate'
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal Procedures'),
        elevation: 0,
        backgroundColor: Colors.blue,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Common Legal Procedures',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Step-by-step guides for everyday legal matters',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _procedures.length,
                  itemBuilder: (context, index) {
                    final procedure = _procedures[index];
                    return _buildProcedureCard(procedure);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcedureCard(Map<String, dynamic> procedure) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showProcedureDetails(procedure),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: procedure['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  procedure['icon'],
                  color: procedure['color'],
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      procedure['title'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      procedure['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showProcedureDetails(Map<String, dynamic> procedure) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: procedure['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        procedure['icon'],
                        color: procedure['color'],
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        procedure['title'],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  procedure['description'],
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Steps to Follow',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  procedure['steps'].length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: procedure['color'],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            procedure['steps'][index],
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '* This information is for general guidance only and may not apply to all situations.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
