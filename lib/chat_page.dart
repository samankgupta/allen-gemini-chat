import 'package:allen/openai_service.dart';
import 'package:allen/pallete.dart';
import 'package:flutter/material.dart';
import 'rag_service.dart';
// RAG/upload UI removed; RagService is used to provide document context from the
// external `rag_index.json` (if present).

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final OpenAIService openAIService = OpenAIService();
  final RagService ragService = RagService();

  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> messages = [];
  bool _isLoading = false;

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _controller.clear();
    });

    // Retrieve relevant document chunks (if any) and call the OpenAIService
    // generate(...) method which already uses a persistent system instruction.
    final relevant = await ragService.retrieveRelevantChunks(text, k: 3);
    final resp = await openAIService.generate(
      text,
      docChunks: relevant,
      historyLimit: 6,
    );

    setState(() {
      messages.add({'role': 'assistant', 'content': resp});
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Chat with Assistant'),
        backgroundColor: Pallete.whiteColor,
        centerTitle: true,
        actions: [
          // Document upload/import UI removed
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final m = messages[index];
                  final isUser = m['role'] == 'user';
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Pallete.firstSuggestionBoxColor
                            : Pallete.thirdSuggestionBoxColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        m['content'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        filled: true,
                        fillColor: Pallete.whiteColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Pallete.firstSuggestionBoxColor,
                    ),
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
