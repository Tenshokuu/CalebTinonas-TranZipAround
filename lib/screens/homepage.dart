import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'loginpage.dart';
import '../services/apiservices.dart';

import 'bus.dart';
import 'favs.dart';
import 'routes.dart';
import 'search.dart';
import 'trains.dart';
import 'favmrt.dart';
import 'trainnews.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? mapController;
  LatLng _center = const LatLng(1.37926, 103.84852);
  final Location location = Location();
  LocationData? _currentLocation;

  int _topMode = 0; // 0 = Bus, 1 = Train
  int _selectedMode = 0;
  String? _selectedStopCode;
  String? _selectedMarkerId;

  final List<String> _modes = [
    'Bus',
    'Favourites',
    'Routes',
    'Search',
    'Train',
  ];

  Set<Marker> _markers = {};
  List<dynamic> _allStops = [];

  final TransformationController _mrtTransformController =
      TransformationController();

  int _trainTabIndex = 0;
  final List<String> _trainTabs = ['MRTs', 'Fav MRTs', 'Train News'];

  @override
  void initState() {
    super.initState();
    _initLocation();
    _fetchAllStops();
  }

  Future<void> _initLocation() async {
    final loc = await location.getLocation();
    setState(() {
      _currentLocation = loc;
      _center = LatLng(loc.latitude!, loc.longitude!);
    });
    mapController?.animateCamera(CameraUpdate.newLatLng(_center));
  }

  Future<void> _fetchAllStops() async {
    List<dynamic> stops = [];
    for (int skip = 0; skip <= 5000; skip += 500) {
      final batch = await ApiServices.getBusStops(skip: skip);
      if (batch.isEmpty) break;
      stops.addAll(batch);
    }
    setState(() => _allStops = stops);
  }

  Future<void> _handleMapIdle() async {
    if (mapController == null) return;
    final center = await mapController!.getLatLng(
      const ScreenCoordinate(x: 200, y: 300),
    );
    await _loadNearbyStops(center);
  }

  Future<void> _loadNearbyStops(LatLng center) async {
    final centerLat = center.latitude;
    final centerLng = center.longitude;

    final userLat = _currentLocation?.latitude;
    final userLng = _currentLocation?.longitude;

    final nearby = _allStops.where((stop) {
      final lat = stop['Latitude'];
      final lng = stop['Longitude'];

      final distFromCenter = Geolocator.distanceBetween(
        centerLat,
        centerLng,
        lat,
        lng,
      );

      final distFromUser = (userLat != null && userLng != null)
          ? Geolocator.distanceBetween(userLat, userLng, lat, lng)
          : double.infinity;

      return distFromCenter <= 1500 || distFromUser <= 1500;
    }).toList();

    Set<Marker> newMarkers = {};
    for (var stop in nearby) {
      final desc = stop['Description'] ?? '';
      final initials = _getInitials(desc);
      final stopCode = stop['BusStopCode'];
      final lat = stop['Latitude'];
      final lng = stop['Longitude'];
      final isSelected = stopCode == _selectedMarkerId;

      final icon = await _createMarkerIcon(initials, isSelected);

      newMarkers.add(
        Marker(
          markerId: MarkerId(stopCode),
          position: LatLng(lat, lng),
          icon: icon,
          onTap: () async {
            setState(() {
              _selectedMarkerId = stopCode;
              _selectedStopCode = null;
            });
            await Future.delayed(const Duration(milliseconds: 100));
            setState(() {
              _selectedStopCode = stopCode;
              _topMode = 0;
              _selectedMode = 0;
            });
            await _loadNearbyStops(center);
          },
        ),
      );
    }

    setState(() => _markers = newMarkers);
  }

  String _getInitials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final s = words[0];
      return (s.length >= 2 ? s.substring(0, 2) : s.substring(0, 1))
          .toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Future<BitmapDescriptor> _createMarkerIcon(
    String initials,
    bool isSelected,
  ) async {
    const size = 60.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = isSelected ? const Color(0xFF33003F) : const Color(0xFFc349cc);

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size);

    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final img = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A0023),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'TranZipAround',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF2A0A34),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                _topChip(label: 'Bus', index: 0),
                _topChip(label: 'Train', index: 1),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _topChip({required String label, required int index}) {
    final selected = _topMode == index;
    return GestureDetector(
      onTap: () => setState(() {
        if (_topMode == 1 && index != 1) {
          _mrtTransformController.value = Matrix4.identity();
        }
        _topMode = index;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFc349cc) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      onMapCreated: (controller) => mapController = controller,
      initialCameraPosition: CameraPosition(
        target: _currentLocation != null
            ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
            : _center,
        zoom: 16,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      onCameraIdle: _handleMapIdle,
      markers: _markers,
      scrollGesturesEnabled: _topMode == 0,
      zoomGesturesEnabled: _topMode == 0,
      rotateGesturesEnabled: _topMode == 0,
      tiltGesturesEnabled: _topMode == 0,
    );
  }

  Widget _buildBusTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(4, (i) {
          final label = _modes[i];
          final isSelected = _selectedMode == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedMode = i),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFc349cc) : Colors.white,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 3,
                  width: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFc349cc)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTrainTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_trainTabs.length, (i) {
          final label = _trainTabs[i];
          final isSelected = _trainTabIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _trainTabIndex = i),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFc349cc) : Colors.white,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 3,
                  width: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFc349cc)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPanel() {
    if (_topMode == 1) {
      switch (_trainTabIndex) {
        case 0:
          return const TrainsPanel();
        case 1:
          return const FavMrtPanel();
        case 2:
          return const TrainNewsPanel();
      }
    }
    switch (_selectedMode) {
      case 0:
        return BusPanel(selectedStop: _selectedStopCode);
      case 1:
        return const FavsPanel();
      case 2:
        return const RoutesPanel();
      case 3:
        return const SearchPanel();
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTrain = _topMode == 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildMap(),

          if (isTrain) ...[
            Positioned.fill(
              // ignore: deprecated_member_use
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _mrtTransformController,
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -70),
                    child: Image.asset(
                      'images/MRTLTAMAP.png',
                      width: MediaQuery.of(context).size.width * 0.9,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ],

          Positioned(top: 0, left: 0, right: 0, child: _buildHeader()),

          // ✅ Accuracy button only in Bus mode, moved higher
          if (!isTrain)
            Positioned(
              bottom: 330,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: const Color(0xFFc349cc),
                onPressed: _initLocation,
                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),

          // bottom panels
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isTrain) _buildBusTabs(),
                  if (!isTrain) const SizedBox(height: 10),
                  if (isTrain) _buildTrainTabs(),
                  if (isTrain) const SizedBox(height: 10),
                  Container(
                    height: 250,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A0023),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: _buildPanel(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
