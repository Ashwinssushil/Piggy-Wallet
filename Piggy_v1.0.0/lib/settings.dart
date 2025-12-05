import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'database.dart';

class SettingsPage extends StatefulWidget {
  final String userName;
  final String currency;
  final Function(String) onUsernameChanged;
  final Function(String) onCurrencyChanged;
  final VoidCallback? onDataCleared;

  const SettingsPage({
    super.key,
    required this.userName,
    required this.currency,
    required this.onUsernameChanged,
    required this.onCurrencyChanged,
    this.onDataCleared,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.deepPurple.withOpacity(0.7),
      ),
    );
  }

  void _changeUsername() {
    String newName = widget.userName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Change Username', style: TextStyle(color: Colors.white)),
        content: TextField(
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Enter new username',
            labelStyle: TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.grey[850],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (value) => newName = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () {
              if (newName.isNotEmpty) {
                widget.onUsernameChanged(newName);
                Navigator.pop(context);
                _showSnackBar('Username updated!');
              }
            },
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _changeCurrency() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Select Currency', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['₹', '\$', '€', '£', '¥']
              .map((curr) => ListTile(
                    title: Text(curr, style: TextStyle(color: Colors.white)),
                    onTap: () {
                      widget.onCurrencyChanged(curr);
                      Navigator.pop(context);
                      _showSnackBar('Currency changed to $curr');
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _clearAllData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Clear All Data', style: TextStyle(color: Colors.red)),
        content: Text(
            'This will delete all transactions permanently. Are you sure?',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper().clearAllTransactions();
              Navigator.pop(context);
              widget.onDataCleared?.call();
              _showSnackBar('All data cleared!');
            },
            child: Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _backupData() async {
    try {
      String filePath = await DatabaseHelper().backupToCSV();
      _showSnackBar('Backup finished: File saved successfully.');
    } catch (e) {
      _showSnackBar('Backup failed: $e');
    }
  }

  Future<String?> _getBackupFolderPath() async {
    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final backupDir = Directory('${downloadsDir.path}/Piggy/Backups');
      if (await backupDir.exists()) {
        return backupDir.path;
      }
    } catch (e) {
      print('Error getting backup folder: $e');
    }
    return null;
  }

  void _importData() async {
    try {
      // Try to get the backup folder path
      String? backupPath = await _getBackupFolderPath();

      if (backupPath != null) {
        _showSnackBar(
            'Look for CSV files in ${backupPath.split('/').last} folder');
      } else {
        _showSnackBar(
            'Look for CSV files in your Downloads/Piggy/Backups folder');
      }

      // Use file picker with minimal configuration
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select CSV Backup File',
      );

      if (result == null || result.files.isEmpty) {
        // User canceled the picker
        return;
      }

      final file = result.files.first;
      final filePath = file.path;

      if (filePath == null) {
        _showSnackBar('Could not access the selected file');
        return;
      }

      if (!filePath.toLowerCase().endsWith('.csv')) {
        _showSnackBar('Please select a CSV file');
        return;
      }

      // Confirm import with the selected file
      _confirmImport(filePath);
    } catch (e) {
      _showSnackBar('Error selecting file: $e');
    }
  }

  void _confirmImport(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Import Data', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will import transactions from the backup file. Do you want to clear existing data first?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performImport(filePath, clearExisting: false);
            },
            child: Text('Keep Existing', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performImport(filePath, clearExisting: true);
            },
            child: Text('Clear & Import',
                style: TextStyle(color: Colors.deepOrange)),
          ),
        ],
      ),
    );
  }

  void _performImport(String filePath, {required bool clearExisting}) async {
    try {
      // Simple validation
      if (!filePath.toLowerCase().endsWith('.csv')) {
        _showSnackBar('Selected file is not a CSV file');
        return;
      }

      // Clear existing data if requested
      if (clearExisting) {
        await DatabaseHelper().clearAllTransactions();
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.deepPurpleAccent),
                SizedBox(width: 20),
                Text('Importing data...',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          );
        },
      );

      // Import the data
      final importCount = await DatabaseHelper().importFromCSV(filePath);

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Refresh main page and show success message
      widget.onDataCleared?.call();
      _showSnackBar('Successfully imported $importCount transactions');
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showSnackBar('Import failed: ${e.toString()}');
    }
  }

  void _showTransactionStats() async {
    try {
      final transactions = await DatabaseHelper().getTransactions();

      if (transactions.isEmpty) {
        _showSnackBar('No transactions to analyze');
        return;
      }

      // Calculate statistics
      int totalTransactions = transactions.length;
      int creditCount = transactions.where((t) => t['isPositive'] == 1).length;
      int debitCount = transactions.where((t) => t['isPositive'] == 0).length;

      double totalCredit = 0;
      double totalDebit = 0;
      DateTime? firstDate;
      DateTime? lastDate;
      Map<String, int> titleFrequency = {};

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
        } else {
          totalDebit += amount;
        }

        // Track dates
        if (transaction['date'] != null) {
          DateTime date = DateTime.parse(transaction['date']);
          if (firstDate == null || date.isBefore(firstDate)) firstDate = date;
          if (lastDate == null || date.isAfter(lastDate)) lastDate = date;
        }

        // Track most common titles
        String title = transaction['title'] ?? 'Unknown';
        titleFrequency[title] = (titleFrequency[title] ?? 0) + 1;
      }

      double currentBalance = totalCredit - totalDebit;
      double avgTransaction = (totalCredit + totalDebit) / totalTransactions;

      // Find most common transaction
      String mostCommon = titleFrequency.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text('Transaction Statistics',
                  style: TextStyle(color: Colors.white)),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pie Chart
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      child: CustomPaint(
                        painter: PieChartPainter(
                          creditAmount: totalCredit,
                          debitAmount: totalDebit,
                          isDonut: true,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('Credits', Colors.green),
                      SizedBox(width: 40),
                      _buildLegendItem('Debits', Colors.red),
                    ],
                  ),
                  SizedBox(height: 30),

                  // Stats Section
                  _buildSectionTitle('Overview'),
                  _buildStatCard([
                    _buildStatRow(
                        '📊 Total Transactions', '$totalTransactions'),
                    _buildStatRow('💰 Current Balance',
                        '${widget.currency}${currentBalance.toStringAsFixed(2)}'),
                  ]),
                  SizedBox(height: 16),

                  _buildSectionTitle('Transaction Counts'),
                  _buildStatCard([
                    _buildStatRow(
                        '📈 Total Credits', '$creditCount transactions'),
                    _buildStatRow(
                        '💸 Total Debits', '$debitCount transactions'),
                  ]),
                  SizedBox(height: 16),

                  _buildSectionTitle('Financial Summary'),
                  _buildStatCard([
                    _buildStatRow('💵 Total Money In',
                        '${widget.currency}${totalCredit.toStringAsFixed(2)}'),
                    _buildStatRow('💳 Total Money Out',
                        '${widget.currency}${totalDebit.toStringAsFixed(2)}'),
                    _buildStatRow('📊 Average Transaction',
                        '${widget.currency}${avgTransaction.toStringAsFixed(2)}'),
                    _buildStatRow('🔄 Most Common', mostCommon),
                  ]),
                  SizedBox(height: 16),

                  if (firstDate != null && lastDate != null) ...[
                    _buildSectionTitle('Timeline'),
                    _buildStatCard([
                      _buildStatRow('📅 First Transaction',
                          '${firstDate!.day}/${firstDate!.month}/${firstDate!.year}'),
                      _buildStatRow('📅 Latest Transaction',
                          '${lastDate!.day}/${lastDate!.month}/${lastDate!.year}'),
                      _buildStatRow('⏱️ Days Active',
                          '${lastDate!.difference(firstDate!).inDays + 1} days'),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Error loading statistics: $e');
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatCard(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 16)),
          Text(value,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            Text('About Piggy Wallet', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0', style: TextStyle(color: Colors.white)),
            SizedBox(height: 8),
            Text('Developer: u337744@gmail.com',
                style: TextStyle(color: Colors.white)),
            SizedBox(height: 8),
            Text('A simple and elegant wallet app to track your transactions.',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: ListTile(
            leading: Icon(icon, color: Colors.deepPurpleAccent),
            title: Text(title, style: TextStyle(color: Colors.white)),
            onTap: onTap,
            trailing:
                Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Settings', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSettingsItem(
              icon: Icons.person,
              title: 'Change Username',
              onTap: _changeUsername,
            ),
            _buildSettingsItem(
              icon: Icons.currency_exchange,
              title: 'Currency Selection',
              onTap: _changeCurrency,
            ),
            _buildSettingsItem(
              icon: Icons.backup,
              title: 'Backup Data',
              onTap: _backupData,
            ),
            _buildSettingsItem(
              icon: Icons.file_download,
              title: 'Import Data',
              onTap: _importData,
            ),
            _buildSettingsItem(
              icon: Icons.delete_forever,
              title: 'Clear All Data',
              onTap: _clearAllData,
            ),
            _buildSettingsItem(
              icon: Icons.analytics,
              title: 'Transaction Statistics',
              onTap: _showTransactionStats,
            ),
            _buildSettingsItem(
              icon: Icons.info,
              title: 'About App',
              onTap: _showAbout,
            ),
          ],
        ),
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final double creditAmount;
  final double debitAmount;
  final bool isDonut;

  PieChartPainter({
    required this.creditAmount,
    required this.debitAmount,
    this.isDonut = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final total = creditAmount + debitAmount;

    if (total == 0) return;

    final creditAngle = (creditAmount / total) * 2 * pi;
    final debitAngle = (debitAmount / total) * 2 * pi;

    // Draw credit section (green)
    final creditPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start from top
      creditAngle,
      true,
      creditPaint,
    );

    // Draw debit section (red)
    final debitPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2 + creditAngle, // Start after credit section
      debitAngle,
      true,
      debitPaint,
    );

    // Draw inner circle for donut effect if enabled
    if (isDonut) {
      final innerRadius = radius * 0.6;
      final bgPaint = Paint()
        ..color = const Color(0xFF121212)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, innerRadius, bgPaint);
    }

    // Draw outer border
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
