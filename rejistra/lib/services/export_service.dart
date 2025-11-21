// rejistra/lib/services/export_service.dart
// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as ex;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ExportService {
  // =======================================================
  // --- EXPORTATION EXCEL (État de Groupe) ---
  // =======================================================
  static Future<void> exportGroupeToExcel({
    required List<DataColumn> columns,
    required List<DataRow> rows,
    required String groupe,
  }) async {
    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel[excel.getDefaultSheet()!];

      final headerCells = columns
          .map((col) => (col.label as Text).data)
          .toList();
      sheet.appendRow(headerCells
          .map((label) => ex.TextCellValue(label ?? ''))
          .toList());

      for (final row in rows) {
        final rowData = row.cells
            .map((cell) => (cell.child as Text).data)
            .toList();
        sheet.appendRow(rowData
            .map((data) => ex.TextCellValue(data ?? ''))
            .toList());
      }

      final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final fileName = 'Export-BAG-${groupe}_$now.xlsx';
      final fileBytes = excel.save();

      if (fileBytes != null) {
        _downloadBytes(fileBytes, fileName);
      }
    } catch (e) {
      debugPrint("Erreur Export Excel: $e");
    }
  }

  // =======================================================
  // --- EXPORTATION PDF (État de Groupe) ---
  // =======================================================
  static Future<void> exportGroupeToPdf({
    required List<DataColumn> columns,
    required List<DataRow> rows,
    required String site,
    required String groupe,
  }) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.latoRegular();
      final boldFont = await PdfGoogleFonts.latoBold();

      final headers = columns
          .map((col) => (col.label as Text).data ?? '')
          .toList();
      final data = rows.map((row) {
        return row.cells
            .map((cell) => (cell.child as Text).data ?? '')
            .toList();
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          header: (context) => _buildPdfHeader(
              'État par Groupe (BAG) - Site: $site | Groupe: $groupe',
              font: boldFont),
          build: (context) => [
            pw.Table.fromTextArray(
              headers: headers,
              data: data,
              headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: 'Export-BAG-${groupe}.pdf');
    } catch (e) {
      debugPrint("Erreur Export PDF (Groupe): $e");
    }
  }

  // =======================================================
  // --- EXPORTATION PDF (État Individuel) AVEC PHOTO ---
  // =======================================================
  static Future<void> exportIndividuelToPdf({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> payments,
  }) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.latoRegular();
      final boldFont = await PdfGoogleFonts.latoBold();

      final studentName = "${student['nom']} ${student['prenom'] ?? ''}";
      final studentId = student['id_etudiant_genere'];
      final studentGroupe = student['groupe'];
      final studentStatut = student['statut'];
      final studentSite = student['site'];
      final photoUrl = student['photo_url'];

      // Télécharger la photo si disponible
      pw.MemoryImage? photoImage;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(photoUrl));
          if (response.statusCode == 200) {
            photoImage = pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          debugPrint("Erreur téléchargement photo: $e");
        }
      }

      final headers = ['Date', 'Motif', 'Mois', 'Nº Reçu', 'Montant (Ar)'];
      final data = payments.map((p) {
        final recu = p['recus'];
        return [
          DateFormat('dd/MM/yy').format(DateTime.parse(recu['date_paiement'])),
          p['motif'],
          p['mois_de'] ?? 'N/A',
          recu['n_recu_principal'],
          NumberFormat.decimalPattern('fr').format(p['montant']),
        ];
      }).toList();

      // Calculer le total des paiements
      double totalPaiements = 0;
      for (var p in payments) {
        totalPaiements += (p['montant'] as num).toDouble();
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // En-tête avec logo/titre
                _buildPdfHeader('État Individuel', font: boldFont),
                pw.SizedBox(height: 20),

                // Section photo + infos
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Photo de profil
                    pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400, width: 1),
                        borderRadius: pw.BorderRadius.circular(40),
                      ),
                      child: photoImage != null
                          ? pw.ClipRRect(
                        horizontalRadius: 40,
                        verticalRadius: 40,
                        child: pw.Image(photoImage, fit: pw.BoxFit.cover),
                      )
                          : pw.Center(
                        child: pw.Text('Photo',
                            style: pw.TextStyle(
                                font: font, color: PdfColors.grey500)),
                      ),
                    ),
                    pw.SizedBox(width: 20),

                    // Informations de l'étudiant
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(studentName,
                              style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 18,
                                  color: PdfColors.blueGrey800)),
                          pw.SizedBox(height: 8),
                          _buildInfoRow('ID Étudiant:', studentId, font, boldFont),
                          _buildInfoRow('Site:', studentSite ?? 'N/A', font, boldFont),
                          _buildInfoRow('Groupe:', studentGroupe ?? 'N/A', font, boldFont),
                          _buildInfoRow('Statut:', studentStatut ?? 'N/A', font, boldFont),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Divider(height: 30, thickness: 1),

                // Titre section financière
                pw.Text('Historique Financier',
                    style: pw.TextStyle(font: boldFont, fontSize: 16)),
                pw.SizedBox(height: 10),

                // Tableau des paiements
                pw.Table.fromTextArray(
                  headers: headers,
                  data: data,
                  headerStyle:
                  pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10),
                  headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
                  cellStyle: pw.TextStyle(font: font, fontSize: 10),
                  cellAlignments: {
                    4: pw.Alignment.centerRight,
                  },
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                ),

                pw.SizedBox(height: 16),

                // Total
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blueGrey100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text('Total Paiements: ',
                              style: pw.TextStyle(font: boldFont, fontSize: 12)),
                          pw.Text(
                              '${NumberFormat.decimalPattern('fr').format(totalPaiements)} Ar',
                              style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 14,
                                  color: PdfColors.blueGrey800)),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),

                // Pied de page
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
                    pw.Text('iTo REJISTRA - Gestion Académique',
                        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
                  ],
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: 'Etat-Individuel-$studentId.pdf');
    } catch (e) {
      debugPrint("Erreur Export PDF (Individuel): $e");
    }
  }

  // --- Helpers Privés ---

  static void _downloadBytes(List<int> bytes, String fileName) {
    final blob = html.Blob([Uint8List.fromList(bytes)],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static pw.Widget _buildPdfHeader(String title, {required pw.Font font}) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border(
            bottom: pw.BorderSide(width: 2, color: PdfColors.blueGrey800)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(font: font, fontSize: 18),
      ),
    );
  }

  static pw.Widget _buildInfoRow(
      String label, String value, pw.Font font, pw.Font boldFont) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 10)),
          pw.SizedBox(width: 8),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10)),
        ],
      ),
    );
  }
}