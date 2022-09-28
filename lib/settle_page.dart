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
  List<Map<int, dynamic>> _payments = [];
  List<Map<int, dynamic>> _settle = [];
  List<Map<String, dynamic>> listedSettle = [];
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

  late Future<List> resultInit;

  @override
  void initState() {
    super.initState();
    // refreshAll(); // 초기화 메소드
    _controller = TextfieldTagsController();
    _refreshNames();
    _refreshPayments();
    _refreshSettle();
    resultInit = _initializeSettle();
  }

  void _refreshNames() {
    _names = _nameBox.values.map((e) => e as String).toList();
  }

  void _refreshPayments() {
    _payments = _payBox.keys.map((key) {
      var value = _payBox.get(key);
      return {key as int: value};
    }).toList();
  }

  void _refreshSettle() {
    _settle = _settleBox.keys.map((key) {
      var value = _settleBox.get(key);
      return {key as int: value};
    }).toList();
  }

  Future<List> _initializeSettle() async {
    // 이름 없으면 settleBox 초기화
    if (_names.isEmpty) {
      refreshAll();
      return [];
    }

    // Total 라인 삭제 (있을 경우)
    var totalLine = _settle.where((row) => row.values.first["sort"] == "Total");
    _settle.removeWhere((e) => totalLine.contains(e));

    // payment 라인 변동시 초기화
    List<int> paymentKeys = _payments.map((row) => row.keys.first).toList();
    List<int> settleKeys = _settle.map((row) => row.keys.first).toList();

    if (!listEquals(paymentKeys, settleKeys)) {
      // paymentkeys 안에 settlekey가 없는 경우 삭제된 경우이므로 settle키를 삭제
      var removeKeys = settleKeys.where((key) => !paymentKeys.contains(key));
      _settle.removeWhere((row) {
        var key = row.keys.first;
        return removeKeys.contains(key);
      });

      // settlekey안에 paymentkey가 없는 경우는 추가된 경우이므로 settle키 생성
      var addedKeys = paymentKeys.where((key) => !settleKeys.contains(key));
      var addedValues =
          _payments.where((row) => addedKeys.contains(row.keys.first));
      for (var row in addedValues) {
        var newNames = <String, bool>{for (var name in _names) name: true};
        row.forEach((k, v) => v.addAll(newNames));
        _settle.add(row);
      }
    }

    // 이름 변동시

    for (var row in _settle) {
      var eachValueOfRow = row.values.first;
      var namesInSettle = eachValueOfRow.keys.toList() as List<dynamic>;
      var noneNameList = ['sort', 'amount', 'payer', 'len', 'nPay'];
      namesInSettle.removeWhere((e) => noneNameList.contains(e));
      // 각 줄마다 이름이 다를 경우
      if (!listEquals(_names, namesInSettle)) {
        // 이름 추가되었을 경우
        for (var name in _names) {
          if (!namesInSettle.contains(name)) {
            eachValueOfRow.addAll({name: true});
          }
        }
        // 이름 삭제된 경우
        for (var nameSettle in namesInSettle) {
          if (!_names.contains(nameSettle)) {
            eachValueOfRow.remove(nameSettle);
          }
        }
      }
    }

    for (var row in _settle) {
      var eachValueOfRow = row.values.first;
      // len 세어 넣기
      int len = eachValueOfRow.values.where((value) => value == true).length;
      eachValueOfRow.addAll({"len": len});
      // nPay 금액 넣기
      int amount = eachValueOfRow["amount"] as int;
      int nPay = 0;
      (len > 0) ? nPay = (amount / len).round() : nPay = 0;
      eachValueOfRow.addAll({"nPay": nPay});
    }

    // Total : 부담금 라인 넣기
    int totalAmount = _settle.map((e) => e.values.first["amount"] as int).sum;
    Map<String, int> totalByEach = {};
    for (var name in _names) {
      int eachAmount = _settle
          .where((x) => x.values.first[name] == true)
          .map((x) => x.values.first["nPay"] as int)
          .sum;
      totalByEach.addAll({name: eachAmount});
    }
    var row = {
      1000: {
        "sort": "Total",
        "amount": totalAmount,
        "payer": "부담금",
        ...totalByEach,
      }
    };
    _settle.add(row);

    // Total : 선납금 라인 넣기
    Map<String, int> totalAdvancedByEach = {};
    for (var name in _names) {
      int eachAdvAmount = 0;
      for (var row in _settle) {
        var value = row.values.first;
        if (value["payer"] == name) {
          eachAdvAmount += value["amount"] as int;
        }
      }
      totalAdvancedByEach.addAll({name: eachAdvAmount});
    }
    var rowAdvanced = {
      1001: {
        "sort": "Total",
        "amount": null,
        "payer": "선납금",
        ...totalAdvancedByEach,
      }
    };
    _settle.add(rowAdvanced);

    // Total : 정산금 라인 넣기
    Map<String, int> totalSettleByEach = {};
    for (var name in _names) {
      int eachSettleAmount = 0;
      for (var row in _settle) {
        var value = row.values.first;
        if (value["payer"] == "부담금") {
          eachSettleAmount += value[name] as int;
        }
        if (value["payer"] == "선납금") {
          eachSettleAmount -= value[name] as int;
        }
      }
      totalSettleByEach.addAll({name: eachSettleAmount});
    }
    var rowSettled = {
      1002: {
        "sort": "Total",
        "amount": null,
        "payer": "정산금",
        ...totalSettleByEach,
      }
    };
    _settle.add(rowSettled);

    // DB에 데이터 넣기
    for (var row in _settle) {
      row.forEach((key, value) => _settleBox.put(key, value));
    }

    // 결과 텍스트 만들기
    List<String> resultSettle = [];

    String totalPayment = NumberFormat('###,###,###,###').format(totalAmount);
    resultSettle.add("전체 경비 : $totalPayment");

    String minName = _names.first;
    Map<String, dynamic> _settleRow =
        _settle.firstWhere((e) => e.keys.first == 1002).values.first;

    // {이름: 정산금, 이름2: 정산금2, ...} 형태
    Map<String, int> settleRow = Map.fromIterable(
        _settleRow.keys.where((e) => _names.contains(e)).toList()
          ..sort((x, y) => _settleRow[y].compareTo(_settleRow[x])),
        value: (e) => _settleRow[e]);

    resultSettle.add("최초 입력된 $minName님 기준으로 정산합니다.");

    settleRow.forEach((k, v) {
      if (k != minName) {
        if (v < 0) {
          int minusSettle = v * -1;
          String strMinusSettle =
              NumberFormat('###,###,###,###').format(minusSettle);
          resultSettle.add(" - $minName → $k에게 $strMinusSettle를 송금하세요. ");
        } else if (v == 0) {
        } else {
          String strV = NumberFormat('###,###,###,###').format(v);
          resultSettle.add(" - $k → $minName에게 $strV를 송금하세요. ");
        }
      }
    });

    // 표를 그리기 위하여 데이터를 리스트화 하기
    var _listedSettle = _settle.map((row) {
      var key = row.keys.first;
      var value = row.values.first;
      Map<String, dynamic> temp = {"key": key};
      temp.addAll(Map.from(value));
      return temp;
    }).toList();

    setState(() {
      payerName = _names.first;
      _settle;
      listedSettle = _listedSettle;
      _resultSettle = resultSettle;
    });

    return resultSettle;
  }

  Future<void> _updateSettleBox(int itemKey, Map<String, dynamic> item) async {
    var row = _settle.firstWhere((e) => e.keys.first == itemKey);
    var value = row.values.first;
    value.addAll(item);

    _settleBox.put(itemKey, value);
    setState(() {});
  }

  Future<void> _updatePayBox(int itemKey, Map<String, dynamic> item) async {
    var row = _payments.firstWhere((e) => e.keys.first == itemKey);
    var value = row.values.first;
    value.addAll(item);

    _payBox.put(itemKey, value);
    _initializeSettle();
  }

  void refreshAll() {
    _nameBox.clear();
    _names = [];
    _payBox.clear();
    _payments = [];
    _settleBox.clear();
    _settle = [];
    _resultSettle = [];
    listedSettle = [];
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
            explainTextWidget('총무부터, 공백/마침표/쉼표로 구분. 중복 이름 불가.'),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 10),
            Expanded(
              child: TextFieldTags(
                textfieldTagsController: _controller,
                initialTags:
                    _names.isNotEmpty ? _names : const ['갑', '을', '병', '정'],
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
                          // helperText: '쉼표 공백으로 구분됩니다. 중복된 이름은 미반영됩니다.',
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
                // var data = _nameBox.values.map((e) => e as String).toList();
                // var data = _nameBox.values.map((e) => e as String).toList();
                _sortController.text = "밥";
                _amountController.text = "50";
                setState(() {
                  _names = tags ??= [];
                  _refreshPayments();
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
              "천원단위 입력을 추천드립니다.",
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
                        // decoration: const InputDecoration(hintText: '구분'),
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
                        // decoration: const InputDecoration(hintText: '금액'),
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
                _refreshPayments();
                _initializeSettle();
                _sortController.text = '밥';
                _amountController.text = '50';
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
            explainTextWidget('반올림으로 마지막 단위 차이가 있을 수 있습니다'),
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
    var nPay = listedSettle.firstWhere((e) => e["key"] == key)['nPay'] as int;
    // var nPay = _settleBox.get(key)['nPay'];
    var nPayComma = NumberFormat('###,###,###,###').format(nPay);
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          minimumSize: const Size.fromHeight(40),
          maximumSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: boolButton
              ? const Color.fromARGB(255, 9, 199, 91)
              : const Color.fromARGB(255, 176, 237, 167),
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
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          minimumSize: const Size.fromHeight(40),
          maximumSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: const Color.fromARGB(255, 176, 237, 167),
        ),
        onPressed: () async {
          await _payBox.delete(key);
          setState(() {
            _refreshPayments();
            _initializeSettle();
          });
        },
        child: const Icon(Icons.delete),
      ),
    );
  }

  Widget totalButton(dynamic totalByEach) {
    // showDialogWithFields();
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
        // 제목행
        Row(
          children: [
            headbutton('삭제'),
            headbutton('구분'),
            headbutton('금액'),
            headbutton('결제'),
            for (String name in _names) headbutton(name),
          ],
        ),
        // 데이터행
        if (listedSettle.isNotEmpty)
          for (Map<String, dynamic> row in listedSettle)
            row['sort'] != "Total"
                ? Row(
                    children: [
                      deleteButton(row['key']),
                      rowButton(row['sort']),
                      rowButton(row['amount']),
                      payerButton(row['key'], row['payer'] as String),
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
      body: FutureBuilder(
        future: resultInit,
        builder: (BuildContext ctx, AsyncSnapshot<List> snapshot) =>
            snapshot.hasData
                ? ListView(
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    children: [
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
                          explainTextWidget('각 금액을 클릭하시면 정산금액이 수정 됩니다.'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      settleTable(),
                    ],
                  )
                : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
