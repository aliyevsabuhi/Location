import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // globalIp və globalPort üçün
import 'package:http/http.dart' as http;
import 'list_detail_page.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  String? _ip;
  String? _port;
  List<String> _listNames = [];

  static const String _insertPath = '/insert-lists'; // <-- API path (dəyə bilərsən)

  @override
  void initState() {
    super.initState();
    _ip = globalIp;
    _port = globalPort;
    _loadSavedData();
  }




  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ip = prefs.getString('server_ip') ?? '';
      _port = prefs.getString('server_port') ?? '';
      _listNames = prefs.getStringList('list_names') ?? [];
    });
  }

  Future<void> _saveCurrentListNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('list_names', _listNames);
  }

  Future<void> _addListName(String name) async {
    if (_listNames.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("'$name' adlı list artıq mövcuddur.")),
      );
      return;
    }
    setState(() {
      _listNames.add(name);
    });
    await _saveCurrentListNames();
  }

  Future<void> _removeListName(int index) async {
    setState(() {
      _listNames.removeAt(index);
    });
    await _saveCurrentListNames();
  }

  Future<void> _showProgressDialog(Future<void> Function() task) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const AlertDialog(
          title: Text("Məlumatlar Göndərilir"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(),
              SizedBox(height: 20),
              Text("Zəhmət olmasa gözləyin..."),
            ],
          ),
        ),
      ),
    );

    try {
      await task();
    } finally {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _editListName(int index, String newName) async {
    if (newName != _listNames[index] && _listNames.contains(newName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("'$newName' adlı list artıq mövcuddur.")),
      );
      return;
    }
    setState(() {
      _listNames[index] = newName;
    });
    await _saveCurrentListNames();
  }

  void _showEditListDialog(int index) {
    final String originalName = _listNames[index];
    final TextEditingController editController =
    TextEditingController(text: originalName);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("List Adını Dəyiş"),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(labelText: "Yeni ad"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Ləğv et"),
          ),
          TextButton(
            onPressed: () {
              if (editController.text.isNotEmpty &&
                  editController.text != originalName) {
                _editListName(index, editController.text);
              } else if (editController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ad boş ola bilməz!")),
                );
              } else {
                Navigator.of(context).pop();
              }
              Navigator.of(context).pop();
            },
            child: const Text("Yadda saxla"),
          ),
        ],
      ),
    );
  }

  void _showAddListDialog() {
    final TextEditingController listController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yeni List Adı"),
        content: TextField(
          controller: listController,
          decoration: const InputDecoration(labelText: "Ad daxil edin"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Ləğv et"),
          ),
          TextButton(
            onPressed: () {
              if (listController.text.isNotEmpty) {
                _addListName(listController.text);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ad boş ola bilməz!")),
                );
              }
            },
            child: const Text("Yadda saxla"),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _buildAllListsPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList('list_names') ?? [];

    final List<Map<String, dynamic>> lists = [];
    for (final name in names) {
      final itemsJson = prefs.getString('list_items_' + name);
      if (itemsJson == null) continue;
      final List<dynamic> items = jsonDecode(itemsJson);
      lists.add({
        'listName': name,
        'items': items,
      });
    }

    return {'lists': lists};
  }

  Future<String> _getBaseUrl() async {
    if (_ip == null || _port == null || _ip!.trim().isEmpty || _port!.trim().isEmpty) {
      throw Exception('Server IP/Port təyin olunmayıb. Parametrləri yoxlayın.');
    }
    String host = _ip!.trim();
    String port = _port!.trim();
    host = host.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');
    if (host == '127.0.0.1' || host.toLowerCase() == 'localhost') {
      host = '10.0.2.2'; // Android emulator üçün
    }
    return 'http://$host:$port';
  }

  Future<void> _sendSingleList(String listName) async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getString('list_items_' + listName);

    if (itemsJson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“$listName” üçün element tapılmadı.')),
      );
      return;
    }

    final List<dynamic> items = jsonDecode(itemsJson);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“$listName” boşdur.')),
      );
      return;
    }

    // ListDetailPage formatına çevir
    double totalQty = 0.0;
    final lines = items.map<Map<String, dynamic>>((e) {
      final m = e as Map<String, dynamic>;
      final qty   = (m['quantity'] as num).toDouble();
      totalQty   += qty;
      return {
        'barcode': m['barcode'],
        'ad'     : m['name'],
        'qty'    : qty,
        'alis'   : (m['buyPrice'] as num).toDouble(),
        'satis'  : (m['sellPrice'] as num).toDouble(),
      };
    }).toList();

    final payload = {
      'date'    : DateTime.now().toIso8601String(),
      'listName': listName,
      'lines'   : lines,
      'totalQty': totalQty,
    };

    await _showProgressDialog(() async {
      try {
        final base = await _getBaseUrl();
        final resp = await http.post(
          Uri.parse('$base/terminal'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 30));

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          // Uğurlu oldu: həmin listi lokaldan sil
          await prefs.remove('list_items_' + listName);

          final names = prefs.getStringList('list_names') ?? [];
          names.remove(listName);
          await prefs.setStringList('list_names', names);

          setState(() => _listNames = names);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('“$listName” serverə göndərildi və silindi.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Xəta: ${resp.statusCode} — ${resp.body}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şəbəkə xətası: $e')),
        );
      }
    });
  }



  Future<void> _sendAllLists() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList('list_names') ?? [];


    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Göndəriləcək siyahı yoxdur.")),
      );
      return;
    }

    await _showProgressDialog(() async {
      try {
        final base = await _getBaseUrl();

        // Hər list üçün ayrıca /terminal çağırışı (ListDetailPage formatında)
        final succeeded = <String>[];
        for (final listName in List<String>.from(names)) {
          final itemsJson = prefs.getString('list_items_' + listName);
          if (itemsJson == null) continue;
          final List<dynamic> items = jsonDecode(itemsJson);
          if (items.isEmpty) continue;

          double totalQty = 0.0;
          final lines = items.map<Map<String, dynamic>>((e) {
            final m = e as Map<String, dynamic>;
            final qty   = (m['quantity'] as num).toDouble();
            totalQty   += qty;
            return {
              'barcode': m['barcode'],
              'ad'     : m['name'],
              'qty'    : qty,
              'alis'   : (m['buyPrice'] as num).toDouble(),
              'satis'  : (m['sellPrice'] as num).toDouble(),
            };
          }).toList();

          final payload = {
            'date'    : DateTime.now().toIso8601String(),
            'listName': listName,
            'lines'   : lines,
            'totalQty': totalQty,
          };

          final resp = await http.post(
            Uri.parse('$base/terminal'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 30));

          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            // Bu list uğurlu oldu -> lokaldan sil
            await prefs.remove('list_items_' + listName);
            succeeded.add(listName);
          } else {
            // Uğursuz olanları toxunmadan saxlayırıq
            debugPrint('List "$listName" error: ${resp.statusCode} — ${resp.body}');
          }
        }

        if (succeeded.isNotEmpty) {
          // list_names-dən uğurla göndərilənləri çıxar
          final newNames = names.where((n) => !succeeded.contains(n)).toList();
          await prefs.setStringList('list_names', newNames);
          setState(() => _listNames = newNames);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Göndərildi: ${succeeded.join(", ")}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Heç bir list göndərilmədi.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şəbəkə xətası: $e')),
        );
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Soffen Mobile"),
      ),

      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: _listNames.isEmpty
                ? const Center(child: Text("Hələ heç bir list əlavə olunmayıb."))
                : ListView.builder(
              itemCount: _listNames.length,
              itemBuilder: (context, index) {
                final listName = _listNames[index];
                final itemKey = Key(listName + '_' + index.toString());
                return Dismissible(
                  key: itemKey,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    color: Colors.blue,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.edit, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      return await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Silmək istəyirsiniz?"),
                          content: Text('“' + listName + '” adlı listi silmək istəyirsinizmi?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("Ləğv et"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("Bəli, sil"),
                            ),
                          ],
                        ),
                      ) ??
                          false;
                    } else if (direction == DismissDirection.endToStart) {
                      _showEditListDialog(index);
                      return false;
                    }
                    return false;
                  },
                  onDismissed: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      // həm list adını, həm də onun item-lərini sil
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('list_items_' + listName);
                      await _removeListName(index);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('“' + listName + '” silindi.')),
                      );
                    }
                  },
                  child: ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(listName),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ListDetailPage(listName: listName),
                        ),
                      );
                    },
                    trailing: IconButton(
                      tooltip: 'Bu listi serverə göndər',
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        // Göndərməzdən əvvəl təsdiq dialoqu
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                          title: const Text('Göndərilsin?'),
                          content: Text('“$listName” serverə göndərilsin? Uğurlu olduqda list silinəcək.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Yox'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Bəli'),
                            ),
                          ],
                        ),
                        ) ?? false;

                        if (ok) {
                          await _sendSingleList(listName);
                        }
                      },
                    ),
                  ),

                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: [
          Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              onPressed: _showAddListDialog,
              tooltip: 'Yeni List Əlavə Et',
              child: const Icon(Icons.add),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FloatingActionButton(
                onPressed: () async {
                  // Əvvəlcə boş olub-olmadığını yoxla
                  if (_listNames.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Göndəriləcək siyahı yoxdur.')),
                    );
                    return;
                  }

                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Göndərilsin?'),
                      content: const Text(
                          'Bütün siyahılar serverə göndərilsin? '
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Yox'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Bəli'),
                        ),
                      ],
                    ),
                  ) ?? false;

                  if (!ok) return;

                  // Təsdiqdən sonra progress göstərərək hamısını göndər
                  await _showProgressDialog(_sendAllLists);
                },
                tooltip: 'Göndər',
                backgroundColor: Colors.green,
                child: const Icon(Icons.send),
              ),
            ),
          )


        ],
      ),
    );
  }

  Future<void> _downloadMallar() async {
    if (_ip == null || _port == null || _ip!.isEmpty || _port!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server IP və Port təyin olunmayıb!")),
      );
      return;
    }

    final url = Uri.parse('http://$_ip:$_port/mallar');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mallar_data', jsonEncode(data));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Məlumatlar uğurla yeniləndi.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xəta baş verdi: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Xəta: $e")),
      );
    }
  }
}
