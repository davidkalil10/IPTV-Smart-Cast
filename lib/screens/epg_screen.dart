import 'package:flutter/material.dart';

class EpgScreen extends StatelessWidget {
  const EpgScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guia de Programação (EPG)')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Nenhum dado de EPG disponível no momento.', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Sincronize sua lista para carregar o guia.', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
