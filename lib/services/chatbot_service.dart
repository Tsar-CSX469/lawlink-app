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
      // Check if asking about who created LawLink AI
      if (_isAskingAboutCreator(newMessageText)) {
        return _selectedLanguage == 'English'
            ? "LawLink AI was created by the TSAR Team. I'm designed to help with Sri Lankan legal questions and topics. How can I assist you with legal matters today?"
            : "LawLink AI සාදන ලද්දේ TSAR කණ්ඩායම විසිනි. මම ශ්‍රී ලංකා නීති ප්‍රශ්න හා මාතෘකා සඳහා උපකාර කිරීමට සැලසුම් කර ඇත. අද දින නීතිමය කරුණු සම්බන්ධයෙන් මට ඔබට උපකාර කළ හැක්කේ කෙසේද?";
      }
      // Pre-filter obviously non-legal questions to reduce API misuse
      else if (_isDefinitelyNotLegalQuestion(newMessageText)) {
        return _selectedLanguage == 'English'
            ? "I'm specifically designed to help with Sri Lankan legal questions and topics. Please ask me about Sri Lankan laws, legal procedures, rights, or legal document analysis, and I'll be happy to assist you."
            : "මම විශේෂයෙන්ම ශ්‍රී ලංකා නීති ප්‍රශ්න හා මාතෘකා සඳහා සහාය වීමට නිර්මාණය කර ඇත. කරුණාකර ශ්‍රී ලංකා නීති, නීතිමය ක්‍රියාපටිපාටි, අයිතිවාසිකම් හෝ නීතිමය ලේඛන විශ්ලේෂණය ගැන මගෙන් අසන්න, මම ඔබට සහාය වීමට සතුටු වෙමි.";
      }

      String languageInstruction =
          _selectedLanguage == 'English'
              ? "Please respond in English."
              : "කරුණාකර සිංහලෙන් පිළිතුරු දෙන්න. (Please respond in Sinhala)";
      final baseSystemInstruction = '''
          You are LawLink AI, a specialized legal assistant primarily for Sri Lankan law and related legal topics. 

          RESPONSE BOUNDARIES - EXTREMELY IMPORTANT:
          1. PRIMARILY answer questions related to Sri Lankan law, legal procedures, rights, cases, courts, and legal documents.
          2. You MAY also provide information about legal services in Sri Lanka including:
             - Contact information for legal aid services and courts
             - Locations of legal institutions, law offices, and government legal departments
             - Phone numbers and addresses for legal consultation services
             - Operating hours of legal institutions
             - General guidance on where to seek legal help
          3. If a user asks questions completely unrelated to law or legal matters, politely redirect them to ask about Sri Lankan legal topics.
          4. DO NOT answer questions about other countries' laws unless specifically comparing them to Sri Lankan law.
          5. DO NOT engage in conversations about politics, entertainment, technology, or other non-legal topics.
          6. For ambiguous questions, interpret them through a Sri Lankan legal lens or ask for clarification.

          Your expertise includes:
          - Consumer Affairs Authority Act and consumer rights
          - Constitution of Sri Lanka and constitutional rights
          - Civil law, Criminal law, Commercial law in Sri Lanka
          - Legal procedures, court systems, and citizen rights in Sri Lanka
          - Legal document analysis and interpretation under Sri Lankan law
          - Recent legal developments and landmark cases in Sri Lanka
          - Contact information and locations for legal services in Sri Lanka
          - Resources for accessing legal aid and consultation services

          Please provide accurate, helpful information about Sri Lankan law and legal services. If you're not certain about specific legal details, recommend consulting with a qualified lawyer in Sri Lanka.
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

  // Check if a question is definitely not related to legal matters
  bool _isDefinitelyNotLegalQuestion(String question) {
    // Convert to lowercase for case-insensitive matching
    final lowercaseQuestion = question.toLowerCase();

    // Check for legal-related keywords that should always be allowed
    final legalRelatedKeywords = [
      'law', 'legal', 'court', 'right', 'justice', 'lawyer', 'attorney',
      'judge', 'case', 'lawsuit', 'plaintiff', 'defendant', 'crime', 'criminal',
      'civil', 'act', 'statute', 'regulation', 'constitution', 'rights',
      'contract',
      'offense',
      'penalty',
      'dispute',
      'hearing',
      'trial',
      'verdict',
      'appeal', 'judicial', 'jurisdiction', 'legislation',

      // Legal service location and contact related terms
      'legal aid', 'legal service', 'lawyer office', 'attorney office',
      'law firm', 'legal consultation', 'legal advice', 'legal help',
      'contact', 'phone', 'address', 'location', 'district court',
      'high court', 'supreme court', 'magistrate', 'chamber', 'bar association',
      'legal counsel', 'pro bono', 'notary', 'commissioner', 'deed',
      'colombo', 'kandy', 'galle', 'jaffna', 'batticaloa', 'negombo',
      'sri lanka bar', 'ministry of justice', 'legal department',
    ];

    for (final keyword in legalRelatedKeywords) {
      if (lowercaseQuestion.contains(keyword)) {
        return false; // This is likely legal-related, don't filter
      }
    }

    // List of obvious non-legal topics
    final nonLegalKeywords = [
      // Entertainment topics
      'movie',
      'film',
      'tv show',
      'netflix',
      'actor',
      'actress',
      'celebrity',
      'song',
      'music',
      'concert',
      'album',
      'hollywood',
      'bollywood',
      'sports',
      'cricket',
      'football',
      'game',

      // Technology topics (unless specifically about tech law)
      'programming',
      'code',
      'software',
      'hardware',
      'coding',
      'javascript',
      'python',
      'java',
      'computer game', 'video game',

      // General knowledge/trivia
      'recipe', 'cook', 'food', 'restaurant', 'hotel', 'vacation', 'holiday',
      'weather', 'climate', 'temperature', 'tell me a joke', 'joke',

      // Homework/personal requests
      'do my homework', 'write an essay', 'write a poem', 'write a story',

      // Relationship/personal advice
      'relationship advice',
      'dating advice',
      'girlfriend',
      'boyfriend',
      'marriage advice',
    ];

    // Check for common question starters that are clearly not legal
    final nonLegalPhrases = [
      'what is your favorite',
      'do you like',
      'tell me a joke',
      'can you write',
      'tell me about yourself',
      // Removed 'who is your creator' as it's handled by _isAskingAboutCreator
      'write a poem',
      'write a story',
      'create a game',
    ];

    // Check if the question contains non-legal keywords
    for (final keyword in nonLegalKeywords) {
      if (lowercaseQuestion.contains(keyword) &&
          !lowercaseQuestion.contains('law') &&
          !lowercaseQuestion.contains('legal') &&
          !lowercaseQuestion.contains('right') &&
          !lowercaseQuestion.contains('court')) {
        return true;
      }
    }

    // Check for non-legal phrases
    for (final phrase in nonLegalPhrases) {
      if (lowercaseQuestion.contains(phrase)) {
        return true;
      }
    }

    return false;
  }

  // Check if the user is asking about who created LawLink AI
  bool _isAskingAboutCreator(String question) {
    // Convert to lowercase for case-insensitive matching
    final lowercaseQuestion = question.toLowerCase();

    // List of patterns that indicate the user is asking about the creator
    final creatorPatterns = [
      'who created you',
      'who made you',
      'who built you',
      'who developed you',
      'who designed you',
      'who is your creator',
      'who is your developer',
      'who is your maker',
      'who is your builder',
      'who developed lawlink',
      'who created lawlink',
      'who built lawlink',
      'who made lawlink',
      'who owns you',
      'who programmed you',
      'who invented you',
      'who is behind you',
      'who are you made by',
      'created by whom',
      'developed by whom',
      'made by whom',
      'who created this app',
      'who made this app',
      'who built this app',
      'company behind you',
      'team behind you',
      'your development team',
      'your creators',
      'your developers',
    ];

    // Check if the question contains any of the creator patterns
    for (final pattern in creatorPatterns) {
      if (lowercaseQuestion.contains(pattern)) {
        return true;
      }
    }

    return false;
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
              ? "You are LawLink AI, a specialized legal assistant EXCLUSIVELY for Sri Lankan law. Please analyze this image ONLY in the context of Sri Lankan law. Identify any legal documents, signatures, or relevant legal content. Provide insights about what legal procedures or rights might be involved. If the image contains non-legal content, politely inform that you can only analyze content relevant to Sri Lankan law. Respond in English."
              : "ඔබ LawLink AI වන අතර, ශ්‍රී ලංකා නීතිය සඳහා විශේෂිත නීති සහකාරයෙකි. කරුණාකර ශ්‍රී ලංකා නීතිය පසුබිම් කරගෙන පමණක් මෙම රූපය විශ්ලේෂණය කරන්න. ඕනෑම නීතිමය ලේඛන, අත්සන් හෝ අදාළ නීතිමය අන්තර්ගතය හඳුනා ගන්න. අදාළ විය හැකි නීතිමය ක්‍රියාපටිපාටි හෝ අයිතිවාසිකම් පිළිබඳ අදහස් ලබා දෙන්න. රූපයේ නීති නොවන අන්තර්ගතයක් අඩංගු නම්, ඔබට ශ්‍රී ලංකා නීතියට අදාළ අන්තර්ගතය පමණක් විශ්ලේෂණය කළ හැකි බව විනීතව දැනුම් දෙන්න. කරුණාකර සිංහලෙන් පිළිතුරු දෙන්න.";

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

    'legal aid': '''
**Legal Aid Services in Sri Lanka:**

1. **Legal Aid Commission of Sri Lanka**
   - Head Office: 129, Hulftsdorp Street, Colombo 12
   - Phone: +94 11 2433 618
   - Services: Free legal advice and representation for low-income individuals

2. **The Asia Foundation's Legal Aid Program**
   - Address: 3/1A Rajakeeya Mawatha, Colombo 7
   - Phone: +94 11 2698 356
   - Services: Support for human rights cases and vulnerable communities

3. **Bar Association Legal Aid Units**
   - Available in most District Courts
   - Contact local Bar Association office for details
   - Services: Pro bono assistance for eligible cases

4. **University Legal Aid Clinics**
   - Faculty of Law, University of Colombo
   - Faculty of Law, University of Peradeniya
   - Services: Legal advice from law students under supervision

For immediate legal consultation, call the Legal Aid Commission hotline: +94 11 243 3618
''',

    'courts locations': '''
**Major Courts in Sri Lanka - Locations:**

1. **Supreme Court**
   - Address: Hulftsdorp Street, Colombo 12
   - Phone: +94 11 2433 388
   - Hours: Monday-Friday, 9:00 AM - 3:30 PM

2. **Court of Appeal**
   - Address: Hulftsdorp Street, Colombo 12
   - Phone: +94 11 2433 327
   - Hours: Monday-Friday, 9:00 AM - 3:30 PM

3. **Colombo District Court**
   - Address: District Court Complex, Hulftsdorp, Colombo 12
   - Phone: +94 11 2445 116
   - Hours: Monday-Friday, 9:00 AM - 3:00 PM

4. **Colombo Magistrate's Court**
   - Address: Aluthkade, Colombo 12
   - Phone: +94 11 2432 901
   - Hours: Monday-Friday, 9:00 AM - 3:00 PM

5. **Commercial High Court**
   - Address: Superior Courts Complex, Colombo 12
   - Phone: +94 11 2335 853
   - Hours: Monday-Friday, 9:00 AM - 3:30 PM

For other district courts, contact the Judicial Service Commission: +94 11 2433 388
''',

    'lawyer contacts': '''
**Finding Legal Representation in Sri Lanka:**

1. **Bar Association of Sri Lanka**
   - Address: Bar Association Building, Hulftsdorp Street, Colombo 12
   - Phone: +94 11 2447 134
   - Website: www.basl.lk
   - Services: Referrals to qualified attorneys

2. **Law Firms Directory**
   - The BASL maintains a directory of registered attorneys by specialty
   - Contact BASL for referrals to specialized attorneys

3. **Law Society of Sri Lanka**
   - Address: Law Society Building, 124 Hulftsdorp Street, Colombo 12
   - Phone: +94 11 2433 427
   - Services: Information on legal practitioners

4. **Ministry of Justice Legal Services**
   - Address: Superior Courts Complex, Colombo 12
   - Phone: +94 11 2435 447
   - Services: Information on legal services

When contacting a lawyer, always confirm:
- Their registration with the Bar Association
- Their specialization area
- Fee structure before engagement
- Estimated timeline for your case
''',
  };
  String getQuickResponse(String query) {
    final lowerQuery = query.toLowerCase();

    // Special mappings for variations of the same query
    final Map<String, String> keywordToResponseKey = {
      // Consumer rights variations
      'consumer right': 'consumer rights',
      'customer right': 'consumer rights',
      'buyer right': 'consumer rights',
      'shopper right': 'consumer rights',
      'purchasing right': 'consumer rights',

      // Warranty claim variations
      'warranty': 'warranty claim',
      'guarantee': 'warranty claim',
      'product return': 'warranty claim',
      'refund': 'warranty claim',
      'exchange policy': 'warranty claim',

      // Legal documentation variations
      'document': 'legal documentation',
      'paperwork': 'legal documentation',
      'deed': 'legal documentation',
      'certificate': 'legal documentation',
      'legal paper': 'legal documentation',

      // Legal aid variations
      'legal aid': 'legal aid',
      'legal assistance': 'legal aid',
      'legal help': 'legal aid',
      'pro bono': 'legal aid',
      'free legal': 'legal aid',
      'legal support': 'legal aid',

      // Court locations variations
      'court location': 'courts locations',
      'court address': 'courts locations',
      'where is the court': 'courts locations',
      'find court': 'courts locations',
      'court contact': 'courts locations',
      'supreme court': 'courts locations',
      'district court': 'courts locations',
      'magistrate court': 'courts locations',

      // Lawyer contacts variations
      'find lawyer': 'lawyer contacts',
      'attorney contact': 'lawyer contacts',
      'legal representation': 'lawyer contacts',
      'contact lawyer': 'lawyer contacts',
      'lawyer number': 'lawyer contacts',
      'lawyer phone': 'lawyer contacts',
      'lawyer directory': 'lawyer contacts',
      'bar association': 'lawyer contacts',
    };

    // Check for matching keywords
    for (final entry in keywordToResponseKey.entries) {
      if (lowerQuery.contains(entry.key)) {
        final responseKey = entry.value;
        if (commonResponses.containsKey(responseKey)) {
          return commonResponses[responseKey]!;
        }
      }
    }

    // Direct key check
    for (final key in commonResponses.keys) {
      if (lowerQuery.contains(key)) {
        return commonResponses[key]!;
      }
    }

    return '';
  }
}
