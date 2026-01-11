import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'user_selection_screen.dart';
import '../models/user_profile.dart';

class LoginScreen extends StatefulWidget {
  final UserProfile? userToEdit;

  const LoginScreen({super.key, this.userToEdit});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.userToEdit?.name ?? '',
    );
    _urlController = TextEditingController(text: widget.userToEdit?.url ?? '');
    _userController = TextEditingController(
      text: widget.userToEdit?.username ?? '',
    );
    _passController = TextEditingController(
      text: widget.userToEdit?.password ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We don't watch AuthProvider here for navigation to avoid rebuild loops during login
    // Navigation is handled manually in _handleLogin

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxHeight < 500;

          // Compact visual settings
          final double verticalSpacing = isSmallScreen ? 10 : 16;
          final double headerSpacing = isSmallScreen ? 10 : 30;
          final double buttonSpacing = isSmallScreen ? 20 : 40;
          final double titleSize = isSmallScreen ? 20 : 24;
          final EdgeInsets formPadding = isSmallScreen
              ? const EdgeInsets.symmetric(horizontal: 20)
              : const EdgeInsets.symmetric(horizontal: 60);

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4A148C), Color(0xFFFF4081)],
                stops: [0.3, 0.9],
              ),
            ),
            child: Row(
              children: [
                // Left Side - Logo/Branding (Hide on very small screens if needed, or adjust flex)
                // Keeping it visible but maybe smaller flex if needed.
                if (!isSmallScreen || constraints.maxWidth > 600)
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tv,
                                size: isSmallScreen ? 60 : 80,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'IPTV',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 30 : 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                'SMART CAST',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 18 : 24,
                                  color: Colors.white70,
                                  letterSpacing: 4,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 20 : 40),
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  if (auth.users.isNotEmpty) {
                                    return ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSmallScreen ? 16 : 24,
                                          vertical: isSmallScreen ? 12 : 16,
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
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.transparent, Colors.black12],
                      ),
                    ),
                    padding: formPadding,
                    child: Center(
                      child: SingleChildScrollView(
                        // Keeps scrolling if really needed
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              widget.userToEdit != null
                                  ? 'Editar Usuário'
                                  : 'Insira seus detalhes de login',
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: headerSpacing),

                            _buildTextField(
                              controller: _nameController,
                              hint: 'Nome qualquer',
                              isDense: isSmallScreen,
                            ),
                            SizedBox(height: verticalSpacing),

                            _buildTextField(
                              controller: _userController,
                              hint: 'Nome de usuário',
                              isDense: isSmallScreen,
                            ),
                            SizedBox(height: verticalSpacing),

                            _buildTextField(
                              controller: _passController,
                              hint: 'Senha',
                              isPassword: true,
                              isPasswordVisible: _isPasswordVisible,
                              onVisibilityChanged: () {
                                setState(
                                  () =>
                                      _isPasswordVisible = !_isPasswordVisible,
                                );
                              },
                              isDense: isSmallScreen,
                            ),
                            SizedBox(height: verticalSpacing),

                            _buildTextField(
                              controller: _urlController,
                              hint: 'http://url_aqui.com:porta',
                              isDense: isSmallScreen,
                            ),

                            SizedBox(height: buttonSpacing),

                            SizedBox(
                              height: isSmallScreen ? 40 : 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                onPressed: _handleLogin,
                                child: Text(
                                  widget.userToEdit != null ||
                                          (widget.userToEdit?.id != null)
                                      ? 'SALVAR'
                                      : 'ENTRAR',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
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
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onVisibilityChanged,
    bool isDense = false,
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
          isDense: isDense,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isDense ? 8 : 14,
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
      userIdToUpdate: widget.userToEdit?.id,
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
