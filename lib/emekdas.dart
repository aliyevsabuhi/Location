import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'main.dart' show globalIp, globalPort;

class EmekdasAddPage extends StatefulWidget {
  const EmekdasAddPage({Key? key}) : super(key: key);

  @override
  State<EmekdasAddPage> createState() => _EmekdasAddPageState();
}

class _EmekdasAddPageState extends State<EmekdasAddPage> {
  String _baseUrl = '';
  List<dynamic> _emekdaslar = [];
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _telController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _baseUrl = 'http://${globalIp}:${globalPort}';
    _fetchEmekdaslar();
  }

  Future<void> _fetchEmekdaslar() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(Uri.parse('$_baseUrl/employees'));

      if (response.statusCode == 200) {
        setState(() {
          _emekdaslar = jsonDecode(response.body);
        });
      }
    } catch (e) {
      _showSnackBar("Xəta: $e", Colors.red);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _addEmekdas() async {
    String ad = _nameController.text.trim();
    String sifre = _passwordController.text.trim();
    String tel = _telController.text.trim();

    if (ad.isEmpty || sifre.length != 6 || tel.isEmpty) {
      _showSnackBar(
          "Ad boş ola bilməz, şifrə 6 rəqəm və telefon daxil edilməlidir!",
          Colors.orange);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/add-employee'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'adi': ad, 'sifre': sifre, 'telefon': tel}),
      );

      if (response.statusCode == 200) {
        _nameController.clear();
        _passwordController.clear();
        _telController.clear();
        _fetchEmekdaslar();
        _showSnackBar("Əməkdaş əlavə edildi", Colors.green);
      }
    } catch (e) {
      _showSnackBar("Xəta: $e", Colors.red);
    }
  }

  void _editEmekdas(dynamic item) {
    final name = TextEditingController(text: item['adi']);
    final tel = TextEditingController(text: item['tel']);
    final sifre = TextEditingController(text: item['sifre']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Əməkdaşı düzəlt"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: "Ad"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Telefon"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: sifre,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Şifrə"),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            child: const Text("Yadda saxla"),
            onPressed: () async {
              await http.post(
                Uri.parse('$_baseUrl/update-employee'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'id': item['id'],
                  'adi': name.text,
                  'telefon': tel.text,
                  'sifre': sifre.text
                }),
              );
              Navigator.pop(context);
              _fetchEmekdaslar();
            },
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Əməkdaş Paneli"),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo[800],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                _buildStyledInput(
                  controller: _nameController,
                  hint: "Ad Soyad",
                  icon: Icons.person,
                ),
                const SizedBox(height: 10),
                _buildStyledInput(
                  controller: _telController,
                  hint: "Telefon",
                  icon: Icons.phone,
                  isNumeric: true,
                ),
                const SizedBox(height: 10),
                _buildStyledInput(
                  controller: _passwordController,
                  hint: "6 rəqəmli şifrə",
                  icon: Icons.lock,
                  isNumeric: true,
                  maxLength: 6,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _addEmekdas,
                    icon: const Icon(Icons.check),
                    label: const Text("Əlavə et"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: _emekdaslar.length,
              itemBuilder: (context, index) {
                final item = _emekdaslar[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(item['adi'] ?? ""),
                    subtitle: Text(item['tel'] ?? ""),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        _editEmekdas(item);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumeric = false,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        maxLength: maxLength,
        inputFormatters:
        isNumeric ? [FilteringTextInputFormatter.digitsOnly] : [],
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.indigo),
          hintText: hint,
          counterText: "",
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}