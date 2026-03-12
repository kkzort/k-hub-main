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

  String get sourceLabel => isPdf ? 'PDF' : 'Fotograf';

  String get sourceLabelLower => isPdf ? 'pdf' : 'fotograf';

  String get unitLabel => isPdf ? 'sayfa' : 'gorsel';
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
      'Fotograf metin okuma bu cihaz kombinasyonunda gecici olarak devre disi. PDF yuklemeyi deneyebilirsin.',
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
          'Fotografta okunabilir metin bulunamadi. Not, slayt veya ekran goruntusu gibi metin agirlikli bir fotograf dene.',
        );
      }
      throw Exception(
        'PDF metni okunamadi. Daha net metin iceren bir PDF dene.',
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
      buffer.writeln('Fotograftaki metin tarandi ve ozetlendi.');
    }

    buffer
      ..writeln()
      ..writeln('Kisa ozet:')
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
        ..writeln('Calisma sorulari:');
      for (final question in analysis.studyQuestions.take(2)) {
        buffer.writeln('- $question');
      }
    }

    buffer
      ..writeln()
      ..write(
        analysis.isPdf
            ? 'Istersen bu PDF icin soru-cevap, daha kisa ozet veya sinav hazirligi yapabilirim.'
            : 'Istersen bu fotograf icin daha kisa ozet, ana noktalar veya soru-cevap yapabilirim.',
      );

    return buffer.toString();
  }

  String replyToPrompt(String prompt, {KBotDocumentAnalysis? document}) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return 'Bir mesaj yazarsan yardimci olabilirim.';
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
    final source = document?.sourceLabelLower ?? 'dokuman';

    if (lower.contains('merhaba') || lower.contains('selam')) {
      return hasDocument
          ? 'Merhaba! Yukledigin $source ile ilgili soru sorabilir ya da benden genel bir calisma yardimi isteyebilirsin.'
          : 'Merhaba! Ben K-Bot. PDF ve fotograf ozetleri cikarabilir, calisma plani hazirlayabilir ve genel amacli bir ogrenim asistani gibi yardimci olabilirim.';
    }

    if (lower.contains('calisma plani')) {
      return 'Hizli bir calisma plani onerisi:\n\n1. Konuyu 3 ana basliga ayir.\n2. Her baslik icin 25 dakikalik odak bloklari kur.\n3. Her blok sonunda 5 dakikada kendi kendine tekrar yap.\n4. En sonda 10 soruluk mini test hazirla.\n\nIstersen konuyu yaz, bunu sana o konuya gore ozellestireyim.';
    }

    if (lower.contains('soru hazirla') ||
        lower.contains('soru uret') ||
        lower.contains('quiz')) {
      return 'Sana soru hazirlayabilirim. En iyi sonuc icin ya PDF/fotograf yukle ya da konuyu net yaz: ornek olarak "anayasa konusu icin 5 soru hazirla".';
    }

    if (lower.contains('ozet')) {
      return hasDocument
          ? 'Yuklu $source icin daha kisa ozet, madde madde ozet veya ana fikir cikarabilirim. Ne tur bir ozet istedigini yazman yeterli.'
          : 'Ozet cikarmam icin once bir PDF veya fotograf yukle. PDF olmadan da herhangi bir konu icin kisa aciklama veya calisma plani verebilirim.';
    }

    if (lower.contains('ne yapabiliyorsun') || lower.contains('yardim')) {
      return 'Yapabileceklerim:\n\n- PDF yukleyip kisa ozet cikarmak\n- Fotograf veya ekran goruntusundeki metni ozetlemek\n- Yuklenen dokuman icin soru-cevap yapmak\n- Ana noktalar ve calisma sorulari uretmek\n- Genel calisma asistani gibi plan ve yonlendirme vermek';
    }

    return hasDocument
        ? 'Yuklu $source uzerinden devam edebilirim. Ornek sorular:\n\n- "Ana fikri ne?"\n- "3 maddede ozetle"\n- "Bu konudan 5 soru hazirla"\n- "Sinav icin kritik yerleri cikar"'
        : 'Ben K-Bot. Su an cihaz ici calisan premium bir ogrenim asistaniyim. Bir PDF veya fotograf yukleyebilir ya da dogrudan bir konu yazip ozet, plan ve soru isteyebilirsin.';
  }

  String? _buildDocumentReply(String prompt, KBotDocumentAnalysis document) {
    final lower = prompt.toLowerCase();
    final source = document.isPdf ? 'PDF' : 'fotograf';

    if (lower.contains('ozet')) {
      return '$source ozeti:\n\n${document.shortSummary}';
    }

    if (lower.contains('ana fikir') ||
        lower.contains('ana nokta') ||
        lower.contains('madde')) {
      final bulletLines = document.keyPoints
          .take(4)
          .map((item) => '- $item')
          .join('\n');
      return 'Bu $source icin one cikan noktalar:\n\n$bulletLines';
    }

    if (lower.contains('soru') ||
        lower.contains('quiz') ||
        lower.contains('sinav')) {
      final questionLines = document.studyQuestions
          .take(4)
          .map((item) => '- $item')
          .join('\n');
      return 'Bu $source uzerinden calisabilecegin sorular:\n\n$questionLines';
    }

    final relevantSentences = _findRelevantSentences(
      prompt,
      document.fullText,
      maxCount: 3,
    );

    if (relevantSentences.isEmpty) {
      return 'Bu soruya dogrudan baglanan bir bolum bulamadim. Dilersen "ana noktalar", "ozet" veya "soru hazirla" gibi daha net bir istekle devam edelim.';
    }

    return '$source gore en ilgili kisimlar:\n\n${relevantSentences.map((line) => '- $line').join('\n')}\n\nIstersen bunu daha kisa, daha detayli ya da soru-cevap formatinda duzenleyebilirim.';
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
        ? '$fileName dokumaninin'
        : '$fileName fotografindaki metnin';

    if (rankedSentences.isEmpty) {
      return [
        '$baseTopic ana fikrini bir paragrafta acikla.',
        '$baseTopic sinavda cikabilecek 3 kritik konusu nedir?',
      ];
    }

    return rankedSentences.take(3).map((sentence) {
      final shortened = sentence.length > 90
          ? '${sentence.substring(0, 90).trim()}...'
          : sentence;
      return 'Su ifadeyi acikla ve ornekle: "$shortened"';
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
