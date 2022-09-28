// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:nppang_app/name_modal.dart';
// import 'package:nppang_app/settle_page.dart';
// import 'package:nppang_app/name_page.dart';
// import 'package:nppang_app/payment_page.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   await Hive.initFlutter();
//   // await Hive.openBox('nBox');
//   await Hive.openBox('nameBox');
//   await Hive.openBox('payBox');
//   await Hive.openBox('settleBox');

//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'N-PPANG',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: const MyHomePage(title: 'N-PPang'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({Key? key, required this.title}) : super(key: key);
//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int currentPage = 0;
//   List<Widget> pages = const [
//     // NamePage(),
//     // NameModal(),
//     SettlePage(),
//     PaymentPage(),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.title),
//       ),
//       body: pages[currentPage],
//       bottomNavigationBar: NavigationBar(
//         destinations: const [
//           // NavigationDestination(
//           //   icon: Icon(Icons.account_box_outlined),
//           //   label: "Name",
//           // ),
//           // NavigationDestination(
//           //   icon: Icon(Icons.account_box_outlined),
//           //   label: "NameMo",
//           // ),
//           NavigationDestination(
//             icon: Icon(Icons.home),
//             label: "Settle",
//           ),
//           NavigationDestination(
//             icon: Icon(Icons.payment),
//             label: "Pay",
//           ),
//         ],
//         onDestinationSelected: (int index) {
//           setState(() {
//             currentPage = index;
//           });
//         },
//         selectedIndex: currentPage,
//       ),
//     );
//   }
// }
