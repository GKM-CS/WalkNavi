import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../providers/login_provider.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  _SuccessScreenState createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation; // 초기 위치를 null로 설정
  bool _isLoading = true; // 로딩 상태를 추가
  final Set<Marker> _markers = {}; // 마커를 저장할 Set
  BitmapDescriptor? _currentLocationIcon; // 현재 위치 마커 아이콘
  BitmapDescriptor? _highRatingIcon; // 높은 평점 마커 아이콘
  BitmapDescriptor? _lowRatingIcon; // 낮은 평점 마커 아이콘
  BitmapDescriptor? _liveIssueIcon; // 라이브 이슈 마커 아이콘

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _setCustomMarkerIcons();
    _getCurrentLocation();
    _startLocationUpdates();
    _loadRatedPlaces(); // 평점이 있는 장소를 로드
    _loadLiveIssues(); // 라이브 이슈를 로드
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
  }

  Future<void> _setCustomMarkerIcons() async {
    _currentLocationIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/current_location_icon.png', // 현재 위치 아이콘 이미지 경로
    );
    _highRatingIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/high_rating_icon.png', // 높은 평점 아이콘 이미지 경로
    );
    _lowRatingIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/low_rating_icon.png', // 낮은 평점 아이콘 이미지 경로
    );
    _liveIssueIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/live_issue_icon.png', // 라이브 이슈 아이콘 이미지 경로
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스가 활성화되어 있는지 확인합니다.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 위치 서비스가 활성화되지 않은 경우 사용자에게 알립니다.
      _showError('Location services are disabled.');
      return;
    }

    // 위치 권한을 확인하고 요청합니다.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // 위치 권한이 거부된 경우 사용자에게 알립니다.
        _showError('Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // 위치 권한이 영구적으로 거부된 경우 사용자에게 알립니다.
      _showError('Location permissions are permanently denied.');
      return;
    }

    // 현재 위치를 가져옵니다.
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _isLoading = false; // 로딩 상태를 false로 설정
      _markers.add(Marker(
        markerId: MarkerId('currentLocation'),
        position: _currentLocation!,
        icon: _currentLocationIcon ??
            BitmapDescriptor.defaultMarker, // 현재 위치 아이콘 설정
        infoWindow: InfoWindow(title: '현재 위치'),
      ));
      _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 17)); // 배율을 17로 설정
    });
  }

  void _startLocationUpdates() {
    Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _markers.add(Marker(
          markerId: MarkerId('currentLocation'),
          position: _currentLocation!,
          icon: _currentLocationIcon ??
              BitmapDescriptor.defaultMarker, // 현재 위치 아이콘 설정
          infoWindow: InfoWindow(title: '현재 위치'),
        ));
        _mapController
            ?.animateCamera(CameraUpdate.newLatLng(_currentLocation!));
      });
    });
  }

  Future<void> _loadRatedPlaces() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('places')
        .where('ratings', isNotEqualTo: {}).get();

    setState(() {
      for (var doc in querySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        var location = data['location'] as GeoPoint;
        var averageRating = data['averageRating'] as double;
        BitmapDescriptor? markerIcon;
        if (averageRating >= 3.5) {
          markerIcon = _highRatingIcon;
        } else if (averageRating <= 3.0) {
          markerIcon = _lowRatingIcon;
        } else {
          markerIcon = BitmapDescriptor.defaultMarker;
        }
        var marker = Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(location.latitude, location.longitude),
          icon: markerIcon ?? BitmapDescriptor.defaultMarker, // 평점에 따른 아이콘 설정
          infoWindow: InfoWindow(
            title: data['name'],
            snippet: '평균 별점: $averageRating',
          ),
        );
        _markers.add(marker);
      }
    });
  }

  Future<void> _loadLiveIssues() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('issues').get();
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final GeoPoint location = data['location'];
        final String imageUrl = data['imageUrl'];
        final String comment = data['comment'];

        setState(() {
          _markers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(location.latitude, location.longitude),
              icon: _liveIssueIcon ?? BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(
                title: comment,
                snippet: '이미지를 보려면 클릭하세요',
                onTap: () {
                  _showImageDialog(imageUrl, comment);
                },
              ),
            ),
          );
        });
      }
    } catch (e) {
      _showError('라이브 이슈를 불러오지 못했습니다: $e');
    }
  }

  void _showImageDialog(String imageUrl, String comment) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(imageUrl),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(comment),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('닫기'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ModalRoute.of(context)?.settings.arguments as User?;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('오류'),
        ),
        body: const Center(
          child: Text('사용자 정보를 불러올 수 없습니다.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('굿핸드'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case '내비게이션':
                  Navigator.pushNamed(context, '/navi');
                  break;
                case '장소 별점 주기':
                  Navigator.pushNamed(context, '/star');
                  break;
                case '경로 별점 주기':
                  Navigator.pushNamed(context, '/routestar');
                  break;
                case '실시간 이슈':
                  Navigator.pushNamed(context, '/liveissue');
                  break;
                case '로그아웃':
                  Provider.of<LoginProvider>(context, listen: false).signOut();
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return {'내비게이션', '장소 별점 주기', '경로 별점 주기', '실시간 이슈', '로그아웃'}
                  .map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 화면의 제목
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '로그인 성공! \n${user.displayName} 님 환영합니다.',
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ),
          // Google Map 추가
          Expanded(
            flex: 9, // 화면의 90%를 차지하도록 설정
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator()) // 로딩 중일 때 로딩 표시
                : GoogleMap(
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (_currentLocation != null) {
                        _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                                _currentLocation!, 17)); // 배율을 17로 설정
                      }
                    },
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation ?? LatLng(0, 0), // 초기 위치 설정
                      zoom: 17, // 배율을 17로 설정
                    ),
                    markers: _markers, // 마커 추가
                  ),
          ),
        ],
      ),
    );
  }
}
