# 🚶‍♂️ 보행자 네비게이션 프로젝트

본 프로젝트는 Flutter 기반 보행자 네비게이션 앱입니다.  
앱 실행을 위해서는 아래 API 키가 필요합니다.

---

## 🔑 필요 API 키
- Firebase API
- Google Maps API
- TMap API

---

## 📂 API 키 설정

### 1. TMap API (`navi_main.dart`)
```dart
class RouteScreenState extends State<RouteScreen> {
  final String apiKey = 'Tmap API'; // <-- 여기에 TMap API 키를 입력하세요
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();
}
```

---

### 2. Google Maps API (star_screen.dart)
```dart
class _PlaceRatingScreenState extends State<PlaceRatingScreen> {
  final String api = 'Google Maps API'; // <-- 여기에 Google Maps API 키를 입력하세요
  final TextEditingController _placeController = TextEditingController();
}
```


---

### 3. Firebase API (firebase_options.dart)
```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_FIREBASE_API_KEY', // <-- Firebase API Key 입력
  appId: 'YOUR_FIREBASE_APP_ID',   // <-- Firebase App ID 입력
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'YOUR_PROJECT_ID',
  storageBucket: 'YOUR_STORAGE_BUCKET',
);

static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'YOUR_FIREBASE_API_KEY', // <-- Firebase API Key 입력
  appId: 'YOUR_FIREBASE_APP_ID',   // <-- Firebase App ID 입력
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'YOUR_PROJECT_ID',
  storageBucket: 'YOUR_STORAGE_BUCKET',
);
```


## 🚀 설치 및 실행

1. Flutter 환경 설정 (>= 3.0)
2. 레포 클론
   ```bash
   git clone https://github.com/사용자/WalkNavi.git
   ```
3. 의존성 설치
   ```bash
   flutter pub get
   ```
4. 본인 API키를 각 파일에 입력
5. 앱 실행
   ```bash
   flutter run
   ```

'''
## 🎬 시연 영상

[사회적 약자 보행자 네비게이션 시연 영상 보기](https://youtu.be/HOOW6AdT450)
