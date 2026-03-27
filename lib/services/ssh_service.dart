// ULTIMA ACTUALIZACION: 12:51:00 - FIX ESCALERAS Y ESTABILIDAD
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:terminal/models/ssh_account.dart';
import 'package:xterm/xterm.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SSHService extends ChangeNotifier {
  final List<SSHAccount> _accounts = [];
  List<SSHAccount> get accounts => List.unmodifiable(_accounts);

  static const String _storageKey = 'ssh_accounts';

  SSHClient? _client;
  SSHSession? _shell;
  final Terminal terminal = Terminal(maxLines: 10000);

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _error;
  String? get error => _error;

  SSHService() {
    // Manejo de entrada de teclado
    terminal.onOutput = (input) {
      if (_shell != null) {
        // MEJORA: Asegurar que backspace (\x7f o \x08) se envíe correctamente en SSH
        if (input == '\x7f' || input == '\x08') {
          _shell!.stdin.add(utf8.encode('\x7f')); // La mayoría de servidores Linux esperan \x7f
        } else {
          _shell!.stdin.add(utf8.encode(input));
        }
      }
    };

    // Soporte para redimensionamiento (clave para SSH funcional)
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _shell?.resizeTerminal(width, height);
    };
  }

  Future<void> connect(SSHAccount account) async {
    _error = null;
    disconnect();
    notifyListeners();

    try {
      terminal.write('--- Conectando a ${account.host}... ---\r\n');
      final socket = await SSHSocket.connect(account.host, account.port,
          timeout: const Duration(seconds: 20));

      _client = SSHClient(
        socket,
        username: account.username,
        onPasswordRequest: () => account.password ?? '',
      );

      await _client!.authenticated.catchError((err) {
        terminal.write('\r\n[SSH] Error Auth: $err\r\n');
        throw err;
      });

      _shell = await _client!.shell(
        pty: const SSHPtyConfig(
          width: 80,
          height: 24,
          modes: {
            SSHTerminalMode.ECHO: 1,
            SSHTerminalMode.ICANON: 1,
            SSHTerminalMode.ISIG: 1,
            SSHTerminalMode.VERASE: 127, // Forzar 127 (DEL) como borrar
          },
        ),
      );

      _isConnected = true;
      _shell!.stdout.cast<List<int>>().transform(utf8.decoder).listen(terminal.write);
      _shell!.stderr.cast<List<int>>().transform(utf8.decoder).listen(terminal.write);

      notifyListeners();
      await _shell!.done;
      _isConnected = false;
      terminal.write('\r\n--- Sesión SSH finalizada ---\r\n');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      terminal.write('\r\nError SSH: $e\r\n');
      _isConnected = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _shell?.close();
    _client?.close();
    _shell = null;
    _client = null;
    _isConnected = false;
    // Limpiamos la terminal al desconectar para una nueva sesión limpia
    terminal.write('\r\n[INFO] Conexión cerrada.\r\n');
    notifyListeners();
  }

  void clearTerminal() {
    terminal.write('\x1b[2J\x1b[H'); // ANSI para limpiar y mover cursor al inicio
    
    // Forzamos el prompt en la shell
    if (_shell != null) {
      _shell!.stdin.add(utf8.encode('\x0c')); // Ctrl+L (Clear & Refresh en SSH)
    }
    
    notifyListeners();
  }

  Future<void> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accountsJson = prefs.getString(_storageKey);
    if (accountsJson != null) {
      final List<dynamic> decoded = jsonDecode(accountsJson);
      _accounts.clear();
      _accounts.addAll(decoded.map((item) => SSHAccount.fromJson(item)));
      notifyListeners();
    }
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  void addAccount(SSHAccount account) {
    _accounts.add(account);
    _saveAccounts();
    notifyListeners();
  }

  void removeAccount(String id) {
    _accounts.removeWhere((a) => a.id == id);
    _saveAccounts();
    notifyListeners();
  }

  void updateAccount(SSHAccount updatedAccount) {
    final index = _accounts.indexWhere((a) => a.id == updatedAccount.id);
    if (index != -1) {
      _accounts[index] = updatedAccount;
      _saveAccounts();
      notifyListeners();
    }
  }
}
