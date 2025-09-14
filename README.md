# 보행자 네비게이션

필요 API키 : Firebase APi, Google Maps ApI, TMap Api 키 필요

navi_main.dart에서 
class RouteScreenState extends State<RouteScreen> {
  final String apiKey = 'Tmap API';
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();

---> Tmap API키를 수정해주세요


star_screen.dart에서
class _PlaceRatingScreenState extends State<PlaceRatingScreen> {
  final String api = 'Google Mpas API';
  final TextEditingController _placeController = TextEditingController();

---> Google Maps API키를 수정해주세요


firebase_options.dart에서
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'Firebase ApiKey',
    appId: 'Firebase AppId',
    messagingSenderId: '228157265795',
    projectId: 'gh-navi',
    storageBucket: 'gh-navi.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'Firebase ApiKey',
    appId: 'Firebase AppId',
    messagingSenderId: '228157265795',
    projectId: 'gh-navi',
    storageBucket: 'gh-navi.appspot.com',
    iosBundleId: 'com.example.ghnavi',
  );
}

---> FIrebase ApiKey 와 AppId를 수정해주세요