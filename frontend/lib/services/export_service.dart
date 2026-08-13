/// Export Service for generating CSV & PDF/Formatted report files for transaction history.
class ExportService {
  /// Generates CSV content string from transaction list
  static String generateCSV(List<Map<String, dynamic>> transactions) {
    final StringBuffer csv = StringBuffer();
    // CSV Header
    csv.writeln('ID,Date,CardName,CardType,Amount,Status');

    for (var tx in transactions) {
      final id = tx['id'] ?? '';
      final date = tx['date'] ?? '';
      final cardName = '"${(tx['cardName'] ?? '').toString().replaceAll('"', '""')}"';
      final cardType = tx['cardType'] ?? 'NFC';
      final amount = tx['amount'] ?? 0;
      final status = tx['status'] ?? 'Success';
      csv.writeln('$id,$date,$cardName,$cardType,$amount,$status');
    }
    return csv.toString();
  }

  /// Generates Formatted PDF Document text report from transaction list
  static String generatePDFReport(List<Map<String, dynamic>> transactions) {
    final StringBuffer pdf = StringBuffer();
    pdf.writeln('====================================================');
    pdf.writeln('            HYDRANGE NFC WALLET - REPORT            ');
    pdf.writeln('====================================================');
    pdf.writeln('Generated Date: ${DateTime.now().toLocal()}');
    pdf.writeln('Total Transactions: ${transactions.length}\n');
    pdf.writeln('----------------------------------------------------');
    pdf.writeln('ID   | Date       | Card Name     | Amount | Status ');
    pdf.writeln('----------------------------------------------------');

    for (var tx in transactions) {
      final id = (tx['id'] ?? '').toString().padRight(4);
      final date = (tx['date'] ?? '').toString().padRight(10);
      final rawCardName = (tx['cardName'] ?? '').toString();
      final cardName = rawCardName.length > 13 ? rawCardName.substring(0, 13) : rawCardName.padRight(13);
      final amount = '\$${tx['amount'] ?? 0}'.padRight(7);
      final status = (tx['status'] ?? 'Success');
      pdf.writeln('$id | $date | $cardName | $amount | $status');
    }
    pdf.writeln('----------------------------------------------------');
    pdf.writeln('End of Report');
    return pdf.toString();
  }
}
