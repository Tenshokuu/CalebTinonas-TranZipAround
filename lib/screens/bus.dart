import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/apiservices.dart';

class BusPanel extends StatefulWidget {
  final String? selectedStop;
  const BusPanel({this.selectedStop, super.key});

  @override
  State<BusPanel> createState() => _BusPanelState();
}

class _BusPanelState extends State<BusPanel> {
  final Location location = Location();
  final user = FirebaseAuth.instance.currentUser;

  List<Map<String, dynamic>> nearbyStops = [];
  Map<String, List<Map<String, String>>> arrivals = {};
  Set<String> favouriteCodes = {};
  bool isLoading = true;
  int? expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadFavourites();
    _loadNearbyAndArrivals();
  }

  Future<void> _loadFavourites() async {
    if (user == null) return;
    final favs = await FirebaseFirestore.instance
        .collection('favourites')
        .where('UserID', isEqualTo: user!.uid)
        .get();

    setState(() {
      favouriteCodes = favs.docs
          .map((doc) => doc.data()['BusStopCode']?.toString())
          .whereType<String>()
          .toSet();
    });
  }

  Future<void> _toggleFavourite(String stopCode, String desc) async {
    if (user == null) return;
    final coll = FirebaseFirestore.instance.collection('favourites');

    final existing = await coll
        .where('UserID', isEqualTo: user!.uid)
        .where('BusStopCode', isEqualTo: stopCode)
        .get();

    if (existing.docs.isNotEmpty) {
      await coll.doc(existing.docs.first.id).delete();
      setState(() => favouriteCodes.remove(stopCode));
    } else {
      await coll.add({
        'UserID': user!.uid,
        'BusStopCode': stopCode,
        'BusStopName': desc,
        'FavName': '',
        'Description': '',
      });
      setState(() => favouriteCodes.add(stopCode));
    }
  }

  Future<void> _loadNearbyAndArrivals() async {
    final loc = await location.getLocation();
    final userLat = loc.latitude!;
    final userLng = loc.longitude!;

    List<Map<String, dynamic>> allStops = [];
    for (int skip = 0; skip <= 5000; skip += 500) {
      final batch = await ApiServices.getBusStops(skip: skip);
      if (batch.isEmpty) break;
      allStops.addAll(batch.map((e) => Map<String, dynamic>.from(e)));
    }

    for (var stop in allStops) {
      stop['distance'] = Geolocator.distanceBetween(
        userLat,
        userLng,
        stop['Latitude'],
        stop['Longitude'],
      );
    }

    final filtered = allStops.where((stop) => stop['distance'] <= 1000).toList()
      ..sort((a, b) => a['distance'].compareTo(b['distance']));
    final top = filtered.take(10).toList();

    if (widget.selectedStop != null) {
      final i = top.indexWhere((s) => s['BusStopCode'] == widget.selectedStop);
      if (i != -1) {
        final selected = top.removeAt(i);
        top.insert(0, selected);
        expandedIndex = 0;
      }
    }

    setState(() {
      nearbyStops = top;
    });

    for (final stop in top) {
      final code = stop['BusStopCode'];
      try {
        final data = await ApiServices.getBusArrivals(code);
        final services = data['Services'] as List<dynamic>;
        final parsed = services.map((svc) {
          final svcNo = svc['ServiceNo']?.toString() ?? '';
          final next1 = _calculateEta(svc['NextBus']['EstimatedArrival']);
          final next2 = _calculateEta(svc['NextBus2']['EstimatedArrival']);
          final next3 = _calculateEta(svc['NextBus3']['EstimatedArrival']);
          return {
            'ServiceNo': svcNo,
            'Next1': next1,
            'Next2': next2,
            'Next3': next3,
          };
        }).toList();

        setState(() {
          arrivals[code] = parsed.cast<Map<String, String>>();
        });
      } catch (_) {
        setState(() {
          arrivals[code] = [];
        });
      }
    }

    setState(() => isLoading = false);
  }

  String _calculateEta(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return 'No Est';
    final dt = DateTime.tryParse(isoTime)?.toLocal();
    if (dt == null) return 'Invalid';
    final diff = dt.difference(DateTime.now()).inMinutes;
    return diff <= 0 ? 'Arriving' : '$diff min';
  }

  Color _etaColor(String eta) {
    if (eta == 'Arriving') return Colors.greenAccent;
    if (eta == 'No Est' || eta == 'Invalid') return Colors.white70;
    final mins = int.tryParse(eta.replaceAll(' min', '')) ?? 999;
    if (mins <= 5) return Colors.greenAccent;
    if (mins <= 10) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && nearbyStops.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bus Stops Near You',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh',
                onPressed: () async {
                  setState(() {
                    isLoading = true;
                    nearbyStops.clear();
                    arrivals.clear();
                  });
                  await _loadNearbyAndArrivals();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: nearbyStops.length,
            itemBuilder: (context, index) {
              final stop = nearbyStops[index];
              final code = stop['BusStopCode'];
              final isExpanded = expandedIndex == index;
              final services = arrivals[code];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    expandedIndex = isExpanded ? null : index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade800, width: 0.6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stop['Description'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$code · ${stop['RoadName']}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _toggleFavourite(
                              stop['BusStopCode'],
                              stop['Description'],
                            ),
                            icon: Icon(
                              favouriteCodes.contains(stop['BusStopCode'])
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.white54,
                            size: 22,
                          ),
                        ],
                      ),
                      if (isExpanded)
                        services == null
                            ? const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Text(
                                  'Loading arrivals...',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : services.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Text(
                                  'No services found',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : Column(
                                children: [
                                  const SizedBox(height: 12),
                                  const Divider(color: Colors.grey, height: 1),
                                  const SizedBox(height: 8),
                                  ...services.map(
                                    (svc) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Bus ${svc['ServiceNo']}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const SizedBox(width: 6),
                                              Text(
                                                svc['Next1']!,
                                                style: TextStyle(
                                                  color: _etaColor(
                                                    svc['Next1']!,
                                                  ),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Text(
                                                svc['Next2']!,
                                                style: TextStyle(
                                                  color: _etaColor(
                                                    svc['Next2']!,
                                                  ),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Text(
                                                svc['Next3']!,
                                                style: TextStyle(
                                                  color: _etaColor(
                                                    svc['Next3']!,
                                                  ),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
