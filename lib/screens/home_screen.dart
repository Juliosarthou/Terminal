import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:terminal/models/ssh_account.dart';
import 'package:terminal/services/ssh_service.dart';
import 'package:terminal/screens/terminal_screen.dart';
import 'package:terminal/screens/ping_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuickTools(context),
                      const SizedBox(height: 30),
                      Text(
                        'Conexiones SSH',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildSSHList(context),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountDialog(context),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        title: Text(
          'Terminal Pro',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10)
            ],
          ),
        ),
        centerTitle: false,
      ),
    );
  }

  Widget _buildQuickTools(BuildContext context) {
    return Row(
      children: [
        _toolCard(
          context,
          'Ping',
          FontAwesomeIcons.networkWired,
          Colors.blueAccent,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PingScreen())),
        ),
        const SizedBox(width: 15),
        _toolCard(
          context,
          'Local',
          FontAwesomeIcons.terminal,
          Colors.purpleAccent,
          () {
            final sshService = Provider.of<SSHService>(context, listen: false);
            sshService.connectLocal();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TerminalScreen()));
          },
        ),
      ],
    );
  }

  Widget _toolCard(BuildContext context, String title, dynamic icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
          FaIcon(icon, color: color, size: 30),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSSHList(BuildContext context) {
    final sshService = Provider.of<SSHService>(context);
    final accounts = sshService.accounts;

    if (accounts.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 50),
            child: Text(
              'No hay conexiones guardadas',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final account = accounts[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF334155),
                  child: FaIcon(FontAwesomeIcons.terminal, size: 16, color: Colors.indigoAccent),
                ),
                title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${account.username}@${account.host}'),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () {
                  sshService.connect(account);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TerminalScreen()),
                  );
                },
              ),
            ),
          );
        },
        childCount: accounts.length,
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    final nameController = TextEditingController();
    final hostController = TextEditingController();
    final userController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Nueva Conexión SSH'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(nameController, 'Nombre (ej: Servidor Web)'),
              _buildTextField(hostController, 'Host (ej: 192.168.1.10)'),
              _buildTextField(userController, 'Usuario'),
              _buildTextField(passwordController, 'Contraseña', obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (hostController.text.isNotEmpty && userController.text.isNotEmpty) {
                final account = SSHAccount(
                  id: DateTime.now().toString(),
                  name: nameController.text.isEmpty ? hostController.text : nameController.text,
                  host: hostController.text,
                  username: userController.text,
                  password: passwordController.text,
                );
                Provider.of<SSHService>(context, listen: false).addAccount(account);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
