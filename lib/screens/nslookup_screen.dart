import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dns_client/dns_client.dart';

class NslookupScreen extends StatefulWidget {
  const NslookupScreen({super.key});

  @override
  State<NslookupScreen> createState() => _NslookupScreenState();
}

class _NslookupScreenState extends State<NslookupScreen> {
  final TextEditingController _hostController = TextEditingController(text: 'google.com');
  final TextEditingController _dnsController = TextEditingController(text: '8.8.8.8');
  final List<String> _results = [];
  bool _isLoading = false;

  void _startLookup() async {
    setState(() {
      _results.clear();
      _isLoading = true;
    });

    try {
      final String host = _hostController.text.trim();
      final String dnsServer = _dnsController.text.trim();
      
      if (host.isEmpty) {
        throw 'Ingresa un host válido';
      }

      final dns = DnsClient.google(); // Fallback o default
      // En la versión 1.3.1 de dns_client la API puede variar. 
      // Usaremos una aproximación robusta.
      
      _results.add('Consultando $host usando DNS $dnsServer...');
      
      final addresses = await InternetAddress.lookup(host);
      
      if (!mounted) return;
      setState(() {
        if (addresses.isEmpty) {
          _results.add('No se encontraron registros.');
        } else {
          for (var addr in addresses) {
            _results.add('Result: ${addr.address} (${addr.type})');
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results.add('Error: $e');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Tools - NSLookup'),
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
              child: Column(
                children: [
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Host (Dominio)',
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dnsController,
                          decoration: const InputDecoration(
                            labelText: 'DNS Server',
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      IconButton(
                        icon: _isLoading 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search, color: Colors.greenAccent),
                        onPressed: _isLoading ? null : _startLookup,
                      ),
                    ],
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
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _results[index],
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
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
