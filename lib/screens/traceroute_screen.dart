import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:dart_ping_ios/dart_ping_ios.dart';

class TracerouteScreen extends StatefulWidget {
  const TracerouteScreen({super.key});

  @override
  State<TracerouteScreen> createState() => _TracerouteScreenState();
}

class _TracerouteScreenState extends State<TracerouteScreen> {
  final TextEditingController _hostController = TextEditingController(text: '8.8.8.8');
  final List<String> _results = [];
  bool _isRunning = false;
  bool _isStopping = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      DartPingIOS.register();
    }
  }

  void _startTraceroute() async {
    setState(() {
      _results.clear();
      _isRunning = true;
      _isStopping = false;
    });

    final String hostInput = _hostController.text.trim();
    if (hostInput.isEmpty) {
      setState(() => _isRunning = false);
      return;
    }

    try {
      // 1. Resolver el dominio a IP para comparar correctamente
      final addresses = await InternetAddress.lookup(hostInput);
      if (addresses.isEmpty) throw 'No se pudo resolver el host';
      final String hostIp = addresses.first.address;

      setState(() {
        _results.add('Rastreando ruta a $hostInput [$hostIp]...');
      });

      // 2. Bucle de traza por TTL
      for (int ttl = 1; ttl <= 30; ttl++) {
        if (_isStopping || !mounted) break;

        setState(() {
          _results.add('Salto $ttl: Escaneando...');
        });

        final ping = Ping(hostIp, count: 1, ttl: ttl, timeout: 2);
        final completer = Completer<PingData>();
        
        // ignore: cancel_subscriptions
        final sub = ping.stream.listen((event) {
          if (event.response != null || event.error != null || event.summary != null) {
            if (!completer.isCompleted) completer.complete(event);
          }
        });

        final result = await completer.future.timeout(const Duration(seconds: 4), onTimeout: () => const PingData());
        sub.cancel();

        if (!mounted) break;

        setState(() {
          _results.removeLast(); // Quitar el "escaneando"
          if (result.response != null) {
            final String responderIp = result.response!.ip ?? 'Desconocido';
            _results.add('Salto $ttl: $responderIp (${result.response!.time?.inMilliseconds} ms)');
            
            // Si la IP que respondió es IGUAL a la del host objetivo, hemos llegado.
            if (responderIp == hostIp) {
              _isStopping = true;
            }
          } else if (result.error != null) {
            _results.add('Salto $ttl: ${result.error}');
          } else {
            _results.add('Salto $ttl: * * * (Tiempo excedido)');
          }
        });

        if (_isStopping) break;
      }
    } catch (e) {
      if (mounted) setState(() => _results.add('Error: $e'));
    }

    if (mounted) {
      setState(() {
        _isRunning = false;
        _isStopping = false;
        _results.add('Traza finalizada.');
      });
    }
  }

  void _stopTraceroute() {
    setState(() {
      _isStopping = true;
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Tools - Traceroute'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Host (IP o Dominio)',
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _isRunning ? null : _startTraceroute(),
                    ),
                  ),
                  const SizedBox(width: 15),
                  IconButton(
                    icon: Icon(
                      _isRunning ? Icons.stop : Icons.play_arrow,
                      color: _isRunning ? Colors.redAccent : Colors.greenAccent,
                    ),
                    onPressed: _isRunning ? _stopTraceroute : _startTraceroute,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _results[index],
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
