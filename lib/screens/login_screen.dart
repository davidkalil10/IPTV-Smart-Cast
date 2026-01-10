import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Novo Usuário'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome do Perfil (ex: IPTV 1)')),
              TextField(controller: _urlController, decoration: const InputDecoration(labelText: 'URL do Servidor')),
              TextField(controller: _userController, decoration: const InputDecoration(labelText: 'Usuário')),
              TextField(controller: _passController, decoration: const InputDecoration(labelText: 'Senha'), obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<AuthProvider>().login(
                _nameController.text, _urlController.text, _userController.text, _passController.text
              );
              if (success) {
                Navigator.pop(context);
                _nameController.clear(); _urlController.clear(); _userController.clear(); _passController.clear();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha no login. Verifique os dados.')));
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFF121212)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text('IPTV Smart Cast', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const Text('Escolha seu perfil', style: TextStyle(fontSize: 18, color: Colors.white70)),
              const SizedBox(height: 40),
              Expanded(
                child: auth.users.isEmpty 
                  ? const Center(child: Text('Nenhum usuário adicionado', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: auth.users.length,
                      itemBuilder: (context, index) {
                        final user = auth.users[index];
                        return Card(
                          color: Colors.white.withOpacity(0.1),
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(user.url, style: const TextStyle(color: Colors.white70)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => auth.removeUser(user.id),
                            ),
                            onTap: () {
                              auth.selectUser(user);
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
                            },
                          ),
                        );
                      },
                    ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _showAddUserDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('ADICIONAR NOVO USUÁRIO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
