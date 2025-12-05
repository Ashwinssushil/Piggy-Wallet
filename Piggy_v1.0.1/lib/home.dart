import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';
import 'settings.dart';
import 'login.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class Transaction {
  final int? id;
  final String title;
  final String amount;
  final bool isPositive;
  final DateTime date;

  Transaction({
    this.id,
    required this.title,
    required this.amount,
    required this.isPositive,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'isPositive': isPositive ? 1 : 0,
      'date': date.toIso8601String(),
    };
  }

  static Transaction fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'].toString(),
      isPositive: map['isPositive'] == 1,
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
    );
  }
}

class _WalletScreenState extends State<WalletScreen> with WidgetsBindingObserver {
  List<Transaction> transactions = [];
  List<Transaction> filteredTransactions = [];
  bool isDeleteMode = false;
  List<bool> selectedTransactions = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String searchQuery = '';
  bool isSearchActive = false;
  String userName = 'User';
  String currency = '₹';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserPreferences();
    _loadTransactions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // App lifecycle handling is now managed in main.dart
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? 'User';
    });
  }

  Future<void> _saveUserName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', userName);
  }

  Future<void> _loadTransactions() async {
    final List<Map<String, dynamic>> maps = await _dbHelper.getTransactions();
    final List<Transaction> loadedTransactions =
        maps.map((map) => Transaction.fromMap(map)).toList();

    // Sort transactions by date (newest first)
    loadedTransactions.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      transactions = loadedTransactions;
      filteredTransactions = loadedTransactions;
      selectedTransactions =
          List<bool>.generate(transactions.length, (_) => false);
    });
  }

  double _calculateBalance() {
    return transactions.fold(0.0, (sum, transaction) {
      String amountStr = transaction.amount
          .replaceAll('₹', '')
          .replaceAll('\$', '')
          .replaceAll('€', '')
          .replaceAll('£', '')
          .replaceAll('¥', '')
          .replaceAll('-', '');
      double amount = double.tryParse(amountStr) ?? 0.0;
      return transaction.isPositive ? sum + amount : sum - amount;
    });
  }

  void _addTransaction() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String title = '';
        String amount = '';
        bool isPositive = true;
        DateTime selectedDate = DateTime.now();

        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.all(24),
              title: Text(
                'Add Transaction',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transaction Name
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.edit,
                            color: Colors.deepPurpleAccent),
                        labelText: 'Transaction Name',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.grey[850],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (value) {
                        title = value;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.currency_rupee,
                            color: Colors.deepPurpleAccent),
                        labelText: 'Amount',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.grey[850],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (value) {
                        amount = value;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Transaction Type Dropdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transaction Type',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                        DropdownButton<bool>(
                          value: isPositive,
                          dropdownColor: Colors.grey[850],
                          iconEnabledColor: Colors.white,
                          style: const TextStyle(color: Colors.white),
                          underline: Container(),
                          items: const [
                            DropdownMenuItem(
                              value: true,
                              child: Text('Credit',
                                  style: TextStyle(color: Colors.green)),
                            ),
                            DropdownMenuItem(
                              value: false,
                              child: Text('Debit',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => isPositive = value);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Date Picker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Date: ${selectedDate.toLocal().toString().split(' ')[0]}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today,
                              size: 18, color: Colors.white),
                          label: const Text("Pick",
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white60)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (title.isNotEmpty && amount.isNotEmpty) {
                          final newTransaction = Transaction(
                            title: title,
                            amount: isPositive
                                ? '$currency$amount'
                                : '-$currency$amount',
                            isPositive: isPositive,
                            date: selectedDate,
                          );
                          await _dbHelper
                              .insertTransaction(newTransaction.toMap());
                          Navigator.of(context).pop();
                          await _loadTransactions(); // This will sort transactions by date
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Add',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleDeleteMode() {
    setState(() {
      if (isDeleteMode) {
        isDeleteMode = false;
        selectedTransactions.clear();
      } else if (filteredTransactions.isNotEmpty) {
        isDeleteMode = true;
        selectedTransactions =
            List<bool>.generate(filteredTransactions.length, (_) => false);
      }
    });
  }

  void _confirmDelete() async {
    List<int> idsToDelete = [];
    for (int i = selectedTransactions.length - 1; i >= 0; i--) {
      if (selectedTransactions[i]) {
        idsToDelete.add(filteredTransactions[i].id!);
      }
    }
    await _dbHelper.deleteSelectedTransactions(idsToDelete);
    await _loadTransactions();
    setState(() {
      isDeleteMode = false;
      selectedTransactions.clear();
    });
  }

  void _clearSearch() {
    setState(() {
      searchQuery = '';
      filteredTransactions = transactions;
      isSearchActive = false;
    });
  }

  void _searchTransactions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Search Transactions',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: Colors.deepPurpleAccent),
              labelText: 'Search by title',
              labelStyle: TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.grey[850],
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value.toLowerCase();
                isSearchActive = searchQuery.isNotEmpty;
                filteredTransactions = transactions
                    .where((transaction) =>
                        transaction.title.toLowerCase().contains(searchQuery))
                    .toList();
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Search', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _updateTransactionsCurrency(String newCurrency) {
    setState(() {
      for (int i = 0; i < transactions.length; i++) {
        String cleanAmount = transactions[i]
            .amount
            .replaceAll('₹', '')
            .replaceAll('\$', '')
            .replaceAll('€', '')
            .replaceAll('£', '')
            .replaceAll('¥', '')
            .replaceAll('-', '');

        bool isNegative = transactions[i].amount.startsWith('-');
        String newAmount = isNegative
            ? '-$newCurrency$cleanAmount'
            : '$newCurrency$cleanAmount';

        transactions[i] = Transaction(
          id: transactions[i].id,
          title: transactions[i].title,
          amount: newAmount,
          isPositive: transactions[i].isPositive,
          date: transactions[i].date,
        );
      }
      filteredTransactions = List.from(transactions);
    });
  }



  void _showSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          userName: userName,
          currency: currency,
          onUsernameChanged: (newName) {
            setState(() {
              userName = newName;
            });
            _saveUserName();
          },
          onCurrencyChanged: (newCurrency) {
            setState(() {
              currency = newCurrency;
              _updateTransactionsCurrency(newCurrency);
            });
          },
          onDataCleared: () {
            setState(() {
              transactions.clear();
              filteredTransactions.clear();
              selectedTransactions.clear();
            });
            _loadTransactions();
          },
        ),
      ),
    );
  }

  void _exportToPdf() async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      _dbHelper.generateTransactionReport(currency);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved successfully'),
          backgroundColor: Colors.deepPurple.withOpacity(0.7),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: SingleChildScrollView(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[900]?.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'About Piggy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      _buildInfoItem(
                        context,
                        title: 'About This App',
                        content:
                            'Piggy is a personal finance app designed to help you track your income and expenses. It provides a simple and intuitive interface to manage your transactions and monitor your financial health. The app focuses on functionality and ease of use for a pleasant user experience.',
                      ),
                      SizedBox(height: 16),
                      _buildInfoItem(
                        context,
                        title: 'Data Usage & Privacy',
                        content:
                            'All your data is stored locally on your device. We do not collect or transmit any personal information. Your transaction history, settings, and preferences remain private and secure on your device. The app does not require internet permissions and operates completely offline.',
                      ),
                      SizedBox(height: 16),
                      _buildInfoItem(
                        context,
                        title: 'Features',
                        content:
                            '• Track income and expenses with detailed transaction records\n• View current balance with automatic calculations\n• Search transactions by title\n• Delete unwanted transactions individually or in bulk\n• Export transactions to PDF for record keeping\n• Customize currency symbol (₹, \$, €, £, ¥)\n• Dark mode interface for comfortable viewing\n• Add transaction details including date, amount, and type',
                      ),
                      SizedBox(height: 16),
                      _buildInfoItem(
                        context,
                        title: 'How to Use',
                        content:
                            '1. Add transactions using the "Add" quick action\n2. View your balance at the top of the screen\n3. Browse your transaction history in the list below\n4. Search for specific transactions using the search feature\n5. Delete transactions by activating delete mode\n6. Export your transactions to PDF for backup or printing\n7. Customize app settings including username and currency',
                      ),
                      SizedBox(height: 16),
                      _buildInfoItem(
                        context,
                        title: 'Storage Location',
                        content:
                            'Your transaction data is stored in the app\'s private database on your device. PDF exports are saved to your device\'s Downloads folder for easy access.',
                      ),
                      SizedBox(height: 16),
                      _buildInfoItem(
                        context,
                        title: 'Technical Details',
                        content:
                            'Piggy is built using Flutter framework with Dart programming language. It implements Material Design principles with custom UI elements for an enhanced user experience.',
                      ),
                      SizedBox(height: 16),
                      _buildInfoItem(
                        context,
                        title: 'Version',
                        content: 'Piggy v1.0.1',
                      ),
                      SizedBox(height: 16),
                      _buildInfoItem(
                        context,
                        title: 'Developer',
                        content: 'Ashwin\nContact: u337744@gmail.com',
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Close',
                            style: TextStyle(color: Colors.deepPurpleAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(BuildContext context,
      {required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        SystemNavigator.pop();
      },
      child: Scaffold(
      floatingActionButton: isDeleteMode
          ? Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 34.0, vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 150,
                    child: _buildGlassButton(
                      label: 'Delete',
                      onPressed: _confirmDelete,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 150,
                    child: _buildGlassButton(
                      label: 'Cancel',
                      onPressed: _toggleDeleteMode,
                    ),
                  ),
                ],
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            toolbarHeight: 80,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome,',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userName,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                        Theme(
                          data: Theme.of(context).copyWith(
                            popupMenuTheme: const PopupMenuThemeData(
                              color: Colors.grey, // Dark grey background
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              ),
                              textStyle: TextStyle(color: Colors.white),
                            ),
                          ),
                          child: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 28,
                            ),
                            onSelected: (value) {
                              if (value == 'info') {
                                _showInfoDialog(context);
                              } else if (value == 'logout') {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const PinLoginPage()),
                                );
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem<String>(
                                value: 'info',
                                child: Row(
                                  children: const [
                                    Icon(Icons.info_outline,
                                        color: Colors.white),
                                    SizedBox(width: 10),
                                    Text('About Piggy'),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'logout',
                                child: Row(
                                  children: const [
                                    Icon(Icons.logout,
                                        color: Colors.white),
                                    SizedBox(width: 10),
                                    Text('Logout'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverAppBar(
            backgroundColor: Colors.transparent,
            expandedHeight: 220,
            floating: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              centerTitle: false,
              background: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.withOpacity(0.4),
                          Colors.purple.withOpacity(0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedDefaultTextStyle(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                              '$currency${_calculateBalance().toStringAsFixed(2)}'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Current Balance',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: const Text(
                'Wallet',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SliverAppBar(
            backgroundColor: Colors.transparent,
            expandedHeight: 160.0,
            floating: true,
            snap: true,
            pinned: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _buildQuickAction(
                            icon: Icons.add,
                            label: 'Add',
                            onTap: _addTransaction,
                          ),
                          const SizedBox(width: 16),
                          _buildQuickAction(
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            onTap: _toggleDeleteMode,
                          ),
                          const SizedBox(width: 16),
                          _buildQuickAction(
                            icon: Icons.search_outlined,
                            label: 'Search',
                            onTap: _searchTransactions,
                          ),
                          const SizedBox(width: 16),
                          _buildQuickAction(
                            icon: Icons.picture_as_pdf_outlined,
                            label: 'PDF',
                            onTap: _exportToPdf,
                          ),
                          const SizedBox(width: 16),
                          _buildQuickAction(
                            icon: Icons.settings_outlined,
                            label: 'Settings',
                            onTap: _showSettings,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isSearchActive ? 'Search Results' : 'Recent Transactions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (isSearchActive)
                    GestureDetector(
                      onTap: _clearSearch,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Back',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          filteredTransactions.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    child: Text(
                      searchQuery.isEmpty
                          ? 'No transactions yet.'
                          : 'No transactions found.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final transaction = filteredTransactions[index];
                      return _buildTransactionTile(
                        title: transaction.title,
                        subtitle:
                            DateFormat('MMMM d, yyyy').format(transaction.date),
                        amount: transaction.amount,
                        isPositive: transaction.isPositive,
                        index: index,
                        isDeleteMode: isDeleteMode,
                        isSelected: index < selectedTransactions.length
                            ? selectedTransactions[index]
                            : false,
                        onCheckboxChanged: (value) {
                          if (index < selectedTransactions.length) {
                            setState(() {
                              selectedTransactions[index] = value ?? false;
                            });
                          }
                        },
                      );
                    },
                    childCount: filteredTransactions.length,
                  ),
                ),
          // Only add extra space at the bottom when in delete mode
          if (isDeleteMode)
            SliverToBoxAdapter(
              child: SizedBox(height: 80), // Extra space at the bottom
            ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 110,
            height: 90,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 30,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTile({
    required String title,
    required String subtitle,
    required String amount,
    required bool isPositive,
    required int index,
    required bool isDeleteMode,
    required bool isSelected,
    required ValueChanged<bool?> onCheckboxChanged,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Card(
          child: InkWell(
            onTap: isDeleteMode ? () => onCheckboxChanged(!isSelected) : null,
            splashColor:
                Colors.deepPurple.withOpacity(0.3), // Custom splash color
            highlightColor: Colors.transparent, // No highlight color
            child: ListTile(
              leading: isDeleteMode
                  ? Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color:
                            isSelected ? Colors.deepPurple : Colors.transparent,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(1, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isPositive
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: isPositive ? Colors.green : Colors.red,
                          size: 28,
                        ),
                      ),
                    ),
              title: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                subtitle,
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green : Colors.red,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required String label,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.deepPurple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: TextButton(
            onPressed: onPressed,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}