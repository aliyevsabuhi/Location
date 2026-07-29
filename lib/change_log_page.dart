import 'dart:convert';
import 'dart:io'; // Fayl əməliyyatları üçün
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart'; // Yeni import
import 'package:open_filex/open_filex.dart';

import 'package:permission_handler/permission_handler.dart'; // Yenə də lazımdır

import 'main.dart' show globalIp, globalPort, currentVersion;

class ChangeLogPage extends StatefulWidget {
  const ChangeLogPage({super.key});

  @override
  State<ChangeLogPage> createState() => _ChangeLogPageState();
}

class _ChangeLogPageState extends State<ChangeLogPage> {
  List versions = [];
  bool loading = true;

  // Yükləmə statusunu izləmək üçün
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    fetchVersions();
  }

  Future<void> fetchVersions() async {
    final url = Uri.parse("http://$globalIp:$globalPort/version");
    try {
      final response = await http.get(url);
      if (mounted) {
        setState(() {
          versions = jsonDecode(response.body);
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  // YENİ VƏ SADƏ YÜKLƏMƏ METODU
  Future<void> downloadAndInstall(String apkUrl, String fileName) async {
    // APK quraşdırma icazəsi
    var installPermission = await Permission.requestInstallPackages.status;
    if (!installPermission.isGranted) {
      installPermission = await Permission.requestInstallPackages.request();
      if (!installPermission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Quraşdırmaya icazə verilmədi.")),
          );
        }
        return;
      }
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      final request = http.Request("GET", Uri.parse(apkUrl));
      final response = await http.Client().send(request);

      final contentLength = response.contentLength ?? 0;
      int bytesReceived = 0;

      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        bytesReceived += chunk.length;
        sink.add(chunk);

        if (contentLength != 0) {
          setState(() {
            _downloadProgress = bytesReceived / contentLength;
          });
        }
      }).asFuture();

      await sink.close();

      //print("Fayl endirildi: $filePath");

      final result = await OpenFilex.open(
        filePath,
        type: "application/vnd.android.package-archive",
      );

     /* if (result.type != ResultType.done) {
        print("Açıla bilmədi: ${result.message}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Quraşdırma açıla bilmədi: ${result.message}")),
          );
        }
      }
      */

    } catch (e) {
      print("Xəta: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Yükləmə zamanı xəta: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isNewVersionAvailable = versions.isNotEmpty && versions.first["version"] != currentVersion;

    return Scaffold(
      appBar: AppBar(title: const Text("Yeniliklər"), centerTitle: true),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : versions.isEmpty
          ? const Center(child: Text("Versiya məlumatı tapılmadı."))
          : ListView.builder(
        // ... (ListView kodunuz eyni qalır)
        padding: const EdgeInsets.all(12),
        itemCount: versions.length,
        itemBuilder: (context, index) {
          final v = versions[index];
          bool isCurrent = v["version"] == currentVersion;
          bool isLatest = index == 0;
          return Card(
            color: isCurrent ? Colors.green.withOpacity(0.1) : null,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Solda versiya məlumatları
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text("Versiya: ${v["version"]}",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          if (isCurrent)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Chip(label: Text("Mövcud"), padding: EdgeInsets.zero),
                            ),
                          if (!isCurrent && isLatest)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Chip(
                                label: Text("Yeni"),
                                backgroundColor: Colors.orangeAccent,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          "Dəyişikliklər:\n${v["bugreport"]}\nTarix: ${v["date"]}",
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  // Sağda düymə
                  if (isLatest && !isCurrent)
                    ElevatedButton(
                      onPressed: _isDownloading
                          ? null
                          : () {
                        final apkUrl = versions.first["apkurl"];
                        final fileName = apkUrl.split('/').last;
                        downloadAndInstall(apkUrl, fileName);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      child: _isDownloading
                          ? Row(
                        children: [
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text("${(_downloadProgress * 100).toStringAsFixed(0)}%"),
                        ],
                      )
                          : const Text("Yenilə"),
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
