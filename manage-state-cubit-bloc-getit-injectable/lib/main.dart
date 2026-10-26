import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'di/injection.dart';
import 'sign_up/bloc/bloc_sign_up_page.dart';
import 'sign_up/cubit/cubit_sign_up_page.dart';
import 'sign_up/injectable/injectable_sign_up_page.dart';
import 'sign_up/sign_up_repository.dart';

void main() {
  // Register everything with get_it before the first widget needs it.
  // Only the Injectable tab uses get_it; the other two wire things by hand.
  configureDependencies();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key, this.repository = const SignUpRepository()});

  final SignUpRepository repository;

  @override
  Widget build(BuildContext context) {
    // RepositoryProvider hands the same repository to the Cubit and Bloc
    // pages. Tests can pass in a faster one.
    return RepositoryProvider.value(
      value: repository,
      child: MaterialApp(
        title: 'Cubit vs Bloc Form',
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  static const _titles = [
    'Sign up (Cubit)',
    'Sign up (Bloc)',
    'Sign up (Injectable)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_tab])),
      // IndexedStack keeps all pages alive, so each form keeps its own state
      // while you switch tabs.
      body: IndexedStack(
        index: _tab,
        children: const [
          CubitSignUpPage(),
          BlocSignUpPage(),
          InjectableSignUpPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bolt), label: 'Cubit'),
          NavigationDestination(icon: Icon(Icons.account_tree), label: 'Bloc'),
          NavigationDestination(icon: Icon(Icons.hub), label: 'Injectable'),
        ],
      ),
    );
  }
}
