import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:allen/secrets.dart';

class OpenAIService {
  final List<Map<String, String>> messages = [];
  String? _systemInstruction =
      'You are a front desk assistant for GWSB Undergraduate programs. Answer student questions helpfully and concisely. If relevant information is available in the provided document context, prioritize it and mention when you cite it.';

  /// Set or replace the persistent system instruction.
  void setSystemInstruction(String instruction) {
    _systemInstruction = instruction;
  }

  /// Generate an assistant response using conversation history, an optional
  /// list of document context chunks, and a persistent system instruction.
  ///
  /// - `userText`: the current user query
  /// - `docChunks`: optional list of relevant document chunks (strings)
  /// - `historyLimit`: number of most recent stored messages to include (not
  ///   counting the system instruction). This limits token usage.
  Future<String> generate(
    String userText, {
    List<String>? docChunks,
    int historyLimit = 6,
  }) async {
    // Build the contents list expected by the Gemini API
    final contents = <Map<String, dynamic>>[];
    // Gemini generateContent expects roles 'user' and 'model' in this API
    // (historically). Some server variants reject a 'system' role. To be
    // compatible we send the system instruction as a 'user' message prefixed
    // with a clear label so the model treats it as system-level guidance.
    if (_systemInstruction != null && _systemInstruction!.isNotEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': '[SYSTEM INSTRUCTION]\n' + _systemInstruction!},
        ],
      });
    }

    if (docChunks != null && docChunks.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.writeln('Context from documents:\n');
      for (final c in docChunks) {
        buffer.writeln('--- CHUNK ---');
        buffer.writeln(c);
        buffer.writeln();
      }
      buffer.writeln('End of context.');
      // Document context is sent as a 'user' role block labelled as context.
      contents.add({
        'role': 'user',
        'parts': [
          {'text': '[DOCUMENT CONTEXT]\n' + buffer.toString()},
        ],
      });
    }

    // Include recent history (exclude any system messages stored previously)
    final nonSystem = messages.where((m) => m['role'] != 'system').toList();
    final start = nonSystem.length - historyLimit;
    final recent = start > 0 ? nonSystem.sublist(start) : nonSystem;
    for (final m in recent) {
      contents.add({
        'role': m['role'],
        'parts': [
          {'text': m['content']},
        ],
      });
    }

    // Finally the current user message
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userText},
      ],
    });

    try {
      final res = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
        ),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': Secrets.geminiApiKey,
        },
        body: jsonEncode({'contents': contents}),
      );
      if (res.statusCode == 200) {
        String content = jsonDecode(
          res.body,
        )['candidates'][0]['content']['parts'][0]['text'];
        content = content.trim();

        // store the conversation history
        messages.add({'role': 'user', 'content': userText});
        messages.add({'role': 'model', 'content': content});
        return content;
      }
      // Try to surface any error message from the API body for easier
      // debugging. Gemini APIs often return JSON with details.
      String body = res.body;
      try {
        final Map<String, dynamic> parsed = jsonDecode(res.body);
        if (parsed.containsKey('error')) {
          body = parsed['error'].toString();
        }
      } catch (_) {}
      return 'An internal error occurred (${res.statusCode}): $body';
    } catch (e) {
      return e.toString();
    }
  }

  // Future<String> isArtPromptAPI(String prompt) async {
  //   try{
  //     final res = await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'),
  //     headers: {
  //       'Content-Type' : 'application/json',
  //       'x-goog-api-key' : Secrets.geminiApiKey,
  //     },
  //     body: jsonEncode({
  //       "contents": [
  //           {
  //             "parts": [
  //               { "text": 'Does this message want to generate and AI picture, image, art or anything similar? $prompt . Simply answer with a yes or no.'
  //                }
  //             ]
  //           }
  //         ]
  //       }),
  //     );

  //     if (res.statusCode == 200){
  //       String content = jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['text'];
  //       content = content.trim();

  //       if (content.startsWith('yes')) {
  //       return await geminiAPI(prompt);
  //     } else {
  //       return await geminiAPI(prompt);
  //     }
  //     }
  //     return 'An internal error occur';
  //   } catch(e){
  //     return e.toString();
  //   }
  // }

  @deprecated
  Future<String> geminiAPI(String prompt) async {
    // Backwards-compatible wrapper that simply calls generate with no doc
    // chunks and a small history limit.
    return generate(prompt, docChunks: null, historyLimit: 6);
  }
}
  // Future<String> dallEAPI(String prompt) async {
  //   messages.add({
  //     'role' : 'user',
  //     'content' : prompt,
  //   });
  //   try{
  //     final res = await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-generate-001:predict'),
  //     headers: {
  //       'Content-Type' : 'application/json',
  //       'x-goog-api-key' : Secrets.geminiApiKey,
  //     },
  //     body: jsonEncode({
  //           "contents": [
  //           {
  //             "parts": [
  //               {"text": prompt} 
  //             ]
  //           }
  //         ],
  //         "generationConfig": {
  //           "candidateCount": 1
  //         }
  //       }),
  //     );
  //     if (res.statusCode == 200){
  //       String imageBase64 = jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['inlineData']['data'];
  //       imageBase64 = imageBase64.trim();

  //       Uint8List bytes = base64Decode(imageBase64);
  //       final dir = await getApplicationDocumentsDirectory();
  //       final filePath = '${dir.path}/gemini_native_image_${DateTime.now().millisecondsSinceEpoch}.png';

  //       final file = File(filePath);
  //       await file.writeAsBytes(bytes);

  //       messages.add({
  //         'role': 'model',
  //         'content':imageBase64,
  //       });
  //       return filePath;
  //     }
  //     return 'An internal error occur';
  //   } catch(e){
  //     return e.toString();
  //   }
  