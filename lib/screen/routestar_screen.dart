import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class RoadRating {
  final LatLng start;
  final LatLng end;
  final double rating;

  RoadRating({required this.start, required this.end, required this.rating});

  Map<String, dynamic> toMap() {
    return {
      'start': GeoPoint(start.latitude, start.longitude),
      'end': GeoPoint(end.latitude, end.longitude),
      'rating': rating,
    };
  }

  static RoadRating fromMap(Map<String, dynamic> map) {
    return RoadRating(
      start: LatLng(map['start'].latitude, map['start'].longitude),
      end: LatLng(map['end'].latitude, map['end'].longitude),
      rating: map['rating'],
    );
  }
}

Future<void> saveRoadRating(RoadRating roadRating) async {
  await FirebaseFirestore.instance
      .collection('road_ratings')
      .add(roadRating.toMap());
}

Future<List<RoadRating>> fetchRoadRatings() async {
  final snapshot =
      await FirebaseFirestore.instance.collection('road_ratings').get();
  return snapshot.docs.map((doc) => RoadRating.fromMap(doc.data())).toList();
}

class RouteStarScreen extends StatefulWidget {
  const RouteStarScreen({super.key});

  @override
  _RouteStarScreenState createState() => _RouteStarScreenState();
}

class _RouteStarScreenState extends State<RouteStarScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  bool _isLoading = true;
  bool _isAddingRoute = false; // 경로 추가 모드 여부
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  BitmapDescriptor? _currentLocationIcon;

  LatLng? _startPoint;
  LatLng? _endPoint;

  @override
  void initState() {
    super.initState();
    _setCustomMarkerIcons();
    _getCurrentLocation();
    _loadRatedRoads();
  }

  Future<void> _setCustomMarkerIcons() async {
    _currentLocationIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/current_location_icon.png',
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('Location permissions are permanently denied.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _isLoading = false;
      _mapController
          ?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 17));
    });
  }

  Future<void> _loadRatedRoads() async {
    List<RoadRating> roadRatings = await fetchRoadRatings();
    setState(() {
      for (var roadRating in roadRatings) {
        _polylines.add(Polyline(
          polylineId: PolylineId(
              roadRating.start.toString() + roadRating.end.toString()),
          points: [roadRating.start, roadRating.end],
          color: _getColorBasedOnRating(roadRating.rating),
          width: 5,
          consumeTapEvents: true, // 터치 이벤트를 소비하도록 설정
          onTap: () {
            if (!_isAddingRoute) {
              _showRateRoadDialog(
                  roadRating.start, roadRating.end, roadRating.rating);
            }
          },
        ));
      }
    });
  }

  Color _getColorBasedOnRating(double rating) {
    if (rating >= 4.0) {
      return Colors.green;
    } else if (rating >= 2.0) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onTap(LatLng position) {
    if (_isAddingRoute) {
      setState(() {
        if (_startPoint == null) {
          _startPoint = position;
          _markers.add(Marker(
            markerId: MarkerId('startPoint'),
            position: _startPoint!,
            infoWindow: InfoWindow(title: 'Start Point'),
          ));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Start point selected. Now select the end point.')),
          );
        } else if (_endPoint == null) {
          _endPoint = position;
          _markers.add(Marker(
            markerId: MarkerId('endPoint'),
            position: _endPoint!,
            infoWindow: InfoWindow(title: 'End Point'),
          ));
          _polylines.add(Polyline(
            polylineId: PolylineId('selectedRoute'),
            points: [_startPoint!, _endPoint!],
            color: Colors.blue,
            width: 5,
          ));
          _showRateRoadDialog(_startPoint!, _endPoint!, null);
        } else {
          _startPoint = position;
          _endPoint = null;
          _markers.clear();
          _polylines.removeWhere(
              (polyline) => polyline.polylineId.value == 'selectedRoute');
          _markers.add(Marker(
            markerId: MarkerId('startPoint'),
            position: _startPoint!,
            infoWindow: InfoWindow(title: 'Start Point'),
          ));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Start point selected. Now select the end point.')),
          );
        }
      });
    }
  }

  void _showRateRoadDialog(LatLng start, LatLng end, double? averageRating) {
    showDialog(
      context: context,
      builder: (context) => RateRoadDialog(
        start: start,
        end: end,
        averageRating: averageRating,
      ),
    ).then((_) {
      setState(() {
        _startPoint = null;
        _endPoint = null;
        _markers.clear();
        _polylines.removeWhere(
            (polyline) => polyline.polylineId.value == 'selectedRoute');
        _loadRatedRoads(); // 별점 저장 후 별점 데이터를 다시 로드
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('도로 구간 별점 매기기'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isAddingRoute = !_isAddingRoute;
                if (!_isAddingRoute) {
                  _startPoint = null;
                  _endPoint = null;
                  _markers.clear();
                  _polylines.removeWhere((polyline) =>
                      polyline.polylineId.value == 'selectedRoute');
                }
              });
            },
            child: Text(
              _isAddingRoute ? '취소' : '새 경로 추가하기',
              style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GoogleMap(
                        onMapCreated: (controller) {
                          _mapController = controller;
                          if (_currentLocation != null) {
                            _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                    _currentLocation!, 17));
                          }
                        },
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation ?? const LatLng(0, 0),
                          zoom: 15,
                        ),
                        polylines: _polylines,
                        markers: _markers,
                        onTap: _onTap,
                      ),
              ),
            ],
          ),
        ],
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

class RateRoadDialog extends StatefulWidget {
  final LatLng start;
  final LatLng end;
  final double? averageRating;

  RateRoadDialog({required this.start, required this.end, this.averageRating});

  @override
  _RateRoadDialogState createState() => _RateRoadDialogState();
}

class _RateRoadDialogState extends State<RateRoadDialog> {
  double _rating = 3.0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('도로 구간 별점 매기기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('도로 구간: ${widget.start} - ${widget.end}'),
          if (widget.averageRating != null)
            Text('평균 별점: ${widget.averageRating!.toStringAsFixed(1)}'),
          Slider(
            value: _rating,
            min: 1,
            max: 5,
            divisions: 4,
            label: _rating.toString(),
            onChanged: (value) {
              setState(() {
                _rating = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('취소'),
        ),
        TextButton(
          onPressed: () async {
            final roadRating = RoadRating(
              start: widget.start,
              end: widget.end,
              rating: _rating,
            );
            await saveRoadRating(roadRating);
            Navigator.of(context).pop();
          },
          child: Text('저장'),
        ),
      ],
    );
  }
}
