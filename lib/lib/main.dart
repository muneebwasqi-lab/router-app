import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ================= CONFIG: agar kuch na chale to sirf yahan badlein =================
class Cfg {
  static const bands = {'wlan1': '5GHz', 'wlan2': '2.4GHz'};
  static const idx = {'wlan1': '0', 'wlan2': '1'}; // wlan index
  static const basicForm = '/boafrm/formWlanSetup';
  static const secForm = '/boafrm/formWlEncrypt';
  static const aclForm = '/boafrm/formWlAc';
  static const rebootForm = '/boafrm/formReboot';
  static const clientsPage = '/wlstatbl.htm';
}
// ====================================================================================

class Router {
  final String ip, user, pass;
  final List<String> log = [];
  Router(this.ip, this.user, this.pass);

  Map<String, String> get _h => {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$user:$pass'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': 'http://$ip/home.htm',
      };

  Future<String> get(String path) async {
    final r = await http.get(Uri.parse('http://$ip$path'), headers: _h)
        .timeout(const Duration(seconds: 8));
    log.add('GET $path -> ${r.statusCode}');
    return r.body;
  }

  Future<String> post(String path, Map<String, String> f) async {
    final r = await http.post(Uri.parse('http://$ip$path'), headers: _h, body: f)
        .timeout(const Duration(seconds: 8));
    log.add('POST $path ${f.keys.join(",")} -> ${r.statusCode}\n'
        '${r.body.length > 300 ? r.body.substring(0, 300) : r.body}');
    return r.body;
  }

  Future<bool> login() async {
    final r = await http.get(Uri.parse('http://$ip/home.htm'), headers: _h)
        .timeout(const Duration(seconds: 8));
    log.add('LOGIN home.htm -> ${r.statusCode}');
    return r.statusCode == 200 && !r.body.contains('wizard_new');
  }

  Future<void> setBasic(String b, {String? ssid, bool? enabled}) => post(Cfg.basicForm, {
        'wlan_id': Cfg.idx[b]!,
        if (enabled != null) 'wlanDisabled': enabled ? 'OFF' : 'ON',
        if (ssid != null) 'ssid': ssid,
        'submit-url': '/wlbasic.htm',
        'save': 'Apply Changes',
      });

  Future<void> setPassword(String b, String key) => post(Cfg.secForm, {
        'wlan_id': Cfg.idx[b]!,
        'method': '6', // WPA2
        'wpaAuth': 'psk',
        'ciphersuite': 'aes',
        'wpa2ciphersuite': 'aes',
        'pskFormat': '0',
        'pskValue': key,
        'submit-url': '/wlwpa.htm',
        'save': 'Apply Changes',
      });

  Future<List<String>> clients(String b) async {
    final html = await get('${Cfg.clientsPage}?wlan_id=${Cfg.idx[b]}');
    final m = RegExp(r'([0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5})').allMatches(html);
    return m.map((e) => e.group(1)!.toLowerCase()).toSet().toList();
  }

  Future<void> block(String b, String mac) => post(Cfg.aclForm, {
        'wlan_id': Cfg.idx[b]!,
        'wlanAcEnabled': '2', // Deny Listed
        'mac': mac.replaceAll(':', ''),
        'comment': 'blocked by app',
        'addFilterMac': 'Apply Changes',
        'submit-url': '/wlactrl.htm',
      });

  Future<void> reboot() => post(Cfg.rebootForm, {'save': 'Reboot', 'submit-url': '/reboot.htm'});
}

void main() => runApp(MaterialApp(
      title: 'Router Manager',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const LoginPage(),
    ));

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State
