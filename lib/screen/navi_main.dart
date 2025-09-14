import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

class RoadRating {
  final LatLng start;
  final LatLng end;
  final double rating;

  RoadRating({required this.start, required this.end, required this.rating});
}

Future<List<RoadRating>> fetchRoadRatings() async {
  final snapshot =
      await FirebaseFirestore.instance.collection('road_ratings').get();
  return snapshot.docs.map((doc) {
    final data = doc.data();
    final start = data['start'] as GeoPoint;
    final end = data['end'] as GeoPoint;
    return RoadRating(
      start: LatLng(start.latitude, start.longitude),
      end: LatLng(end.latitude, end.longitude),
      rating: data['rating'],
    );
  }).toList();
}

double calculateRouteWeight(
    LatLng point1, LatLng point2, List<RoadRating> ratings) {
  double distance = calculateDistance(point1, point2);
  double ratingWeight = 1.0;

  // 해당 구간의 별점 찾기
  for (var rating in ratings) {
    if ((rating.start.latitude == point1.latitude &&
            rating.start.longitude == point1.longitude &&
            rating.end.latitude == point2.latitude &&
            rating.end.longitude == point2.longitude) ||
        (rating.start.latitude == point2.latitude &&
            rating.start.longitude == point2.longitude &&
            rating.end.latitude == point1.latitude &&
            rating.end.longitude == point1.longitude)) {
      // 별점이 낮을수록 가중치 증가 (5점 만점 기준)
      ratingWeight = 6 - rating.rating;
      break;
    }
  }

  return distance * ratingWeight;
}

double calculateDistance(LatLng p1, LatLng p2) {
  const earthRadius = 6371;
  double dLat = (p2.latitude - p1.latitude) * (pi / 180);
  double dLon = (p2.longitude - p1.longitude) * (pi / 180);

  double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(p1.latitude * (pi / 180)) *
          cos(p2.latitude * (pi / 180)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '보행자 별점 네비게이션',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('보행자 별점 네비게이션'),
        ),
        body: const RouteScreen(),
      ),
    );
  }
}

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  RouteScreenState createState() => RouteScreenState();
}

class RouteScreenState extends State<RouteScreen> {
  final String apiKey = 'QsBisAwDFZ4jmI9bOVRSm6tP0M8NZfJg7cK2eON3';
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();

  GoogleMapController? _mapController;
  StreamSubscription<Position>? positionStream;

  bool isFetchingCoordinates = false;
  bool isFetchingRoute = false;
  bool isFetchingPlaces = false;

  List<String> routeDescriptions = [];
  List<LatLng> routePoints = [];
  Set<Polyline> polylines = {};
  Set<Marker> markers = {}; // 마커를 저장할 Set
  String routeDescription = '';

  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;
  BitmapDescriptor? _currentLocationIcon;

  @override
  void initState() {
    super.initState();
    _setCustomMarkerIcon();
    _initializeLocation();
  }

  Future<void> _setCustomMarkerIcon() async {
    _currentLocationIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/current_location_icon.png',
    );
  }

  void _initializeLocation() async {
    await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: _currentLocation!,
          icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(title: '현재 위치'),
        ),
      );
    });
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    _positionStream = Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        
        // 현재 위치 마커 업데이트
        markers.removeWhere((marker) => marker.markerId.value == 'currentLocation');
        markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: _currentLocation!,
            icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: const InfoWindow(title: '현재 위치'),
          ),
        );

        // 경로 추적 및 업데이트
        if (routePoints.isNotEmpty) {
          int nearestIndex = _findNearestPointIndex(position);
          if (nearestIndex > 0) {
            // 지나온 경로 제거
            routePoints = routePoints.sublist(nearestIndex);
            
            // 폴리라인 업데이트
            polylines.clear();
            if (routePoints.length > 1) {
              polylines.add(Polyline(
                polylineId: const PolylineId('route'),
                points: routePoints,
                color: Colors.blue,
                width: 5,
              ));
            }
            
            // 경로 설명 업데이트
            routeDescriptions = routeDescriptions.sublist(nearestIndex);
            routeDescription = routeDescriptions.join('\n');
          }
        }
      });
    });
  }

  int _findNearestPointIndex(Position position) {
    if (routePoints.isEmpty) return -1;
    
    int nearestIndex = 0;
    double minDistance = double.infinity;
    
    for (int i = 0; i < routePoints.length; i++) {
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        routePoints[i].latitude,
        routePoints[i].longitude,
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }
    
    // 5미터 이내에 있을 때만 해당 포인트를 지난 것으로 간주
    return minDistance < 5 ? nearestIndex : -1;
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    startController.dispose();
    endController.dispose();
    super.dispose();
  }

  void _trackUserLocation() {
    positionStream = Geolocator.getPositionStream().listen((Position position) {
      LatLng userPosition = LatLng(position.latitude, position.longitude);
      updateRemainingRouteDescription(userPosition);
      setState(() {
        _mapController?.animateCamera(CameraUpdate.newLatLng(userPosition));
      });
    });
  }

  void updateRemainingRouteDescription(LatLng userPosition) {
    routeDescriptions = routeDescriptions.skipWhile((description) {
      final index = routeDescriptions.indexOf(description);
      if (index < routePoints.length) {
        final distance = calculateDistance(userPosition, routePoints[index]);
        return distance < 0.05;
      }
      return false;
    }).toList();

    setState(() {
      routeDescription = routeDescriptions.join("\n");
    });
  }

  Future<void> fetchCoordinatesAndRoute() async {
    if (startController.text.isEmpty || endController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출발지와 목적지 주소를 입력해주세요.')),
      );
      return;
    }

    try {
      setState(() {
        isFetchingCoordinates = true;
      });

      final start = await fetchCoordinates(startController.text);
      final end = await fetchCoordinates(endController.text);

      setState(() {
        isFetchingCoordinates = false;
        isFetchingPlaces = true;
      });

      // 회피할 장소 가져오기
      final avoidedPlaces = await fetchAvoidedPlaces();
      final waypoints = await fetchRatedPlaces();

      setState(() {
        isFetchingPlaces = false;
        isFetchingRoute = true;
      });

      if (start != null && end != null) {
        List<LatLng> filteredWaypoints =
            await filterWaypoints(start, end, waypoints, 1.2, 4.0);

        // 회피할 장소 필터링
        filteredWaypoints.removeWhere((waypoint) => avoidedPlaces.any(
            (avoided) =>
                waypoint.latitude == avoided.latitude &&
                waypoint.longitude == avoided.longitude));

        List<LatLng> fullRoute;
        if (filteredWaypoints.isEmpty) {
          fullRoute = [start, end];
        } else {
          List<LatLng> optimalRoute = findOptimalRoute(filteredWaypoints);
          fullRoute = [start, ...optimalRoute, end];
        }

        updateRoute(fullRoute, 'mainRoute');
        await fetchRoute(fullRoute);

        // 시작점과 도착점에 마커 추가
        setState(() {
          markers.add(Marker(
            markerId: MarkerId('start'),
            position: start,
            infoWindow: InfoWindow(title: 'Start Point'),
          ));
          markers.add(Marker(
            markerId: MarkerId('end'),
            position: end,
            infoWindow: InfoWindow(title: 'End Point'),
          ));
        });
      }
    } catch (error) {
      print('Error fetching route: $error');
    } finally {
      setState(() {
        isFetchingRoute = false;
      });
    }
  }

  Future<LatLng?> fetchCoordinates(String address) async {
    final url = Uri.parse(
      'https://apis.openapi.sk.com/tmap/geo/fullAddrGeo?version=1&format=json&appKey=$apiKey&fullAddr=$address',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coordinate = data['coordinateInfo']['coordinate'][0];
        return LatLng(
            double.parse(coordinate['lat']), double.parse(coordinate['lon']));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소를 통해 좌표 가져오는 데 실패했습니다. 다시 시도해주세요.')),
      );
    }
    return null;
  }

  Future<void> fetchRoute(List<LatLng> waypoints) async {
    try {
      final url = Uri.parse(
          'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&format=json&appKey=$apiKey');

      final body = {
        "startX": waypoints.first.longitude.toString(),
        "startY": waypoints.first.latitude.toString(),
        "endX": waypoints.last.longitude.toString(),
        "endY": waypoints.last.latitude.toString(),
        "reqCoordType": "WGS84GEO",
        "resCoordType": "WGS84GEO",
        "startName": "출발지",
        "endName": "도착지",
      };

      if (waypoints.length > 2) {
        body["passList"] = waypoints
            .sublist(1, waypoints.length - 1)
            .map((point) => "${point.longitude},${point.latitude}")
            .join('_');
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<LatLng> routePoints = [];
        List<String> descriptions = []; // 경로 설명을 저장할 리스트

        for (var feature in data['features']) {
          if (feature['geometry']['type'] == 'LineString') {
            var coordinates = feature['geometry']['coordinates'] as List;
            for (var coord in coordinates) {
              // T-map API는 [경도, 위도] 순서로 반환하므로 순서를 바꿔서 저장
              routePoints.add(LatLng(
                  (coord[1] as num).toDouble(), (coord[0] as num).toDouble()));
            }
          }

          // 경로 설명 추출
          if (feature['properties'] != null &&
              feature['properties']['description'] != null) {
            String description = feature['properties']['description'];
            // 불필요한 HTML 태그 제거
            description = description.replaceAll(RegExp(r'<[^>]*>'), '');
            descriptions.add(description);
          }
        }

        setState(() {
          polylines.clear();
          polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: routePoints,
            color: Colors.blue,
            width: 5,
          ));

          // 마커 업데이트
          markers.clear();
          
          // 시작점 마커
          markers.add(Marker(
            markerId: const MarkerId('start'),
            position: waypoints.first,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ));
          
          // 도착점 마커
          markers.add(Marker(
            markerId: const MarkerId('end'),
            position: waypoints.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ));
          
          // 현재 위치 마커 유지
          if (_currentLocation != null) {
            markers.add(Marker(
              markerId: const MarkerId('currentLocation'),
              position: _currentLocation!,
              icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarker,
              infoWindow: const InfoWindow(title: '현재 위치'),
            ));
          }

          // 경로 정보 업데이트
          routeDescription = descriptions.join('\n');
          routeDescriptions = descriptions;
          this.routePoints = routePoints;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('경로를 가져오는 중 오류가 발생했습다: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<List<LatLng>> fetchRatedPlaces() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final snapshot =
        await FirebaseFirestore.instance.collection('places').get();

    return snapshot.docs.map((doc) {
      final location = doc['location'] as GeoPoint;
      return LatLng(location.latitude, location.longitude);
    }).toList();
  }

  Future<List<LatLng>> fetchAvoidedPlaces() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('issues') // 회피할 장소를 저장한 컬렉
        .get();

    return snapshot.docs.map((doc) {
      final location = doc['location'] as GeoPoint;
      return LatLng(location.latitude, location.longitude);
    }).toList();
  }

  Future<List<LatLng>> filterWaypoints(LatLng start, LatLng end,
      List<LatLng> waypoints, double maxMultiplier, double minRating) async {
    double shortestDistance = calculateDistance(start, end);
    double maxDistance = shortestDistance * maxMultiplier;

    List<LatLng> filteredWaypoints = [];

    for (var waypoint in waypoints) {
      final snapshot = await FirebaseFirestore.instance
          .collection('places')
          .where('location',
              isEqualTo: GeoPoint(waypoint.latitude, waypoint.longitude))
          .get();

      double averageRating = 0.0;
      for (var doc in snapshot.docs) {
        averageRating = doc['averageRating'] ?? 0.0;
      }

      if (averageRating < minRating) continue;

      double routeDistance =
          calculateDistance(start, waypoint) + calculateDistance(waypoint, end);
      if (routeDistance <= maxDistance) {
        filteredWaypoints.add(waypoint);
      }
    }

    return filteredWaypoints;
  }

  // TSP 알고즘 개선된 함수들
  List<LatLng> findOptimalRoute(List<LatLng> waypoints) {
    if (waypoints.isEmpty) return [];

    List<LatLng> initialRoute = findNearestNeighborRoute(List.from(waypoints));
    List<LatLng> optimizedRoute = twoOpt(initialRoute);

    return optimizedRoute;
  }

  List<LatLng> findNearestNeighborRoute(List<LatLng> waypoints) {
    if (waypoints.isEmpty) return [];

    List<LatLng> route = [waypoints.removeAt(0)];
    while (waypoints.isNotEmpty) {
      LatLng last = route.last;
      LatLng next = waypoints.reduce((a, b) =>
          calculateDistance(last, a) < calculateDistance(last, b) ? a : b);
      waypoints.remove(next);
      route.add(next);
    }
    return route;
  }

  List<LatLng> twoOpt(List<LatLng> route) {
    bool improved = true;
    while (improved) {
      improved = false;
      for (int i = 1; i < route.length - 2; i++) {
        for (int j = i + 1; j < route.length - 1; j++) {
          double d1 = calculateDistance(route[i - 1], route[i]) +
              calculateDistance(route[j], route[j + 1]);
          double d2 = calculateDistance(route[i - 1], route[j]) +
              calculateDistance(route[i], route[j + 1]);
          if (d2 < d1) {
            List<LatLng> newRoute = List<LatLng>.from(route);
            newRoute.setRange(i, j + 1, route.sublist(i, j + 1).reversed);
            route = newRoute;
            improved = true;
          }
        }
      }
    }
    return route;
  }

  void updateRoute(List<LatLng> newRoute, String routeId) {
    setState(() {
      polylines.removeWhere((polyline) => polyline.polylineId.value == routeId);
      polylines.add(Polyline(
        polylineId: PolylineId(routeId),
        points: newRoute,
        color: Colors.blue,
        width: 5,
      ));
    });
  }

  Future<List<LatLng>> findBetterRoute(
      LatLng start, LatLng end, List<RoadRating> ratings) async {
    // 직선 거리의 1.5배 이내에 있는 높은 평점의 도로 구간 찾기
    double directDistance = calculateDistance(start, end);
    double maxAllowedDistance = directDistance * 1.5;

    List<LatLng> betterRoute = [start];

    // 높은 평점(4.0 이상)의 도로 구간 찾기
    List<RoadRating> goodRatings = ratings
        .where((r) =>
            r.rating >= 4.0 &&
            calculateRouteWeight(start, r.start, ratings) +
                    calculateRouteWeight(r.end, end, ratings) <=
                maxAllowedDistance)
        .toList();

    if (goodRatings.isNotEmpty) {
      // 가장 좋은 평점의 도로 구간을 경유지로 추가
      RoadRating bestRating =
          goodRatings.reduce((a, b) => a.rating > b.rating ? a : b);
      betterRoute.add(bestRating.start);
      betterRoute.add(bestRating.end);
    }

    betterRoute.add(end);
    return betterRoute;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('경로 안내'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 400,
              child: GoogleMap(
                onMapCreated: (controller) => _mapController = controller,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
                initialCameraPosition: CameraPosition(
                  target: LatLng(0, 0), // 초기 위치는 임시로 설정
                  zoom: 14,
                ),
                polylines: polylines,
                markers: markers, // 마커 추가
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: startController,
              decoration: const InputDecoration(
                labelText: '출발지 주소를 입력하세요',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: endController,
              decoration: const InputDecoration(
                labelText: '목적지 주소를 입력하세요',
                prefixIcon: Icon(Icons.flag),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isFetchingCoordinates ||
                        isFetchingRoute ||
                        isFetchingPlaces)
                    ? null
                    : fetchCoordinatesAndRoute,
                child: (isFetchingCoordinates ||
                        isFetchingRoute ||
                        isFetchingPlaces)
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(width: 12),
                          Text('경로를 찾는 중입니다...'),
                        ],
                      )
                    : const Text('경로 탐색'),
              ),
            ),
            const SizedBox(height: 20),
            if (routeDescription.isNotEmpty)
              Card(
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '경로 설명:\n$routeDescription',
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentLocation != null) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(_currentLocation!, 17),
            );
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
