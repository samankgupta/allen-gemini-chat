import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// A small local RAG service that:
/// - extracts text from .docx files
/// - chunks the text
/// - computes a simple "embedding" (term-frequency map) and stores it in SQLite
/// - retrieves top-K chunks for a query using cosine similarity over the TF maps
///
/// NOTE: This uses a local, simple vectorization (bag-of-words TF) to avoid
/// requiring a cloud embeddings provider. It's fully local and can be swapped
/// to use real embeddings later by replacing `computeEmbedding` and storage.

class RagService {
  static final RagService _instance = RagService._internal();
  factory RagService() => _instance;
  RagService._internal();

  Database? _db;
  // In-memory cache for CLI-produced JSON index to avoid re-reading the file
  // on every retrieval. This is populated by `loadJsonIndex` when a
  // `rag_index.json` file is found in the current working directory.
  List<Map<String, dynamic>>? _jsonChunksCache;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'rag_store.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
        CREATE TABLE chunks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          docName TEXT,
          chunkText TEXT,
          embedding TEXT
        )
      ''');
      },
    );
    return _db!;
  }

  Future<String> extractDocxText(String filePath) async {
    final bytes = File(filePath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      if (file.name == 'word/document.xml') {
        final content = String.fromCharCodes(file.content as List<int>);
        final xmlDoc = XmlDocument.parse(content);
        final buffer = StringBuffer();
        for (final node in xmlDoc.findAllElements('t')) {
          buffer.write(node.text);
        }
        return buffer.toString();
      }
    }
    return '';
  }

  /// Extract text from raw bytes of a .docx file.
  Future<String> extractDocxTextFromBytes(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      if (file.name == 'word/document.xml') {
        final content = String.fromCharCodes(file.content as List<int>);
        final xmlDoc = XmlDocument.parse(content);
        final buffer = StringBuffer();
        for (final node in xmlDoc.findAllElements('t')) {
          buffer.write(node.text);
        }
        return buffer.toString();
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

  /// Simple term-frequency embedding: map token -> freq (normalized)
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
    final total = tokens.length == 0 ? 1 : tokens.length;
    final normalized = <String, double>{};
    freqs.forEach((k, v) {
      normalized[k] = v / total;
    });
    return normalized;
  }

  double _cosineSimilarity(Map<String, double> a, Map<String, double> b) {
    double dot = 0.0;
    double norma = 0.0;
    double normb = 0.0;
    final keys = <String>{}
      ..addAll(a.keys)
      ..addAll(b.keys);
    for (final k in keys) {
      final av = a[k] ?? 0.0;
      final bv = b[k] ?? 0.0;
      dot += av * bv;
      norma += av * av;
      normb += bv * bv;
    }
    if (norma == 0 || normb == 0) return 0.0;
    return dot / (sqrt(norma) * sqrt(normb));
  }

  /// Store chunks for a document into the local DB.
  Future<void> storeDocumentChunks(String docName, List<String> chunks) async {
    final database = await db;
    final batch = database.batch();
    for (final c in chunks) {
      final emb = computeEmbedding(c);
      batch.insert('chunks', {
        'docName': docName,
        'chunkText': c,
        'embedding': jsonEncode(emb),
      });
    }
    await batch.commit(noResult: true);
  }

  /// Retrieve top K most similar chunks for a query string.
  Future<List<String>> retrieveRelevantChunks(String query, {int k = 3}) async {
    final qEmb = computeEmbedding(query);
    final scored = <MapEntry<String, double>>[];
    // Try to load an external JSON index into the in-memory cache if present.
    // We support multiple locations so the app can find the index whether it's
    // placed in the development working directory, the app's documents folder,
    // or bundled as an asset under `assets/rag_index.json`.
    if (_jsonChunksCache == null) {
      try {
        await loadJsonIndex();
      } catch (_) {
        // loading failed: fall back to sqlite below
      }
    }

    if (_jsonChunksCache != null) {
      for (final c in _jsonChunksCache!) {
        final chunkText = c['chunkText'] as String? ?? '';
        final Map<String, dynamic> embMap = (c['embedding'] as Map)
            .cast<String, dynamic>();
        final emb = embMap.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
        final score = _cosineSimilarity(qEmb, emb);
        scored.add(MapEntry(chunkText, score));
      }
      scored.sort((a, b) => b.value.compareTo(a.value));
      return scored.take(k).map((e) => e.key).toList();
    }

    // Fallback to SQLite-backed store
    final database = await db;
    final rows = await database.query('chunks');
    for (final r in rows) {
      final embJson = r['embedding'] as String? ?? '{}';
      final Map<String, dynamic> embMap = jsonDecode(embJson);
      final emb = embMap.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );
      final score = _cosineSimilarity(qEmb, emb);
      scored.add(MapEntry(r['chunkText'] as String, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(k).map((e) => e.key).toList();
  }

  /// Clear stored chunks (for debugging)
  Future<void> clearStore() async {
    final database = await db;
    await database.delete('chunks');
  }

  /// Import an index JSON produced by the CLI into the local SQLite store.
  ///
  /// The JSON is expected to be of the form:
  /// {
  ///   "docName": "...",
  ///   "chunks": [ { "chunkText": "...", "embedding": { token: weight, ... } }, ... ]
  /// }
  ///
  /// This method deletes any existing chunks with the same docName before
  /// inserting the new chunks to avoid duplicates (so running the CLI twice
  /// replaces the old index for that document).
  Future<void> importIndexFromJson(String jsonPath) async {
    final f = File(jsonPath);
    if (!await f.exists()) throw Exception('Index file not found: $jsonPath');
    final content = await f.readAsString();
    final Map<String, dynamic> data = jsonDecode(content);
    final docName = data['docName'] as String? ?? 'imported_doc';
    final List<dynamic> chunks = data['chunks'] ?? [];

    final database = await db;
    // remove any existing chunks for this document so import is idempotent
    await database.delete('chunks', where: 'docName = ?', whereArgs: [docName]);

    final batch = database.batch();
    for (final c in chunks) {
      final chunkText = c['chunkText'] as String? ?? '';
      final embeddingVal = c['embedding'];
      // ensure embedding is stored as JSON string
      final embJson = jsonEncode(embeddingVal);
      batch.insert('chunks', {
        'docName': docName,
        'chunkText': chunkText,
        'embedding': embJson,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Convenience: import the bundled asset `assets/rag_index.json` into the
  /// SQLite store. This is useful when you include the index as an app asset
  /// (see pubspec.yaml) and want to persist it into the app database so it
  /// can be queried later without relying on the asset file.
  Future<void> importAssetIndexToSqlite() async {
    try {
      final content = await rootBundle.loadString('assets/rag_index.json');
      final Map<String, dynamic> data = jsonDecode(content);
      final docName = data['docName'] as String? ?? 'imported_doc';
      final List<dynamic> chunks = data['chunks'] ?? [];

      final database = await db;
      await database.delete(
        'chunks',
        where: 'docName = ?',
        whereArgs: [docName],
      );
      final batch = database.batch();
      for (final c in chunks) {
        final chunkText = c['chunkText'] as String? ?? '';
        final embeddingVal = c['embedding'];
        final embJson = jsonEncode(embeddingVal);
        batch.insert('chunks', {
          'docName': docName,
          'chunkText': chunkText,
          'embedding': embJson,
        });
      }
      await batch.commit(noResult: true);

      // Also populate in-memory cache so immediate retrieval can use it.
      _jsonChunksCache = (chunks).map((c) {
        final embRaw = c['embedding'] as Map? ?? {};
        final emb = embRaw.map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        );
        return {'chunkText': c['chunkText'] as String? ?? '', 'embedding': emb};
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Load the CLI-produced `rag_index.json` into memory. This does not write
  /// to the SQLite DB; it simply caches the chunks for fast retrieval. Use
  /// this when you prefer read-only use of an external index file.
  Future<void> loadJsonIndex([String? jsonPath]) async {
    // Attempt several locations for the index file. Priority:
    // 1) explicit jsonPath param
    // 2) application documents directory (useful for files copied to app storage)
    // 3) bundled asset at assets/rag_index.json (useful for including the index at build time)
    String? content;
    if (jsonPath != null) {
      final f = File(jsonPath);
      if (await f.exists()) {
        content = await f.readAsString();
      } else {
        throw Exception('Index file not found: $jsonPath');
      }
    } else {
      // check app documents directory
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final candidate = p.join(docsDir.path, 'rag_index.json');
        final fc = File(candidate);
        if (await fc.exists()) {
          content = await fc.readAsString();
        }
      } catch (_) {}

      // fallback to asset bundle
      if (content == null) {
        try {
          content = await rootBundle.loadString('assets/rag_index.json');
        } catch (_) {
          // asset not present or failed to load
        }
      }

      if (content == null)
        throw Exception('Index file not found in documents or assets');
    }
    final Map<String, dynamic> data = jsonDecode(content);
    final List<dynamic> chunks = data['chunks'] ?? [];
    _jsonChunksCache = chunks.map((c) {
      // normalize embedding values to double
      final embRaw = c['embedding'] as Map? ?? {};
      final emb = embRaw.map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      );
      return {'chunkText': c['chunkText'] as String? ?? '', 'embedding': emb};
    }).toList();
  }
}
