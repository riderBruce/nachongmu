// import 'dart:html';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:textfield_tags/textfield_tags.dart';

class SettlePage extends StatefulWidget {
  const SettlePage({super.key});

  @override
  State<SettlePage> createState() => _SettlePageState();
}

class _SettlePageState extends State<SettlePage> {
  List<String> _names = [];
  // List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _settle = [];
  List<String> _resultSettle = [];
  final TextEditingController _sortController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String payerName = "";

  final _nameBox = Hive.box('nameBox');
  final _payBox = Hive.box('payBox');
  final _settleBox = Hive.box('settleBox');

  late double _distanceToField;
  late TextfieldTagsController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _distanceToField = MediaQuery.of(context).size.width;
  }

  @override
  void dispose() {
    super.dispose();
    _settle.isNotEmpty ? _controller.dispose() : null;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextfieldTagsController();
    // refreshAll();
    _refreshNames();
    // _refreshPayments();
    _initializeSettle();
  }

  void _refreshNames() {
    final data = _nameBox.values.map((e) => e as String).toList();
    setState(() {
      _names = data;
    });
  }

  // Future<void> _refreshPayments() async {
  //   final data = await _payBox.keys.map((key) {
  //     final value = _payBox.get(key);
  //     return {
  //       "key": key,
  //       "sort": value["sort"],
  //       "amount": value["amount"],
  //       "payer": value["payer"]
  //     };
  //   }).toList();
  //   setState(() {
  //     _payments = data;
  //   });
  // }

  Future<void> _initializeSettle() async {
    if (_names.isEmpty) {
      await _settleBox.clear();
      return;
    }

    // ??????????????? ?????? ?????????
    if (_settleBox.isEmpty) {
      // add name columns on payment box data
      final payBoxData = _payBox.keys.map((key) {
        final value = _payBox.get(key);
        for (String name in _names) {
          value.addAll({name: true});
        }
        return {key as int: value};
      }).toList();

      // save settle box with calculated data
      for (var d in payBoxData) {
        d.forEach((k, v) => _settleBox.put(k, v));
      }
    }

    // Total ?????? ????????? (??????)
    _settleBox.keys
        .where((e) => _settleBox.get(e)["sort"] == "Total")
        .forEach((e) async => await _settleBox.delete(e));

    // payment ?????? ????????? ?????????
    List<int> paymentKeys = _payBox.keys.map((e) => e as int).toList();
    List<int> settleKeys = _settleBox.keys.map((e) => e as int).toList();
    if (!listEquals(paymentKeys, settleKeys)) {
      // paymentkeys ?????? settlekey??? ?????? ?????? ????????? ??????????????? settle?????? ??????
      settleKeys
          .where((x) => !paymentKeys.contains(x))
          .forEach((x) async => await _settleBox.delete(x));
      // settlekey?????? paymentkey??? ?????? ????????? ????????? ??????????????? settle??? ??????
      paymentKeys.where((x) => !settleKeys.contains(x)).forEach((x) {
        var value = _payBox.get(x);
        _settleBox.put(x, <String, dynamic>{
          "sort": value["sort"],
          "amount": value["amount"],
          "payer": value["payer"],
          for (var name in _names) name: true,
        });
      });
    }

    // payment ?????? ?????? ??????
    for (var key in _payBox.keys) {
      var value = await _payBox.get(key);
      await _settleBox.put(key, value);
    }

    // ????????? ??????????????? ?????? settle?????? ????????? ??????
    for (var row in _settleBox.values) {
      for (var rKey in row.keys.toList()) {
        if (['sort', 'amount', 'payer', 'len', 'nPay'].contains(rKey)) {
          continue;
        }
        if (!_names.contains(rKey)) {
          await row.remove(rKey);
        }
      }
    }

    // settle ???????????? ????????? ????????? ?????? ????????? ?????? ????????? ????????? ?????????
    for (var row in _settleBox.values) {
      print("?????? : " + row.toString());
      for (var name in _names) {
        if (!row.keys.contains(name)) {
          await row.addAll({name: true});
          print("?????? : " + row.toString());
        }
      }
    }

    // ???????????? ?????? ??????
    for (var e in _settleBox.values) {
      int len = e.values.where((x) => x == true).length;
      await e.addAll({"len": len});
    }

    // ?????? ?????? ??????
    for (var e in _settleBox.keys) {
      var value = await _settleBox.get(e);
      int amount = value["amount"] as int;
      int len = value["len"];
      int nPay = 0;
      if (len > 0) {
        nPay = (amount / len).round();
      }
      await value.addAll({"nPay": nPay});
    }

    // Total : ????????? ?????? ??????
    int totalAmount = _settleBox.values.map((e) => e["amount"] as int).sum;
    Map<String, int> totalByEach = {};
    for (var name in _names) {
      int eachAmount = _settleBox.values
          .where((x) => x[name] == true)
          .map((x) => x["nPay"] as int)
          .sum;
      totalByEach.addAll({name: eachAmount});
    }
    var row = {
      "sort": "Total",
      "amount": totalAmount,
      "payer": "?????????",
      ...totalByEach,
    };
    await _settleBox.add(row);

    // Total : ????????? ?????? ??????
    Map<String, int> totalAdvancedByEach = {};
    for (var name in _names) {
      int eachAdvAmount = 0;
      for (var row in _settleBox.values) {
        if (row["payer"] == name) {
          eachAdvAmount += row["amount"] as int;
        }
      }
      totalAdvancedByEach.addAll({name: eachAdvAmount});
    }
    var rowAdvanced = {
      "sort": "Total",
      "amount": null,
      "payer": "?????????",
      ...totalAdvancedByEach,
    };
    await _settleBox.add(rowAdvanced);

    // Total : ????????? ?????? ??????
    Map<String, int> totalSettleByEach = {};
    for (var name in _names) {
      int eachSettleAmount = 0;
      for (var row in _settleBox.values) {
        if (row["payer"] == "?????????") {
          eachSettleAmount += row[name] as int;
        }
        if (row["payer"] == "?????????") {
          eachSettleAmount -= row[name] as int;
        }
      }
      totalSettleByEach.addAll({name: eachSettleAmount});
    }
    var rowSettled = {
      "sort": "Total",
      "amount": null,
      "payer": "?????????",
      ...totalSettleByEach,
    };
    await _settleBox.add(rowSettled);

    // DB?????? ?????? ????????? ????????????
    final settleBoxData = _settleBox.keys.map((key) {
      final value = _settleBox.get(key);
      Map<String, dynamic> temp = {"key": key};
      temp.addAll(Map.from(value));
      return temp;
    }).toList();

    // ?????? ????????? ?????????
    List<String> resultSettle = [];

    String totalPayment = NumberFormat('###,###,###,###').format(totalAmount);
    resultSettle.add("?????? ?????? : $totalPayment");

    String minName = "";
    minName = _names.first;
    Map<String, dynamic> _settleRow =
        _settleBox.values.firstWhere((e) => e["payer"] == "?????????");
    Map<String, int> settleRow = Map.fromIterable(
        _settleRow.keys.where((e) => _names.contains(e)).toList()
          ..sort((x, y) => _settleRow[y].compareTo(_settleRow[x])),
        value: (e) => _settleRow[e]);
    // int min = settleRow[minName] ??= 0;
    resultSettle.add("?????? ????????? $minName??? ???????????? ???????????????.");

    settleRow.forEach((k, v) {
      if (k != minName) {
        if (v < 0) {
          int minusSettle = v * -1;
          String strMinusSettle =
              NumberFormat('###,###,###,###').format(minusSettle);
          resultSettle.add(" - $minName ??? $k?????? $strMinusSettle??? ???????????????. ");
        } else if (v == 0) {
        } else {
          String strV = NumberFormat('###,###,###,###').format(v);
          resultSettle.add(" - $k ??? $minName?????? $strV??? ???????????????. ");
        }
      }
    });

    setState(() {
      payerName = _names.first;
      _settle = settleBoxData;
      _resultSettle = resultSettle;
    });
  }

  Future<void> _updateSettleBox(int itemKey, Map<String, dynamic> item) async {
    // get specific data from box
    final value = _settleBox.get(itemKey);
    // add data to varable
    value.addAll(item);
    // add data to box
    await _settleBox.put(itemKey, value);
    // get all data from box
    final settleBoxData = _settleBox.keys.map((key) {
      final value = _settleBox.get(key);
      Map<String, dynamic> temp = {"key": key};
      temp.addAll(Map.from(value));
      return temp;
    }).toList();
    // set state
    setState(() {
      _settle = settleBoxData;
    });
  }

  Future<void> _updatePayBox(int itemKey, Map<String, dynamic> item) async {
    final value = _payBox.get(itemKey);
    value.addAll(item);
    await _payBox.put(itemKey, value);
    final payBoxData = _payBox.keys.map((key) {
      final value = _payBox.get(key);
      Map<String, dynamic> temp = {"key": key};
      temp.addAll(Map.from(value));
      return temp;
    }).toList();
    _initializeSettle();
  }

  void refreshAll() {
    _nameBox.clear();
    _names = [];
    _resultSettle = [];
    _payBox.clear();
    _settleBox.clear();
    _settle = [];
  }

  Widget refreshButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        setState(() {
          refreshAll();
          _controller.clearTags();
          _initializeSettle();
        });
      },
      label: const Text('Refresh'),
      icon: const Icon(Icons.refresh),
      backgroundColor: Colors.green[400],
    );
  }

  Widget titleTextWidget(String title) {
    return Row(
      children: [
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget explainTextWidget(String content) {
    return Text(
      content,
      style: const TextStyle(
          color: Color.fromARGB(255, 74, 137, 92), fontSize: 10),
    );
  }

  Widget nameFieldWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            titleTextWidget("Name"),
            explainTextWidget('????????????, ??????/?????????/????????? ??????. ?????? ?????? ??????.'),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 10),
            Expanded(
              child: TextFieldTags(
                textfieldTagsController: _controller,
                initialTags:
                    _names.isNotEmpty ? _names : const ['???', '???', '???', '???'],
                textSeparators: const [' ', ',', '.'],
                letterCase: LetterCase.normal,
                inputfieldBuilder:
                    (context, tec, fn, error, onChanged, onSubmitted) {
                  return ((context, sc, tags, onTagDelete) {
                    return Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: TextField(
                        controller: tec,
                        focusNode: fn,
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color.fromARGB(255, 74, 137, 92),
                              width: 3.0,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color.fromARGB(255, 74, 137, 92),
                              width: 3.0,
                            ),
                          ),
                          // helperText: '?????? ???????????? ???????????????. ????????? ????????? ??????????????????.',
                          helperStyle: const TextStyle(
                            color: Color.fromARGB(255, 74, 137, 92),
                          ),
                          hintText: _controller.hasTags ? '' : "Enter tag...",
                          errorText: error,
                          prefixIconConstraints:
                              BoxConstraints(maxWidth: _distanceToField * 0.74),
                          prefixIcon: tags.isNotEmpty
                              ? SingleChildScrollView(
                                  controller: sc,
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                      children: tags.map((String tag) {
                                    return Container(
                                      decoration: const BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(20.0),
                                        ),
                                        color: Color.fromARGB(255, 74, 137, 92),
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 5.0),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10.0, vertical: 5.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          InkWell(
                                            child: Text(
                                              tag,
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                            onTap: () {
                                              print("$tag selected");
                                            },
                                          ),
                                          const SizedBox(width: 4.0),
                                          InkWell(
                                            child: const Icon(
                                              Icons.cancel,
                                              size: 14.0,
                                              color: Color.fromARGB(
                                                  255, 233, 233, 233),
                                            ),
                                            onTap: () {
                                              onTagDelete(tag);
                                            },
                                          )
                                        ],
                                      ),
                                    );
                                  }).toList()),
                                )
                              : null,
                        ),
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                      ),
                    );
                  });
                },
              ),
            ),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(
                  const Color.fromARGB(255, 74, 137, 92),
                ),
              ),
              onPressed: () async {
                await _nameBox.clear();
                var tags = _controller.getTags?.toSet().toList();
                tags?.forEach((e) => _nameBox.add(e));
                var data = _nameBox.values.map((e) => e as String).toList();
                _sortController.text = "???";
                _amountController.text = "20";
                setState(() {
                  _names = data;
                  _initializeSettle();
                });
              },
              child: const Text('Set'),
            ),
            const SizedBox(width: 15),
          ],
        ),
      ],
    );
  }

  Future<void> _createItem(Map<String, dynamic> newItem) async {
    await _payBox.add(newItem);
    // _initializeSettle();
  }

  Widget inputPayment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            titleTextWidget("Payment"),
            const Text(
              "???????????? ????????? ??????????????????.",
              style: TextStyle(
                  color: Color.fromARGB(255, 74, 137, 92), fontSize: 10),
            )
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 20),
            Expanded(
              child: Container(
                // decoration: BoxDecoration(
                //   border: Border.all(color: Colors.grey),
                //   borderRadius: const BorderRadius.all(Radius.circular(3.0)),
                // ),
                child: Row(
                  children: [
                    Flexible(
                      child: TextField(
                        controller: _sortController,
                        onTap: () => _sortController.text = "",
                        // decoration: const InputDecoration(hintText: '??????'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        controller: _amountController,
                        onTap: () => _amountController.text = "",
                        // decoration: const InputDecoration(hintText: '??????'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: DropdownButtonFormField(
                        isExpanded: true,
                        enableFeedback: true,
                        items: _names
                            .map((name) => DropdownMenuItem(
                                value: name, child: Text(name)))
                            .toList(),
                        onChanged: (name) {
                          setState(() {
                            payerName = name as String;
                          });
                        },
                        // value: payerName,
                        value: payerName.isEmpty ? null : payerName,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(
                  const Color.fromARGB(255, 74, 137, 92),
                ),
              ),
              onPressed: () async {
                _createItem({
                  "sort": _sortController.text,
                  "amount": int.parse(_amountController.text),
                  "payer": payerName,
                });
                _initializeSettle();
                _sortController.text = '???';
                _amountController.text = '20';
                // Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
            const SizedBox(width: 15),
          ],
        ),
      ],
    );
  }

  Widget resultText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            titleTextWidget("Settle"),
            explainTextWidget('??????????????? ????????? ?????? ????????? ?????? ??? ????????????'),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._resultSettle.map(
                  (e) => Text(
                    e.toString(),
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          ],
        )
      ],
    );
  }

  Widget headbutton(String buttonText) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          minimumSize: const Size.fromHeight(40),
          maximumSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: const Color.fromARGB(255, 74, 137, 92),
        ),
        onPressed: () {},
        child: Text(
          buttonText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }

  Widget rowButton(dynamic buttonText) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          minimumSize: const Size.fromHeight(40),
          maximumSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: Colors.white,
        ),
        onPressed: () {},
        child: Text(
          buttonText.runtimeType == int
              ? NumberFormat('###,###,###,###').format(buttonText)
              : buttonText.toString(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }

  Widget payerButton(int key, String name) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          minimumSize: const Size.fromHeight(40),
          maximumSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: const Color.fromARGB(255, 9, 199, 91),
        ),
        onPressed: () {
          int i = _names.indexOf(name);
          i++;
          i = i % _names.length;
          name = _names[i];
          _updatePayBox(key, {'payer': name});
        },
        child: Text(
          name.toString(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }

  Widget oxButton(int key, String name, bool boolButton) {
    var nPay = _settle.firstWhere((e) => e["key"] == key)['nPay'];
    // var nPay = _settleBox.get(key)['nPay'];
    var nPayComma = NumberFormat('###,###,###,###').format(nPay);
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          minimumSize: Size.fromHeight(40),
          maximumSize: Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: boolButton
              ? Color.fromARGB(255, 9, 199, 91)
              : Color.fromARGB(255, 176, 237, 167),
        ),
        onPressed: () async {
          // change true/false -> false/true
          boolButton = !boolButton;
          Map<String, dynamic> newItem = {name: boolButton};
          await _updateSettleBox(key, newItem);
          setState(() {
            _initializeSettle();
          });
        },
        child: Text(
          boolButton ? nPayComma : "X",
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }

  Widget deleteButton(int key) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          minimumSize: Size.fromHeight(40),
          maximumSize: Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: Color.fromARGB(255, 176, 237, 167),
        ),
        onPressed: () async {
          await _payBox.delete(key);
          setState(() {
            _initializeSettle();
          });
        },
        child: Icon(Icons.delete),
      ),
    );
  }

  Widget totalButton(dynamic totalByEach) {
    // showDialogWithFields();
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          minimumSize: Size.fromHeight(40),
          maximumSize: Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: const Color.fromARGB(255, 74, 137, 92),
        ),
        onPressed: () {},
        child: Text(
          totalByEach.runtimeType == int
              ? NumberFormat('###,###,###,###').format(totalByEach)
              : totalByEach.toString(),
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }

  Widget settleTable() {
    return Column(
      children: [
        // ?????????
        Row(
          children: [
            headbutton('??????'),
            headbutton('??????'),
            headbutton('??????'),
            headbutton('??????'),
            // headbutton('len'),
            // headbutton('nPay'),
            for (String name in _names) headbutton(name),
          ],
        ),
        // ????????????
        for (Map<String, dynamic> row in _settle)
          row['sort'] != "Total"
              ? Row(
                  children: [
                    deleteButton(row['key']),
                    rowButton(row['sort']),
                    rowButton(row['amount']),
                    payerButton(row['key'], row['payer'] as String),
                    // rowButton(row['len']),
                    // rowButton(row['nPay']),
                    for (String name in _names)
                      oxButton(row['key'], name, row[name]),
                  ],
                )
              : Row(
                  children: [
                    totalButton(""),
                    totalButton(row['sort']),
                    totalButton(row['amount'] ??= ''),
                    totalButton(row['payer'] ??= ''),
                    // totalButton(row['len'] ??= ''),
                    // totalButton(row['nPay'] ??= ''),
                    for (String name in _names) totalButton(row[name]),
                  ],
                )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: refreshButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: ListView(
        scrollDirection: Axis.vertical,
        shrinkWrap: true,
        children: [
          // refreshButton(),
          // const Divider(),
          const SizedBox(height: 10),
          nameFieldWidget(),
          const Divider(),
          inputPayment(),
          const Divider(),
          resultText(),
          const Divider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              titleTextWidget("Result"),
              explainTextWidget('??? ????????? ??????????????? ??????????????? ?????? ?????????.'),
            ],
          ),
          const SizedBox(height: 10),
          settleTable(),
        ],
      ),
    );
  }
}
