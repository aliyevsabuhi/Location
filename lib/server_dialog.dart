import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bu funksiya kənardan çağırılır.
/// Lazım olan parametrləri alır və dialogue göstərir.
Future<void> showServerDialog({
  required BuildContext context,
  required String ip,
  required String port,
  required bool qiymetyoxlaVisible,
  required ValueChanged<String> onIpChanged,
  required ValueChanged<String> onPortChanged,
  required ValueChanged<bool> onQiymetyoxlaChanged,
  Future<void> Function()? onTestPrint,
  bool isLoadingPrint = false,
}) async {
  final TextEditingController ipController = TextEditingController(text: ip);
  final TextEditingController portController = TextEditingController(text: port);
  bool termQiymetyoxlaVisible = qiymetyoxlaVisible;

  await showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (stfContext, setDialogState) {
          return AlertDialog(
            title: const Text("Server Tənzimləmələri"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Parametrlər", style: TextStyle(fontWeight: FontWeight.w600)),
                  TextField(controller: ipController, decoration: const InputDecoration(labelText: "Server IP")),
                  TextField(controller: portController, decoration: const InputDecoration(labelText: "Port"), keyboardType: TextInputType.number),

                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Ləğv et")),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('server_ip', ipController.text);
                  await prefs.setString('server_port', portController.text);
                  await prefs.setBool('perm_qiymetyoxla_visible', termQiymetyoxlaVisible);

                  onIpChanged(ipController.text);
                  onPortChanged(portController.text);
                  onQiymetyoxlaChanged(termQiymetyoxlaVisible);

                  if (Navigator.of(dialogContext).canPop()) Navigator.of(dialogContext).pop();
                },
                child: const Text("Yadda saxla"),
              ),

            ],
          );
        },
      );
    },
  );
}
