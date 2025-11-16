import 'package:allen/pallete.dart';
import 'package:flutter/material.dart';
import 'package:allen/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // NOTE: Indexing is performed externally via `bin/index_doc.dart`.
  // We no longer auto-import a bundled `assets/rag_index.json` at startup to
  // avoid coupling build-time bundling with the one-time CLI indexing step.
  // If you want to use a prebuilt index file in the app, either:
  //  - copy the CLI-produced `rag_index.json` into `assets/` and rebuild the app
  //    (then you can import it manually by calling
  //    `RagService().importAssetIndexToSqlite()` from a debug screen), or
  //  - copy `rag_index.json` into the app's documents directory on the device
  //    and load it at runtime with `RagService().loadJsonIndex(path)`.

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Allen',
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Pallete.whiteColor,
        appBarTheme: const AppBarTheme(backgroundColor: Pallete.whiteColor),
      ),
      home: const HomePage(),
    );
  }
}
