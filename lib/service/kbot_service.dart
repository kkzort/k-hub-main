import 'dart:io';
import 'dart:math' as math;

import 'package:pdf_text_extract/pdf_text_extract.dart';

enum KBotDocumentType { pdf, image }

class KBotDocumentAnalysis {
  final KBotDocumentType type;
  final String fileName;
  final String fullText;
  final String shortSummary;
  final List<String> keyPoints;
  final List<String> studyQuestions;
  final int unitCount;

  const KBotDocumentAnalysis({
    required this.type,
    required this.fileName,
    required this.fullText,
    required this.shortSummary,
    required this.keyPoints,
    required this.studyQuestions,
    required this.unitCount,
  });

  bool get isPdf => type == KBotDocumentType.pdf;

  bool get isImage => type == KBotDocumentType.image;

  String get sourceLabel => isPdf ? 'PDF' : 'Fotoğraf';

  String get sourceLabelLower => isPdf ? 'pdf' : 'fotoğraf';

  String get unitLabel => isPdf ? 'sayfa' : 'görsel';
}

class KBotService {
  static const Set<String> _stopWords = {
    've',
    'veya',
    'ile',
    'icin',
    'ama',
    'fakat',
    'gibi',
    'daha',
    'cok',
    'az',
    'bir',
    'bu',
    'su',
    'o',
    'da',
    'de',
    'mi',
    'mu',
    'midir',
    'ise',
    'olarak',
    'olan',
    'olur',
    'olanlar',
    'kadar',
    'sonra',
    'once',
    'uzere',
    'the',
    'and',
    'or',
    'with',
    'for',
    'that',
    'from',
    'into',
    'about',
    'have',
    'has',
    'had',
    'will',
    'would',
    'could',
    'should',
  };

  Future<KBotDocumentAnalysis> analyzePdf(File file, {String? fileName}) async {
    final document = await PDFDoc.fromFile(file);
    final rawText = await document.text;

    return _buildAnalysis(
      type: KBotDocumentType.pdf,
      fileName: fileName ?? _fileNameFromPath(file.path),
      rawText: rawText,
      unitCount: document.length,
    );
  }

  Future<KBotDocumentAnalysis> analyzeImage(
    File file, {
    String? fileName,
  }) async {
    throw Exception(
      'Fotoğraf metin okuma bu cihaz kombinasyonunda geçici olarak devre dışı. PDF yüklemeyi deneyebilirsin.',
    );
  }

  KBotDocumentAnalysis _buildAnalysis({
    required KBotDocumentType type,
    required String fileName,
    required String rawText,
    required int unitCount,
  }) {
    final normalizedText = _normalizeText(rawText);
    final minimumLength = type == KBotDocumentType.image ? 25 : 80;

    if (normalizedText.length < minimumLength) {
      if (type == KBotDocumentType.image) {
        throw Exception(
          'Fotoğrafta okunabilir metin bulunamadı. Not, slayt veya ekran görüntüsü gibi metin ağırlıklı bir fotoğraf dene.',
        );
      }
      throw Exception(
        'PDF metni okunamadı. Daha net metin içeren bir PDF dene.',
      );
    }

    final rankedSentences = _rankSentences(normalizedText, maxCount: 5);
    final summary = _buildSummary(normalizedText, rankedSentences);
    final keyPoints = rankedSentences.take(4).toList();
    final questions = _buildStudyQuestions(
      fileName: fileName,
      rankedSentences: rankedSentences,
      type: type,
    );

    return KBotDocumentAnalysis(
      type: type,
      fileName: fileName,
      fullText: normalizedText,
      shortSummary: summary,
      keyPoints: keyPoints,
      studyQuestions: questions,
      unitCount: unitCount,
    );
  }

  String buildDocumentSummaryMessage(KBotDocumentAnalysis analysis) {
    final buffer = StringBuffer()
      ..writeln('${analysis.sourceLabel} hazir: ${analysis.fileName}')
      ..writeln();

    if (analysis.isPdf) {
      buffer.writeln('Boyut: ${analysis.unitCount} ${analysis.unitLabel}');
    } else {
      buffer.writeln('Fotoğraftaki metin tarandı ve özetlendi.');
    }

    buffer
      ..writeln()
      ..writeln('Kısa özet:')
      ..writeln(analysis.shortSummary);

    if (analysis.keyPoints.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Ana noktalar:');
      for (final point in analysis.keyPoints.take(3)) {
        buffer.writeln('- $point');
      }
    }

    if (analysis.studyQuestions.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Çalışma soruları:');
      for (final question in analysis.studyQuestions.take(2)) {
        buffer.writeln('- $question');
      }
    }

    buffer
      ..writeln()
      ..write(
        analysis.isPdf
            ? 'İstersen bu PDF için soru-cevap, daha kısa özet veya sınav hazırlığı yapabilirim.'
            : 'İstersen bu fotoğraf için daha kısa özet, ana noktalar veya soru-cevap yapabilirim.',
      );

    return buffer.toString();
  }

  String replyToPrompt(String prompt, {KBotDocumentAnalysis? document}) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return 'Bir mesaj yazarsan yardımcı olabilirim.';
    }

    if (document != null) {
      final documentReply = _buildDocumentReply(trimmed, document);
      if (documentReply != null) {
        return documentReply;
      }
    }

    return _buildGeneralReply(trimmed, document: document);
  }

  String _buildGeneralReply(String prompt, {KBotDocumentAnalysis? document}) {
    final lower = prompt.toLowerCase();
    final hasDocument = document != null;
    final source = document?.sourceLabelLower ?? 'doküman';

    if (lower.contains('merhaba') || lower.contains('selam')) {
      return hasDocument
          ? 'Merhaba! Yüklediğin $source ile ilgili soru sorabilir ya da benden genel bir çalışma yardımı isteyebilirsin.'
          : 'Merhaba! Ben K-Bot. PDF ve fotoğraf özetleri çıkarabilir, çalışma planı hazırlayabilir ve genel amaçlı bir öğrenim asistanı gibi yardımcı olabilirim.';
    }

    if (lower.contains('calisma plani')) {
      return 'Hızlı bir çalışma planı önerisi:\n\n1. Konuyu 3 ana başlığa ayır.\n2. Her başlık için 25 dakikalık odak blokları kur.\n3. Her blok sonunda 5 dakikada kendi kendine tekrar yap.\n4. En sonda 10 soruluk mini test hazırla.\n\nİstersen konuyu yaz, bunu sana o konuya göre özelleştireyim.';
    }

    if (lower.contains('soru hazirla') ||
        lower.contains('soru uret') ||
        lower.contains('quiz')) {
      return 'Sana soru hazırlayabilirim. En iyi sonuç için ya PDF/fotoğraf yükle ya da konuyu net yaz: örnek olarak "anayasa konusu için 5 soru hazırla".';
    }

    if (lower.contains('ozet')) {
      return hasDocument
          ? 'Yüklü $source için daha kısa özet, madde madde özet veya ana fikir çıkarabilirim. Ne tür bir özet istediğini yazman yeterli.'
          : 'Özet çıkarmam için önce bir PDF veya fotoğraf yükle. PDF olmadan da herhangi bir konu için kısa açıklama veya çalışma planı verebilirim.';
    }

    if (lower.contains('ne yapabiliyorsun') || lower.contains('yardim')) {
      return 'Yapabileceklerim:\n\n- PDF yükleyip kısa özet çıkarmak\n- Fotoğraf veya ekran görüntüsündeki metni özetlemek\n- Yüklenen doküman için soru-cevap yapmak\n- Ana noktalar ve çalışma soruları üretmek\n- Genel çalışma asistanı gibi plan ve yönlendirme vermek';
    }

    return hasDocument
        ? 'Yüklü $source üzerinden devam edebilirim. Örnek sorular:\n\n- "Ana fikri ne?"\n- "3 maddede özetle"\n- "Bu konudan 5 soru hazırla"\n- "Sınav için kritik yerleri çıkar"'
        : 'Ben K-Bot. Şu an cihaz içi çalışan premium bir öğrenim asistanıyım. Bir PDF veya fotoğraf yükleyebilir ya da doğrudan bir konu yazıp özet, plan ve soru isteyebilirsin.';
  }

  String? _buildDocumentReply(String prompt, KBotDocumentAnalysis document) {
    final lower = prompt.toLowerCase();
    final source = document.isPdf ? 'PDF' : 'fotoğraf';

    if (lower.contains('ozet')) {
      return '$source özeti:\n\n${document.shortSummary}';
    }

    if (lower.contains('ana fikir') ||
        lower.contains('ana nokta') ||
        lower.contains('madde')) {
      final bulletLines = document.keyPoints
          .take(4)
          .map((item) => '- $item')
          .join('\n');
      return 'Bu $source için öne çıkan noktalar:\n\n$bulletLines';
    }

    if (lower.contains('soru') ||
        lower.contains('quiz') ||
        lower.contains('sinav')) {
      final questionLines = document.studyQuestions
          .take(4)
          .map((item) => '- $item')
          .join('\n');
      return 'Bu $source üzerinden çalışabileceğin sorular:\n\n$questionLines';
    }

    final relevantSentences = _findRelevantSentences(
      prompt,
      document.fullText,
      maxCount: 3,
    );

    if (relevantSentences.isEmpty) {
      return 'Bu soruya doğrudan bağlanan bir bölüm bulamadım. Dilersen "ana noktalar", "özet" veya "soru hazırla" gibi daha net bir istekle devam edelim.';
    }

    return '$source göre en ilgili kısımlar:\n\n${relevantSentences.map((line) => '- $line').join('\n')}\n\nİstersen bunu daha kısa, daha detaylı ya da soru-cevap formatında düzenleyebilirim.';
  }

  List<String> _findRelevantSentences(
    String prompt,
    String text, {
    int maxCount = 3,
  }) {
    final sentences = _splitSentences(
      text,
    ).where((sentence) => sentence.length >= 30).toList();
    final promptTokens = _keywords(prompt);
    if (promptTokens.isEmpty) return const [];

    final ranked = <MapEntry<String, double>>[];
    for (final sentence in sentences) {
      final sentenceTokens = _keywords(sentence);
      if (sentenceTokens.isEmpty) continue;

      double score = 0;
      for (final token in promptTokens) {
        if (sentenceTokens.contains(token)) {
          score += 2;
        }
        if (sentence.toLowerCase().contains(token)) {
          score += 1;
        }
      }

      if (score > 0) {
        score += math.min(sentence.length / 180, 1.2);
        ranked.add(MapEntry(sentence, score));
      }
    }

    ranked.sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(maxCount).map((entry) => entry.key).toList();
  }

  List<String> _rankSentences(String text, {int maxCount = 5}) {
    final sentences = _splitSentences(
      text,
    ).where((sentence) => sentence.length >= 40).toList();
    final frequencies = _wordFrequencies(text);
    final ranked = <MapEntry<String, double>>[];

    for (final sentence in sentences) {
      final words = _keywords(sentence);
      if (words.isEmpty) continue;

      double score = 0;
      for (final word in words) {
        score += frequencies[word] ?? 0;
      }

      score = score / words.length;
      if (sentence.length > 220) {
        score *= 0.88;
      }
      if (sentence.length < 55) {
        score *= 0.82;
      }
      ranked.add(MapEntry(sentence, score));
    }

    ranked.sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(maxCount).map((entry) => entry.key).toList();
  }

  String _buildSummary(String text, List<String> rankedSentences) {
    final intro = _firstMeaningfulParagraph(text);
    final selected = <String>[];

    if (intro.isNotEmpty) {
      selected.add(intro);
    }

    for (final sentence in rankedSentences) {
      if (selected.any(
        (item) => item.toLowerCase() == sentence.toLowerCase(),
      )) {
        continue;
      }
      selected.add(sentence);
      if (selected.length >= 3) break;
    }

    return selected.join(' ');
  }

  List<String> _buildStudyQuestions({
    required String fileName,
    required List<String> rankedSentences,
    required KBotDocumentType type,
  }) {
    final baseTopic = type == KBotDocumentType.pdf
        ? '$fileName dokümanının'
        : '$fileName fotoğrafındaki metnin';

    if (rankedSentences.isEmpty) {
      return [
        '$baseTopic ana fikrini bir paragrafta açıkla.',
        '$baseTopic sınavda çıkabilecek 3 kritik konusu nedir?',
      ];
    }

    return rankedSentences.take(3).map((sentence) {
      final shortened = sentence.length > 90
          ? '${sentence.substring(0, 90).trim()}...'
          : sentence;
      return 'Şu ifadeyi açıkla ve örnekle: "$shortened"';
    }).toList();
  }

  Map<String, double> _wordFrequencies(String text) {
    final frequencies = <String, double>{};
    for (final word in _keywords(text)) {
      frequencies[word] = (frequencies[word] ?? 0) + 1;
    }
    return frequencies;
  }

  List<String> _keywords(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll('c', 'c')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    return normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2 && !_stopWords.contains(word.trim()))
        .toList();
  }

  List<String> _splitSentences(String text) {
    return text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((sentence) => sentence.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((sentence) => sentence.isNotEmpty)
        .toList();
  }

  String _firstMeaningfulParagraph(String text) {
    final paragraphs = text
        .split(RegExp(r'\n{2,}'))
        .map((paragraph) => paragraph.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((paragraph) => paragraph.length >= 60)
        .toList();

    return paragraphs.isEmpty ? '' : paragraphs.first;
  }

  String _normalizeText(String text) {
    return text
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' ?\n ?'), '\n')
        .trim();
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }
}
