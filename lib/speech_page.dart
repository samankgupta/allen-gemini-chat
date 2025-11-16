import 'package:allen/openai_service.dart';
import 'package:allen/pallete.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart'
    show SpeechRecognitionResult;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'rag_service.dart';

class SpeechPage extends StatefulWidget {
  const SpeechPage({super.key});

  @override
  State<SpeechPage> createState() => _SpeechPageState();
}

class _SpeechPageState extends State<SpeechPage> {
  final speechToText = SpeechToText();
  final flutterTts = FlutterTts();
  final OpenAIService openAIService = OpenAIService();
  final RagService ragService = RagService();

  String lastWords = '';
  final List<Map<String, String>> messages = [];
  bool isListening = false;
  bool _isProcessing = false;
  bool isSpeaking = false;

  @override
  void initState() {
    super.initState();
    initSpeechToText();
    initTextToSpeech();
  }

  Future<void> initTextToSpeech() async {
    await flutterTts.setSharedInstance(true);
    // Handlers to track speaking state so we can show a stop button
    flutterTts.setStartHandler(() {
      setState(() {
        isSpeaking = true;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });

    flutterTts.setErrorHandler((message) {
      setState(() {
        isSpeaking = false;
      });
    });

    // Configure TTS for reliable playback
    try {
      await flutterTts.setVolume(1.0); // max volume
      await flutterTts.setSpeechRate(0.45); // moderate rate
      await flutterTts.setPitch(1.0);
      await flutterTts.setLanguage('en-US');
      // Ensure the plugin waits for speak completion when requested
      await flutterTts.awaitSpeakCompletion(true);
      // On iOS, set audio category so TTS can play without requiring the
      // microphone/audio session started by speech_to_text. This allows
      // playback even if the app hasn't started listening.
      try {
        await flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      } catch (e) {
        // ignore if platform doesn't support or enums are different
      }
    } catch (e) {
      // ignore; keep handlers so UI still works
    }

    setState(() {});
  }

  Future<void> initSpeechToText() async {
    await speechToText.initialize();
    setState(() {});
  }

  void onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      lastWords = result.recognizedWords;
    });
  }

  Future<void> startListening() async {
    await speechToText.listen(onResult: onSpeechResult);
    setState(() {
      isListening = true;
    });
  }

  Future<void> stopListeningAndSend() async {
    await speechToText.stop();
    setState(() {
      isListening = false;
      _isProcessing = true;
      messages.add({'role': 'user', 'content': lastWords});
    });

    final relevant = await ragService.retrieveRelevantChunks(lastWords, k: 3);
    final resp = await openAIService.generate(
      lastWords,
      docChunks: relevant,
      historyLimit: 6,
    );

    setState(() {
      messages.add({'role': 'assistant', 'content': resp});
      _isProcessing = false;
    });

    // Auto-play assistant response
    if (resp.trim().isNotEmpty) {
      try {
        await flutterTts.speak(resp);
      } catch (e) {
        // ignore TTS errors but ensure UI state is consistent
        setState(() {
          isSpeaking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    speechToText.stop();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speak with Assistant'),
        backgroundColor: Pallete.whiteColor,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                lastWords.isEmpty
                    ? 'Tap the mic and speak. Your words will appear here.'
                    : lastWords,
                style: const TextStyle(fontSize: 18),
              ),
            ),
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
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    backgroundColor: isListening
                        ? Colors.redAccent
                        : Pallete.firstSuggestionBoxColor,
                    onPressed: () async {
                      if (!isListening) {
                        await startListening();
                      } else {
                        await stopListeningAndSend();
                      }
                    },
                    child: Icon(isListening ? Icons.stop : Icons.mic),
                  ),
                  const SizedBox(width: 12),
                  // Stop speaking button when TTS is active
                  if (isSpeaking)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () async {
                        await flutterTts.stop();
                        setState(() {
                          isSpeaking = false;
                        });
                      },
                      icon: const Icon(Icons.stop, size: 18),
                      label: const Text('Stop'),
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
