import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Api {
  final String ip, user, pass;
  Api(this.ip, this.user, this.pass);
  Map<String, String> get _h =>
      {'Authorization': 'Basic ${base64Encode(utf8.encode('$user:$pass'))}'};
  Future<String> _get(String p) async {
    final r = await http.get(Uri.parse('http://$ip$p'), headers: _h)
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
    return r.body;
  }
  Future<bool> login() async => !(await _get('/home.htm')).contains('wizard_new');
  Future<List<String>> clients() async {
    final h = await _get('/wlstatbl.htm?wlan_id=0');
    return RegExp(r'(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}')
        .allMatches(h).map((m) => m.group(0)!.toLowerCase()).toSet().toList();
  }
}

void soon(BuildContext c) => ScaffoldMessenger.of(c).showSnackBar(
    const SnackBar(content: Text('Yeh button agla version mein chalega')));

void main() => runApp(MaterialApp(
      title: 'Mera Router',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
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
  bool busy = false, hide = true;
  String? err;

  Future<void> go() async {
    setState(() { busy = true; err = null; });
    final api = Api(ip.text.trim(), user.text.trim(), pass.text);
    try {
      if (await api.login()) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Home(api)));
        return;
      }
      err = 'Login nakam. Username/password check karein.';
    } catch (e) {
      err = 'Router tak nahi pahunch saka. Ghar ke WiFi se connected hain?';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: const Color(0xFFE6F4F1),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 30),
            const Icon(Icons.router, size: 80, color: Colors.teal),
            const Text('Mera Router', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const Text('Sirf ghar ka WiFi / LAN control', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  TextField(controller: ip, decoration: const InputDecoration(
                      labelText: 'Router IP', prefixIcon: Icon(Icons.router))),
                  TextField(controller: user, decoration: const InputDecoration(
                      labelText: 'Username', prefixIcon: Icon(Icons.person))),
                  TextField(
                    controller: pass, obscureText: hide,
                    decoration: InputDecoration(
                      labelText: 'Password', prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                          icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => hide = !hide)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : go,
                child: Padding(padding: const EdgeInsets.all(12),
                    child: Text(busy ? 'Connect ho raha hai...' : 'Login'))),
            if (err != null)
              Padding(padding: const EdgeInsets.only(top: 12),
                  child: Text(err!, style: const TextStyle(color: Colors.red))),
          ]),
        ),
      );
}

class Home extends StatefulWidget {
  final Api api;
  const Home(this.api, {super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  List<String> macs = [];
  bool busy = true;

  Future<void> load() async {
    setState(() => busy = true);
    try { macs = await widget.api.clients(); } catch (_) {}
    if (mounted) setState(() => busy = false);
  }

  @override
  void initState() { super.initState(); load(); }

  @override
  Widget build(BuildContext c) {
    const titles = ['Dashboard', 'Connected Devices', 'Wi-Fi Settings'];
    final pages = [Dash(macs.length, busy), DevicesTab(macs), const WifiTab()];
    return Scaffold(
      appBar: AppBar(title: Text(titles[tab]),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: load)]),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.devices), label: 'Devices'),
          NavigationDestination(icon: Icon(Icons.wifi), label: 'Wi-Fi'),
        ],
      ),
    );
  }
}

class Dash extends StatelessWidget {
  final int n;
  final bool busy;
  const Dash(this.n, this.busy, {super.key});
  @override
  Widget build(BuildContext c) {
    final tiles = [
      [Icons.public, 'WAN Status', 'Connection info'],
      [Icons.devices, 'Devices', '$n connected'],
      [Icons.wifi, 'Wi-Fi', 'Naam aur password'],
      [Icons.pie_chart, 'Usage', 'Traffic statistics'],
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0F9D58), Color(0xFF34D399)]),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('DIR-803', style: TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            Chip(label: Text(busy ? '...' : 'ONLINE')),
          ]),
          const Align(alignment: Alignment.centerLeft,
              child: Text('192.168.1.1', style: TextStyle(color: Colors.white70))),
          const SizedBox(height: 16),
          const Icon(Icons.router, size: 90, color: Colors.white),
          const SizedBox(height: 12),
          Text('$n devices', style: const TextStyle(color: Colors.white, fontSize: 18)),
        ]),
      ),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.5, crossAxisSpacing: 12, mainAxisSpacing: 12,
        children: [
          for (final t in tiles)
            InkWell(
              onTap: () => soon(c),
              child: Card(child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t[0] as IconData),
                    Text(t[1] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(t[2] as String, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )),
            ),
        ],
      ),
    ]);
  }
}

class DevicesTab extends StatelessWidget {
  final List<String> macs;
  const DevicesTab(this.macs, {super.key});
  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: Card(child: ListTile(
              leading: const Icon(Icons.devices, color: Colors.teal),
              title: Text('${macs.length}'), subtitle: const Text('Connected')))),
          const Expanded(child: Card(child: ListTile(
              leading: Icon(Icons.block, color: Colors.red),
              title: Text('0'), subtitle: Text('Blocked')))),
        ]),
        Card(
          color: const Color(0xFFD7F0EA),
          child: const Padding(padding: EdgeInsets.all(12),
              child: Text('Block buttons agle version mein kaam karenge.')),
        ),
        for (final m in macs)
          Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.wifi, color: Colors.deepPurple),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Device', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(m, style: const TextStyle(fontFamily: 'monospace')),
                ])),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: FilledButton.tonal(
                    style: FilledButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => soon(c), child: const Text('Block 2.4G'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.tonal(
                    style: FilledButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => soon(c), child: const Text('Block 5G'))),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: FilledButton.tonal(
                  style: FilledButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => soon(c), child: const Text('Block Internet'))),
            ]),
          )),
      ]);
}

class WifiTab extends StatefulWidget {
  const WifiTab({super.key});
  @override
  State<WifiTab> createState() => _WifiTabState();
}

class _WifiTabState extends State<WifiTab> {
  String band = '2.4GHz';
  bool enable = true, hideSsid = false, obscure = true;

  Widget field(String label) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder())),
      );

  Widget save(BuildContext c) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: FilledButton(onPressed: () => soon(c),
            child: const Padding(padding: EdgeInsets.all(12), child: Text('Save'))),
      );

  @override
  Widget build(BuildContext c) => DefaultTabController(
        length: 3,
        child: Column(children: [
          const TabBar(tabs: [Tab(text: 'SSID'), Tab(text: 'Security'), Tab(text: 'Guest')]),
          Expanded(child: TabBarView(children: [
            ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<String>(
                value: band,
                decoration: const InputDecoration(
                    labelText: 'Choose SSID', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: '2.4GHz', child: Text('2.4GHz')),
                  DropdownMenuItem(value: '5GHz', child: Text('5GHz')),
                ],
                onChanged: (v) => setState(() => band = v!),
              ),
              SwitchListTile(title: const Text('SSID Enable'), value: enable,
                  onChanged: (v) => setState(() => enable = v)),
              SwitchListTile(title: const Text('Broadcast band karein'), value: !hideSsid,
                  onChanged: (v) => setState(() => hideSsid = !v)),
              field('SSID Name'),
              save(c),
            ]),
            ListView(padding: const EdgeInsets.all(16), children: [
              TextField(
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi Password', border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => obscure = !obscure)),
                ),
              ),
              save(c),
            ]),
            ListView(padding: const EdgeInsets.all(16), children: [
              field('Guest Network Name (SSID)'),
              field('Guest Password'),
              save(c),
            ]),
          ])),
        ]),
      );
}
