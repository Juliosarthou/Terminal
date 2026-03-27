import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:dart_ping_ios/dart_ping_ios.dart';

class PingScreen extends StatefulWidget {
  const PingScreen({super.key});

  @override
  State<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends State<PingScreen> {
  final TextEditingController _hostController = TextEditingController(text: '8.8.8.8');
  final List<PingData> _results = [];
  bool _isPingRunning = false;
  Ping? _ping;

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      DartPingIOS.register();
    }
  }

  void _startPing() {
    setState(() {
      _results.clear();
      _isPingRunning = true;
    });

    try {
      _ping = Ping(_hostController.text, count: 50);

      _ping!.stream.listen((event) {
        if (!mounted) return;
        setState(() {
          _results.add(event);
        });
      }).onDone(() {
        if (!mounted) return;
        setState(() {
          _isPingRunning = false;
        });
      });
    } catch (e) {
      setState(() {
        _isPingRunning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _stopPing() {
    _ping?.stop();
    setState(() {
      _isPingRunning = false;
    });
  }

  @override
  void dispose() {
    _ping?.stop();
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Tools - Ping'),
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
                    ),
                  ),
                  const SizedBox(width: 15),
                  IconButton(
                    icon: Icon(
                      _isPingRunning ? Icons.stop : Icons.play_arrow,
                      color: _isPingRunning ? Colors.redAccent : Colors.greenAccent,
                    ),
                    onPressed: _isPingRunning ? _stopPing : _startPing,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final data = _results[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Seq: ${index + 1}', style: const TextStyle(color: Colors.white70)),
                        if (data.response != null) ...[
                          Text('${data.response!.ip}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${data.response!.time?.inMilliseconds} ms',
                              style: const TextStyle(color: Colors.greenAccent)),
                        ] else if (data.error != null) ...[
                          Text('Error: ${data.error}', style: const TextStyle(color: Colors.redAccent)),
                        ] else ...[
                          const Text('Request timed out', style: TextStyle(color: Colors.orangeAccent)),
                        ],
                      ],
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
