import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LiveIssueScreen extends StatefulWidget {
  const LiveIssueScreen({super.key});

  @override
  _LiveIssueScreenState createState() => _LiveIssueScreenState();
}

class _LiveIssueScreenState extends State<LiveIssueScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  final TextEditingController _commentController = TextEditingController();
  final Set<Marker> _markers = {};
  BitmapDescriptor? _liveIssueIcon;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _getCurrentLocation();
    _loadExistingIssues();
    _setCustomMarkerIcon();
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    _currentUser = FirebaseAuth.instance.currentUser;
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

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _selectedLocation = LatLng(position.latitude, position.longitude);
      _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedLocation!));

      _markers.add(
        Marker(
          markerId: const MarkerId('현재 위치'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: '현재 위치'),
        ),
      );
    }); // 세미콜론 추가
  }

  Future<void> _loadExistingIssues() async {
    final querySnapshot =
        await FirebaseFirestore.instance.collection('issues').get();
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final GeoPoint location = data['location'];
      final String imageUrl = data['imageUrl'];
      final String comment = data['comment'];
      final String userId = data['userId'];

      setState(() {
        _markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(location.latitude, location.longitude),
            icon: _liveIssueIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(
              title: comment,
              snippet: 'Tap to view image',
              onTap: () {
                _showImageDialog(doc.id, imageUrl, comment, userId);
              },
            ),
          ),
        );
      });
    }
  }

  Future<void> _setCustomMarkerIcon() async {
    _liveIssueIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(
          size: Size(48, 48)), // low_rating_icon과 동일한 크기 설정
      'assets/live_issue_icon.png',
    );
  }

  void _showImageDialog(
      String markerId, String imageUrl, String comment, String userId) {
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
              if (_currentUser?.uid == userId)
                TextButton(
                  onPressed: () {
                    _deleteIssue(markerId, imageUrl);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Delete'),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteIssue(String markerId, String imageUrl) async {
    try {
      // Firebase Storage에서 이미지 삭제
      final storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await storageRef.delete();

      // Firestore에서 문서 삭제
      await FirebaseFirestore.instance
          .collection('issues')
          .doc(markerId)
          .delete();

      setState(() {
        _markers.removeWhere((marker) => marker.markerId.value == markerId);
      });
      _showError('Issue deleted successfully.');
    } catch (e) {
      _showError('Failed to delete issue: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitIssue() async {
    if (_selectedLocation == null ||
        _image == null ||
        _commentController.text.isEmpty) {
      _showError(
          'Please select a location, upload an image, and enter a comment.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Firebase Storage에 이미지 업로드
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(_image!);
      final imageUrl = await storageRef.getDownloadURL();

      // Firestore에 문제 보고서 저장
      await FirebaseFirestore.instance.collection('issues').add({
        'location':
            GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        'imageUrl': imageUrl,
        'comment': _commentController.text,
        'userId': _currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showError('Issue reported successfully.');
      _commentController.clear();
      _image = null;
      _loadExistingIssues(); // 새로 추가된 마커를 로드
    } catch (e) {
      _showError('Failed to report issue: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Live Issue'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 8,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  initialCameraPosition: CameraPosition(
                    target:
                        _selectedLocation ?? const LatLng(37.7749, -122.4194),
                    zoom: 14.0,
                  ),
                  onTap: (position) {
                    setState(() {
                      _selectedLocation = position;
                      _markers.add(
                        Marker(
                          markerId: const MarkerId('selectedLocation'),
                          position: _selectedLocation!,
                          icon:
                              _liveIssueIcon ?? BitmapDescriptor.defaultMarker,
                        ),
                      );
                    });
                  },
                  markers: _markers,
                ),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Enter a comment',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      onPressed: _pickImage,
                      child: const Icon(Icons.camera_alt),
                    ),
                    FloatingActionButton(
                      onPressed: _submitIssue,
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
