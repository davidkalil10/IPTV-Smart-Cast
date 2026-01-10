import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  bool _isXtreamMode = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ChannelProvider>();
    _urlController = TextEditingController(text: provider.savedUrl ?? '');
    _userController = TextEditingController(text: provider.savedUser ?? '');
    _passController = TextEditingController(text: provider.savedPass ?? '');
    _isXtreamMode = provider.isXtream;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações da Lista')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo de Conexão', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('M3U URL', style: TextStyle(fontSize: 16))),
                    selected: !_isXtreamMode,
                    onSelected: (val) => setState(() => _isXtreamMode = !val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Xtream Codes', style: TextStyle(fontSize: 16))),
                    selected: _isXtreamMode,
                    onSelected: (val) => setState(() => _isXtreamMode = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _urlController,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: _isXtreamMode ? 'URL do Servidor' : 'URL da Lista M3U',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                hintText: _isXtreamMode ? 'http://servidor.com:8080' : 'https://exemplo.com/lista.m3u',
              ),
            ),
            if (_isXtreamMode) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _userController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Usuário',
                  border: OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                style: const TextStyle(fontSize: 18),
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  final provider = context.read<ChannelProvider>();
                  if (_isXtreamMode) {
                    if (_urlController.text.isNotEmpty && _userController.text.isNotEmpty && _passController.text.isNotEmpty) {
                      provider.loadXtream(_urlController.text, _userController.text, _passController.text);
                      Navigator.pop(context);
                    }
                  } else {
                    if (_urlController.text.isNotEmpty) {
                      provider.loadM3u(_urlController.text);
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Salvar e Conectar', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: () {
                  context.read<ChannelProvider>().clearList();
                  _urlController.clear();
                  _userController.clear();
                  _passController.clear();
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Limpar Tudo', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
