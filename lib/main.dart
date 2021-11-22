import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:magisk_repo/screens/home.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //only portrait
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp],
  );

  MobileAds.instance.initialize();

  OneSignal.shared.setLogLevel(OSLogLevel.verbose, OSLogLevel.none);
  OneSignal.shared.setAppId("48bb2b76-ccaa-4b07-89a8-ebc031ae364c");
  OneSignal.shared
      .promptUserForPushNotificationPermission()
      .then((accepted) {});

  await FlutterDownloader.initialize(
      debug: true // optional: set false to disable printing logs to console
      );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();
}

class _MyAppState extends State<MyApp> {
  int geted = 4;
  ThemeMode _themeMode = ThemeMode.system;

  static createMaterialColor(Color color) {
    List strengths = <double>[.05];
    final swatch = <int, Color>{};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  MaterialColor? primaryColor = createMaterialColor(const Color(0xFF009688));

  Future<void> changeColor(Color wcollor) async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    _prefs.setInt("priColor", wcollor.value);
    setState(() {
      primaryColor = createMaterialColor(wcollor);
    });
  }

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  getState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      if (prefs.getInt('priColor') != null) {
        Color c = Color(prefs.getInt('priColor') ?? 0xFF42A5F5);
        primaryColor = createMaterialColor(c);
      }

      var _darkValue = prefs.getString("darkAmk") ?? "device";
      if (_darkValue == "light") {
        _themeMode = ThemeMode.light;
      } else if (_darkValue == "dark") {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (geted == 4) {
      getState();
      geted = 9;
    }
    final platform = Theme.of(context).platform;

    return MaterialApp(
      title: 'Magic Mask',
      themeMode: _themeMode,
      theme: ThemeData(
        primarySwatch: primaryColor,
        primaryColor: primaryColor,
        backgroundColor: const Color(0xfff3f3f3),
        appBarTheme: const AppBarTheme(
          foregroundColor: Colors.black,
          systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Color(0xfff3f3f3),
              statusBarIconBrightness: Brightness.dark),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: primaryColor,
        primaryColor: primaryColor,
        primaryColorDark: primaryColor,
        brightness: Brightness.dark,
        backgroundColor: const Color(0xff000000),
        appBarTheme: const AppBarTheme(
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Color(0xff000000),
              statusBarIconBrightness: Brightness.light),
        ),
      ),
      home: MyHomePage(title: 'Magic Mask Repo', platform: platform),
      debugShowCheckedModeBanner: false,
    );
  }
}
