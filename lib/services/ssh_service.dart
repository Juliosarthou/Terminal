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
  Process? _localProcess;
  final Terminal terminal = Terminal(maxLines: 10000);
  int _localTypedCount = 0; // Rastrear caracteres escritos en shell local
  final List<String> _localHistory = []; // Historial manual para shell local
  int _localHistoryPointer = -1; // Puntero al historial
  String _localCurrentBuffer = ""; // Lo que el usuario está escribiendo actualmente

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _error;
  String? get error => _error;

  SSHService() {
    // Manejo de entrada de teclado
    terminal.onOutput = (input) {
      if (_shell != null) {
        _shell!.stdin.add(utf8.encode(input));
      } else if (_localProcess != null) {
        if (input == '\r') {
          terminal.write('\r\n');
          _localProcess!.stdin.add(utf8.encode('\n'));
          if (_localCurrentBuffer.trim().isNotEmpty) {
            _localHistory.add(_localCurrentBuffer);
          }
          _localHistoryPointer = _localHistory.length;
          _localCurrentBuffer = "";
          _localTypedCount = 0;
        } else if (input == '\x7f' || input == '\x08') {
          if (_localTypedCount > 0) {
            terminal.write('\b \b');
            _localProcess!.stdin.add(utf8.encode('\x08'));
            _localTypedCount--;
            if (_localCurrentBuffer.isNotEmpty) {
              _localCurrentBuffer = _localCurrentBuffer.substring(0, _localCurrentBuffer.length - 1);
            }
          }
        } else if (input == '\x1b[A' || input == '\x1b[B') {
          // GESTIÓN MANUAL DE HISTORIAL (UP / DOWN)
          if (_localHistory.isEmpty) return;

          if (input == '\x1b[A' && _localHistoryPointer > 0) {
            _localHistoryPointer--;
          } else if (input == '\x1b[B' && _localHistoryPointer < _localHistory.length - 1) {
            _localHistoryPointer++;
          } else {
            return;
          }

          // 1. Borrar lo que haya actualmente en pantalla y en el buffer de la shell
          String backspaces = '\b' * _localTypedCount;
          _localProcess!.stdin.add(utf8.encode(backspaces)); // Borra buffer shell
          terminal.write('\b \b' * _localTypedCount); // Borra visualmente

          // 2. Cargar comando del historial
          String newCmd = _localHistory[_localHistoryPointer];
          terminal.write(newCmd);
          _localProcess!.stdin.add(utf8.encode(newCmd));
          
          // 3. Actualizar estado
          _localCurrentBuffer = newCmd;
          _localTypedCount = newCmd.length;
        } else {
          // No hacemos eco visual de secuencias de escape
          if (!input.startsWith('\x1B')) {
            terminal.write(input);
            _localTypedCount += input.length;
            _localCurrentBuffer += input;
          }
          _localProcess!.stdin.add(utf8.encode(input));
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
        pty: const SSHPtyConfig(width: 80, height: 24),
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

  Future<void> connectLocal() async {
    _error = null;
    disconnect();
    clearTerminal(); // Iniciamos con pantalla limpia
    _isConnected = true;
    notifyListeners();

    terminal.write('--- SHELL LOCAL ANDROID ---\r\n');
    terminal.write('[INFO] Usando alineación automática (\r\n).\r\n\r\n');
    
    try {
      final shellPath = Platform.isAndroid ? '/system/bin/sh' : (Platform.isWindows ? 'cmd.exe' : '/bin/sh');
      
      // MEJORAMOS EL PATH PARA QUE ls, cd, etc FUNCIONEN DIRECTAMENTE
      final Map<String, String> environment = {
        'TERM': 'xterm-256color',
        'PATH': '/system/bin:/system/xbin:/vendor/bin:/sbin:/bin:/usr/bin:/usr/sbin:/apex/com.android.runtime/bin:/apex/com.android.art/bin:/data/local/tmp',
        'HOME': Platform.isAndroid ? '/sdcard' : '.',
        'USER': 'android',
        'PS1': '\$ ' // Prompt limpio y profesional
      };

      try {
        _localProcess = await Process.start(
          shellPath,
          Platform.isAndroid ? ['-i'] : [],
          environment: environment,
          includeParentEnvironment: true,
          workingDirectory: Platform.isAndroid ? '/sdcard' : null,
        );
      } catch (e) {
        // Fallback si /sdcard falla (p. ej. permisos o desktop)
        _localProcess = await Process.start(
          shellPath,
          Platform.isAndroid ? ['-i'] : [],
          environment: environment,
          includeParentEnvironment: true,
        );
      }

      _localProcess!.stdout.transform(utf8.decoder).listen((data) {
        // Si hay una nueva línea en la salida, reiniciamos el contador de escritura
        if (data.contains('\n') || data.contains('\r')) {
          _localTypedCount = 0;
          _localCurrentBuffer = "";
          _localHistoryPointer = _localHistory.length;
        }
        // IMPORTANTE: Convertimos LF a CRLF para evitar el efecto 'escalera' en shell local
        terminal.write(data.replaceAll(RegExp(r'\r?\n'), '\r\n'));
      });
      
      _localProcess!.stderr.transform(utf8.decoder).listen((data) {
        if (data.contains('\n') || data.contains('\r')) {
          _localTypedCount = 0;
          _localCurrentBuffer = "";
          _localHistoryPointer = _localHistory.length;
        }
        terminal.write(data.replaceAll(RegExp(r'\r?\n'), '\r\n'));
      });

      notifyListeners();
      await _localProcess!.exitCode;
      _isConnected = false;
      terminal.write('\r\n--- Shell finalizado ---\r\n');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      terminal.write('\r\nError Shell Local: $e\r\n');
      _isConnected = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _shell?.close();
    _client?.close();
    _localProcess?.kill();
    _shell = null;
    _client = null;
    _localProcess = null;
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
    } else if (_localProcess != null) {
      _localProcess!.stdin.add(utf8.encode('\n')); // Enter (Forzar nuevo prompt en Local)
      _localTypedCount = 0;
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
}
