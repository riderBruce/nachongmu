import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NamePage extends StatefulWidget {
  const NamePage({super.key});

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  List<Map<String, dynamic>> _items = [];

  final _nBox = Hive.box('nBox');

  @override
  void initState() {
    super.initState();
    _refreshItems();
  }

  void _refreshItems() {
    final data = _nBox.keys.map((key) {
      final value = _nBox.get(key);
      return {"key": key, "name": value["name"]};
    }).toList();

    setState(() {
      _items = data.toList();
    });
  }

  Future<void> _createItem(Map<String, dynamic> newItem) async {
    await _nBox.add(newItem);
    _refreshItems();
  }

  Map<String, dynamic> _readItem(int key) {
    final item = _nBox.get(key);
    return item;
  }

  Future<void> _updateItem(int itemKey, Map<String, dynamic> item) async {
    await _nBox.put(itemKey, item);
    _refreshItems();
  }

  Future<void> _deleteItem(int itemKey) async {
    await _nBox.delete(itemKey);
    _refreshItems();

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An item has been deleted")));
  }

  final TextEditingController _nameController = TextEditingController();

  // applied to both floating button and update button
  void _showForm(BuildContext ctx, int? itemKey) async {
    if (itemKey != null) {
      final existingItem =
          _items.firstWhere((element) => element["key"] == itemKey);
      _nameController.text = existingItem['name'];
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
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Name'),
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: () async {
                if (itemKey == null) {
                  _createItem({"name": _nameController.text});
                }
                if (itemKey != null) {
                  _updateItem(itemKey, {'name': _nameController.text.trim()});
                }
                _nameController.text = '';
                Navigator.of(context).pop();
              },
              child: Text(itemKey == null ? 'Create New' : 'Update'),
            ),
            const SizedBox(
              height: 15,
            ),
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
      body: _items.isEmpty
          ? const Center(
              child: Text("No Data", style: TextStyle(fontSize: 30)),
            )
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (_, index) {
                final currentItem = _items[index];
                return Card(
                  color: Color.fromARGB(255, 178, 231, 255),
                  margin: const EdgeInsets.all(10),
                  elevation: 3,
                  child: ListTile(
                    title: Text(currentItem['name']),
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
