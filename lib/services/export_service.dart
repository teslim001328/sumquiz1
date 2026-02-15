import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:intl/intl.dart';
import 'package:sumquiz/services/download/download_helper.dart';

class ExportService {
  /// Generates a PDF containing the Summary, Quiz, and Flashcards
  /// Returns the file bytes
  Future<List<int>> generatePdf({
    LocalSummary? summary,
    LocalQuiz? quiz,
    LocalFlashcardSet? flashcardSet,
  }) async {
    // Create a new PDF document
    final PdfDocument document = PdfDocument();

    // -- STYLES --
    final PdfStandardFont titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold);
    final PdfStandardFont headerFont =
        PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfStandardFont subHeaderFont =
        PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final PdfStandardFont bodyFont =
        PdfStandardFont(PdfFontFamily.helvetica, 12);
    final PdfStandardFont smallFont = PdfStandardFont(
        PdfFontFamily.helvetica, 10,
        style: PdfFontStyle.italic);

    PdfPage? lastPage;
    double yPos = 0;

    // Helper to get or add page
    PdfPage getPage() {
      if (lastPage == null || yPos >= lastPage!.getClientSize().height - 50) {
        // Add new page if current one is full or no page exists
        lastPage = document.pages.add();
        yPos = 0; // Reset yPos for the new page
      }
      return lastPage!;
    }

    // -- SECTION 1: SUMMARY --
    if (summary != null) {
      final page = getPage();

      // Title
      page.graphics.drawString(summary.title, titleFont,
          bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width, 30));
      yPos += 40;

      // Meta
      final dateStr = DateFormat.yMMMd().format(summary.timestamp);
      page.graphics.drawString('Generated on $dateStr via SumQuiz', smallFont,
          bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width, 20));
      yPos += 30;

      // Divider
      page.graphics.drawLine(PdfPen(PdfColor(200, 200, 200)), Offset(0, yPos),
          Offset(page.getClientSize().width, yPos));
      yPos += 20;

      // Summary Header
      page.graphics.drawString('Summary', headerFont,
          bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width, 25));
      yPos += 30;

      final PdfTextElement summaryElement = PdfTextElement(
        text: summary.content,
        font: bodyFont,
      );

      var layoutResult = summaryElement.draw(
        page: page,
        bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width,
            page.getClientSize().height - yPos),
      );

      if (layoutResult != null) {
        lastPage = layoutResult.page;
        yPos = layoutResult.bounds.bottom + 20;
      }
    }

    // -- SECTION 2: QUIZ --
    if (quiz != null) {
      // Start new page for Quiz if we already have content
      if (summary != null) {
        lastPage = document.pages.add();
        yPos = 0;
      }
      final page = getPage();

      page.graphics.drawString('Quiz: ${quiz.title}', headerFont,
          bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width, 25));
      yPos += 30;

      final StringBuffer quizBuffer = StringBuffer();
      for (int i = 0; i < quiz.questions.length; i++) {
        final q = quiz.questions[i];
        quizBuffer.writeln('${i + 1}. ${q.question}');
        for (final opt in q.options) {
          quizBuffer.writeln('   - $opt');
        }
        quizBuffer.writeln('');
      }

      final PdfTextElement quizElement =
          PdfTextElement(text: quizBuffer.toString(), font: bodyFont);

      var layoutResult = quizElement.draw(
          page: page,
          bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width,
              page.getClientSize().height - yPos));

      if (layoutResult != null) {
        lastPage = layoutResult.page;
        yPos = layoutResult.bounds.bottom + 20;
      }
    }

    // -- SECTION 3: FLASHCARDS --
    if (flashcardSet != null) {
      // Start new page for Flashcards if we already have content
      if (summary != null || quiz != null) {
        lastPage = document.pages.add();
        yPos = 0;
      }
      final page = getPage();

      page.graphics.drawString('Flashcards: ${flashcardSet.title}', headerFont,
          bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width, 25));
      yPos += 30;

      final StringBuffer flashBuffer = StringBuffer();
      for (int i = 0; i < flashcardSet.flashcards.length; i++) {
        final f = flashcardSet.flashcards[i];
        flashBuffer.writeln('Q: ${f.question}');
        flashBuffer.writeln('A: ${f.answer}');
        flashBuffer.writeln('----------------------------------------');
        flashBuffer.writeln('');
      }

      final PdfTextElement flashElement =
          PdfTextElement(text: flashBuffer.toString(), font: bodyFont);

      flashElement.draw(
          page: page,
          bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width,
              page.getClientSize().height - yPos));
    }

    // Save
    final List<int> bytes = await document.save();
    document.dispose();
    return bytes;
  }

  /// Exports the PDF.
  Future<void> exportPdf(
    BuildContext context, {
    LocalSummary? summary,
    LocalQuiz? quiz,
    LocalFlashcardSet? flashcardSet,
  }) async {
    try {
      if (summary == null && quiz == null && flashcardSet == null) return;

      // If summary is null but others exist, we need a title for the file name
      String title = 'Export';
      if (summary != null) {
        title = summary.title;
      } else if (quiz != null)
        title = quiz.title;
      else if (flashcardSet != null) title = flashcardSet.title;

      final bytes = await generatePdf(
          summary: summary, quiz: quiz, flashcardSet: flashcardSet);

      final String fileName = 'SumQuiz_${title.replaceAll(' ', '_')}.pdf';

      await downloadPdf(bytes, fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            // Use a simple message here, behavior handled by downloadPdf roughly
            const SnackBar(content: Text('Export started...')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Export failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
