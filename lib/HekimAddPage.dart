import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart' show globalIp, globalPort;

class HekimAddPage extends StatefulWidget {
  const HekimAddPage({Key? key}) : super(key: key);

  @override
  State<HekimAddPage> createState() => _HekimAddPageState();
}

class _HekimAddPageState extends State<HekimAddPage> {
  String _baseUrl = '';
  List<dynamic> _hekimler = [];
  List<dynamic> _filteredHekimler = [];
  List<dynamic> _klinikalar = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _baseUrl = 'http://$globalIp:$globalPort';
    _setup();
  }

  Future<void> _setup() async {
    await _fetchKlinikalar();
    await _fetchHekimler();
  }

  Future<void> _fetchKlinikalar() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/eraziler'));
      if (response.statusCode == 200) {
        setState(() => _klinikalar = jsonDecode(response.body));
      }
    } catch (e) { print("Klinika gətirmə xətası: $e"); }
  }

  Future<void> _fetchHekimler() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/hekimlernew'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _hekimler = data;
          _filteredHekimler = data;
        });
      }
    } catch (e) { print("Həkim gətirmə xətası: $e"); }
    setState(() => _isLoading = false);
  }

  void _openKlinikaPicker(List<int> selectedIds, Function(void Function()) setDialogState) {
    String modalSearchQuery = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredKlinikalar = _klinikalar.where((k) {
              return k['erazi_adi'].toString().toLowerCase().contains(modalSearchQuery.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              builder: (_, controller) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        decoration: const InputDecoration(hintText: "Klinika axtar...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                        onChanged: (val) => setModalState(() => modalSearchQuery = val),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: controller,
                        itemCount: filteredKlinikalar.length,
                        itemBuilder: (context, index) {
                          final k = filteredKlinikalar[index];
                          final id = k['erazi_id'];
                          final isSelected = selectedIds.contains(id);

                          return CheckboxListTile(
                            title: Text(k['erazi_adi'] ?? ""),
                            value: isSelected,
                            activeColor: Colors.indigo,
                            onChanged: (bool? val) {
                              setModalState(() {
                                if (val == true) selectedIds.add(id);
                                else selectedIds.remove(id);
                              });
                              setDialogState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showHekimDialog({dynamic hekim}) {
    final isEdit = hekim != null;
    final name = TextEditingController(text: isEdit ? hekim['hekim_adi']?.toString() : "");
    final tel = TextEditingController(text: isEdit ? hekim['tel']?.toString() : "");
    final qeyd = TextEditingController(text: isEdit ? hekim['qeyd']?.toString() : "");
    int? derece = isEdit ? hekim['derece'] : 1;
    List<int> selectedKlinikaIds = [];

    if (isEdit) {
      var rawIds = hekim['klinika_ids'];
      if (rawIds != null && rawIds is String) {
        selectedKlinikaIds = rawIds.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? "Düzəliş et" : "Yeni Həkim"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: "Həkim adı")),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: derece,
                  decoration: const InputDecoration(labelText: "Dərəcə", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("1 ci dərəcəli")),
                    DropdownMenuItem(value: 2, child: Text("2 ci dərəcəli")),
                    DropdownMenuItem(value: 3, child: Text("Deaktiv")),
                  ],
                  onChanged: (v) => derece = v,
                ),
                const SizedBox(height: 10),
                TextField(controller: tel, decoration: const InputDecoration(labelText: "Telefon")),
                const SizedBox(height: 10),
                TextField(controller: qeyd, decoration: const InputDecoration(labelText: "Qeyd")),
                const SizedBox(height: 15),
                InkWell(
                  onTap: () => _openKlinikaPicker(selectedKlinikaIds, setDialogState),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(selectedKlinikaIds.isEmpty ? "Klinika seçin" : "${selectedKlinikaIds.length} klinika seçildi", overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Ləğv et")),
            ElevatedButton(
              onPressed: () async {
                if (name.text.isEmpty || derece == null) return;
                final url = isEdit ? '$_baseUrl/update-hekim' : '$_baseUrl/add-hekimnew';
                final body = {
                  if (isEdit) 'id': hekim['id'],
                  'hekim_adi': name.text,
                  'telefon': tel.text,
                  'qeyd': qeyd.text,
                  'derece': derece,
                  'klinika_ids': selectedKlinikaIds,
                };
                await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
                Navigator.pop(ctx);
                _fetchHekimler();
              },
              child: Text(isEdit ? "Yadda saxla" : "Əlavə et"),
            )
          ],
        ),
      ),
    );
  }

  void _searchHekim(String query) {
    setState(() {
      _filteredHekimler = _hekimler.where((h) => h['hekim_adi'].toString().toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  String _dereceText(int d) {
    if (d == 1) return "1 ci dərəcəli";
    if (d == 2) return "2 ci dərəcəli";
    if (d == 3) return "Deaktiv";
    return "Naməlum";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Həkimlər"), backgroundColor: Colors.indigo),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHekimDialog(),
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(hintText: "Həkim axtar...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: _searchHekim,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
                itemCount: _filteredHekimler.length,
                itemBuilder: (context, index) {
                  final h = _filteredHekimler[index];
                  String klinikaAdlari = h['klinika_adlari'] ?? "Yoxdur";
                  if (klinikaAdlari.endsWith(', ')) klinikaAdlari = klinikaAdlari.substring(0, klinikaAdlari.length - 2);

                  return Card(
                    elevation: 2,
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.person, color: Colors.white)),
                      title: Text(h['hekim_adi'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${h['tel'] ?? ""} | ${_dereceText(h['derece'] ?? 0)}"),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.local_hospital, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(child: Text(klinikaAdlari, style: const TextStyle(color: Colors.indigo, fontSize: 12, fontWeight: FontWeight.w500))),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.indigo), onPressed: () => _showHekimDialog(hekim: h)),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}