import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_android_tv_text_field/native_textfield_tv.dart';
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
  late NativeTextFieldController _nameController;
  late NativeTextFieldController _urlController;
  late NativeTextFieldController _userController;
  late NativeTextFieldController _passController;
  bool _isPasswordVisible = false;

  // Focus Nodes
  late FocusNode _nameFocus;
  late FocusNode _userFocus;
  late FocusNode _passFocus;
  late FocusNode _urlFocus;
  late FocusNode _btnFocus;
  late FocusNode _listUsersFocus;

  @override
  void initState() {
    super.initState();
    _nameController = NativeTextFieldController(
      text: widget.userToEdit?.name ?? '',
    );
    _urlController = NativeTextFieldController(
      text: widget.userToEdit?.url ?? '',
    );
    _userController = NativeTextFieldController(
      text: widget.userToEdit?.username ?? '',
    );
    _passController = NativeTextFieldController(
      text: widget.userToEdit?.password ?? '',
    );

    // Initialize Focus Nodes
    _nameFocus = FocusNode(onKeyEvent: _handleKeyEvent)
      ..addListener(_onFocusChange);
    _userFocus = FocusNode(onKeyEvent: _handleKeyEvent)
      ..addListener(_onFocusChange);
    _passFocus = FocusNode(onKeyEvent: _handleKeyEvent)
      ..addListener(_onFocusChange);
    _urlFocus = FocusNode(onKeyEvent: _handleKeyEvent)
      ..addListener(_onFocusChange);
    _btnFocus = FocusNode()..addListener(_onFocusChange);
    _listUsersFocus = FocusNode()..addListener(_onFocusChange);

    // Initial Focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_nameFocus);
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Navigation
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        FocusScope.of(context).nextFocus();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        FocusScope.of(context).previousFocus();
        return KeyEventResult.handled;
      }

      // ENTER/Select -> Activate Editing manually
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select) {
        SystemChannels.textInput.invokeMethod('TextInput.show');
        return KeyEventResult.handled;
      }

      // BACK/Escape -> Exit Editing manually
      if (event.logicalKey == LogicalKeyboardKey.goBack ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        node.unfocus(); // Optional: or just hide keyboard
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _nameFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _urlFocus.dispose();
    _btnFocus.dispose();
    _listUsersFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We don't watch AuthProvider here for navigation to avoid rebuild loops during login
    // Navigation is handled manually in _handleLogin

    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Prevents focus loss when keyboard opens/closes
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxHeight < 500;

          bool useStandardTextField = kIsWeb;
          if (!kIsWeb) {
            // Use standard text field on iOS, or on Android if it's a small screen (phone/tablet likely)
            // or if the user explicitly prefers it for touch devices.
            // Using isSmallScreen as a proxy for 'Mobile/Tablet' layout.
            if (Platform.isIOS || (Platform.isAndroid && isSmallScreen)) {
              useStandardTextField = true;
            }
          }

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
                // Left Side - Logo/Branding
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
                                    return Transform.scale(
                                      scale: _listUsersFocus.hasFocus
                                          ? 1.05
                                          : 1.0,
                                      child: ElevatedButton.icon(
                                        focusNode: _listUsersFocus,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              _listUsersFocus.hasFocus
                                              ? Colors.purpleAccent
                                              : Colors.white,
                                          foregroundColor:
                                              _listUsersFocus.hasFocus
                                              ? Colors.white
                                              : Colors.black,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isSmallScreen ? 16 : 24,
                                            vertical: isSmallScreen ? 12 : 16,
                                          ),
                                          side: _listUsersFocus.hasFocus
                                              ? const BorderSide(
                                                  color: Colors.white,
                                                  width: 3,
                                                )
                                              : BorderSide.none,
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
                                      ),
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
                      child: Shortcuts(
                        shortcuts: <LogicalKeySet, Intent>{
                          LogicalKeySet(LogicalKeyboardKey.enter):
                              const ActivateIntent(),
                        },
                        child: FocusTraversalGroup(
                          child: SingleChildScrollView(
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
                                  focusNode: _nameFocus,
                                  nextFocus: _userFocus,
                                  hint: 'Nome qualquer',
                                  isDense: isSmallScreen,
                                  useStandardTextField: useStandardTextField,
                                ),
                                SizedBox(height: verticalSpacing),

                                _buildTextField(
                                  controller: _userController,
                                  focusNode: _userFocus,
                                  nextFocus: _passFocus,
                                  hint: 'Nome de usuário',
                                  isDense: isSmallScreen,
                                  useStandardTextField: useStandardTextField,
                                ),
                                SizedBox(height: verticalSpacing),

                                _buildTextField(
                                  controller: _passController,
                                  focusNode: _passFocus,
                                  nextFocus: _urlFocus,
                                  hint: 'Senha',
                                  isPassword: true,
                                  isPasswordVisible: _isPasswordVisible,
                                  onVisibilityChanged: () {
                                    setState(
                                      () => _isPasswordVisible =
                                          !_isPasswordVisible,
                                    );
                                  },
                                  isDense: isSmallScreen,
                                  useStandardTextField: useStandardTextField,
                                ),
                                SizedBox(height: verticalSpacing),

                                _buildTextField(
                                  controller: _urlController,
                                  focusNode: _urlFocus,
                                  nextFocus: _btnFocus,
                                  hint: 'http://url_aqui.com:porta',
                                  isDense: isSmallScreen,
                                  useStandardTextField: useStandardTextField,
                                ),

                                SizedBox(height: buttonSpacing),

                                SizedBox(
                                  height: isSmallScreen ? 40 : 50,
                                  child: Transform.scale(
                                    scale: _btnFocus.hasFocus ? 1.05 : 1.0,
                                    child: ElevatedButton(
                                      focusNode: _btnFocus,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _btnFocus.hasFocus
                                            ? Colors.purpleAccent
                                            : Colors.white,
                                        foregroundColor: _btnFocus.hasFocus
                                            ? Colors.white
                                            : Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          side: _btnFocus.hasFocus
                                              ? const BorderSide(
                                                  color: Colors.white,
                                                  width: 3,
                                                )
                                              : BorderSide.none,
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
                                ),
                              ],
                            ),
                          ),
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
    required NativeTextFieldController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required String hint,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onVisibilityChanged,
    bool isDense = false,
    bool useStandardTextField = false,
  }) {
    final isFocused = focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isFocused
                ? Colors.white.withOpacity(0.9)
                : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
            border: isFocused
                ? Border.all(color: Colors.purple, width: 2)
                : null,
            boxShadow: isFocused
                ? [const BoxShadow(color: Colors.purpleAccent, blurRadius: 8)]
                : [],
          ),
          child: Stack(
            children: [
              if (useStandardTextField)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  child: TextFormField(
                    controller: controller, // Assuming compatible
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: hint,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    obscureText: isPassword && !isPasswordVisible,
                    style: const TextStyle(color: Colors.black),
                    onFieldSubmitted: (_) {
                      if (nextFocus != null) {
                        FocusScope.of(context).requestFocus(nextFocus);
                      } else {
                        _handleLogin();
                      }
                    },
                  ),
                )
              else
                AndroidTVTextField(
                  key: ValueKey('${hint}_$isPasswordVisible'),
                  controller: controller,
                  hint: hint,
                  focusNode: focusNode,
                  textColor: Colors.black,
                  obscureText: isPassword && !isPasswordVisible,
                  backgroundColor: Colors
                      .transparent, // Use transparent to show AnimatedContainer background
                  focuesedBorderColor: Colors
                      .transparent, // Disable native border to use our custom one
                  onSubmitted: (_) {
                    if (nextFocus != null) {
                      FocusScope.of(context).requestFocus(nextFocus);
                    } else {
                      _handleLogin();
                    }
                  },
                ),
              if (isPassword)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: isFocused ? Colors.black54 : Colors.white70,
                      ),
                      onPressed: onVisibilityChanged,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (isPassword && !useStandardTextField)
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              'Clique para digitar. Acompanhe no campo nativo.',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
      ],
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
