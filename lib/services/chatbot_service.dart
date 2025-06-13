import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ChatbotService {
  static const String _apiKey =
      'YOUR_GOOGLE_AI_API_KEY'; 
  late GenerativeModel _model;

  ChatbotService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-preview',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
    );
  }

  Future<String> sendMessage(String message) async {
    try {
      
      final contextualPrompt = '''
You are LawLink AI, a specialized legal assistant for Sri Lankan law. You have expertise in:
- Consumer Affairs Authority Act
- Constitution of Sri Lanka
- Civil law, Criminal law, Commercial law
- Legal procedures and rights in Sri Lanka
- Legal document analysis

User query: $message

Please provide accurate, helpful information about Sri Lankan law. If you're not certain about specific legal details, recommend consulting with a qualified lawyer.
''';

      final content = [Content.text(contextualPrompt)];
      final response = await _model.generateContent(content);

      return response.text ??
          'I apologize, but I couldn\'t generate a response. Please try again.';
    } catch (e) {
      if (e.toString().contains('API_KEY')) {
        return 'Please configure your Google AI API key in the ChatbotService to enable AI responses. For now, I can help you navigate through the law documents and provide basic guidance.';
      }
      return 'I\'m experiencing technical difficulties. Please try again later. Error: ${e.toString()}';
    }
  }

  Future<String> analyzeImage(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      final content = [
        Content.multi([
          TextPart(
            'Please analyze this image in the context of Sri Lankan law. Identify any legal documents, signatures, or relevant legal content. Provide insights about what legal procedures or rights might be involved.',
          ),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];

      final response = await _model.generateContent(content);
      return response.text ??
          'I couldn\'t analyze the image. Please try again.';
    } catch (e) {
      return 'Error analyzing image: ${e.toString()}. Please ensure the image is valid and try again.';
    }
  }

  Future<String> analyzeDocument(PlatformFile file) async {
    try {
      if (file.extension?.toLowerCase() == 'txt') {
        final content = await File(file.path!).readAsString();
        return await _analyzeTextContent(content, file.name);
      } else if (file.extension?.toLowerCase() == 'pdf') {
        // For PDF files, we would need additional processing
        return await _analyzePdfDocument(file);
      } else {
        return 'Document type ${file.extension} is not supported yet. Please upload a PDF or text file.';
      }
    } catch (e) {
      return 'Error analyzing document: ${e.toString()}';
    }
  }

  Future<String> _analyzeTextContent(String content, String fileName) async {
    try {
      final prompt = '''
Analyze this legal document content in the context of Sri Lankan law:

Document name: $fileName
Content: $content

Please provide:
1. Document type identification
2. Key legal points
3. Relevant Sri Lankan laws or acts
4. Important clauses or sections
5. Potential legal implications
6. Recommendations or next steps
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'I couldn\'t analyze the document content.';
    } catch (e) {
      return 'Error analyzing text content: ${e.toString()}';
    }
  }

  Future<String> _analyzePdfDocument(PlatformFile file) async {
    // This is a simplified version. In a real implementation, you would:
    // 1. Extract text from PDF using a library like pdf_text
    // 2. Send the extracted text to the AI model for analysis

    return '''
PDF document "${file.name}" uploaded successfully. 

For detailed analysis, I would need to extract the text content from the PDF. In the current implementation, please consider:

1. Converting the PDF to text format for analysis
2. Sharing specific sections or questions about the document
3. Uploading the document as an image if it contains forms or signatures

I can help you understand Sri Lankan legal procedures, consumer rights, and other legal matters based on the document context you provide.
''';
  }

  // Pre-defined responses for common legal queries
  Map<String, String> get commonResponses => {
    'consumer rights': '''
**Sri Lankan Consumer Rights:**

Under the Consumer Affairs Authority Act, you have the right to:
- Safe and quality goods and services
- Clear information about products/services
- Fair prices and honest dealing
- Compensation for defective products
- Return/exchange within warranty period
- Proper receipts for all purchases

If your rights are violated, you can:
1. Contact the trader directly
2. File a complaint with Consumer Affairs Authority
3. Seek legal action through Magistrate Court
''',

    'warranty claim': '''
**Warranty Claims in Sri Lanka:**

1. **Check your rights**: Warranty period should be clearly stated
2. **Documentation**: Keep receipts and warranty cards
3. **Contact seller**: First approach the retailer/manufacturer
4. **Consumer Affairs**: If unsatisfied, contact CAA
5. **Legal action**: Last resort through courts

**Important**: Warranty doesn't cover normal wear, misuse, or accidental damage.
''',

    'legal documentation': '''
**Important Legal Documents in Sri Lanka:**

- **Contracts**: Must be clear, legal, and agreed by both parties
- **Property deeds**: Essential for ownership proof
- **Employment contracts**: Should specify terms clearly
- **Insurance policies**: Read terms and conditions carefully
- **Wills**: Must follow proper legal format

Always keep original documents safe and get legal advice for complex matters.
''',
  };

  String getQuickResponse(String query) {
    final lowerQuery = query.toLowerCase();

    for (final key in commonResponses.keys) {
      if (lowerQuery.contains(key)) {
        return commonResponses[key]!;
      }
    }

    return '';
  }
}
