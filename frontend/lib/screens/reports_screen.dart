import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/api_config.dart';
import '../services/export_service.dart';
import '../services/haptic_service.dart';
import '../providers/locale_provider.dart';
import '../providers/auth_provider.dart';

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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('Xác Nhận Xóa Lịch Sử', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa toàn bộ lịch sử giao dịch? Dữ liệu nhật ký giao dịch sẽ bị xóa và không thể khôi phục.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa sạch toàn bộ lịch sử giao dịch!'), backgroundColor: Colors.green),
        );
        _fetchTransactions();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa lịch sử giao dịch'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _removeDiacritics(String str) {
    const withDiacritics = 'àáảãạăắằẳẵặânấầnẩẫậnèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵđÀÁẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÈÉẺẼẸÊẾỀỂỄỆÌÍỈĨỊÒÓỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÙÚỦŨỤƯỨỪỬỮỰỲÝỶỸỴĐ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyydaaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyd';
    var result = str;
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result.toLowerCase();
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    final now = DateTime.now();
    return _allTransactions.map((tx) => Map<String, dynamic>.from(tx as Map)).where((tx) {
      if (_selectedStatus != 'All' && tx['status'] != _selectedStatus) return false;
      if (_selectedCardType != 'All' && tx['cardType'] != _selectedCardType) return false;

      // Time Range Filter Logic
      if (_selectedTimeFilter != 'All') {
        final dateStr = (tx['date'] ?? '').toString();
        DateTime? txDate = DateTime.tryParse(dateStr)?.toLocal();
        if (txDate == null && dateStr.contains(' ')) {
          txDate = DateTime.tryParse(dateStr.replaceFirst(' ', 'T'))?.toLocal();
        }
        if (txDate != null) {
          if (_selectedTimeFilter == 'Today') {
            if (txDate.year != now.year || txDate.month != now.month || txDate.day != now.day) return false;
          } else if (_selectedTimeFilter == 'ThisMonth') {
            if (txDate.year != now.year || txDate.month != now.month) return false;
          } else if (_selectedTimeFilter == 'LastMonth') {
            final lastMonthDate = DateTime(now.year, now.month - 1, 1);
            if (txDate.year != lastMonthDate.year || txDate.month != lastMonthDate.month) return false;
          } else if (_selectedTimeFilter == 'Last7Days') {
            final sevenDaysAgo = now.subtract(const Duration(days: 7));
            if (txDate.isBefore(sevenDaysAgo) || txDate.isAfter(now)) return false;
          }
        }
      }

      // Smart Vietnamese Accented & Unaccented Search Logic
      if (_searchQuery.trim().isNotEmpty) {
        final rawQuery = _searchQuery.trim();
        final normQuery = _removeDiacritics(rawQuery);

        final title = (tx['title'] ?? '').toString();
        final id = (tx['id'] ?? '').toString();
        final cardName = (tx['cardName'] ?? '').toString();
        final category = (tx['category'] ?? '').toString();
        final amountStr = (tx['amount'] ?? '').toString();

        final normTitle = _removeDiacritics(title);
        final normId = _removeDiacritics(id);
        final normCardName = _removeDiacritics(cardName);
        final normCategory = _removeDiacritics(category);

        final matchesQuery = normTitle.contains(normQuery) ||
            normId.contains(normQuery) ||
            normCardName.contains(normQuery) ||
            normCategory.contains(normQuery) ||
            amountStr.contains(rawQuery);

        if (!matchesQuery) return false;
      }
      return true;
    }).toList();
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    final dt = DateTime.tryParse(rawDate)?.toLocal();
    if (dt == null) return rawDate;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day $hour:$minute';
  }

  void _showTransactionDetails(Map<String, dynamic> tx) {
    HapticService.selectionFeedback();
    final bool isExpense = tx['isExpense'] == true;
    final bool isSuccess = tx['status'] == 'Success';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isExpense
                    ? Colors.redAccent.withValues(alpha: 0.15)
                    : Colors.greenAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpense ? Icons.shopping_bag_outlined : Icons.account_balance_wallet_outlined,
                size: 36,
                color: isExpense ? Colors.redAccent : Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tx['title'].toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              '${isExpense ? '-' : '+'}\$${tx['amount']}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isExpense ? Colors.redAccent : Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            _buildDetailRow('Mã giao dịch', tx['id'].toString()),
            _buildDetailRow('Thời gian', _formatDate(tx['date']?.toString())),
            _buildDetailRow('Danh mục', (tx['category'] ?? 'Giao dịch').toString()),
            _buildDetailRow('Nguồn tiền/Thẻ', tx['cardName'].toString()),
            _buildDetailRow(
              'Trạng thái',
              isSuccess ? 'Thành công' : 'Thất bại',
              valueColor: isSuccess ? Colors.greenAccent : Colors.redAccent,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                child: const Text('Đóng Hóa Đơn'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  void _showExportResult(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: SelectableText(content, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.cyanAccent)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: Colors.white70)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

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
      if (tx['status'] == 'Success') {
        successCount++;
        if (tx['isExpense'] == true) {
          totalExpense += (tx['amount'] as num).toDouble();
        } else {
          totalIncome += (tx['amount'] as num).toDouble();
        }
      }
    }

    double avgAmount = successCount > 0 ? (totalExpense + totalIncome) / successCount : 0.0;
    double successRate = totalCount > 0 ? (successCount / totalCount) * 100 : 100.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Title Header & Export Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localeProvider.getText('transactions'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.purpleAccent, size: 22),
                  tooltip: localeProvider.getText('export_pdf'),
                  onPressed: () {
                    HapticService.successFeedback();
                    final pdf = ExportService.generatePDFReport(filtered);
                    _showExportResult(localeProvider.getText('export_pdf'), pdf);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.table_chart, color: Colors.tealAccent, size: 22),
                  tooltip: localeProvider.getText('export_csv'),
                  onPressed: () {
                    HapticService.successFeedback();
                    final csv = ExportService.generateCSV(filtered);
                    _showExportResult(localeProvider.getText('export_csv'), csv);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
                  tooltip: localeProvider.getText('clear_history'),
                  onPressed: _clearTransactionHistory,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // -------------------------------------------------------------
        // 1. FINTECH ANALYTICS & FREQUENCY BANNER
        // -------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1E38), Color(0xFF2A2A4E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                          children: const [
                            Icon(Icons.arrow_downward_rounded, color: Colors.redAccent, size: 16),
                            SizedBox(width: 4),
                            Text('TỔNG CHI TIÊU', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
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
                  Container(width: 1, height: 40, color: Colors.white12),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.arrow_upward_rounded, color: Colors.greenAccent, size: 16),
                            SizedBox(width: 4),
                            Text('TỔNG NHẬN TIỀN', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 14),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 14),

              // Row 2: Frequency & Statistics Metrics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeProvider.getText('total_transactions').toUpperCase(),
                        style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.cyanAccent),
                          const SizedBox(width: 4),
                          Text(
                            '$totalCount lượt',
                            style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeProvider.getText('avg_amount').toUpperCase(),
                        style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          localeProvider.formatAmount(avgAmount),
                          style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        localeProvider.getText('success_rate').toUpperCase(),
                        style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${successRate.toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // -------------------------------------------------------------
        // 2. SEARCH BAR
        // -------------------------------------------------------------
        TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm giao dịch, tên thẻ, số tiền (VD: thanh toan, 50000)...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),

        const SizedBox(height: 12),

        // -------------------------------------------------------------
        // 3. MULTI-FILTER DROPDOWNS (TIME, STATUS, CARD TYPE)
        // -------------------------------------------------------------
        // Dropdown 1: Time Filter
        DropdownButtonFormField<String>(
          initialValue: _selectedTimeFilter,
          dropdownColor: const Color(0xFF16213E),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            labelText: localeProvider.getText('time_filter'),
            labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.03),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: [
            DropdownMenuItem(value: 'All', child: Text('${localeProvider.getText('filter_all')} (Tất cả thời gian)')),
            DropdownMenuItem(value: 'Today', child: Text(localeProvider.getText('filter_today'))),
            DropdownMenuItem(value: 'ThisMonth', child: Text(localeProvider.getText('filter_this_month'))),
            DropdownMenuItem(value: 'LastMonth', child: Text(localeProvider.getText('filter_last_month'))),
            DropdownMenuItem(value: 'Last7Days', child: Text(localeProvider.getText('filter_last_7_days'))),
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
                dropdownColor: const Color(0xFF16213E),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Trạng thái',
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.03),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  DropdownMenuItem(value: 'All', child: Text(localeProvider.getText('filter_all'))),
                  DropdownMenuItem(value: 'Success', child: Text(localeProvider.getText('filter_success'))),
                  DropdownMenuItem(value: 'Failed', child: Text(localeProvider.getText('filter_failed'))),
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
                dropdownColor: const Color(0xFF16213E),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Loại thẻ / NFC',
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.03),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('Tất cả loại thẻ')),
                  DropdownMenuItem(value: 'Visa', child: Text('Visa')),
                  DropdownMenuItem(value: 'Mastercard', child: Text('Mastercard')),
                  DropdownMenuItem(value: 'NFC', child: Text('NFC Contactless')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCardType = val);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // -------------------------------------------------------------
        // 4. REAL DETAILED TRANSACTION HISTORY LIST
        // -------------------------------------------------------------
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            child: const Center(
              child: Text(
                'Chưa có lịch sử giao dịch phù hợp với bộ lọc.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          )
        else
          ...filtered.map((tx) {
            final bool isExpense = tx['isExpense'] == true;
            final bool isSuccess = tx['status'] == 'Success';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ListTile(
                onTap: () => _showTransactionDetails(tx),
                leading: CircleAvatar(
                  backgroundColor: isExpense
                      ? Colors.redAccent.withValues(alpha: 0.15)
                      : Colors.greenAccent.withValues(alpha: 0.15),
                  child: Icon(
                    isExpense ? Icons.shopping_bag_outlined : Icons.account_balance_wallet_outlined,
                    color: isExpense ? Colors.redAccent : Colors.greenAccent,
                    size: 22,
                  ),
                ),
                title: Text(
                  tx['title'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                ),
                subtitle: Text(
                  '${tx['id']} • ${_formatDate(tx['date']?.toString())}\n${tx['cardName']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 120,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${isExpense ? '-' : '+'}${localeProvider.formatAmount(tx['amount'])}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isExpense ? Colors.redAccent : Colors.greenAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSuccess ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isSuccess ? 'Thành công' : 'Thất bại',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSuccess ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
