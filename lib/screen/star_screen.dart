import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class PlaceRatingScreen extends StatefulWidget {
  const PlaceRatingScreen({super.key});

  @override
  _PlaceRatingScreenState createState() => _PlaceRatingScreenState();
}

class _PlaceRatingScreenState extends State<PlaceRatingScreen> {
  final String api = 'AIzaSyAqDK2UZ1Ukalop_kkz1kuXbfGxCvZT_-s';
  final TextEditingController _placeController = TextEditingController();
  GoogleMapController? _mapController;
  String? _placeName;
  String? _placeId;
  LatLng? _currentLocation;
  double? _userRating;
  double _averageRating = 0.0;
  bool _hasRated = false;
  bool _isLoading = true;
  Set<Marker> _markers = {};
  BitmapDescriptor? _currentLocationIcon;
  BitmapDescriptor? _highRatingIcon;
  BitmapDescriptor? _lowRatingIcon;

  @override
  void initState() {
    super.initState();
    _setCustomMarkerIcons();
    _getCurrentLocation();
    _startLocationUpdates();
    _loadRatedPlaces();
  }

  Future<void> _setCustomMarkerIcons() async {
    _currentLocationIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/current_location_icon.png',
    );
    _highRatingIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/high_rating_icon.png',
    );
    _lowRatingIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/low_rating_icon.png',
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
      _markers.add(Marker(
        markerId: MarkerId('currentLocation'),
        position: _currentLocation!,
        icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(title: '현재 위치'),
      ));
      _mapController
          ?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 17));
    });
  }

  void _startLocationUpdates() {
    Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _markers.add(Marker(
          markerId: MarkerId('currentLocation'),
          position: _currentLocation!,
          icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarker,
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
          icon: markerIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: data['name'],
            snippet: '평균 별점: $averageRating',
          ),
        );
        _markers.add(marker);
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _goToCurrentLocation() {
    if (_currentLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 17),
      );
    } else {
      _showError('현재 위치를 가져올 수 없습니다.');
    }
  }

  Future<void> _searchPlace(String place) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$place&inputtype=textquery&fields=place_id,name,geometry&key=$api');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final result = data['candidates'][0];
        setState(() {
          _placeName = result['name'];
          _placeId = result['place_id'];
          final location = result['geometry']['location'];
          _currentLocation = LatLng(location['lat'], location['lng']);
          _markers.add(Marker(
            markerId: MarkerId('searchedLocation'),
            position: _currentLocation!,
            infoWindow: InfoWindow(title: _placeName),
          ));
          _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(_currentLocation!, 17));
        });
        fetchAverageRating();
      } else {
        _showError('Place not found.');
      }
    } else {
      _showError('Error searching place: ${response.body}');
    }
  }

  Future<void> fetchAverageRating() async {
    if (_placeId != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('places')
          .doc(_placeId)
          .get();
      if (snapshot.exists) {
        final data = snapshot.data();
        setState(() {
          _averageRating = data?['averageRating'] ?? 0.0;
          _hasRated = data?['ratings']
                  ?.containsKey(FirebaseAuth.instance.currentUser?.uid) ??
              false;
        });
      }
    }
  }

  Future<void> _submitRating(double rating) async {
    if (_placeId != null) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _showError('User not logged in.');
        return;
      }

      final placeRef =
          FirebaseFirestore.instance.collection('places').doc(_placeId);
      final snapshot = await placeRef.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        final ratings = Map<String, double>.from(data?['ratings'] ?? {});
        if (ratings.containsKey(userId)) {
          _showError('You have already rated this place.');
          return;
        }
        ratings[userId] = rating;
        final averageRating =
            ratings.values.reduce((a, b) => a + b) / ratings.length;
        await placeRef.update({
          'ratings': ratings,
          'averageRating': averageRating,
        });
      } else {
        await placeRef.set({
          'name': _placeName,
          'location':
              GeoPoint(_currentLocation!.latitude, _currentLocation!.longitude),
          'ratings': {userId: rating},
          'averageRating': rating,
        });
      }
      fetchAverageRating();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록되었습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place Rating'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _placeController,
                  decoration: InputDecoration(
                    labelText: 'Search Place',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search),
                      onPressed: () {
                        _searchPlace(_placeController.text);
                      },
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GoogleMap(
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                  _currentLocation!, 17));
                        },
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation ?? LatLng(0, 0),
                          zoom: 15,
                        ),
                        markers: _markers,
                      ),
              ),
              if (_placeName != null) ...[
                Text(
                  '$_placeName의 평균 별점: $_averageRating',
                  style: const TextStyle(fontSize: 20),
                ),
                if (!_hasRated)
                  Column(
                    children: [
                      Slider(
                        min: 0.5,
                        max: 5.0,
                        divisions: 9,
                        value: _userRating ?? 0.5,
                        label: '${_userRating ?? 0.5}',
                        onChanged: (value) {
                          setState(() {
                            _userRating = value;
                          });
                        },
                      ),
                      ElevatedButton(
                        onPressed: _userRating != null
                            ? () => _submitRating(_userRating!)
                            : null,
                        child: const Text('별점 등록'),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
