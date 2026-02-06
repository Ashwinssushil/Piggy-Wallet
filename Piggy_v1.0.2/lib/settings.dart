import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'database.dart';
import 'authentication.dart';
import 'main.dart';

// Constants
class SettingsConstants {
  static const List<String> currencies = ['₹', '\$', '€', '£', '¥'];
  static const String backupFolderPath = '/Piggy/Backups';
  static const String androidDownloadPath = '/storage/emulated/0/Download';
  static const int pinLength = 4;
  static const double chartInnerRadius = 0.6;
  static const double borderRadius = 12.0;
  static const double cardOpacity = 0.1;
  static const double borderOpacity = 0.2;
}

// Theme constants
class SettingsTheme {
  static const Color backgroundColor = Color(0xFF121212);
  static const Color primaryColor = Colors.deepPurpleAccent;
  static const Color cardColor = Colors.deepPurple;
  static const Color textColor = Colors.white;
  static const Color textSecondaryColor = Colors.white70;
  static const Color errorColor = Colors.red;
  static const Color successColor = Colors.green;
}

class SettingsPage extends StatefulWidget {
  final String userName;
  final String currency;
  final Function(String) onUsernameChanged;
  final Function(String) onCurrencyChanged;
  final VoidCallback? onDataCleared;
  final VoidCallback? onImportStarted;
  final VoidCallback? onImportCompleted;

  const SettingsPage({
    super.key,
    required this.userName,
    required this.currency,
    required this.onUsernameChanged,
    required this.onCurrencyChanged,
    this.onDataCleared,
    this.onImportStarted,
    this.onImportCompleted,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Authentication state
  bool _authEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  
  // Loading states
  bool _isLoading = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    await _loadAuthSettings();
  }

  Future<void> _loadAuthSettings() async {
    final enabled = await AuthService.isAuthEnabled();
    final biometricEnabled = await AuthService.isBiometricEnabled();
    final biometricAvailable = await AuthService.isBiometricAvailable();
    if (mounted) {
      setState(() {
        _authEnabled = enabled;
        _biometricEnabled = biometricEnabled;
        _biometricAvailable = biometricAvailable;
      });
    }
  }

  // UI Helper Methods
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? SettingsTheme.errorColor.withOpacity(0.8)
            : SettingsTheme.cardColor.withOpacity(0.7),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SettingsConstants.borderRadius),
        ),
        duration: const Duration(seconds: 2), // Half the default time (4s -> 2s)
      ),
    );
  }

  void _showLoadingDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: Colors.grey[900],
          content: Row(
            children: [
              CircularProgressIndicator(color: SettingsTheme.primaryColor),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: SettingsTheme.textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hideLoadingDialog() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // Authentication Methods
  Future<void> _toggleBiometric(bool enabled) async {
    try {
      await AuthService.setBiometricEnabled(enabled);
      if (mounted) {
        setState(() {
          _biometricEnabled = enabled;
        });
        _showSnackBar(enabled ? 'Fingerprint enabled' : 'Fingerprint disabled');
      }
    } catch (e) {
      _showSnackBar('Failed to toggle fingerprint: $e', isError: true);
    }
  }

  Future<void> _toggleAuthentication(bool enabled) async {
    try {
      await AuthService.setAuthEnabled(enabled);
      
      if (!enabled) {
        await AuthService.setBiometricEnabled(false);
        if (mounted) {
          setState(() {
            _authEnabled = enabled;
            _biometricEnabled = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _authEnabled = enabled;
          });
        }
      }
      
      _showSnackBar(enabled ? 'App lock enabled' : 'App lock disabled');
    } catch (e) {
      _showSnackBar('Failed to toggle app lock: $e', isError: true);
    }
  }

  // User Settings Methods
  void _changeUsername() {
    final TextEditingController controller = TextEditingController(text: widget.userName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Change Username', style: TextStyle(color: SettingsTheme.textColor)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: SettingsTheme.textColor),
          decoration: InputDecoration(
            labelText: 'Enter new username',
            labelStyle: const TextStyle(color: SettingsTheme.textSecondaryColor),
            filled: true,
            fillColor: Colors.grey[850],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SettingsConstants.borderRadius),
            ),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != widget.userName) {
                widget.onUsernameChanged(newName);
                Navigator.pop(context);
                _showSnackBar('Username updated!');
              } else if (newName.isEmpty) {
                _showSnackBar('Username cannot be empty', isError: true);
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: SettingsTheme.textColor)),
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
        title: const Text('Select Currency', style: TextStyle(color: SettingsTheme.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsConstants.currencies
              .map((currency) => ListTile(
                    title: Text(
                      currency,
                      style: const TextStyle(color: SettingsTheme.textColor, fontSize: 18),
                    ),
                    leading: widget.currency == currency
                        ? const Icon(Icons.check, color: SettingsTheme.primaryColor)
                        : null,
                    onTap: () {
                      if (currency != widget.currency) {
                        widget.onCurrencyChanged(currency);
                        _showSnackBar('Currency changed to $currency');
                      }
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  // Data Management Methods
  void _clearAllData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Clear All Data', style: TextStyle(color: SettingsTheme.errorColor)),
        content: const Text(
          'This will delete all transactions permanently. This action cannot be undone. Are you sure?',
          style: TextStyle(color: SettingsTheme.textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performClearData();
            },
            child: const Text('Delete All', style: TextStyle(color: SettingsTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _performClearData() async {
    try {
      _showLoadingDialog('Clearing all data...');
      await DatabaseHelper().clearAllTransactions();
      _hideLoadingDialog();
      widget.onDataCleared?.call();
      _showSnackBar('All data cleared successfully!');
    } catch (e) {
      _hideLoadingDialog();
      _showSnackBar('Failed to clear data: $e', isError: true);
    }
  }

  Future<void> _backupData() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      _showLoadingDialog('Creating backup...');
      final filePath = await DatabaseHelper().backupToCSV();
      _hideLoadingDialog();
      _showSnackBar('Backup created successfully!');
    } catch (e) {
      _hideLoadingDialog();
      _showSnackBar('Backup failed: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _getBackupFolderPath() async {
    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory(SettingsConstants.androidDownloadPath);
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final backupDir = Directory('${downloadsDir.path}${SettingsConstants.backupFolderPath}');
      if (await backupDir.exists()) {
        return backupDir.path;
      }
    } catch (e) {
      debugPrint('Error getting backup folder: $e');
    }
    return null;
  }

  Future<void> _importData() async {
    if (_isImporting) return;

    try {
      setState(() => _isImporting = true);
      AppState.isImportingData = true; // Set global flag to prevent auth checks
      widget.onImportStarted?.call();

      final backupPath = await _getBackupFolderPath();
      final folderHint = backupPath != null
          ? 'Look for CSV files in ${backupPath.split('/').last} folder'
          : 'Look for CSV files in your Downloads/Piggy/Backups folder';

      _showSnackBar(folderHint);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Select CSV Backup File',
      );

      if (result == null || result.files.isEmpty) {
        _handleImportCompletion();
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        _showSnackBar('Could not access the selected file', isError: true);
        _handleImportCompletion();
        return;
      }

      await _confirmImport(filePath);
    } catch (e) {
      _showSnackBar('Error selecting file: ${e.toString()}', isError: true);
      _handleImportCompletion();
    }
  }

  void _handleImportCompletion() {
    widget.onImportCompleted?.call();
    if (mounted) setState(() => _isImporting = false);
  }

  Future<void> _confirmImport(String filePath) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Import Data', style: TextStyle(color: SettingsTheme.textColor)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performImport(filePath, clearExisting: false);
            },
            child: const Text('Keep Existing', style: TextStyle(color: SettingsTheme.textColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performImport(filePath, clearExisting: true);
            },
            child: const Text('Clear & Import', style: TextStyle(color: SettingsTheme.textColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _performImport(String filePath, {required bool clearExisting}) async {
    try {
      if (!filePath.toLowerCase().endsWith('.csv')) {
        _showSnackBar('Selected file is not a CSV file', isError: true);
        _handleImportCompletion();
        return;
      }

      if (clearExisting) {
        await DatabaseHelper().clearAllTransactions();
      }

      _showLoadingDialog('Importing data...');
      
      final importCount = await DatabaseHelper().importFromCSV(filePath);
      
      _hideLoadingDialog();
      widget.onDataCleared?.call();
      
      if (mounted) {
        _showSnackBar('Successfully imported $importCount transactions');
      }
    } catch (e) {
      _hideLoadingDialog();
      if (mounted) {
        _showSnackBar('Import failed: ${e.toString()}', isError: true);
      }
    } finally {
      _handleImportCompletion();
    }
  }

  void _showTransactionStats() async {
    try {
      final transactions = await DatabaseHelper().getTransactions();

      if (transactions.isEmpty) {
        _showSnackBar('No transactions to analyze');
        return;
      }

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

        if (transaction['date'] != null) {
          DateTime date = DateTime.parse(transaction['date']);
          if (firstDate == null || date.isBefore(firstDate)) firstDate = date;
          if (lastDate == null || date.isAfter(lastDate)) lastDate = date;
        }

        String title = transaction['title'] ?? 'Unknown';
        titleFrequency[title] = (titleFrequency[title] ?? 0) + 1;
      }

      double currentBalance = totalCredit - totalDebit;
      double avgTransaction = (totalCredit + totalDebit) / totalTransactions;

      String mostCommon = titleFrequency.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Scaffold(
            backgroundColor: SettingsTheme.backgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Transaction Statistics',
                  style: TextStyle(color: SettingsTheme.textColor)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: SettingsTheme.textColor),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
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
                  const SizedBox(height: 20),
                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('Credits', SettingsTheme.successColor),
                      const SizedBox(width: 40),
                      _buildLegendItem('Debits', SettingsTheme.errorColor),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Stats Section
                  _buildSectionTitle('Overview'),
                  _buildStatCard([
                    _buildStatRow(
                        '📊 Total Transactions', '$totalTransactions'),
                    _buildStatRow('💰 Current Balance',
                        '${widget.currency}${currentBalance.toStringAsFixed(2)}'),
                  ]),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Transaction Counts'),
                  _buildStatCard([
                    _buildStatRow(
                        '📈 Total Credits', '$creditCount transactions'),
                    _buildStatRow(
                        '💸 Total Debits', '$debitCount transactions'),
                  ]),
                  const SizedBox(height: 16),

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
                  const SizedBox(height: 16),

                  if (firstDate != null && lastDate != null) ...[
                    _buildSectionTitle('Timeline'),
                    _buildStatCard([
                      _buildStatRow('📅 First Transaction',
                          '${firstDate.day}/${firstDate.month}/${firstDate.year}'),
                      _buildStatRow('📅 Latest Transaction',
                          '${lastDate.day}/${lastDate.month}/${lastDate.year}'),
                      _buildStatRow('⏱️ Days Active',
                          '${lastDate.difference(firstDate).inDays + 1} days'),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Error loading statistics: $e', isError: true);
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
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: SettingsTheme.textColor, fontSize: 16)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: SettingsTheme.textSecondaryColor,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SettingsTheme.cardColor.withOpacity(SettingsConstants.cardOpacity),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(SettingsConstants.borderOpacity),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: SettingsTheme.textSecondaryColor, fontSize: 16)),
          Text(value,
              style: const TextStyle(
                  color: SettingsTheme.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _changePin() {
    final TextEditingController currentPinController = TextEditingController();
    final TextEditingController newPinController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Change PIN', style: TextStyle(color: SettingsTheme.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPinController,
              style: const TextStyle(color: SettingsTheme.textColor),
              decoration: InputDecoration(
                labelText: 'Current PIN',
                labelStyle: const TextStyle(color: SettingsTheme.textSecondaryColor),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SettingsConstants.borderRadius),
                ),
              ),
              keyboardType: TextInputType.number,
              maxLength: SettingsConstants.pinLength,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPinController,
              style: const TextStyle(color: SettingsTheme.textColor),
              decoration: InputDecoration(
                labelText: 'New PIN',
                labelStyle: const TextStyle(color: SettingsTheme.textSecondaryColor),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SettingsConstants.borderRadius),
                ),
              ),
              keyboardType: TextInputType.number,
              maxLength: SettingsConstants.pinLength,
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              await _handlePinChange(currentPinController.text, newPinController.text);
              Navigator.pop(context);
            },
            child: const Text('Change', style: TextStyle(color: SettingsTheme.textColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePinChange(String currentPin, String newPin) async {
    if (currentPin.length != SettingsConstants.pinLength || 
        newPin.length != SettingsConstants.pinLength) {
      _showSnackBar('PIN must be ${SettingsConstants.pinLength} digits', isError: true);
      return;
    }

    try {
      if (await AuthService.validatePin(currentPin)) {
        await AuthService.setPin(newPin);
        _showSnackBar('PIN changed successfully!');
      } else {
        _showSnackBar('Current PIN is incorrect', isError: true);
      }
    } catch (e) {
      _showSnackBar('Failed to change PIN: $e', isError: true);
    }
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('About Piggy Wallet', style: TextStyle(color: SettingsTheme.textColor)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: v1.0.2', style: TextStyle(color: SettingsTheme.textColor)),
            SizedBox(height: 8),
            Text('Developer: u337744@gmail.com',
                style: TextStyle(color: SettingsTheme.textColor)),
            SizedBox(height: 8),
            Text('A simple and elegant wallet app to track your transactions.',
                style: TextStyle(color: SettingsTheme.textSecondaryColor)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: SettingsTheme.textColor)),
          ),
        ],
      ),
    );
  }

  // UI Building Methods
  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(SettingsConstants.borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: SettingsTheme.cardColor.withOpacity(SettingsConstants.cardOpacity),
            borderRadius: BorderRadius.circular(SettingsConstants.borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(SettingsConstants.borderOpacity),
              width: 1,
            ),
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: SettingsTheme.primaryColor,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: SettingsTheme.textColor,
              ),
            ),
            onTap: onTap,
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SettingsTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: SettingsTheme.textColor)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SettingsTheme.textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSecuritySection(),
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
              icon: Icons.lock,
              title: 'Change PIN',
              onTap: _changePin,
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
              isDestructive: true,
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

  Widget _buildSecuritySection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(SettingsConstants.borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: SettingsTheme.cardColor.withOpacity(SettingsConstants.cardOpacity),
            borderRadius: BorderRadius.circular(SettingsConstants.borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(SettingsConstants.borderOpacity),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.security, color: SettingsTheme.primaryColor),
                title: const Text('App Lock', style: TextStyle(color: SettingsTheme.textColor)),
                trailing: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _authEnabled,
                    onChanged: _toggleAuthentication,
                    activeColor: SettingsTheme.primaryColor,
                  ),
                ),
              ),
              if (_authEnabled && _biometricAvailable)
                ListTile(
                  leading: const Icon(Icons.fingerprint, color: SettingsTheme.primaryColor),
                  title: const Text('Enable Fingerprint', style: TextStyle(color: SettingsTheme.textColor)),
                  trailing: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _biometricEnabled,
                      onChanged: _toggleBiometric,
                      activeColor: SettingsTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
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

    final creditPaint = Paint()
      ..color = SettingsTheme.successColor
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      creditAngle,
      true,
      creditPaint,
    );

    final debitPaint = Paint()
      ..color = SettingsTheme.errorColor
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2 + creditAngle,
      debitAngle,
      true,
      debitPaint,
    );

    if (isDonut) {
      final innerRadius = radius * SettingsConstants.chartInnerRadius;
      final bgPaint = Paint()
        ..color = SettingsTheme.backgroundColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, innerRadius, bgPaint);
    }

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}