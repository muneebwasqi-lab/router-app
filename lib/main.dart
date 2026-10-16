
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

class _LoginPageState extends State<LoginPage> {
  final ip = TextEditingController(text: '192.168.1.1');
  final user = TextEditingController(text: 'admin');
  final pass = TextEditingController();
  String? err;
  bool busy = false;

  Future<void> go() async {
    setState(() { busy = true; err = null; });
    final r = Router(ip.text.trim(), user.text.trim(), pass.text);
    try {
      if (await r.login()) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Home(r)));
        return;
      }
      err = 'Login nakam. Username/password check karein.';
    } catch (e) {
      err = 'Router tak nahi pahunch saka. WiFi se connected hain? ($e)';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Router Login')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: ip, decoration: const InputDecoration(labelText: 'Router IP')),
          TextField(controller: user, decoration: const InputDecoration(labelText: 'Username')),
          TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : go, child: Text(busy ? '...' : 'Login')),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: const TextStyle(color: Colors.red))),
        ]),
      );
}

class Home extends StatefulWidget {
  final Router r;
  const Home(this.r, {super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  @override
  Widget build(BuildContext c) {
    final pages = [WifiTab(widget.r), DevicesTab(widget.r), DebugTab(widget.r)];
    return Scaffold(
      appBar: AppBar(title: const Text('Router Manager'), actions: [
        IconButton(
          icon: const Icon(Icons.restart_alt),
          tooltip: 'Reboot',
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: c,
              builder: (_) => AlertDialog(title: const Text('Router reboot karein?'), actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nahi')),
                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Haan')),
              ]),
            );
            if (ok == true) { try { await widget.r.reboot(); } catch (_) {} }
          },
        ),
      ]),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wifi), label: 'WiFi'),
          NavigationDestination(icon: Icon(Icons.devices), label: 'Devices'),
          NavigationDestination(icon: Icon(Icons.bug_report), label: 'Debug'),
        ],
      ),
    );
  }
}

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

class WifiTab extends StatelessWidget {
  final Router r;
  const WifiTab(this.r, {super.key});
  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.all(12),
        children: [for (final b in Cfg.bands.keys) BandCard(r, b)],
      );
}

class BandCard extends StatefulWidget {
  final Router r;
  final String band;
  const BandCard(this.r, this.band, {super.key});
  @override
  State<BandCard> createState() => _BandCardState();
}

class _BandCardState extends State<BandCard> {
  final ssid = TextEditingController();
  final pw = TextEditingController();
  bool on = true;

  Future<void> run(String ok, Future<void> Function() f) async {
    try { await f(); if (mounted) snack(context, ok); }
    catch (e) { if (mounted) snack(context, 'Error: $e'); }
  }

  @override
  Widget build(BuildContext c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(Cfg.bands[widget.band]!, style: Theme.of(c).textTheme.titleLarge),
            SwitchListTile(
              title: const Text('WiFi on/off'),
              value: on,
              onChanged: (v) {
                setState(() => on = v);
                run(v ? 'WiFi on' : 'WiFi off', () => widget.r.setBasic(widget.band, enabled: v));
              },
            ),
            TextField(controller: ssid, decoration: const InputDecoration(labelText: 'Naya WiFi naam (SSID)')),
            TextButton(
              onPressed: () { if (ssid.text.isNotEmpty) run('Naam change hua', () => widget.r.setBasic(widget.band, ssid: ssid.text)); },
              child: const Text('Naam change karein'),
            ),
            TextField(controller: pw, decoration: const InputDecoration(labelText: 'Naya password (kam az kam 8 characters)')),
            TextButton(
              onPressed: () {
                if (pw.text.length < 8) { snack(c, 'Password kam az kam 8 characters ka ho'); return; }
                run('Password change hua', () => widget.r.setPassword(widget.band, pw.text));
              },
              child: const Text('Password change karein'),
            ),
          ]),
        ),
      );
}

class DevicesTab extends StatefulWidget {
  final Router r;
  const DevicesTab(this.r, {super.key});
  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  final Map<String, List<String>> data = {};
  bool busy = false;

  Future<void> load() async {
    setState(() => busy = true);
    for (final b in Cfg.bands.keys) {
      try { data[b] = await widget.r.clients(b); } catch (_) { data[b] = []; }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void initState() { super.initState(); load(); }

  @override
  Widget build(BuildContext c) => RefreshIndicator(
        onRefresh: load,
        child: ListView(children: [
          if (busy) const LinearProgressIndicator(),
          for (final b in Cfg.bands.keys) ...[
            Padding(padding: const EdgeInsets.all(12), child: Text('${Cfg.bands[b]} devices', style: Theme.of(c).textTheme.titleMedium)),
            if ((data[b] ?? []).isEmpty) const ListTile(title: Text('Koi device nahi')),
            for (final mac in data[b] ?? [])
              ListTile(
                leading: const Icon(Icons.smartphone),
                title: Text(mac),
                trailing: TextButton(
                  onPressed: () async {
                    try { await widget.r.block(b, mac); if (c.mounted) snack(c, 'Block ho gaya'); }
                    catch (e) { if (c.mounted) snack(c, 'Error: $e'); }
                  },
                  child: const Text('Block'),
                ),
              ),
          ],
        ]),
      );
}

class DebugTab extends StatelessWidget {
  final Router r;
  const DebugTab(this.r, {super.key});
  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Agar koi cheez na chale to is screen ka screenshot bhejein.'),
          const Divider(),
          for (final l in r.log.reversed) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l, style: const TextStyle(fontSize: 12))),
        ],
      );
}
