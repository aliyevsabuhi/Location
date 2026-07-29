
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'main.dart' show globalIp, globalPort, globalAllowDateChange, globalTermname,globalceki, globaleded, kSavedPrinterAddrKey, kSavedPrinterNameKey;  // qlobal dəyərlər üçün


/// ================== KONFİQURASİYA ==================
const String _kassaMedaxilEndpoint = '/kassa_medaxil'; // lazım olsa dəyiş: '/kassa/medaxil' və s.

/// ================== MODELLƏR ==================
class LookupItem {
  final int id;
  final String name;
  LookupItem({required this.id, required this.name});

  factory LookupItem.fromMap(Map<String, dynamic> m) => LookupItem(
    id: (m['idn'] as num).toInt(),
    name: (m['adi'] ?? '').toString(),
  );
}

/// ================== SƏHİFƏ ==================
class KassaMedaxilPage extends StatefulWidget {
  const KassaMedaxilPage({super.key});

  @override
  State<KassaMedaxilPage> createState() => _KassaMedaxilPageState();
}

class _KassaMedaxilPageState extends State<KassaMedaxilPage> {
  final _formKey = GlobalKey<FormState>();

  // Header
  DateTime _date = DateTime.now();
  String _paymentType = 'Nağd'; // Nağd | Kart

  // Seçilənlər (ID)
  int? _selectedCashDeskId;
  int? _selectedCustomerId;
  int? _selectedMuqavileId;
  int? _selectedSorguId;
  int? _selectedValyutaId;

  // Lookup-lar
  List<LookupItem> _cashDesks = [];
  List<LookupItem> _customers = [];
  List<LookupItem> _muqavile = [];
  List<LookupItem> _sorgu = [];
  List<LookupItem> _valyuta = [];

  // Dəyərlər
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  // UI vəziyyət
  bool _loadingLookups = false;
  String? _lookupError;
  bool _loadingMLookups = false;
  String? _lookupMError;
  bool _loadingSLookups = false;
  String? _lookupSError;
  bool _submitting = false;

  static const String _draftKey = 'kassa_medaxil_draft';



  @override
  void initState() {
    super.initState();
    _loadDraft().then((_) => _loadLookups());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// ----- Server Base -----
  Future<String> _getBaseUrl() async {
    if (globalIp == null ||
        globalPort == null ||
        globalIp!.trim().isEmpty ||
        globalPort!.toString().trim().isEmpty) {
      throw Exception('Server IP/Port təyin olunmayıb. Parametrləri yoxlayın.');
    }
    String host = globalIp!.trim();
    String port = globalPort!.toString().trim();
    host = host.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');
    if (host == '127.0.0.1' || host.toLowerCase() == 'localhost') {
      host = '10.0.2.2';
    }
    final base = 'http://$host:$port';
    return base;
  }

  /// ----- Lookup-ları yüklə -----
  Future<void> _loadLookups() async {
    setState(() {
      _loadingLookups = true;
      _lookupError = null;
    });

    try {
      final base = await _getBaseUrl();
      final responses = await Future.wait([
        http.get(Uri.parse('$base/musteri?userId=$globalTermname')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$base/kassa?userId=$globalTermname')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$base/valyuta')).timeout(const Duration(seconds: 15)),
      ]);

      if (responses.any((r) => r.statusCode != 200)) {
        throw Exception('Lookup yüklənmə xətası (status != 200)');
      }

      final custJson = jsonDecode(responses[0].body) as List;
      final kassJson = jsonDecode(responses[1].body) as List;
      final valyutaJson = jsonDecode(responses[2].body) as List;

      final customers = custJson.map((e) => LookupItem.fromMap(e)).toList();
      final kassas = kassJson.map((e) => LookupItem.fromMap(e)).toList();
      final valyutalar = valyutaJson.map((e) => LookupItem.fromMap(e)).toList();

      setState(() {
        _customers = customers;
        _cashDesks = kassas;
        _valyuta = valyutalar;

        //_selectedCustomerId ??= _customers.isNotEmpty ? _customers.first.id : null;
        _selectedCashDeskId ??= _cashDesks.isNotEmpty ? _cashDesks.first.id : null;
        _selectedValyutaId ??= _valyuta.isNotEmpty ? _valyuta.first.id : null;
      });
    } catch (e) {
      setState(() => _lookupError = e.toString());
    } finally {
      setState(() => _loadingLookups = false);
    }

    _loadLookupsmuqavile();
    _loadLookupsorgu();
  }
  String _customerNameById(int? id) {
    if (id == null) return 'Seçilməyib';
    final idx = _customers.indexWhere((e) => e.id == id);
    if (idx == -1) return '#$id';
    return _customers[idx].name;
  }






  Future<void> _loadLookupsorgu() async {
    setState(() {
      _loadingSLookups = true;
      _lookupSError = null;
      _sorgu = []; // köhnə məlumatları təmizləyirik
      _selectedSorguId = null;
    });

    try {
      final base = await _getBaseUrl();
      final response = await http
          .get(Uri.parse('$base/sorgu?userId=$_selectedCustomerId'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Sorğu yüklənmə xətası (status != 200)');
      }

      final body = response.body.trim();
      if (body.isEmpty || body == 'null') {
        // Backend boş cavab qaytarıb
        setState(() {
          _sorgu = [];
          _selectedSorguId = null;
        });
        return;
      }

      final decoded = jsonDecode(body);
      if (decoded is! List) {
        // Serverdəki məlumat siyahı deyil
        setState(() {
          _sorgu = [];
          _selectedSorguId = null;
        });
        return;
      }

      final sorguList = decoded.map((e) => LookupItem.fromMap(e)).toList();

      setState(() {
        _sorgu = sorguList;
        _selectedSorguId =
        _sorgu.isNotEmpty ? _sorgu.first.id : null;
      });
    } catch (e) {
      setState(() {
        _lookupSError = e.toString();
        _sorgu = [];
        _selectedSorguId = null;
      });
    } finally {
      setState(() => _loadingSLookups = false);
    }
  }

  Future<void> _loadLookupsmuqavile() async {
    setState(() {
      _loadingMLookups = true;
      _lookupMError = null;
      _muqavile = []; // köhnə məlumatları təmizləyirik
      _selectedMuqavileId = null;
    });

    try {
      final base = await _getBaseUrl();
      final response = await http
          .get(Uri.parse('$base/muqavile?userId=$_selectedCustomerId'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Müqavilə yüklənmə xətası (status != 200)');
      }

      final body = response.body.trim();
      if (body.isEmpty || body == 'null') {
        // Backend boş cavab qaytarıb
        setState(() {
          _muqavile = [];
          _selectedMuqavileId = null;
        });
        return;
      }

      final decoded = jsonDecode(body);
      if (decoded is! List) {
        // Serverdəki məlumat siyahı deyil
        setState(() {
          _muqavile = [];
          _selectedMuqavileId = null;
        });
        return;
      }

      final muqavileList = decoded.map((e) => LookupItem.fromMap(e)).toList();

      setState(() {
        _muqavile = muqavileList;
        _selectedMuqavileId =
        _muqavile.isNotEmpty ? _muqavile.first.id : null;
      });
    } catch (e) {
      setState(() {
        _lookupMError = e.toString();
        _muqavile = [];
        _selectedMuqavileId = null;
      });
    } finally {
      setState(() => _loadingMLookups = false);
    }
  }




  /// ----- Draft -----
  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_draftKey);
    if (s == null) return;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      setState(() {
        _date = DateTime.tryParse((m['date'] ?? '').toString()) ?? DateTime.now();
        _paymentType = (m['payment'] ?? _paymentType).toString();
        _selectedCashDeskId = (m['cashdeskId'] as num?)?.toInt();
        _selectedCustomerId = (m['customerId'] as num?)?.toInt();
        _amountCtrl.text = (m['amount'] ?? '').toString();
        _noteCtrl.text = (m['note'] ?? '').toString();
      });
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'date': _date.toIso8601String(),
      'payment': _paymentType,
      'cashdeskId': _selectedCashDeskId,
      'customerId': _selectedCustomerId,
      'amount': _amountCtrl.text.trim(),
      'note': _noteCtrl.text.trim(),
    };
    await prefs.setString(_draftKey, jsonEncode(map));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  /// ----- Tarix seç -----
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute);
      });
      // _saveDraft();
    }
  }

  /// ----- Göndər -----
  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Məbləğ düzgün deyil.')),
      );
      return;
    }
    if (_selectedCustomerId == null || _selectedCashDeskId == null || _selectedMuqavileId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Müştəri, Kassa və Müqavilə seçilməlidir.')),
      );
      return;
    }

    final payment = _paymentType == 'Nağd' ? 0 : 1; // 0=Nağd, 1=Kart
    final payload = {
      'date': _date.toIso8601String(),
      'customerId': _selectedCustomerId,
      'cashdeskId': _selectedCashDeskId,
      'muqavileId': _selectedMuqavileId,
      'sorguId': _selectedSorguId,
      'userId' : globalTermname,
      'payment': payment,
      'amount': amount,
      'valyuta': _selectedValyutaId,
      'note': _noteCtrl.text.trim(),
    };

    setState(() => _submitting = true);
    try {
      final base = await _getBaseUrl();
      final resp = await http
          .post(
        Uri.parse('$base$_kassaMedaxilEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        await _clearDraft();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kassa mədaxil sənədi saxlanıldı')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xəta: ${resp.statusCode} — ${resp.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Şəbəkə xətası: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    final canChangeDate = globalAllowDateChange; // qlobaldan oxu

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kassa mədaxil'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: _loadingLookups
          ? const Center(child: CircularProgressIndicator())
          : _lookupError != null
          ? Center(child: Text('Yükləmə xətası: $_lookupError'))
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(6),
          children: [
            // HEADER KARTI
            // ... build() içində, HEADER KARTI hissəsində:
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    // 1-ci sıra: Tarix (dar) + Ödəniş növü (geniş)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 160,
                          child: IgnorePointer(
                            ignoring: !canChangeDate,
                            child: Opacity(
                              opacity: canChangeDate ? 1 : 0.5,
                              child: _HeaderTile(
                                label: 'Tarix',
                                value: df.format(_date),
                                onTap: canChangeDate ? _pickDate : () {},

                              ),

                            ),

                          ),
                        ),

                        const SizedBox(width: 50),
                      ],
                    ),

                    const SizedBox(height: 12),
                    // 2-ci sıra: Müştəri (tam eninə)
                    _CustomerSearchPicker(
                      label: 'Müştəri',
                      valueText: _customerNameById(_selectedCustomerId),
                      items: _customers,
                      onSelected: (item) {
                        if (item != null && item.id != _selectedCustomerId) {
                          setState(() {
                            _selectedCustomerId = item.id;
                          });
                          if (_selectedCustomerId != null) {
                            _loadLookupsmuqavile();
                            _loadLookupsorgu();
                          }
                        }
                      },
                    ),



                    const SizedBox(height: 12),
                    // 2-ci sıra: Müştəri (tam eninə)
                    _HeaderDropdownGeneric(
                      label: 'Müqavilə',
                      selectedId: _selectedMuqavileId,
                      items: _muqavile,
                      onChanged: (id) {
                        setState(() => _selectedMuqavileId = id);
                        // _saveDraft();
                      },
                    ),


                    const SizedBox(height: 12),
                    _HeaderDropdownGeneric(
                      label: 'Sorğu',
                      selectedId: _selectedSorguId,
                      items: _sorgu,
                      onChanged: (id) {
                        setState(() => _selectedSorguId = id);
                        // _saveDraft();
                      },
                    ),


                    const SizedBox(height: 12),
                    // 3-cü sıra: Kassa (tam eninə)
                    _HeaderDropdownGeneric(
                      label: 'Kassa',
                      selectedId: _selectedCashDeskId,
                      items: _cashDesks,
                      onChanged: (id) {
                        setState(() => _selectedCashDeskId = id);
                        // _saveDraft();
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Card(

              child: Column( // Ana widget'ları dikeyde hizalamak için Column
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // Dikeyde hizalamayı ayarlar
                    children: [
                      Expanded(
                        flex: 2, // Məbləğ alanına daha çox yer ver (isteğe bağlı)
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'Məbləğ',
                            labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.black54),
                            ),
                          ),
                          onTap: () => _amountCtrl.selection =
                              TextSelection(baseOffset: 0, extentOffset: _amountCtrl.text.length),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1, // Valyuta alanına daha az yer ver (isteğe bağlı)
                        child: _HeaderDropdownGeneric(
                          label: 'Valyuta',
                          selectedId: _selectedValyutaId,
                          items: _valyuta,
                          onChanged: (id) {
                            setState(() => _selectedValyutaId = id);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12), // Boşluğu biraz artırabiliriz
                  // Qeyd alanı zaten Expanded içinde olduğu için burada bir sorun yok.
                  TextFormField(
                    controller: _noteCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Qeyd',
                      labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ===== Actions =====
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [

                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: Text(_submitting ? 'Göndərilir...' : 'Təsdiqlə'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

//// ==== Köməkçi UI vidcetləri ====


// Ümumi şrift ölçüsü üçün sabit
const double kGlobalBaseFontSize = 13.0; // Vahid şrift ölçüsü

// Tarix üçün kliklənən tile
class _HeaderTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _HeaderTile({
    super.key, // super.key əlavə etdim
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: kGlobalBaseFontSize - 1, // label bir az kiçik
          color: Colors.black87,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black54),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap, // 👈 tarixi seçmək üçün
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12), // kassa field ilə eyni hündürlük
          child: Row(
            children: [
              const Icon(Icons.event, size: 18, color: Colors.black87), // istəsən silə bilərsən
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value, // df.format(_date) gəlir
                  style: TextStyle(
                    fontSize: kGlobalBaseFontSize, // əsas mətn ölçüsü
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderDropdownGeneric extends StatelessWidget {
  final String label;
  final dynamic selectedId; // int və ya String ola bilər
  final List<LookupItem> items;
  final ValueChanged<dynamic?> onChanged; // int və ya String ola bilər
  final bool enabled;

  const _HeaderDropdownGeneric({
    super.key, // super.key əlavə etdim
    required this.label,
    required this.selectedId,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: kGlobalBaseFontSize - 1, // Label bir az daha kiçik
          color: Colors.black87,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black54),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), // Padding-i bir az tənzimlədim
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>( // value və onChanged-in tipi dynamic oldu
          value: selectedId,
          isExpanded: true,
          iconSize: 18,iconEnabledColor: Colors.black87,
          style: TextStyle(
            fontSize: kGlobalBaseFontSize, // Seçilmiş elementin mətni
            color: Colors.black87,
          ),
          items: items.map((e) {
            return DropdownMenuItem<dynamic>( // value tipi dynamic oldu
              value: e.id,
              child: Text(
                e.name,
                style: TextStyle(
                  fontSize: kGlobalBaseFontSize,fontWeight: FontWeight.w500, // Siyahıdakı elementlərin mətni
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis, // Uzun mətnlər üçün
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _PaymentChips extends StatelessWidget {
  final String value; // Nağd | Kart
  final ValueChanged<String> onChanged;
  const _PaymentChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text(
            'Nağd',
            style: TextStyle(fontSize: 8), // 🔸 yazı ölçüsünü kiçildir
          ),
          selected: value == 'Nağd',
          onSelected: (s) => s ? onChanged('Nağd') : null,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 🔸 boşluğu azaldır
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // 🔸 tap target kiçilir
          visualDensity: VisualDensity.compact, // 🔸 sıxlıq daha yığcam olur
        ),
        ChoiceChip(
          label: const Text(
            'Kart',
            style: TextStyle(fontSize: 8),
          ),
          selected: value == 'Kart',
          onSelected: (s) => s ? onChanged('Kart') : null,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

}




// 🔎 Müştəri üçün axtarışlı picker (bottom sheet ilə)
class _CustomerSearchPicker extends StatelessWidget {
  final String label;
  final String valueText; // göstərilən seçilmiş dəyər
  final List<LookupItem> items;
  final ValueChanged<LookupItem?> onSelected;

  // valueTextFontSize və labelFontSize parametrləri qaldı,
  // amma əgər təyin edilməsələr kGlobalBaseFontSize istifadə olunacaq.
  final double? valueTextFontSize;
  final double? labelFontSize;

  const _CustomerSearchPicker({
    super.key,
    required this.label,
    required this.valueText,
    required this.items,
    required this.onSelected,
    this.valueTextFontSize,
    this.labelFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        label: Text(
          label,
          style: TextStyle(fontSize: labelFontSize ?? kGlobalBaseFontSize -1, color: Colors.black87), // Label bir az kiçik
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
      child: InkWell(
        onTap: () => _openSearch(context),
        child: Row(
          children: [
            //const Icon(Icons.person_search, size: 18),
            //const SizedBox(width: 8),
            Expanded(
              child: Text(
                valueText,
                style: TextStyle(fontSize: valueTextFontSize ?? kGlobalBaseFontSize, color:  Colors.black87), // Əsas mətn
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down,size: 18,color: Colors.black87,),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    List<LookupItem> filtered = List.of(items);
    final ctrl = TextEditingController();
    // Tema-nı burada almağa ehtiyac yoxdur, birbaşa TextStyle istifadə edəcəyik

    final selected = await showModalBottomSheet<LookupItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 8,
          ),
          child: StatefulBuilder(
            builder: (ctx, setMS) {
              void doFilter(String q) {
                final query = q.toLowerCase().trim();
                setMS(() {
                  filtered = items.where((e) =>
                  e.name.toLowerCase().contains(query) ||
                      e.id.toString().toLowerCase().contains(query) // id-ni də kiçik hərflə axtar
                  ).toList();
                });
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Müştəri seç',
                      style: GoogleFonts.poppins(
                          fontSize: kGlobalBaseFontSize, // Başlıq üçün əsas ölçü
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: TextStyle(fontSize: kGlobalBaseFontSize, color: Colors.black87), // Daxil edilən mətn
                      cursorColor: Colors.black87,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Axtar',
                        labelStyle: TextStyle(fontSize: kGlobalBaseFontSize -1), // Label bir az kiçik
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      ),
                      onChanged: doFilter,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: MediaQuery.of(ctx).size.height * 0.5, // Hündürlüyü tənzimləyə bilərsiniz
                      child: filtered.isEmpty
                          ? Center(child: Text('Nəticə tapılmadı', style: TextStyle(fontSize: kGlobalBaseFontSize -1 ))) // Kiçik mətn
                          : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final it = filtered[i];
                          return ListTile(
                            leading: const Icon(Icons.person_outline, size: 20),
                            title: Text(
                              it.name,
                              style: TextStyle(fontSize: kGlobalBaseFontSize), // Siyahı elementi
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            dense: true,
                            onTap: () => Navigator.pop(ctx, it),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (context.mounted && selected != null) { // selected null ola bilər, onSelected-i çağırmazdan əvvəl yoxla
      onSelected(selected);
    } else if (context.mounted && selected == null) {
      onSelected(null); // İstifadəçi heç nə seçməyibsə null göndər
    }
  }
}

