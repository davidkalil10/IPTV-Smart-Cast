import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'user_selection_screen.dart';

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
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    // We don't watch AuthProvider here for navigation to avoid rebuild loops during login
    // Navigation is handled manually in _handleLogin

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4A148C),
              Color(0xFFFF4081),
            ], // Purple to Pink/Orangeish
            stops: [0.3, 0.9],
          ),
        ),
        child: Row(
          children: [
            // Left Side - Logo/Branding
            Expanded(
              flex: 4,
              child: Container(
                color: Colors.transparent, // Or a slight overlay
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.tv, size: 80, color: Colors.white),
                        const SizedBox(height: 20),
                        const Text(
                          'IPTV',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const Text(
                          'SMART CAST',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white70,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // If users exist, show button to List Users
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            if (auth.users.isNotEmpty) {
                              return ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const UserSelectionScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.people),
                                label: const Text('LISTAR USUÁRIOS'),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Right Side - Login Form
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  // Optional: Frosted glass or semi-transparent background for form area
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.black12],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Insira seus detalhes de login',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),

                        _buildTextField(
                          controller: _nameController,
                          hint: 'Nome qualquer',
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _userController,
                          hint: 'Nome de usuário',
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _passController,
                          hint: 'Senha',
                          isPassword: true,
                          isPasswordVisible: _isPasswordVisible,
                          onVisibilityChanged: () {
                            setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _urlController,
                          hint: 'http://url_aqui.com:porta',
                        ),

                        const SizedBox(height: 40),

                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            onPressed: _handleLogin,
                            child: const Text(
                              'ENTRAR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onVisibilityChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isPasswordVisible,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white70,
                  ),
                  onPressed: onVisibilityChanged,
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_nameController.text.isEmpty ||
        _urlController.text.isEmpty ||
        _userController.text.isEmpty ||
        _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos.')),
      );
      return;
    }

    final success = await context.read<AuthProvider>().login(
      _nameController.text,
      _urlController.text,
      _userController.text,
      _passController.text,
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha no login. Verifique os dados.')),
      );
    }
  }
}
