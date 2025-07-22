import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Topstep Tracker',
      theme: ThemeData.dark(),
      home: DashboardScreen(),
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

  Trade({required this.date, required this.number, required this.pnl, this.note = '', this.screenshotPath});
}

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final double startingBalance = 50000;
  final double profitTarget = 3000;
  final double trailingLimitOffset = 2000;

  List<Trade> trades = [];
  final _dateController = TextEditingController();
  final _tradeNumberController = TextEditingController();
  final _pnlController = TextEditingController();
  final _noteController = TextEditingController();

  double get currentBalance {
    return trades.fold(startingBalance, (sum, trade) => sum + trade.pnl);
  }

  double get highestBalance {
    double balance = startingBalance;
    double high = startingBalance;
    for (var trade in trades) {
      balance += trade.pnl;
      if (balance > high) high = balance;
    }
    return high;
  }

  double get trailingLossLimit => highestBalance - trailingLimitOffset;

  void addTrade() {
    final date = _dateController.text;
    final number = int.tryParse(_tradeNumberController.text) ?? 0;
    final pnl = double.tryParse(_pnlController.text) ?? 0;
    final note = _noteController.text;

    if (date.isEmpty || number == 0) return;

    setState(() {
      trades.add(Trade(date: date, number: number, pnl: pnl, note: note));
    });

    _dateController.clear();
    _tradeNumberController.clear();
    _pnlController.clear();
    _noteController.clear();
  }

  List<FlSpot> get _chartSpots {
    double balance = startingBalance;
    List<FlSpot> spots = [];
    for (int i = 0; i < trades.length; i++) {
      balance += trades[i].pnl;
      spots.add(FlSpot(i.toDouble(), balance));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Topstep Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 20,
              children: [
                _statCard("Balance", currentBalance.toStringAsFixed(2), Colors.blue),
                _statCard("Profit Target", (startingBalance + profitTarget).toStringAsFixed(2), Colors.green),
                _statCard("Trailing Loss Limit", trailingLossLimit.toStringAsFixed(2), Colors.red),
              ],
            ),
            SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _chartSpots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(y: startingBalance + profitTarget, color: Colors.green, strokeWidth: 1),
                      HorizontalLine(y: trailingLossLimit, color: Colors.red, strokeWidth: 1),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: TextField(controller: _dateController, decoration: InputDecoration(labelText: "Date"))),
                SizedBox(width: 10),
                Expanded(child: TextField(controller: _tradeNumberController, decoration: InputDecoration(labelText: "Trade #"), keyboardType: TextInputType.number)),
                SizedBox(width: 10),
                Expanded(child: TextField(controller: _pnlController, decoration: InputDecoration(labelText: "PnL"), keyboardType: TextInputType.number)),
              ],
            ),
            SizedBox(height: 10),
            TextField(controller: _noteController, decoration: InputDecoration(labelText: "Trade Notes")),
            SizedBox(height: 10),
            ElevatedButton(onPressed: addTrade, child: Text("Add Trade")),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: trades.length,
                itemBuilder: (context, index) {
                  final t = trades[index];
                  return ListTile(
                    title: Text("${t.date} - Trade ${t.number}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("PnL: \$${t.pnl.toStringAsFixed(2)}"),
                        if (t.note.isNotEmpty) Text("Note: ${t.note}"),
                        if (t.screenshotPath != null) Text("Screenshot: ${t.screenshotPath}"),
                      ],
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
      color: color.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 14)),
            Text("$value", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
          ],
        ),
      ),
    );
  }
}
