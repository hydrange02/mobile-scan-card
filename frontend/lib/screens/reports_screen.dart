import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/api_config.dart';
import '../services/export_service.dart';
import '../services/haptic_service.dart';
import '../providers/locale_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'All';
  String _selectedCardType = 'All';
  String _selectedTimeFilter = 'All'; // All, Today, ThisMonth, LastMonth, Last7Days
  String _searchQuery = '';
  List<dynamic> _allTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/transactions'),
        headers: authProvider.authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _allTransactions = json.decode(response.body);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _allTransactions = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allTransactions = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearTransactionHistory() async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 8),
            Text(localeProvider.getText('confirm_clear_title'), style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          localeProvider.getText('confirm_clear_msg'),
          style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localeProvider.getText('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text(localeProvider.getText('clear_history')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/transactions'),
        headers: authProvider.authHeaders,
      );

      if (response.statusCode == 200 && mounted) {
        HapticService.successFeedback();
        setState(() {
          _allTransactions = [];
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localeProvider.getText('history_cleared')), backgroundColor: Colors.green),
        );
        _fetchTransactions();
      } else if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localeProvider.getText('clear_history_failed')), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localeProvider.getText('error_prefix')}: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<dynamic> get _filteredTransactions {
    final now = DateTime.now();

    return _allTransactions.where((tx) {
      // 1. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final title = (tx['title'] ?? '').toString().toLowerCase();
        final category = (tx['category'] ?? '').toString().toLowerCase();
        final cardName = (tx['cardName'] ?? '').toString().toLowerCase();
        final amount = (tx['amount'] ?? '').toString();
        if (!title.contains(query) &&
            !category.contains(query) &&
            !cardName.contains(query) &&
            !amount.contains(query)) {
          return false;
        }
      }

      // 2. Status Filter
      if (_selectedStatus != 'All') {
        if ((tx['status'] ?? 'Success') != _selectedStatus) {
          return false;
        }
      }

      // 3. Card Type Filter
      if (_selectedCardType != 'All') {
        final cardName = (tx['cardName'] ?? '').toString();
        if (_selectedCardType == 'Visa' && !cardName.contains('Visa')) return false;
        if (_selectedCardType == 'Mastercard' && !cardName.contains('Mastercard')) return false;
        if (_selectedCardType == 'NFC' && !cardName.contains('NFC')) return false;
      }

      // 4. Time Filter
      if (_selectedTimeFilter != 'All' && tx['createdAt'] != null) {
        try {
          final txDate = DateTime.parse(tx['createdAt']).toLocal();
          if (_selectedTimeFilter == 'Today') {
            if (!_isSameDay(txDate, now)) return false;
          } else if (_selectedTimeFilter == 'ThisMonth') {
            if (txDate.year != now.year || txDate.month != now.month) return false;
          } else if (_selectedTimeFilter == 'LastMonth') {
            final lastMonth = DateTime(now.year, now.month - 1, 1);
            if (txDate.year != lastMonth.year || txDate.month != lastMonth.month) return false;
          } else if (_selectedTimeFilter == 'Last7Days') {
            final sevenDaysAgo = now.subtract(const Duration(days: 7));
            if (txDate.isBefore(sevenDaysAgo)) return false;
          }
        } catch (_) {}
      }

      return true;
    }).toList();
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  void _showTransactionDetailModal(Map<String, dynamic> tx) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final bool isExpense = tx['isExpense'] == true;
    final double amount = _parseNum(tx['amount']);
    final String status = tx['status'] ?? 'Success';
    final String title = tx['title'] ?? localeProvider.getText('nfc_transaction');
    final String cardName = tx['cardName'] ?? localeProvider.getText('nfc_card');
    final String createdAt = tx['createdAt'] != null
        ? DateTime.parse(tx['createdAt']).toLocal().toString().split('.')[0]
        : 'N/A';

    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.dialogBgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localeProvider.getText('transaction_detail'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'Success'
                        ? Colors.greenAccent.withValues(alpha: 0.15)
                        : Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status == 'Success' ? localeProvider.getText('filter_success') : localeProvider.getText('filter_failed'),
                    style: TextStyle(
                      color: status == 'Success' ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Text(
                    title,
                    style: TextStyle(color: themeProvider.textColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${isExpense ? '-' : '+'}${localeProvider.formatAmount(amount)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isExpense ? Colors.redAccent : Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildDetailRow(localeProvider.getText('card_used'), cardName, themeProvider),
            _buildDetailRow(localeProvider.getText('category'), tx['category'] ?? localeProvider.getText('payment_label'), themeProvider),
            _buildDetailRow(localeProvider.getText('time_label'), createdAt, themeProvider),
            _buildDetailRow(localeProvider.getText('transaction_id'), '#TXN-${tx['id'] ?? tx['dbId'] ?? '0000'}', themeProvider),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                child: Text(localeProvider.getText('close'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeProvider themeProvider, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor ?? themeProvider.textColor, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  void _showExportResult(String title, String content) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Text(title, style: TextStyle(color: themeProvider.textColor)),
        content: SingleChildScrollView(
          child: SelectableText(content, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.cyanAccent)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(localeProvider.getText('close'), style: const TextStyle(color: Colors.grey)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
    }

    // Calculate Summary Stats based on filtered transactions
    final filtered = _filteredTransactions;
    int totalCount = filtered.length;
    int successCount = 0;
    double totalExpense = 0;
    double totalIncome = 0;

    for (var tx in filtered) {
      final amt = _parseNum(tx['amount']);
      final bool isExpense = tx['isExpense'] == true;
      if (tx['status'] == 'Success') {
        successCount++;
        if (isExpense) {
          totalExpense += amt;
        } else {
          totalIncome += amt;
        }
      }
    }

    return Container(
      color: themeProvider.backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------------------
            // 1. TOP TITLE & EXPORT ACTION BUTTONS
            // -------------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localeProvider.getText('transactions'),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.purpleAccent, size: 22),
                      tooltip: localeProvider.getText('export_pdf'),
                      onPressed: () {
                        HapticService.successFeedback();
                        final pdf = ExportService.generatePDFReport(List<Map<String, dynamic>>.from(filtered));
                        _showExportResult(localeProvider.getText('export_pdf'), pdf);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.table_chart, color: Colors.tealAccent, size: 22),
                      tooltip: localeProvider.getText('export_csv'),
                      onPressed: () {
                        HapticService.successFeedback();
                        final csv = ExportService.generateCSV(List<Map<String, dynamic>>.from(filtered));
                        _showExportResult(localeProvider.getText('export_csv'), csv);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 22),
                      tooltip: localeProvider.getText('clear_history'),
                      onPressed: _clearTransactionHistory,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // -------------------------------------------------------------
            // 2. DASHBOARD STATS CARD (INCOME, EXPENSE, TOTAL TRANSACTIONS)
            // -------------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: themeProvider.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: themeProvider.cardBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Row 1: Thu & Chi
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.arrow_downward_rounded, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 4),
                                Text(localeProvider.getText('total_expense'), style: TextStyle(color: themeProvider.subtitleColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '-${localeProvider.formatAmount(totalExpense)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: themeProvider.cardBorderColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.arrow_upward_rounded, color: Colors.greenAccent, size: 16),
                                const SizedBox(width: 4),
                                Text(localeProvider.getText('total_income'), style: TextStyle(color: themeProvider.subtitleColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '+${localeProvider.formatAmount(totalIncome)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: themeProvider.cardBorderColor, height: 1),
                  const SizedBox(height: 12),
                  // Row 2: Counts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${localeProvider.getText('total_transactions')}: $totalCount',
                        style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12),
                      ),
                      Text(
                        '${localeProvider.getText('filter_success')}: $successCount / $totalCount',
                        style: TextStyle(color: themeProvider.accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // -------------------------------------------------------------
            // 3. SEARCH BAR & MULTI-FILTER DROPDOWNS
            // -------------------------------------------------------------
            TextField(
              controller: _searchController,
              style: TextStyle(color: themeProvider.textColor),
              decoration: InputDecoration(
                hintText: localeProvider.getText('search_hint'),
                hintStyle: TextStyle(color: themeProvider.subtitleColor),
                prefixIcon: Icon(Icons.search, color: themeProvider.accentColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: themeProvider.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeProvider.cardBorderColor)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),

            const SizedBox(height: 12),

            // Dropdown 1: Time Filter
            DropdownButtonFormField<String>(
              initialValue: _selectedTimeFilter,
              dropdownColor: themeProvider.dialogBgColor,
              style: TextStyle(color: themeProvider.textColor, fontSize: 12),
              decoration: InputDecoration(
                labelText: localeProvider.getText('time_filter'),
                labelStyle: TextStyle(color: themeProvider.subtitleColor, fontSize: 12),
                filled: true,
                fillColor: themeProvider.cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: themeProvider.cardBorderColor)),
              ),
              items: [
                DropdownMenuItem(value: 'All', child: Text('${localeProvider.getText('filter_all')} (${localeProvider.getText('all_time')})', style: TextStyle(color: themeProvider.textColor))),
                DropdownMenuItem(value: 'Today', child: Text(localeProvider.getText('filter_today'), style: TextStyle(color: themeProvider.textColor))),
                DropdownMenuItem(value: 'ThisMonth', child: Text(localeProvider.getText('filter_this_month'), style: TextStyle(color: themeProvider.textColor))),
                DropdownMenuItem(value: 'LastMonth', child: Text(localeProvider.getText('filter_last_month'), style: TextStyle(color: themeProvider.textColor))),
                DropdownMenuItem(value: 'Last7Days', child: Text(localeProvider.getText('filter_last_7_days'), style: TextStyle(color: themeProvider.textColor))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedTimeFilter = val);
              },
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    dropdownColor: themeProvider.dialogBgColor,
                    style: TextStyle(color: themeProvider.textColor, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: localeProvider.getText('status'),
                      labelStyle: TextStyle(color: themeProvider.subtitleColor, fontSize: 12),
                      filled: true,
                      fillColor: themeProvider.cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: themeProvider.cardBorderColor)),
                    ),
                    items: [
                      DropdownMenuItem(value: 'All', child: Text(localeProvider.getText('filter_all'), style: TextStyle(color: themeProvider.textColor))),
                      DropdownMenuItem(value: 'Success', child: Text(localeProvider.getText('filter_success'), style: TextStyle(color: themeProvider.textColor))),
                      DropdownMenuItem(value: 'Failed', child: Text(localeProvider.getText('filter_failed'), style: TextStyle(color: themeProvider.textColor))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCardType,
                    dropdownColor: themeProvider.dialogBgColor,
                    style: TextStyle(color: themeProvider.textColor, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: localeProvider.getText('card_type'),
                      labelStyle: TextStyle(color: themeProvider.subtitleColor, fontSize: 12),
                      filled: true,
                      fillColor: themeProvider.cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: themeProvider.cardBorderColor)),
                    ),
                    items: [
                      DropdownMenuItem(value: 'All', child: Text(localeProvider.getText('filter_all_cards'), style: TextStyle(color: themeProvider.textColor))),
                      DropdownMenuItem(value: 'Visa', child: Text('Visa', style: TextStyle(color: themeProvider.textColor))),
                      DropdownMenuItem(value: 'Mastercard', child: Text('Mastercard', style: TextStyle(color: themeProvider.textColor))),
                      DropdownMenuItem(value: 'NFC', child: Text('NFC Contactless', style: TextStyle(color: themeProvider.textColor))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCardType = val);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // -------------------------------------------------------------
            // 4. TRANSACTION HISTORY LIST VIEW
            // -------------------------------------------------------------
            filtered.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          localeProvider.getText('no_transactions'),
                          style: TextStyle(color: themeProvider.subtitleColor, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final tx = filtered[index];
                      final bool isExpense = tx['isExpense'] == true;
                      final double amount = _parseNum(tx['amount']);
                      final String title = tx['title'] ?? localeProvider.getText('nfc_transaction');
                      final String cardName = tx['cardName'] ?? localeProvider.getText('nfc_card');
                      final String status = tx['status'] ?? 'Success';
                      final String? rawDate = tx['createdAt'] ?? tx['date'];
                      final String dateStr = (rawDate != null && rawDate.isNotEmpty)
                          ? DateTime.parse(rawDate).toLocal().toString().split('.')[0]
                          : '';

                      return Card(
                        color: themeProvider.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: themeProvider.cardBorderColor),
                        ),
                        child: ListTile(
                          onTap: () => _showTransactionDetailModal(tx),
                          leading: CircleAvatar(
                            backgroundColor: isExpense
                                ? Colors.redAccent.withValues(alpha: 0.15)
                                : Colors.greenAccent.withValues(alpha: 0.15),
                            child: Icon(
                              isExpense ? Icons.shopping_bag_outlined : Icons.account_balance_wallet_outlined,
                              color: isExpense ? Colors.redAccent : Colors.greenAccent,
                            ),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '$cardName • $dateStr',
                            style: TextStyle(color: themeProvider.subtitleColor, fontSize: 11),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isExpense ? '-' : '+'}${localeProvider.formatAmount(amount)}',
                                style: TextStyle(
                                  color: isExpense ? Colors.redAccent : Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                status == 'Success' ? localeProvider.getText('filter_success') : localeProvider.getText('filter_failed'),
                                style: TextStyle(
                                  color: status == 'Success' ? Colors.green : Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
