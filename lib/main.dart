import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

void main() => runApp(const TTDApp());

class TTDApp extends StatelessWidget {
  const TTDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Topstep Tracker',
      theme: ThemeData.dark(),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Trade {
  final String date;
  final int number;
  final double pnl;
  final String note;
  final String? screenshotPath;

  Trade({
    required this.date,
    required this.number,
    required this.pnl,
    required this.note,
    this.screenshotPath,
  });

  bool get isWin => pnl >= 0;

  Map<String, dynamic> toJson() => {
        'date': date,
        'number': number,
        'pnl': pnl,
        'note': note,
        'screenshotPath': screenshotPath,
      };

  static Trade fromJson(Map<String, dynamic> json) => Trade(
        date: json['date'],
        number: json['number'],
        pnl: json['pnl'],
        note: json['note'],
        screenshotPath: json['screenshotPath'],
      );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double startingBalance = 50000;
  double profitTarget = 3000;
  double maxLossLimit = 2000;
  List<Trade> trades = [];
  List<String> savedAccounts = [];
  String? currentAccount;
  bool showCalendar = false;

  final _dateController = TextEditingController();
  final _tradeNumberController = TextEditingController();
  final _pnlController = TextEditingController();
  final _noteController = TextEditingController();

  double get currentBalance => trades.fold(startingBalance, (sum, t) => sum + t.pnl);
  double get highestBalance {
    double balance = startingBalance, high = startingBalance;
    for (var t in trades) {
      balance += t.pnl;
      if (balance > high) high = balance;
    }
    return high;
  }

  double get trailingLossLimit => highestBalance - maxLossLimit;

  void addTrade() {
    final date = _dateController.text;
    final number = int.tryParse(_tradeNumberController.text) ?? 0;
    final pnl = double.tryParse(_pnlController.text) ?? 0;
    final note = _noteController.text;
    if (date.isEmpty || number == 0) return;
    setState(() {
      trades.add(Trade(date: date, number: number, pnl: pnl, note: note));
      trades.sort((a, b) => a.date.compareTo(b.date));
    });
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _tradeNumberController.clear();
    _pnlController.clear();
    _noteController.clear();
    saveCurrentState();
  }

  Future<void> pickScreenshot(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        trades[index] = Trade(
          date: trades[index].date,
          number: trades[index].number,
          pnl: trades[index].pnl,
          note: trades[index].note,
          screenshotPath: result.files.single.path!,
        );
      });
      saveCurrentState();
    }
  }

  Future<void> saveCurrentState() async {
    if (currentAccount == null) {
      final controller = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Save Account As"),
          content: TextField(controller: controller),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text("Save")),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty) return;
      currentAccount = name.trim();
      savedAccounts.add(currentAccount!);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('accounts', savedAccounts);
    await prefs.setString('${currentAccount!}_trades', jsonEncode(trades.map((t) => t.toJson()).toList()));
    await prefs.setDouble('${currentAccount!}_starting', startingBalance);
  }

  Future<void> loadAccount(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final savedTrades = prefs.getString('${name}_trades');
    if (savedTrades != null) {
      final list = jsonDecode(savedTrades) as List;
      trades = list.map((e) => Trade.fromJson(e)).toList();
      trades.sort((a, b) => a.date.compareTo(b.date));
    }
    startingBalance = prefs.getDouble('${name}_starting') ?? 50000;
    currentAccount = name;
    setState(() {});
  }

  Future<void> deleteAccount(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${name}_trades');
    await prefs.remove('${name}_starting');
    savedAccounts.remove(name);
    if (currentAccount == name) {
      trades.clear();
      currentAccount = null;
    }
    await prefs.setStringList('accounts', savedAccounts);
    setState(() {});
  }

  List<FlSpot> get _chartSpots {
    double balance = startingBalance;
    return trades.asMap().entries.map((entry) {
      balance += entry.value.pnl;
      return FlSpot(entry.key.toDouble(), balance);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    SharedPreferences.getInstance().then((prefs) {
      savedAccounts = prefs.getStringList('accounts') ?? [];
      setState(() {});
    });
  }

  void showScreenshotModal(String? path) {
    if (path == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Image.file(File(path), fit: BoxFit.contain),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(currentAccount ?? 'Topstep Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => setState(() => showCalendar = !showCalendar),
          ),
          DropdownButton<String>(
            hint: const Text("Accounts", style: TextStyle(color: Colors.white)),
            value: null,
            dropdownColor: Colors.grey[900],
            items: savedAccounts.map((acc) {
              return DropdownMenuItem(
                value: acc,
                child: Row(
                  children: [
                    Text(acc, style: const TextStyle(color: Colors.white)),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteAccount(acc),
                    )
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) => loadAccount(val!),
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: saveCurrentState)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              children: [
                _statCard("Balance", "\$${currentBalance.toStringAsFixed(2)}", Colors.blue),
                _statCard("Profit Target", "\$${(startingBalance + profitTarget).toStringAsFixed(2)}", Colors.green),
                _statCard("Trailing Loss", "\$${trailingLossLimit.toStringAsFixed(2)}", Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _chartSpots,
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.orange,
                      dotData: FlDotData(show: false),
                    )
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(y: startingBalance + profitTarget, color: Colors.green, strokeWidth: 1),
                      HorizontalLine(y: trailingLossLimit, color: Colors.red, strokeWidth: 1),
                    ],
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                ),
              ),
            ),
            if (showCalendar) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                height: 300,
                child: SfDateRangePicker(
                  view: DateRangePickerView.month,
                  selectionColor: Colors.transparent,
                  onSelectionChanged: (args) {
                    if (args.value is DateTime) {
                      _dateController.text = DateFormat('yyyy-MM-dd').format(args.value);
                      setState(() => showCalendar = false);
                    }
                  },
                  cellBuilder: (context, details) {
                    final dateStr = DateFormat('yyyy-MM-dd').format(details.date);
                    final dayTrades = trades.where((t) => t.date == dateStr).toList();
                    Color bgColor = Colors.transparent;
                    if (dayTrades.isNotEmpty) {
                      final net = dayTrades.fold(0.0, (sum, t) => sum + t.pnl);
                      bgColor = net >= 0 ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3);
                    }
                    return Container(
                      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('${details.date.day}', style: const TextStyle(color: Colors.white)),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: () => setState(() => showCalendar = true),
                    decoration: const InputDecoration(labelText: "Date"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _tradeNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Trade #"),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pnlController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "PnL"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    onSubmitted: (_) => addTrade(),
                    decoration: const InputDecoration(labelText: "Note"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: addTrade,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
              child: const Text("Add Trade"),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: trades.length,
                itemBuilder: (_, i) {
                  final t = trades[i];
                  return Card(
                    color: t.isWin ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    child: ListTile(
                      title: Text("${t.date} - Trade ${t.number}"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("PnL: \$${t.pnl.toStringAsFixed(2)}",
                              style: TextStyle(color: t.isWin ? Colors.green : Colors.red)),
                          if (t.note.isNotEmpty) Text("Note: ${t.note}"),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.image),
                        onPressed: () => t.screenshotPath != null
                            ? showScreenshotModal(t.screenshotPath)
                            : pickScreenshot(i),
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 14)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
