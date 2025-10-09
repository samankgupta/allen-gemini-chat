import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:allen/secrects.dart';


class OpenAIService {
  final List<Map<String, String>> messages = [];

  Future<String> isArtPromptAPI(String prompt) async {
    try{
      final res = await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'),
      headers: {
        'Content-Type' : 'application/json',
        'x-goog-api-key' : Secrets.geminiApiKey,
      },
      body: jsonEncode({
        "contents": [
            {
              "parts": [
                { "text": 'Does this message want to generate and AI picture, image, art or anything similar? $prompt . Simply answer with a yes or no.'
                 }
              ]
            }
          ]
        }),
      );

      if (res.statusCode == 200){
        String content = jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['text'];
        content = content.trim();

        if (content.startsWith('yes')) {
        return await geminiAPI(prompt);
      } else {
        return await geminiAPI(prompt);
      }
      }
      return 'An internal error occur';
    } catch(e){
      return e.toString();
    }
  }
  Future<String> geminiAPI(String prompt) async {
    messages.add({
      'role' : 'user',
      'content' : prompt,
    });
    try{
      final res = await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'),
      headers: {
        'Content-Type' : 'application/json',
        'x-goog-api-key' : Secrets.geminiApiKey,
      },
      body: jsonEncode({
          "contents": messages.map((m) => {
            "role": m['role'],
            "parts": [
              {"text": m['content']}
            ]
          }).toList(),
        }),
      );
      if (res.statusCode == 200){
        String content = jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['text'];
        content = content.trim();

        messages.add({
          'role': 'model',
          'content':content,
        });
        return content;
      }
      return 'An internal error occur';
    } catch(e){
      return e.toString();
    }
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
  