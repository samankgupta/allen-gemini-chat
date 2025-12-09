# GWSB Front Desk Assistant

Welcome to the GWSB Front Desk mobile app. This Flutter app provides two main features:

- Chat: text chat with a Gemini-backed assistant that always includes context from a local RAG JSON index.
- Speech: speak to the assistant (speech-to-text), then automatically play the assistant's spoken reply (text-to-speech). A Stop button cancels playback.

## Visual Overview

App flow (high level):

```
  +----------------------+      +-------------------+      +---------------------+
  |     User (Phone)     | <--> |    Allen App UI   | <--> |   Local RagService  |
  |  (Chat / Speech UI)  |      | (Chat & Speech)   |      |      (JSON)         |
  +----------------------+      +-------------------+      +---------------------+
                                           |
                                           v
                                 +----------------------+
                                 |  Gemini API          |
                                 | (assistant responses)|
                                 +----------------------+
```

On Speech: the app uses `speech_to_text` for STT and `flutter_tts` for TTS (auto-play + Stop).
RAG retrieval uses a simple, local TF-based embedding (term frequency) read from a
CLI-produced `rag_index.json` for fast, read-only retrieval.

## Key files

- `bin/index_doc.dart` — CLI that takes a `.docx` and writes `rag_index.json` (chunks + embeddings).
- `lib/rag_service.dart` — local RAG logic: extract, chunk, compute embeddings, and retrieve top-k from the JSON index.
- `lib/openai_service.dart` — Gemini wrapper that composes messages (system instruction + doc chunks + user question).
- `lib/chat_page.dart` — chat UI wired to RAG + Gemini.
- `lib/speech_page.dart` — speech UI with STT and TTS (auto-play replies + Stop).

## One-time indexing (CLI)

Use the included CLI to build the RAG index from your DOCX. This is a one-time, local operation you run on your machine:

```bash
# from project root
dart run bin/index_doc.dart /path/to/your-document.docx
# writes rag_index.json to the project root
```

The produced `rag_index.json` contains a `docName` and a `chunks` array where each chunk has `chunkText` and a local embedding (term-frequency map).


## Quick simulator check (no signing)


```bash
flutter build ios --simulator
```

This does not require codesigning and is a fast way to confirm the app compiles and that `assets/rag_index.json` is included.
