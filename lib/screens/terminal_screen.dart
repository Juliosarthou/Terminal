import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terminal/services/ssh_service.dart';
import 'package:xterm/xterm.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _terminal;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _terminal = Provider.of<SSHService>(context, listen: false).terminal;
    
    // Auto-enfocar el teclado al entrar después de renderizar el frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sshService = Provider.of<SSHService>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Terminal'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          // Botón para forzar el foco si falla
          IconButton(
            icon: const Icon(Icons.keyboard),
            onPressed: () {
              FocusScope.of(context).requestFocus(_focusNode);
            },
            tooltip: 'Pedir Teclado',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              sshService.disconnect();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de teclas especiales - AHORA DISTRIBUIDA
          Container(
            color: const Color(0xFF1E293B),
            height: 40,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _keyBtn('ESC', '\x1B'),
                _keyBtn('TAB', '\x09'),
                _actionBtn('CLEAR', () => sshService.clearTerminal()),
                _keyBtn('CTRL+C', '\x03'),
                _keyBtn('CTRL-D', '\x04'),
                _keyBtn('UP', '\x1B[A'),
                _keyBtn('DOWN', '\x1B[B'),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).requestFocus(_focusNode);
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                color: Colors.black,
                child: TerminalView(
                  _terminal,
                  focusNode: _focusNode,
                  autofocus: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyBtn(String label, String value) {
    return _actionBtn(label, () => _terminal.onOutput?.call(value));
  }

  Widget _actionBtn(String label, VoidCallback onPressed) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
