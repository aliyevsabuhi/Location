import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart' show globalIp, globalPort;

class HekimlerAllPage extends StatefulWidget {
  const HekimlerAllPage({Key? key}) : super(key: key);

  @override
  State<HekimlerAllPage> createState() => _HekimlerAllPageState();
}

class _HekimlerAllPageState extends State<HekimlerAllPage> {

  String _baseUrl = '';
  List<dynamic> _data = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _baseUrl = 'http://${globalIp}:${globalPort}';
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);

    final res = await http.get(Uri.parse('$_baseUrl/hekimler-all'));

    if (res.statusCode == 200) {
      setState(() {
        _data = jsonDecode(res.body);
      });
    }

    setState(() => _isLoading = false);
  }

  String _dereceText(int d) {
    if (d == 1) return "1 ci dərəcəli";
    if (d == 2) return "2 ci dərəcəli";
    if (d == 3) return "Deaktiv";
    return "";
  }

  void _delete(int id) async {
    await http.post(
      Uri.parse('$_baseUrl/delete-hekim'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': id}),
    );

    _fetchAll();
  }

  void _edit(dynamic h) {
    final name = TextEditingController(text: h['hekim_adi']);
    final tel = TextEditingController(text: h['telefon']);
    final qeyd = TextEditingController(text: h['qeyd']);
    int derece = h['derece'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Düzəliş et"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: "Ad"),
            ),

            TextField(
              controller: tel,
              decoration: const InputDecoration(labelText: "Telefon"),
            ),

            TextField(
              controller: qeyd,
              decoration: const InputDecoration(labelText: "Qeyd"),
            ),

            DropdownButtonFormField<int>(
              value: derece,
              items: const [
                DropdownMenuItem(value: 1, child: Text("1 ci dərəcəli")),
                DropdownMenuItem(value: 2, child: Text("2 ci dərəcəli")),
                DropdownMenuItem(value: 3, child: Text("Deaktiv")),
              ],
              onChanged: (v) => derece = v!,
            )
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await http.post(
                Uri.parse('$_baseUrl/update-hekim'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'id': h['id'],
                  'hekim_adi': name.text,
                  'telefon': tel.text,
                  'qeyd': qeyd.text,
                  'derece': derece
                }),
              );

              Navigator.pop(context);
              _fetchAll();
            },
            child: const Text("Yadda saxla"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bütün həkimlər"),
        backgroundColor: Colors.deepPurple,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context); // əvvəlki səhifəyə qaytarır (əlavə səhifən)
        },
        child: const Icon(Icons.add),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(

        itemCount: _data.length,

        itemBuilder: (context, i) {

          final h = _data[i];

          return Card(
            child: ListTile(
              leading: const Icon(Icons.person),

              title: Text(h['hekim_adi']),

              subtitle: Text(
                      "Klinika: ${h['erazi_adi']}\n"
                      "Tel: ${h['telefon']}\n"
                      "Dərəcə: ${_dereceText(h['derece'])}\n"
                      "Qeyd: ${h['qeyd']}"
              ),

              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _edit(h),
                  ),

                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _delete(h['id']),
                  ),

                ],
              ),
            ),
          );
        },
      ),
    );
  }
}