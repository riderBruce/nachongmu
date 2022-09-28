import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  List<String> _names = [];
  List<Map<String, dynamic>> _payments = [];
  String payerName = "";

  // final _nBox = Hive.box('nBox');
  final _nameBox = Hive.box('nameBox');
  final _payBox = Hive.box('payBox');

  @override
  void initState() {
    super.initState();
    _refreshNames();
    _refreshPayments();
  }

  void _refreshNames() {
    final data = _nameBox.values.map((e) => e as String).toList();
    // final List<String> data =
    //     _nBox.values.map((e) => e["name"].toString()).toList();
    setState(() {
      _names = data;
      payerName = data.isNotEmpty ? data.first : '누구?';
    });
  }

  void _refreshPayments() {
    final data = _payBox.keys.map((key) {
      final value = _payBox.get(key);
      return {
        "key": key,
        "sort": value["sort"],
        "amount": value["amount"] as int,
        "payer": value["payer"]
      };
    }).toList();

    setState(() {
      _payments = data.toList();
    });
  }

  Future<void> _createItem(Map<String, dynamic> newItem) async {
    await _payBox.add(newItem);
    _refreshPayments();
  }

  Map<String, dynamic> _readItem(int key) {
    final item = _payBox.get(key);
    return item;
  }

  Future<void> _updateItem(int itemKey, Map<String, dynamic> item) async {
    await _payBox.put(itemKey, item);
    _refreshPayments();
  }

  Future<void> _deleteItem(int itemKey) async {
    await _payBox.delete(itemKey);
    _refreshPayments();

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An item has been deleted")));
  }

  final TextEditingController _sortController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  // applied to both floating button and update button
  void _showForm(BuildContext ctx, int? itemKey) async {
    if (itemKey != null) {
      final existingItem =
          _payments.firstWhere((element) => element["key"] == itemKey);
      _sortController.text = existingItem['sort'];
      _amountController.text = existingItem['amount'].toString();
      payerName = existingItem['payer'];
    }

    showModalBottomSheet(
      context: ctx,
      elevation: 5,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          top: 15,
          left: 15,
          right: 15,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: _sortController,
              decoration: const InputDecoration(hintText: 'sort'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(hintText: 'amount'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              isExpanded: true,
              enableFeedback: true,
              items: _names
                  .map((name) => DropdownMenuItem(
                        value: name,
                        child: Text(name),
                      ))
                  .toList(),
              onChanged: (name) {
                setState(() {
                  payerName = name as String;
                });
              },
              value: payerName,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (itemKey == null) {
                  _createItem({
                    "sort": _sortController.text,
                    "amount": int.parse(_amountController.text),
                    "payer": payerName,
                  });
                }
                if (itemKey != null) {
                  _updateItem(itemKey, {
                    'sort': _sortController.text.trim(),
                    'amount': int.parse(_amountController.text.trim()),
                    'payer': payerName,
                  });
                }
                _sortController.text = '';
                _amountController.text = '';
                Navigator.of(context).pop();
              },
              child: Text(itemKey == null ? 'Create New' : 'Update'),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context, null),
        child: const Icon(Icons.add),
      ),
      body: _payments.isEmpty
          ? const Center(
              child: Text("No Data", style: TextStyle(fontSize: 30)),
            )
          : ListView.builder(
              itemCount: _payments.length,
              itemBuilder: (_, index) {
                final currentItem = _payments[index];
                return Card(
                  color: const Color.fromARGB(255, 219, 208, 113),
                  margin: const EdgeInsets.all(10),
                  elevation: 3,
                  child: ListTile(
                    leading: SizedBox(
                      width: 100,
                      child: Text(
                        NumberFormat('###,###,###,###')
                            .format(currentItem['amount']),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(currentItem['sort']),
                    subtitle: Text(
                      currentItem['payer'] ??= '',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () =>
                              _showForm(context, currentItem['key']),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => _deleteItem(currentItem['key']),
                          icon: const Icon(Icons.delete),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
