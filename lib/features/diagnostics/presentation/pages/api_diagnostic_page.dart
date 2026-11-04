
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';

class ApiDiagnosticPage extends StatefulWidget {
  const ApiDiagnosticPage({super.key});

  @override
  State<ApiDiagnosticPage> createState() => _ApiDiagnosticPageState();
}

class _ApiDiagnosticPageState extends State<ApiDiagnosticPage> {
  final ApiClient _apiClient = ApiClient();

  bool _isLoading = false;
  String _result = 'Aguardando teste de conexão...';

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _result = 'Conectando ao servidor...';
    });

    try {
      final response = await _apiClient.dio.get('/');

      if (!mounted) return;

      setState(() {
        _result = 'Conexão estabelecida!\n\n'
            'Status HTTP: ${response.statusCode}\n'
            'Resposta: ${response.data}';
      });
    } on DioException catch (error) {
      if (!mounted) return;

      setState(() {
        _result = 'Falha na conexão.\n\n'
            'Erro: ${error.message}';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _result = 'Erro inesperado: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _apiClient.dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico da API'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Teste de comunicação com o servidor FinPlan.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Testar conexão'),
            ),
            const SizedBox(height: 24),
            SelectableText(_result),
          ],
        ),
      ),
    );
  }
}
