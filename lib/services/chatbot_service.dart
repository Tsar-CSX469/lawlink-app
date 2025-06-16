import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lawlink/screens/chatbot_page.dart';

class ChatbotService {
  late final String _apiKey;
  late GenerativeModel _model;
  String _selectedLanguage = 'English';

  ChatbotService() {
    // Get API key from environment variables
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
    );
  }

  void sendSystemPrompt(String language) {
    _selectedLanguage = language;
  }

  Future<String> sendMessage(
    String newMessageText,
    List<Message> chatHistory,
  ) async {
    try {
      String languageInstruction =
          _selectedLanguage == 'English'
              ? "Please respond in English."
              : "කරුණාකර සිංහලෙන් පිළිතුරු දෙන්න. (Please respond in Sinhala)";

      final baseSystemInstruction = '''
          You are LawLink AI, a specialized legal assistant for Sri Lankan law. You have expertise in:
          - Consumer Affairs Authority Act
          - Constitution of Sri Lanka
          - Civil law, Criminal law, Commercial law
          - Legal procedures and rights in Sri Lanka
          - Legal document analysis

          Please provide accurate, helpful information about Sri Lankan law. If you're not certain about specific legal details, recommend consulting with a qualified lawyer.
          ''';

      final fullSystemInstruction =
          "$baseSystemInstruction\n\n$languageInstruction";
      List<Content> geminiContents =
          chatHistory.map((msg) => msg.toGeminiContent()).toList();

      geminiContents.insert(0, Content.text(fullSystemInstruction));

      final chat = _model.startChat(history: geminiContents);

      // final content = [Content.text(contextualPrompt)];
      final response = await chat.sendMessage(Content.text(newMessageText));

      return response.text ??
          'I apologize, but I couldn\'t generate a response. Please try again.';
    } catch (e) {
      print('Gemini API error: $e');
      if (e.toString().contains('API_KEY')) {
        return 'Please configure your Google AI API key in the ChatbotService to enable AI responses. For now, I can help you navigate through the law documents and provide basic guidance.';
      } else if (e.toString().contains('not found') ||
          e.toString().contains('not supported')) {
        return 'The AI model is currently unavailable. Please check your model configuration or try again later.\n\nError details: ${e.toString()}';
      }
      return 'I\'m experiencing technical difficulties. Please try again later. Error: ${e.toString()}';
    }
  }

  Future<String> analyzeImage(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      // Create a vision-specific model for image analysis
      final visionModel = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
      );
      String languageInstruction =
          _selectedLanguage == 'English'
              ? "Please analyze this image in the context of Sri Lankan law. Identify any legal documents, signatures, or relevant legal content. Provide insights about what legal procedures or rights might be involved. Respond in English."
              : "කරුණාකර ශ්‍රී ලංකා නීතිය පසුබිම් කරගෙන මෙම රූපය විශ්ලේෂණය කරන්න. ඕනෑම නීතිමය ලේඛන, අත්සන් හෝ අදාළ නීතිමය අන්තර්ගතය හඳුනා ගන්න. අදාළ විය හැකි නීතිමය ක්‍රියාපටිපාටි හෝ අයිතිවාසිකම් පිළිබඳ අදහස් ලබා දෙන්න. කරුණාකර සිංහලෙන් පිළිතුරු දෙන්න.";

      final content = [
        Content.multi([
          TextPart(languageInstruction),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];

      final response = await visionModel.generateContent(content);
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
      String languagePrompt =
          _selectedLanguage == 'English'
              ? "Analyze this legal document content in the context of Sri Lankan law. Respond in English."
              : "ශ්‍රී ලංකා නීතියේ පසුබිම තුළ මෙම නීති ලේඛනයේ අන්තර්ගතය විශ්ලේෂණය කරන්න. කරුණාකර සිංහලෙන් පිළිතුරු දෙන්න.";

      final prompt = '''
$languagePrompt

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

    if (_selectedLanguage == 'English') {
      return '''
PDF document "${file.name}" uploaded successfully. 

For detailed analysis, I would need to extract the text content from the PDF. In the current implementation, please consider:

1. Converting the PDF to text format for analysis
2. Sharing specific sections or questions about the document
3. Uploading the document as an image if it contains forms or signatures

I can help you understand Sri Lankan legal procedures, consumer rights, and other legal matters based on the document context you provide.
''';
    } else {
      return '''
PDF ලේඛනය "${file.name}" සාර්ථකව උඩුගත කරන ලදී.

විස්තරාත්මක විශ්ලේෂණයක් සඳහා, මට PDF වෙතින් පෙළ අන්තර්ගතය උපුටා ගැනීමට අවශ්‍ය වනු ඇත. වත්මන් ක්‍රියාත්මක කිරීමේදී, කරුණාකර සලකා බලන්න:

1. විශ්ලේෂණය සඳහා PDF පෙළ ආකෘතියට පරිවර්තනය කිරීම
2. ලේඛනය පිළිබඳ නිශ්චිත කොටස් හෝ ප්‍රශ්න බෙදා ගැනීම
3. ලේඛනයේ පෝරම හෝ අත්සන් අඩංගු නම් එය රූපයක් ලෙස උඩුගත කිරීම

ඔබ සපයන ලේඛන සන්දර්භය මත පදනම්ව ශ්‍රී ලංකා නීති ක්‍රියාපටිපාටි, පාරිභෝගික අයිතිවාසිකම් සහ වෙනත් නීති කරුණු තේරුම් ගැනීමට මට ඔබට උපකාර කළ හැක.
''';
    }
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
