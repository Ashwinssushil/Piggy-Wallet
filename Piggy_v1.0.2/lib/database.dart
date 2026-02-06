import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;
  List<Map<String, dynamic>>? _cachedTransactions;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'transactions.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            date TEXT,
            amount TEXT,
            isPositive INTEGER
          )
        ''');
        await db.execute('CREATE INDEX idx_date ON transactions(date)');
        await db
            .execute('CREATE INDEX idx_isPositive ON transactions(isPositive)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_date ON transactions(date)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_isPositive ON transactions(isPositive)');
        }
      },
    );
  }

  Future<void> insertTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    await db.insert('transactions', transaction);
    _invalidateCache();
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    if (_cachedTransactions != null) {
      return _cachedTransactions!;
    }

    final db = await database;
    _cachedTransactions = await db.query('transactions', orderBy: 'date DESC');
    return _cachedTransactions!;
  }

  void _invalidateCache() {
    _cachedTransactions = null;
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    _invalidateCache();
  }

  Future<void> deleteSelectedTransactions(List<int> ids) async {
    final db = await database;
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.delete(
      'transactions',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    _invalidateCache();
  }

  Future<void> clearAllTransactions() async {
    final db = await database;
    await db.delete('transactions');
    _invalidateCache();
  }

  Future<int> importFromCSV(String filePath) async {
    List<String> lines;
    
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }

      final content = await file.readAsString();
      lines = content.split(RegExp(r'\r?\n'));

      if (lines.isEmpty || lines.length < 2) {
        throw Exception('Invalid CSV format');
      }
    } catch (e) {
      print('Error reading file: $e');
      throw Exception('Could not read the file. Please make sure it\'s a valid CSV file.');
    }

    final db = await database;
    int importCount = 0;

    var batch = db.batch();
    final batchSize = 100;
    
    final headerLine = lines[0].trim().toLowerCase();
    final headerValues = _parseCSVLine(headerLine);
    
    int idIndex = -1;
    int titleIndex = -1;
    int amountIndex = -1;
    int typeIndex = -1;
    int dateIndex = -1;
    
    for (int i = 0; i < headerValues.length; i++) {
      final header = headerValues[i].toLowerCase();
      if (header.contains('id')) idIndex = i;
      if (header.contains('title')) titleIndex = i;
      if (header.contains('amount')) amountIndex = i;
      if (header.contains('type')) typeIndex = i;
      if (header.contains('date')) dateIndex = i;
    }
    
    if (titleIndex == -1 || amountIndex == -1 || typeIndex == -1 || dateIndex == -1) {
      if (headerValues.length >= 5) {
        idIndex = 0;
        titleIndex = 1;
        amountIndex = 2;
        typeIndex = 3;
        dateIndex = 4;
      } else {
        throw Exception('CSV format not recognized. Expected columns: Title, Amount, Type, Date');
      }
    }

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      List<String> values = _parseCSVLine(line);

      if (values.length <= max(titleIndex, max(amountIndex, max(typeIndex, dateIndex)))) {
        continue;
      }

      try {
        final title = values[titleIndex].replaceAll('"', '');
        final amount = values[amountIndex].replaceAll('"', '');
        
        bool isPositive;
        if (typeIndex >= 0 && typeIndex < values.length) {
          final typeValue = values[typeIndex].toLowerCase();
          isPositive = typeValue.contains('credit') || 
                      typeValue.contains('income') || 
                      typeValue.contains('in');
        } else {
          isPositive = !amount.contains('-');
        }
        
        String dateStr = '';
        if (dateIndex >= 0 && dateIndex < values.length) {
          dateStr = values[dateIndex].trim();
          
          try {
            final parsedDate = DateTime.parse(dateStr);
            dateStr = parsedDate.toIso8601String();
          } catch (e) {
            try {
              final parts = dateStr.split('/');
              if (parts.length == 3) {
                final day = int.parse(parts[0]);
                final month = int.parse(parts[1]);
                final year = int.parse(parts[2]);
                dateStr = DateTime(year, month, day).toIso8601String();
              }
            } catch (e) {
              dateStr = DateTime.now().toIso8601String();
            }
          }
        } else {
          dateStr = DateTime.now().toIso8601String();
        }

        final transaction = {
          'title': title,
          'amount': amount,
          'isPositive': isPositive ? 1 : 0,
          'date': dateStr,
        };

        batch.insert('transactions', transaction);
        importCount++;

        if (importCount % batchSize == 0) {
          await batch.commit(noResult: true);
          batch = db.batch();
        }
      } catch (e) {
        print('Error importing row: $e');
      }
    }

    if (importCount % batchSize != 0) {
      await batch.commit(noResult: true);
    }

    _invalidateCache();
    return importCount;
  }
  
  List<String> _parseCSVLine(String line) {
    List<String> values = [];
    bool inQuotes = false;
    String currentValue = '';

    for (int j = 0; j < line.length; j++) {
      final char = line[j];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        values.add(currentValue);
        currentValue = '';
      } else {
        currentValue += char;
      }
    }

    values.add(currentValue);
    return values;
  }

  Future<String> backupToCSV() async {
    final transactions = await getTransactions();

    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
    } else {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    final appDir = Directory('${downloadsDir.path}/Piggy');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

    final backupDir = Directory('${appDir.path}/Backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final fileName =
        'Piggy_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final file = File('${backupDir.path}/$fileName');

    String csvContent = 'ID,Title,Amount,Type,Date\n';

    for (var transaction in transactions) {
      String type = transaction['isPositive'] == 1 ? 'Credit' : 'Debit';
      String date = transaction['date'] != null
          ? DateFormat('yyyy-MM-dd').format(DateTime.parse(transaction['date']))
          : '';

      csvContent +=
          '${transaction['id']},"${transaction['title']}","${transaction['amount']}",$type,$date\n';
    }

    await file.writeAsString(csvContent);
    return file.path;
  }

  Future<String> generateTransactionReport([String currency = '₹']) async {
    String pdfCurrency;
    switch (currency) {
      case '₹':
        pdfCurrency = 'Rs. ';
        break;
      case '\$':
        pdfCurrency = '\$ ';
        break;
      case '€':
        pdfCurrency = 'EUR ';
        break;
      case '£':
        pdfCurrency = 'GBP ';
        break;
      case '¥':
        pdfCurrency = 'JPY ';
        break;
      default:
        pdfCurrency = '$currency ';
    }
  
    final transactions = await getTransactions();

    double totalBalance = 0;
    double totalCredit = 0;
    double totalDebit = 0;

    for (var transaction in transactions) {
      String amountStr = transaction['amount']
          .toString()
          .replaceAll('₹', '')
          .replaceAll('\$', '')
          .replaceAll('€', '')
          .replaceAll('£', '')
          .replaceAll('¥', '')
          .replaceAll('-', '');
      double amount = double.tryParse(amountStr) ?? 0.0;

      if (transaction['isPositive'] == 1) {
        totalCredit += amount;
        totalBalance += amount;
      } else {
        totalDebit += amount;
        totalBalance -= amount;
      }
    }

    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
    } else {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    final appDir = Directory('${downloadsDir.path}/Piggy');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

    final pdfDir = Directory('${appDir.path}/PDF');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(60),
        build: (pw.Context context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.deepPurple,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Piggy Wallet Report',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('MMM dd, yyyy').format(DateTime.now()),
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 14)),
              ],
            ),
          ),

          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Current Balance',
                          style: pw.TextStyle(
                              fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('$pdfCurrency${totalBalance.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: totalBalance >= 0
                                  ? PdfColors.green
                                  : PdfColors.red)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Transactions',
                          style: pw.TextStyle(
                              fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('${transactions.length}',
                          style: pw.TextStyle(
                              fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          pw.Text('All Transactions',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          transactions.isEmpty
              ? pw.Text('No transactions found.')
              : pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black),
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('S.No',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Title',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Date',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Amount',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10)),
                        ),
                      ],
                    ),
                    ...transactions.asMap().entries.map((entry) {
                      int index = entry.key + 1;
                      var tx = entry.value;
                      bool isCredit = tx['isPositive'] == 1;
                      String amount = tx['amount'] ?? 'NULL';
                      String cleanAmount = amount
                          .replaceAll('₹', '')
                          .replaceAll('\$', '')
                          .replaceAll('€', '')
                          .replaceAll('£', '')
                          .replaceAll('¥', '')
                          .replaceAll('Rs.', '')
                          .replaceAll('-', '');

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color:
                              isCredit ? PdfColors.green300 : PdfColors.red300,
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('$index',
                                style: pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('${tx['title'] ?? ''}',
                                style: pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              tx['date'] != null
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(DateTime.parse(tx['date']))
                                  : '',
                              style: pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('$pdfCurrency$cleanAmount',
                                style: pw.TextStyle(fontSize: 9)),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),

          pw.SizedBox(height: 10),
          pw.Text('Total Records: ${transactions.length}',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Text(
            'Generated on ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())} | Piggy Wallet App',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final fileName =
        'Piggy_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    final file = File('${pdfDir.path}/$fileName');

    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}