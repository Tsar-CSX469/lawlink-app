import 'package:flutter/material.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadActs();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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

  List<Act> get filteredActs {
    if (searchQuery.isEmpty) {
      return acts;
    }
    return acts
        .where(
          (act) =>
              act.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              act.number.toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: ShaderMask(
          shaderCallback:
              (bounds) => LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
          child: const Text(
            'Sri Lankan Acts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.blue.shade700),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.shade50],
            stops: const [0.7, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Search bar with proper spacing
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search acts...',
                    prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                    suffixIcon:
                        searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                            )
                            : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Acts list
            Expanded(
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                      )
                      : filteredActs.isEmpty
                      ? Center(
                        child: Text(
                          searchQuery.isNotEmpty
                              ? 'No acts matching "${searchQuery}"'
                              : 'No acts found. Check if PDF is correctly loaded.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: filteredActs.length,
                        itemBuilder: (context, index) {
                          final act = filteredActs[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 4,
                            // ignore: deprecated_member_use
                            shadowColor: Colors.blue.withOpacity(0.1),
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Colors.blue.shade100,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.gavel_rounded,
                                        size: 24,
                                        color: Colors.blue.shade700,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Act No. ${act.number}',
                                              style: TextStyle(
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              act.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _getSummary(act.content),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Action buttons row with download and share
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      // Download button
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(
                                            Icons.file_download,
                                            size: 18,
                                          ),
                                          label: const Text('Download'),
                                          onPressed: () {
                                            _downloadPdf(context, act);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            backgroundColor:
                                                Colors.blue.shade700,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Share button
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(
                                            Icons.share,
                                            size: 18,
                                          ),
                                          label: const Text('Share'),
                                          onPressed: () {
                                            _sharePdf(context, act);
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Colors.blue.shade700,
                                            side: BorderSide(
                                              color: Colors.blue.shade300,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

  String _getSummary(String content) {
    if (content.length <= 100) {
      return content;
    }
    return '${content.substring(0, 100)}...';
  }

  // Method to prepare PDF file from assets  // Method removed as it's no longer used// Method to download PDF
  Future<void> _downloadPdf(BuildContext context, Act act) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${act.title} PDF...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      // Check storage permission on Android
      if (Platform.isAndroid) {
        // For Android 13+ (API level 33+), we need to request specific permissions
        if (await Permission.manageExternalStorage.request().isGranted ||
            await Permission.storage.request().isGranted) {
          // Permission granted
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to download PDFs'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      // Get the directory for saving downloads on the device
      Directory? directory;

      if (Platform.isAndroid) {
        // Try to get the Downloads directory for Android
        try {
          if (await Permission.manageExternalStorage.isGranted) {
            directory = Directory('/storage/emulated/0/Download');
            if (!await directory.exists()) {
              await directory.create(recursive: true);
            }
          } else {
            directory =
                await getExternalStorageDirectory() ??
                await getApplicationDocumentsDirectory();
          }
        } catch (e) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        // For iOS and other platforms
        directory = await getApplicationDocumentsDirectory();
      }

      // Create a new file in the downloads directory
      final file = File(
        '${directory.path}/${act.title.replaceAll(' ', '_')}.pdf',
      );

      // Get the PDF from assets
      final bytes = await rootBundle.load('assets/pdfs/ConsumerAct.pdf');

      // Write bytes to the file
      await file.writeAsBytes(bytes.buffer.asUint8List());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${act.title} PDF downloaded to: ${file.path}'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download: $e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to share Act information
  Future<void> _sharePdf(BuildContext context, Act act) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preparing to share ${act.title}...'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Get the position of the widget to show the share dialog (important for iPads)
      final box = context.findRenderObject() as RenderBox?;

      // Share act information
      await Share.share(
        'Check out ${act.title} (Act No. ${act.number})',
        subject: '${act.title} - Legal Document',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share: $e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
