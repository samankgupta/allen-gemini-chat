import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

// Simple CLI to index a single .docx file and write rag_index.json in the
// current working directory. This JSON is then picked up by the Flutter app's
// RagService (when running from the project directory) to answer queries.

void main(List<String> args) {
  final path = args.isNotEmpty
      ? args[0]
      : '/Users/samankgupta/Downloads/Allen Bot Training.docx';
  final outFile = File('${Directory.current.path}/rag_index.json');

  if (!File(path).existsSync()) {
    print('File not found: $path');
    exit(2);
  }

  print('Indexing: $path');
  final bytes = File(path).readAsBytesSync();
  final text = extractDocxTextFromBytes(bytes);
  if (text.isEmpty) {
    print('No text extracted. Is this a valid .docx file?');
    // try a helpful debug: list archive entries
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      print('Archive entries (first 40):');
      var i = 0;
      for (final f in archive) {
        print(' - ${f.name}');
        i++;
        if (i >= 40) break;
      }
      if (archive.isEmpty) print('Archive appears empty or not a zip.');
    } catch (e) {
      print('Failed to read archive entries: $e');
    }
    exit(3);
  }

  final chunks = chunkText(text, chunkSize: 3000);
  final entries = <Map<String, dynamic>>[];
  for (final c in chunks) {
    final emb = computeEmbedding(c);
    entries.add({'chunkText': c, 'embedding': emb});
  }

  final json = jsonEncode({
    'docName': path.split(Platform.pathSeparator).last,
    'chunks': entries,
  });

  outFile.writeAsStringSync(json);
  print('Wrote index to ${outFile.path} with ${entries.length} chunks');
}

String extractDocxTextFromBytes(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  for (final file in archive) {
    // Accept exact 'word/document.xml' or any entry that ends with 'document.xml'
    if (file.name == 'word/document.xml' ||
        file.name.endsWith('document.xml')) {
      final content = String.fromCharCodes(file.content as List<int>);

      // Debug: print a short preview of the document.xml to help diagnose
      // extraction issues (first run only when debugging).
      // print(content.substring(0, min(800, content.length)));

      try {
        final xmlDoc = XmlDocument.parse(content);
        final buffer = StringBuffer();
        // Find all text nodes named 't' (WordprocessingML uses <w:t>)
        for (final node in xmlDoc.findAllElements('t')) {
          buffer.write(node.text);
        }
        final out = buffer.toString();
        if (out.trim().isNotEmpty) return out;
        // fallback: try to extract by regex if xml parsing yields nothing
        final reg = RegExp(r'<w:t[^>]*>(.*?)<\/w:t>', dotAll: true);
        final matches = reg.allMatches(content);
        final xmlText = StringBuffer();
        for (final m in matches) {
          xmlText.write(m.group(1));
        }
        return xmlText.toString();
      } catch (e) {
        // If XML parsing fails, try regex fallback
        final reg = RegExp(r'<w:t[^>]*>(.*?)<\/w:t>', dotAll: true);
        final matches = reg.allMatches(content);
        final xmlText = StringBuffer();
        for (final m in matches) {
          xmlText.write(m.group(1));
        }
        return xmlText.toString();
      }
    }
  }
  return '';
}

List<String> chunkText(String text, {int chunkSize = 3000}) {
  final chunks = <String>[];
  for (var i = 0; i < text.length; i += chunkSize) {
    final end = (i + chunkSize) < text.length ? i + chunkSize : text.length;
    chunks.add(text.substring(i, end));
  }
  return chunks;
}

Map<String, double> computeEmbedding(String text) {
  final tokens = text
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
      .split(RegExp(r"\s+"))
      .where((t) => t.isNotEmpty)
      .toList();
  final freqs = <String, int>{};
  for (final t in tokens) {
    freqs[t] = (freqs[t] ?? 0) + 1;
  }
  final total = tokens.isEmpty ? 1 : tokens.length;
  final normalized = <String, double>{};
  freqs.forEach((k, v) {
    normalized[k] = v / total;
  });
  return normalized;
}
