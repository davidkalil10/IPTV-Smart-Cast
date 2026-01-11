import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../models/user_profile.dart';

class UserSelectionScreen extends StatelessWidget {
  const UserSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F0F), Color(0xFF1A1A2E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'IPTV SMART CAST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24, // Reduced from 32
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6), // Reduced from 10
                  const Text(
                    'LISTAR USUÁRIOS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16, // Reduced from 18
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20), // Reduced from 40
                  Expanded(
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent:
                                400, // 1 col on phone, 2 on tablet
                            mainAxisExtent:
                                110, // Fixed height for consistent look
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: auth.users.length,
                      itemBuilder: (context, index) {
                        final user = auth.users[index];
                        return _buildUserCard(context, user, auth);
                      },
                    ),
                  ),
                  const SizedBox(height: 10), // Reduced from 20
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 10, // Reduced from 20
                    ),
                    child: SizedBox(
                      width: 250,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'ADICIONAR NOVO USUÁRIO',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    UserProfile user,
    AuthProvider auth,
  ) {
    return Container(
      decoration: BoxDecoration(
        // Dark metallic/glass effect
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            auth.selectUser(user);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Avatar Area
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF00BFA5), Color(0xFF008C79)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BFA5).withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),

                // Text Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.username,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.link,
                            size: 14,
                            color: Colors.white.withOpacity(0.4),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatUrl(user.url),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Delete Button
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () {
                    // Confirm delete
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E1E), // Dark Dialog
                        title: const Text(
                          'Remover Usuário',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: Text(
                          'Tem certeza que deseja remover ${user.name}?',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              await auth.removeUser(user.id);
                              // If no users left, go to login automatically
                              if (auth.users.isEmpty && context.mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              'Remover',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatUrl(String url) {
    if (url.startsWith('http://')) return url.substring(7);
    if (url.startsWith('https://')) return url.substring(8);
    return url;
  }
}
