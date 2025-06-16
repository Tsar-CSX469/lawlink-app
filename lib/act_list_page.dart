import 'package:flutter/material.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:lawlink/widgets/floating_chatbot_button.dart';

class Act {
  final String number;
  final String title;
  final String content;

  Act({required this.number, required this.title, required this.content});
}

class ActListPage extends StatefulWidget {
  const ActListPage({super.key});

  @override
  ActListPageState createState() => ActListPageState();
}

class ActListPageState extends State<ActListPage> {
  List<Act> acts = [];
  bool isLoading = true;
  String rawPdfText = ""; // Store raw text for debugging

  @override
  void initState() {
    super.initState();
    loadActs();
  }

  Future<void> loadActs() async {
    try {
      // Load PDF from assets to a temp file
      final bytes = await rootBundle.load('assets/pdfs/ConsumerAct.pdf');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ConsumerAct.pdf');
      await file.writeAsBytes(bytes.buffer.asUint8List());

      // Extract text from PDF
      String text = await ReadPdfText.getPDFtext(file.path);

      // Save raw text for debugging
      setState(() {
        rawPdfText = text;
      });

      // For the Consumer Affairs Authority Act specifically
      if (text.isNotEmpty) {
        setState(() {
          acts = [
            Act(
              number: "9 of 2003",
              title: "Consumer Affairs Authority Act",
              content: text,
            ),
          ];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading PDF: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChatbotWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sri Lankan Acts'),
          backgroundColor: Colors.blue.shade50,
          titleTextStyle: const TextStyle(
            color: Colors.blue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Colors.blue),
          elevation: 0,
          actions: [
            // Debug button to view raw text
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Debug PDF Text',
              onPressed: () {
                _showRawText(context);
              },
              color: Colors.blue,
            ),
          ],
        ),
        body:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : acts.isEmpty
                ? const Center(
                  child: Text(
                    'No acts found. Check if PDF is correctly loaded.',
                  ),
                )
                : ListView.builder(
                  itemCount: acts.length,
                  itemBuilder: (context, index) {
                    final act = acts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(
                          'Act No. ${act.number}: ${act.title}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _getSummary(act.content),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          _showActDetails(context, act);
                        },
                      ),
                    );
                  },
                ),
      ),
    );
  }

  String _getSummary(String content) {
    // Try to extract a relevant summary from the content
    if (content.contains("WHEREAS")) {
      final preambleStart = content.indexOf("WHEREAS");
      final preambleEnd = content.indexOf("NOW THEREFORE", preambleStart);
      if (preambleEnd > preambleStart) {
        return content.substring(preambleStart, preambleEnd).trim();
      }
    }

    // Default to first 150 characters if preamble not found
    return content.length > 150 ? "${content.substring(0, 150)}..." : content;
  }

  void _showActDetails(BuildContext context, Act act) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: Text('Act No. ${act.number}: ${act.title}'),
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.blue.shade50,
                    titleTextStyle: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    elevation: 0,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Display sections of the act in a structured way
                          _buildStructuredContent(act.content),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildStructuredContent(String content) {
    // Attempt to structure the content by identifying sections
    List<Widget> sections = [];

    // Add title
    sections.add(
      const Text(
        'CONSUMER AFFAIRS AUTHORITY ACT, No. 9 OF 2003',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
    sections.add(const SizedBox(height: 16));

    // Add preamble if found
    if (content.contains('WHEREAS')) {
      final preambleStart = content.indexOf('WHEREAS');
      final preambleEnd = content.indexOf('NOW THEREFORE', preambleStart);
      if (preambleEnd > preambleStart) {
        sections.add(
          const Text('PREAMBLE', style: TextStyle(fontWeight: FontWeight.bold)),
        );
        sections.add(const SizedBox(height: 8));
        sections.add(
          Text(content.substring(preambleStart, preambleEnd).trim()),
        );
        sections.add(const SizedBox(height: 16));
      }
    }

    // Try to identify parts and sections
    final partRegex = RegExp(r'PART\s+([IVX]+)\s+([A-Z\s]+)');
    final parts = partRegex.allMatches(content);

    if (parts.isNotEmpty) {
      for (final part in parts) {
        final partNumber = part.group(1) ?? '';
        final partTitle = part.group(2) ?? '';

        sections.add(
          Text(
            'PART $partNumber - $partTitle',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        );
        sections.add(const SizedBox(height: 8));

        // Try to find the content of this part
        final partStart = part.start;
        int partEnd = content.length;
        try {
          final nextPart = parts.firstWhere((m) => m.start > partStart);
          partEnd = nextPart.start;
        } catch (e) {
          // No next part found, use content.length as partEnd
        }
        if (partEnd > partStart) {
          String partContent = content.substring(partStart, partEnd).trim();
          // Remove the part title from the content
          partContent = partContent.replaceFirst(partRegex, '').trim();
          sections.add(Text(partContent));
          sections.add(const SizedBox(height: 16));
        }
      }
    } else {
      // If we couldn't identify parts, just show the raw content
      sections.add(Text(content));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  void _showRawText(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('Raw PDF Text (Debug)'),
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.blue.shade50,
                    titleTextStyle: const TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    elevation: 0,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        rawPdfText.isEmpty
                            ? 'No text extracted from PDF'
                            : rawPdfText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
