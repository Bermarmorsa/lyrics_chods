// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'library/library_screen.dart';
import 'setlists/setlists_screen.dart';
import 'concerts/concerts_screen.dart';

/// Pantalla raíz de la app: envuelve las dos pestañas principales con
/// un [NavigationBar] en la parte inferior.
///
/// Usa [IndexedStack] para mantener el estado de cada pestaña en memoria
/// aunque no esté visible (el scroll de la biblioteca se conserva al
/// cambiar a setlists y volver).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Las pantallas se instancian una sola vez y permanecen en memoria
  static const _screens = <Widget>[
    LibraryScreen(),
    SetlistsScreen(),
    ConcertsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack muestra solo la pestaña activa pero mantiene el estado
      // de todas. Sin esto, cada cambio de pestaña reconstruiría la pantalla.
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        backgroundColor: const Color(0xFF1A1A1A),
        indicatorColor: const Color(0x33FFB300), // ámbar semitransparente
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Biblioteca',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_music_outlined),
            selectedIcon: Icon(Icons.queue_music),
            label: 'Setlists',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none_outlined),
            selectedIcon: Icon(Icons.mic),
            label: 'Conciertos',
          ),
        ],
      ),
    );
  }
}
