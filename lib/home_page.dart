import 'package:allen/pallete.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import 'chat_page.dart';
import 'speech_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Home page no longer hosts speech/chat logic; those live on their pages.
  int start = 200;
  int delay = 200;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BounceInDown(child: const Text('GWSB Front Desk')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // virtual assistant picture
            ZoomIn(
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      height: 120,
                      width: 120,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: const BoxDecoration(
                        color: Pallete.assistantCircleColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Container(
                    height: 123,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage('assets/images/virtualAssistant.png'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // short description
            FadeInRight(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                margin: const EdgeInsets.symmetric(
                  horizontal: 24,
                ).copyWith(top: 24),
                child: const Text(
                  'Welcome to the GW School of Business Undergraduate Programs. \n\nSelect how you would like to interact with our front desk assistant - by chat or by voice.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cera Pro',
                    color: Pallete.mainFontColor,
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            // Buttons for Chat and Speech
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 40,
              ),
              child: Column(
                children: [
                  SlideInLeft(
                    delay: Duration(milliseconds: start),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Pallete.firstSuggestionBoxColor,
                          // make the button slightly taller
                          minimumSize: const Size.fromHeight(56),
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text(
                          'Chat with the Assistant',
                          style: TextStyle(fontSize: 18),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ChatPage()),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SlideInLeft(
                    delay: Duration(milliseconds: start + delay),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Pallete.secondSuggestionBoxColor,
                          // make the button slightly taller
                          minimumSize: const Size.fromHeight(56),
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.mic_none_outlined),
                        label: const Text(
                          'Speak with the Assistant',
                          style: TextStyle(fontSize: 18),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SpeechPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // (Feature previews removed per request)
          ],
        ),
      ),
      // floating action removed - functionality moved to dedicated pages
    );
  }
}
