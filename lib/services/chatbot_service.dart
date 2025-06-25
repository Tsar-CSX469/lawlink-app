import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lawlink/screens/chatbot_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:lawlink/services/location_service.dart';

class ChatbotService {
  late final String _apiKey;
  late GenerativeModel _model;
  String _selectedLanguage = 'English';

  ChatbotService() {
    // Get API key from environment variables
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      ),
    );
  }

  void sendSystemPrompt(String language) {
    _selectedLanguage = language;
  }

  Future<String> sendMessage(
    String newMessageText,
    List<Message> chatHistory, {
    BuildContext? context,
  }) async {
    try {
      // Check if asking about who created LawLink AI
      if (_isAskingAboutCreator(newMessageText)) {
        return _selectedLanguage == 'English'
            ? "LawLink AI was created by the TSAR Team. I'm designed to help with Sri Lankan legal questions and topics. How can I assist you with legal matters today?"
            : "LawLink AI සාදන ලද්දේ TSAR කණ්ඩායම විසිනි. මම ශ්‍රී ලංකා නීති ප්‍රශ්න හා මාතෘකා සඳහා උපකාර කිරීමට සැලසුම් කර ඇත. අද දින නීතිමය කරුණු සම්බන්ධයෙන් මට ඔබට උපකාර කළ හැක්කේ කෙසේද?";
      }
      // Check if this is a location-based query
      else if (_isLocationBasedQuestion(newMessageText)) {
        final locationResponse = await _processLocationBasedQuery(
          newMessageText,
          _selectedLanguage,
          context,
        );
        // Make location-based responses concise as well
        return makeConciseResponseWithFollowUps(locationResponse);
      }
      // Pre-filter obviously non-legal questions to reduce API misuse
      else if (_isDefinitelyNotLegalQuestion(newMessageText)) {
        return _selectedLanguage == 'English'
            ? "I'm specifically designed to help with Sri Lankan legal questions and topics. Please ask me about Sri Lankan laws, legal procedures, rights, or legal document analysis, and I'll be happy to assist you."
            : "මම විශේෂයෙන්ම ශ්‍රී ලංකා නීති ප්‍රශ්න හා මාතෘකා සඳහා සහාය වීමට නිර්මාණය කර ඇත. කරුණාකර ශ්‍රී ලංකා නීති, නීතිමය ක්‍රියාපටිපාටි, අයිතිවාසිකම් හෝ නීතිමය ලේඛන විශ්ලේෂණය ගැන මගෙන් අසන්න, මම ඔබට සහාය වීමට සතුටු වෙමි.";
      }

      // Check if it matches any quick response patterns
      String quickResponse = getQuickResponse(newMessageText);
      if (quickResponse.isNotEmpty) {
        // Quick responses are already concise, no need for follow-up processing
        return quickResponse;
      }

      String languageInstruction =
          _selectedLanguage == 'English'
              ? "Please respond in English. Keep your answer concise and to the point."
              : "කරුණාකර සිංහලෙන් පිළිතුරු දෙන්න. (Please respond in Sinhala). Keep your answer concise and to the point.";
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

      final response = await chat.sendMessage(Content.text(newMessageText));

      // Get the original response from the model
      final originalResponse =
          response.text ??
          'I apologize, but I couldn\'t generate a response. Please try again.';

      // Make the response concise and add follow-up tags
      return makeConciseResponseWithFollowUps(originalResponse);
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

  Future<String> analyzeImage(String imagePath, {String? userQuestion}) async {
    try {
      // Initial message based on selected language to inform user that image processing has started
      String processingMessage =
          _selectedLanguage == 'English'
              ? "📸 I'm analyzing your image from a legal perspective... One moment please.\n\n"
              : "📸 මම නීතිමය දෘෂ්ටිකෝණයකින් ඔබගේ රූපය විශ්ලේෂණය කරමින් සිටිමි... මොහොතක් රැඳී සිටින්න.\n\n";

      // Log image processing for debugging purposes
      print('Starting image analysis for: $imagePath');
      if (userQuestion != null && userQuestion.isNotEmpty) {
        print('User question: $userQuestion');
      }

      final imageFile = File(imagePath);
      final imageBytes =
          await imageFile
              .readAsBytes(); // Create a vision-specific model for image analysis
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

      // Base instruction for image analysis
      String baseInstruction =
          _selectedLanguage == 'English'
              ? "You are LawLink AI, a specialized legal assistant EXCLUSIVELY for Sri Lankan law. Please analyze this image ONLY in the context of Sri Lankan law. Identify any legal documents, signatures, or relevant legal content. Provide insights about what legal procedures or rights might be involved. If the image contains non-legal content, politely inform that you can only analyze content relevant to Sri Lankan law. Respond in English."
              : "ඔබ LawLink AI වන අතර, ශ්‍රී ලංකා නීතිය සඳහා විශේෂිත නීති සහකාරයෙකි. කරුණාකර ශ්‍රී ලංකා නීතිය පසුබිම් කරගෙන පමණක් මෙම රූපය විශ්ලේෂණය කරන්න. ඕනෑම නීතිමය ලේඛන, අත්සන් හෝ අදාළ නීතිමය අන්තර්ගතය හඳුනා ගන්න. අදාළ විය හැකි නීතිමය ක්‍රියාපටිපාටි හෝ අයිතිවාසිකම් පිළිබඳ අදහස් ලබා දෙන්න. රූපයේ නීති නොවන අන්තර්ගතයක් අඩංගු නම්, ඔබට ශ්‍රී ලංකා නීතියට අදාළ අන්තර්ගතය පමණක් විශ්ලේෂණය කළ හැකි බව විනීතව දැනුම් දෙන්න. කරුණාකර සිංහලෙන් පිළිතුරු දෙන්න.";

      // If user provided a question, add it to the instruction
      if (userQuestion != null && userQuestion.isNotEmpty) {
        String questionPrompt =
            _selectedLanguage == 'English'
                ? "\n\nThe user specifically asks: \"$userQuestion\" Please address this question in relation to the image."
                : "\n\nපරිශීලකයා විශේෂයෙන් අසන්නේ: \"$userQuestion\" කරුණාකර රූපයට සම්බන්ධව මෙම ප්‍රශ්නය ගැන සලකා බලන්න.";
        baseInstruction += questionPrompt;
      }

      // Create a list to hold the content parts
      List<Part> parts = [];

      // Add the text instruction first
      parts.add(TextPart(baseInstruction));

      // Then add the image data
      parts.add(DataPart('image/jpeg', imageBytes));

      // Create content with proper "user" role formatting for Gemini 2.5 Flash
      final content = Content("user", parts);

      // Generate content with the proper model
      final response = await visionModel.generateContent([content]);

      // Get the result text
      String result =
          response.text ?? 'I couldn\'t analyze the image. Please try again.';

      // Add the processing message at the beginning
      return processingMessage + result;
    } catch (e) {
      print('Error in analyzeImage: ${e.toString()}');
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

      // Create content with proper "user" role formatting for Gemini 2.5 Flash
      final response = await _model.generateContent([
        Content("user", [TextPart(prompt)]),
      ]);
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

  // Check if a question is related to location
  bool _isLocationBasedQuestion(String question) {
    final lowercaseQuestion = question.toLowerCase();

    final locationKeywords = [
      'near',
      'nearby',
      'closest',
      'nearest',
      'around',
      'in my area',
      'location',
      'where is',
      'where are',
      'find me',
      'in this area',
      'proximity',
      'close by',
      'walking distance',
      'driving distance',
      'in',
    ];

    final legalTerms = [
      'lawyer',
      'court',
      'legal',
      'attorney',
      'law firm',
      'legal aid',
      'police station',
      'notary',
      'judge',
      'magistrate',
      'high court',
      'supreme court',
      'district court',
      'bar association',
      'legal department',
      'justice',
    ];

    // Check for combinations of location keywords and legal terms
    for (final keyword in locationKeywords) {
      for (final term in legalTerms) {
        if (lowercaseQuestion.contains(keyword) &&
            lowercaseQuestion.contains(term)) {
          return true;
        }
      }
    }

    return false;
  }

  // Extract location from query
  String? _extractLocationFromQuery(String query) {
    final lowercaseQuery = query.toLowerCase();

    // Common Sri Lankan cities and regions
    final sriLankanLocations = [
      'colombo',
      'kandy',
      'galle',
      'jaffna',
      'batticaloa',
      'trincomalee',
      'negombo',
      'anuradhapura',
      'ratnapura',
      'matara',
      'nuwara eliya',
      'kurunegala',
      'polonnaruwa',
      'hambantota',
      'matale',
      'puttalam',
      'kalutara',
      'gampaha',
      'badulla',
      'ampara',
      'kegalle',
      'monaragala',
      'mullaitivu',
      'kilinochchi',
      'mannar',
      'vavuniya',
    ];

    // Check if any location is mentioned
    for (final location in sriLankanLocations) {
      if (lowercaseQuery.contains(location)) {
        // Find the full context of the location mention
        final words = query.split(' ');
        for (int i = 0; i < words.length; i++) {
          if (words[i].toLowerCase().contains(location)) {
            // Return the word (may be capitalized in original query)
            return words[i];
          }
        }
        return location.substring(0, 1).toUpperCase() + location.substring(1);
      }
    }

    // Check for phrases like "near ABC" or "in XYZ"
    final locationPrefixes = ['near ', 'in ', 'at ', 'around '];
    for (final prefix in locationPrefixes) {
      if (lowercaseQuery.contains(prefix)) {
        final index = lowercaseQuery.indexOf(prefix) + prefix.length;
        // Extract up to 3 words after the prefix as the potential location
        final remainingText = lowercaseQuery.substring(index).trim();
        final potentialLocation = remainingText.split(' ').take(3).join(' ');

        // Check if this is actually about "me" or "my area"
        if (potentialLocation.contains('me') ||
            potentialLocation.contains('my') ||
            potentialLocation.startsWith('this')) {
          return null;
        }

        // Return the extracted location if it's not empty
        if (potentialLocation.isNotEmpty) {
          return potentialLocation.substring(0, 1).toUpperCase() +
              potentialLocation.substring(1);
        }
      }
    }

    return null;
  }

  // These methods have been moved to LocationService class  // Process location-based query
  Future<String> _processLocationBasedQuery(
    String query,
    String language, [
    BuildContext? context,
  ]) async {
    try {
      // Check if the query is about a specific location rather than the user's current location
      String? specificLocation = _extractLocationFromQuery(query);

      // Determine what the user is looking for (lawyers, courts, etc.)
      String lookingFor = _determineLookingFor(query, language);
      String enhancedQuery;

      if (specificLocation != null) {
        // This is a query about a specific location, not the user's current location
        if (language == 'English') {
          enhancedQuery = '''$query
The user is asking about legal services near $specificLocation in Sri Lanka.
Please provide information about $lookingFor in or near $specificLocation.
Include relevant contact information if available.''';
        } else {
          enhancedQuery = '''$query
පරිශීලකයා ශ්‍රී ලංකාවේ $specificLocation ආසන්නයේ නීති සේවා ගැන විමසයි.
කරුණාකර $specificLocation හි හෝ ඒ අවට $lookingFor පිළිබඳ තොරතුරු සපයන්න.
ලබා ගත හැකි නම් අදාළ සම්බන්ධතා තොරතුරු ඇතුළත් කරන්න.''';
        } // Use the AI model to get a response based on the location
        // Instead of using a chat session, use direct content generation with system message
        final systemMessage = Content("user", [TextPart(enhancedQuery)]);
        final response = await _model.generateContent([systemMessage]);

        return response.text ??
            (language == 'English'
                ? "I'm having trouble providing specific information about legal services in $specificLocation at this moment."
                : "මට මේ මොහොතේ $specificLocation හි නීති සේවා පිළිබඳ නිශ්චිත තොරතුරු සැපයීමට අපහසුය.");
      }

      // If we get here, this is about the user's current location
      if (context != null) {
        // Use the more user-friendly permission request if context is available
        bool hasPermission = await LocationService.requestLocationPermission(
          context,
        );
        if (!hasPermission) {
          return language == 'English'
              ? "To help you find legal services near you, LawLink needs permission to access your location. Please enable location access in your device settings."
              : "ඔබ අසල නීති සේවා සොයා ගැනීමට ඔබට උදව් කිරීම සඳහා, LawLink හට ඔබගේ ස්ථානයට ප්රවේශ වීමට අවසර අවශ්ය වේ. කරුණාකර ඔබගේ උපකරණ සැකසුම්වල ස්ථාන ප්රවේශය සක්රිය කරන්න.";
        }
      }

      // Get current position using the LocationService
      Position? position = await LocationService.getCurrentLocation();
      if (position == null) {
        return language == 'English'
            ? "I wasn't able to access your location. Please check your location permissions and try again."
            : "ඔබගේ ස්ථානය වෙත ප්රවේශ වීමට මට නොහැකි විය. කරුණාකර ඔබගේ ස්ථාන අවසරයන් පරීක්ෂා කර නැවත උත්සාහ කරන්න.";
      }

      // Get address using the LocationService
      String? address = await LocationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Add location information to the original query and forward to AI model
      if (language == 'English') {
        enhancedQuery = '''$query 
The user's current location is: ${address ?? 'Unknown location'}
Coordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}
Please provide information about $lookingFor near this location in Sri Lanka.
Include relevant contact information for this area if available.''';
      } else {
        enhancedQuery = '''$query 
පරිශීලකයාගේ වත්මන් ස්ථානය: ${address ?? 'නොදන්නා ස්ථානයක'}
ඛණ්ඩාංක: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}
කරුණාකර ශ්‍රී ලංකාවේ මෙම ස්ථානයට ආසන්නව $lookingFor පිළිබඳ තොරතුරු සපයන්න.
ලබා ගත හැකි නම් මෙම ප්‍රදේශය සඳහා අදාළ සම්බන්ධතා තොරතුරු ඇතුළත් කරන්න.''';
      } // Forward the enhanced query with location info to the model
      // Use direct content generation instead of chat session
      final systemMessage = Content("user", [TextPart(enhancedQuery)]);
      final response = await _model.generateContent([systemMessage]);

      return response.text ??
          (language == 'English'
              ? "I found your location at ${address ?? 'Unknown location'}, but I'm having trouble providing specific legal service information for that area."
              : "මම ඔබගේ ස්ථානය ${address ?? 'නොදන්නා ස්ථානයකට'} සොයා ගත්තත්, එම ප්‍රදේශය සඳහා නිශ්චිත නීති සේවා තොරතුරු සැපයීමේ අපහසුතාවයක් ඇත.");
    } catch (e) {
      print('Error processing location query: $e');
      return language == 'English'
          ? "I couldn't process your location-based query: $e. Please check your device permissions and try again."
          : "ඔබගේ ස්ථාන-පාදක විමසුම සැකසීමට මට නොහැකි විය: $e. කරුණාකර ඔබගේ උපාංග අවසරයන් පරීක්ෂා කර නැවත උත්සාහ කරන්න.";
    }
  }

  // Helper method to determine what legal service the user is looking for
  String _determineLookingFor(String query, String language) {
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('lawyer') || lowerQuery.contains('attorney')) {
      return language == 'English' ? 'lawyers or attorneys' : 'නීතිඥයන්';
    } else if (lowerQuery.contains('court')) {
      return language == 'English' ? 'courts' : 'අධිකරණ';
    } else if (lowerQuery.contains('legal aid')) {
      return language == 'English' ? 'legal aid services' : 'නීති ආධාර සේවා';
    } else if (lowerQuery.contains('police')) {
      return language == 'English' ? 'police stations' : 'පොලිස් ස්ථාන';
    } else if (lowerQuery.contains('notary')) {
      return language == 'English' ? 'notary services' : 'නොතාරිස් සේවා';
    } else {
      return language == 'English' ? 'legal services' : 'නීති සේවා';
    }
  }

  // Generate a concise response with follow-up tags
  String makeConciseResponseWithFollowUps(String originalResponse) {
    if (originalResponse.length < 300) {
      // Already concise enough, no need to modify
      return originalResponse;
    }

    // Extract enough content for a substantial concise answer
    String conciseResponse = '';
    List<String> paragraphs = originalResponse.split('\n\n');

    // Check if the first paragraph ends with a colon, which often indicates
    // it's just introducing a list but doesn't contain actual content
    bool firstParagraphIsIncomplete = false;
    if (paragraphs.isNotEmpty) {
      String firstPara = paragraphs[0].trim();
      if (firstPara.endsWith(':') ||
          firstPara.endsWith('such as:') ||
          firstPara.length < 100) {
        firstParagraphIsIncomplete = true;
        print("First paragraph appears incomplete: $firstPara");
      }
    }

    // Take enough paragraphs to provide a complete main answer
    if (paragraphs.isNotEmpty) {
      // Always include the first paragraph
      conciseResponse = paragraphs[0];

      // If first paragraph ends with a colon or is very short,
      // always include the next paragraph if available
      if (firstParagraphIsIncomplete && paragraphs.length > 1) {
        conciseResponse += '\n\n' + paragraphs[1];
        if (paragraphs.length > 2 && paragraphs[1].trim().length < 100) {
          // If second paragraph is also short, include the third
          conciseResponse += '\n\n' + paragraphs[2];
        }
      }

      // Include more paragraphs if needed to provide a substantial answer
      int contentLength = conciseResponse.length;
      int paragraphIndex = firstParagraphIsIncomplete ? 3 : 1;

      // Include additional paragraphs until we have a substantial answer
      // Make sure we have at least 300 characters of content
      while ((contentLength < 500 || firstParagraphIsIncomplete) &&
          paragraphIndex < paragraphs.length &&
          contentLength < originalResponse.length * 0.7) {
        // Skip paragraphs that are just bullet points or very short
        if (paragraphs[paragraphIndex].trim().length > 20) {
          conciseResponse += '\n\n' + paragraphs[paragraphIndex];
          contentLength += paragraphs[paragraphIndex].length;
        }
        paragraphIndex++;

        // Always include at least 2 substantive paragraphs
        if (paragraphIndex >= 3 &&
            contentLength > 300 &&
            !firstParagraphIsIncomplete) {
          break;
        }
      }
    } else {
      // No paragraphs, take enough sentences to provide a meaningful answer
      List<String> sentences = originalResponse.split('. ');
      if (sentences.length > 3) {
        // Take at least 3 sentences or more if they're short
        int sentenceCount = min(
          sentences.length,
          max(5, 800 ~/ (originalResponse.length / sentences.length)),
        );
        conciseResponse = sentences.take(sentenceCount).join('. ') + '.';
      } else {
        // If very few sentences, take most of the original content
        conciseResponse = originalResponse.substring(
          0,
          min(originalResponse.length * 3 ~/ 4, originalResponse.length),
        );
      }
    }

    // Add follow-up tags based on content
    List<String> followUpTags = _generateFollowUpTags(
      originalResponse,
    ); // Format the response with follow-up tags
    String response = conciseResponse;

    // Print debug information to see what's happening
    print('ORIGINAL LENGTH: ${originalResponse.length}');
    print('CONCISE LENGTH: ${conciseResponse.length}');
    print(
      'CONCISE RESPONSE FIRST 100 CHARS: ${conciseResponse.substring(0, min(100, conciseResponse.length))}...',
    );

    if (followUpTags.isNotEmpty) {
      response += '\n\n**Want to know more?**\n';
      for (var tag in followUpTags) {
        response += '- $tag\n';
      }
    }

    return response;
  }

  List<String> _generateFollowUpTags(String fullResponse) {
    // Extract potential follow-up topics from the response
    List<String> followUps = [];

    // Common legal follow-up patterns
    Map<String, String> followUpPatterns = {
      'procedure': 'What\'s the procedure?',
      'cost': 'What are the costs involved?',
      'time': 'How long does it take?',
      'documents': 'What documents do I need?',
      'rights': 'What are my rights?',
      'appeal': 'Can I appeal this decision?',
      'deadline': 'What are the deadlines?',
      'penalty': 'What are the penalties?',
      'court': 'Which court handles this?',
      'lawyer': 'Do I need a lawyer?',
      'alternatives': 'Are there alternatives?',
      'laws': 'What laws apply here?',
      'examples': 'Can you give examples?',
    };

    // Check for keywords in the response and generate relevant follow-up tags
    followUpPatterns.forEach((keyword, question) {
      if (fullResponse.toLowerCase().contains(keyword.toLowerCase()) &&
          !followUps.contains(question) &&
          followUps.length < 3) {
        followUps.add(question);
      }
    });

    // If no specific tags were identified, add general ones
    if (followUps.isEmpty) {
      followUps.add('Tell me more details');
      followUps.add('Can you explain further?');
    }

    // Limit to 3 follow-up tags at most
    return followUps.take(3).toList();
  }
}
