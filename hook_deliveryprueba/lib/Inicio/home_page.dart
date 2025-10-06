// lib/Inicio/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Configuraciones/app_localizations.dart';
import '../Configuraciones/settings_controller.dart';
import '../Configuraciones/settings_page.dart';
import '../InicioSesión/login_page.dart';
import '../Pagina/website_page.dart';
import '../Rastreo/tracking_page.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> userInfo;
  const HomePage({super.key, required this.userInfo});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  Map<String, dynamic> get personal => widget.userInfo['personalInfo'][0];

  // ---------- PERFIL ----------
  Widget _buildProfileScreen(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final lang = settings.language;
    final isDark = settings.theme == AppTheme.blueDark;
    final mainColor = isDark
        ? const Color(0xFF29B6F6)
        : const Color(0xFFF20A32);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 4,
          color: isDark ? Colors.grey[900] : const Color(0xfff8f4fa),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            leading: Icon(Icons.person, size: 30, color: mainColor),
            title: Text(
              AppLocalizations.t('full_name', lang),
              style: TextStyle(fontWeight: FontWeight.bold, color: mainColor),
            ),
            subtitle: Text(
              personal['r_user_name'] ??
                  (lang == AppLanguage.es ? 'No disponible' : 'Not available'),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 4,
          color: isDark ? Colors.grey[900] : const Color(0xfff8f4fa),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            leading: Icon(Icons.work, size: 30, color: mainColor),
            title: Text(
              AppLocalizations.t('role', lang),
              style: TextStyle(fontWeight: FontWeight.bold, color: mainColor),
            ),
            subtitle: Text(
              personal['r_name_role'] ??
                  (lang == AppLanguage.es ? 'No disponible' : 'Not available'),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 4,
          color: isDark ? Colors.grey[900] : const Color(0xfff8f4fa),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            leading: Icon(Icons.business, size: 30, color: mainColor),
            title: Text(
              AppLocalizations.t('office', lang),
              style: TextStyle(fontWeight: FontWeight.bold, color: mainColor),
            ),
            subtitle: Text(
              personal['r_name_office'] ??
                  (lang == AppLanguage.es ? 'No disponible' : 'Not available'),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 4,
          color: isDark ? Colors.grey[900] : const Color(0xfff8f4fa),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            leading: Icon(Icons.badge, size: 30, color: mainColor),
            title: Text(
              AppLocalizations.t('operator', lang),
              style: TextStyle(fontWeight: FontWeight.bold, color: mainColor),
            ),
            subtitle: Text(
              personal['r_operator'] ??
                  (lang == AppLanguage.es ? 'No disponible' : 'Not available'),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(color: mainColor, width: 2),
              ),
            ),
            onPressed: () => _confirmLogout(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: mainColor),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.t('logout', lang),
                  style: TextStyle(
                    fontSize: 16,
                    color: mainColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final lang = context.read<SettingsController>().language;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.t('logout', lang)),
          content: Text(
            lang == AppLanguage.es
                ? '¿Volver a iniciar sesión?'
                : 'Do you want to login again?',
          ),
          actions: <Widget>[
            TextButton(
              child: Text(lang == AppLanguage.es ? 'No' : 'No'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(lang == AppLanguage.es ? 'Sí' : 'Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                _logout(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('email');
    await prefs.remove('password');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isDark = settings.theme == AppTheme.blueDark;
    final lang = settings.language;
    final mainColor = isDark
        ? const Color(0xFF29B6F6)
        : const Color(0xFFF20A32);

    final screens = [
      _buildProfileScreen(context),
      const SettingsPage(),
      const WebsitePage(),
      TrackShipmentPage(
        userInfo: widget.userInfo,
      ), // <-- antes: const TrackShipmentPage()
    ];

    final titles = [
      lang == AppLanguage.es ? 'Perfil' : 'Profile',
      lang == AppLanguage.es ? 'Configuración' : 'Settings',
      lang == AppLanguage.es ? 'Sitio Web' : 'Website',
      lang == AppLanguage.es ? 'Rastrear Envío' : 'Track Shipment',
    ];

    final drawerOptions = [
      {
        'label': lang == AppLanguage.es ? 'Perfil' : 'Profile',
        'index': 0,
        'icon': Icons.person,
      },
      {
        'label': lang == AppLanguage.es ? 'Config.' : 'Settings',
        'index': 1,
        'icon': Icons.settings,
      },
      {
        'label': lang == AppLanguage.es ? 'Sitio Web' : 'Website',
        'index': 2,
        'icon': Icons.language,
      },
      {
        'label': lang == AppLanguage.es ? 'Rastreo' : 'Tracking',
        'index': 3,
        'icon': Icons.local_shipping,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex], style: TextStyle(color: mainColor)),
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: mainColor,
        elevation: 0,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: mainColor),
              child: const Center(
                child: Text(
                  'assets/logo.png',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ...drawerOptions
                .where((opt) => opt['index'] != _currentIndex)
                .map(
                  (opt) => ListTile(
                    leading: Icon(opt['icon'] as IconData, color: mainColor),
                    title: Text(opt['label'] as String),
                    onTap: () {
                      setState(() => _currentIndex = opt['index'] as int);
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ],
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        height: 65,
        selectedIndex: _currentIndex,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        animationDuration: const Duration(milliseconds: 300),
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.person, color: mainColor),
            label: lang == AppLanguage.es ? 'Perfil' : 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings, color: mainColor),
            label: lang == AppLanguage.es ? 'Config.' : 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.language, color: mainColor),
            label: lang == AppLanguage.es ? 'Sitio Web' : 'Website',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping, color: mainColor),
            label: lang == AppLanguage.es ? 'Rastreo' : 'Tracking',
          ),
        ],
      ),
    );
  }
}
