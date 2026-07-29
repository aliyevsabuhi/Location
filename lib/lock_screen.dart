import 'dart:async';
import 'dart:convert';
import 'package:aliyev_apk/server_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'main.dart';

class LockScreenPage extends StatefulWidget {
  const LockScreenPage({super.key});

  @override
  State<LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends State<LockScreenPage> {

  String _enteredPassword = "";
  String? _errorMessage;
  bool _isCheckingPassword = false;
  final int _passwordLength = 6;

  Timer? _errorClearTimer;

  List<Map<String,dynamic>> _users = [];
  Map<String,dynamic>? _selectedUser;
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _errorClearTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUsers() async {

    try {

      final url = Uri.parse('http://$globalIp:$globalPort/api/users');
      final response = await http.get(url);

      if(response.statusCode == 200){

        final List data = json.decode(response.body);

        setState(() {

          _users = data.cast<Map<String,dynamic>>();

          if(_users.isNotEmpty){
            _selectedUser = _users.first;
          }

          _loadingUsers = false;

        });

      }

    } catch(e){

      setState(() {
        _loadingUsers = false;
      });

    }

  }

  void _navigateToHome() async {

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();

    final loggedInUserIdn = prefs.getString('logged_in_user_idn') ?? '0';
    final loggedInUserName = prefs.getString('logged_in_user_name') ?? 'İstifadəçi';
    final loggedInUserRol = prefs.getString('logged_in_user_role') ?? '';

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AnaSehife(
          userIdn: loggedInUserIdn,
          userName: loggedInUserName,
          userRol: loggedInUserRol,
        ),
      ),
    );
  }

  void _onNumberPress(String number) {

    if (_isCheckingPassword) return;

    HapticFeedback.lightImpact();

    if (_enteredPassword.length < _passwordLength) {

      setState(() {

        _enteredPassword += number;
        _errorMessage = null;

      });

      if (_enteredPassword.length == _passwordLength) {

        _fetchAndVerifyPassword();

      }

    }

  }

  void _onBackspacePress() {

    if (_isCheckingPassword) return;

    HapticFeedback.lightImpact();

    if (_enteredPassword.isNotEmpty) {

      setState(() {

        _enteredPassword =
            _enteredPassword.substring(0, _enteredPassword.length - 1);

        _errorMessage = null;

      });

    }

  }

  Future<void> _fetchAndVerifyPassword() async {

    setState(() {

      _isCheckingPassword = true;
      _errorMessage = null;

    });

    /// ADMIN ŞİFRƏ
    if (_enteredPassword == '651006') {

      setState(() {
        _isCheckingPassword = false;
        _enteredPassword = '';
      });

      final prefs = await SharedPreferences.getInstance();

      await showServerDialog(
        context: context,
        ip: prefs.getString('server_ip') ?? '',
        port: prefs.getString('server_port') ?? '',
        qiymetyoxlaVisible: prefs.getBool('perm_qiymetyoxla_visible') ?? true,
        onIpChanged: (v) => globalIp = v,
        onPortChanged: (v) => globalPort = v,
        onQiymetyoxlaChanged: (v) {},
        onTestPrint: () async {},
      );

      return;

    }

    /// NORMAL USER CHECK

    if(_selectedUser != null &&
        (_selectedUser!['password']?.toString() ?? '') == _enteredPassword)
    {

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
          'logged_in_user_idn',
          _selectedUser!['idn'].toString());

      await prefs.setString(
          'logged_in_user_name',
          _selectedUser!['name']);

      await prefs.setString(
          'logged_in_user_role',
          _selectedUser!['mob_role'].toString());

      _navigateToHome();

    }
    else
    {

      _handleIncorrectPassword();

    }

    setState(() {
      _isCheckingPassword = false;
    });

  }

  void _handleIncorrectPassword() {

    HapticFeedback.heavyImpact();

    setState(() {

      _errorMessage = "Yanlış şifrə!";
      _enteredPassword = "";

    });

    _startErrorClearTimer();

  }

  void _startErrorClearTimer() {

    _errorClearTimer?.cancel();

    _errorClearTimer = Timer(
        const Duration(seconds: 3), () {

      if (mounted) {

        setState(() {
          _errorMessage = null;
        });

      }

    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.deepPurple[400],

      body: Stack(

        children: [

          SafeArea(

            child: Padding(

              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 32),

              child: Column(

                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,

                children: [

                  Expanded(

                    child: Column(

                      mainAxisAlignment:
                      MainAxisAlignment.center,

                      children: [

                        Icon(
                          Icons.lock_outline_rounded,
                          size: 70,
                          color: Colors.white,
                        ),

                        const SizedBox(height: 15),

                        if(_loadingUsers)

                          const CircularProgressIndicator()

                        else

                          DropdownButtonFormField<Map<String,dynamic>>(

                            value: _selectedUser,

                            dropdownColor: Colors.white,

                            decoration: InputDecoration(

                              filled: true,
                              fillColor: Colors.white,

                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),

                            ),

                            items: _users.map((user){

                              return DropdownMenuItem(

                                value: user,

                                child: Text(user['name']),

                              );

                            }).toList(),

                            onChanged: (v){

                              setState(() {
                                _selectedUser = v;
                              });

                            },

                          ),

                        const SizedBox(height: 20),

                        Text(
                          'Şifrəni daxil edin',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 30),

                        Row(

                          mainAxisAlignment:
                          MainAxisAlignment.center,

                          children: List.generate(
                              _passwordLength, (index) {

                            return Container(

                              margin: const EdgeInsets.symmetric(horizontal: 6),

                              width: 18,
                              height: 18,

                              decoration: BoxDecoration(

                                shape: BoxShape.circle,

                                color: index < _enteredPassword.length
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),

                              ),

                            );

                          }),

                        ),

                        const SizedBox(height: 20),

                        AnimatedOpacity(

                          opacity: _errorMessage != null ? 1.0 : 0.0,

                          duration:
                          const Duration(milliseconds: 300),

                          child: Text(

                            _errorMessage ?? "",

                            style: GoogleFonts.poppins(
                                color: Colors.red[200],
                                fontSize: 14),

                          ),

                        ),

                      ],

                    ),

                  ),

                  _buildNumpad(),

                  const SizedBox(height: 20),

                ],

              ),

            ),

          ),

          if (_isCheckingPassword)

            Container(

              color: Colors.black.withOpacity(0.5),

              child: const Center(

                child: SpinKitFadingCircle(
                  color: Colors.white,
                  size: 50,
                ),

              ),

            ),

        ],

      ),

    );

  }

  Widget _buildNumpad() {

    return Column(

      children: [

        Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumpadButton('1'),
            _buildNumpadButton('2'),
            _buildNumpadButton('3'),
          ],
        ),

        const SizedBox(height: 15),

        Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumpadButton('4'),
            _buildNumpadButton('5'),
            _buildNumpadButton('6'),
          ],
        ),

        const SizedBox(height: 15),

        Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumpadButton('7'),
            _buildNumpadButton('8'),
            _buildNumpadButton('9'),
          ],
        ),

        const SizedBox(height: 15),

        Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceEvenly,
          children: [

            const SizedBox(width:70),

            _buildNumpadButton('0'),

            _buildNumpadButton(
              '',
              icon: Icons.backspace_outlined,
              onPressed: _onBackspacePress,
            ),

          ],

        ),

      ],

    );

  }

  Widget _buildNumpadButton(
      String text,{
        IconData? icon,
        VoidCallback? onPressed,
      }) {

    return SizedBox(

      width: 70,
      height: 70,

      child: Material(

        color: Colors.transparent,

        child: InkWell(

          onTap: onPressed ?? () => _onNumberPress(text),

          borderRadius: BorderRadius.circular(35),

          child: Center(

            child: icon != null
                ? Icon(icon,
                color: Colors.white,
                size: 28)

                : Text(

              text,

              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),

            ),

          ),

        ),

      ),

    );

  }

}