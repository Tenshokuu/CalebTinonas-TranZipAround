// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/apiservices.dart';

class RoutesPanel extends StatefulWidget {
  const RoutesPanel({super.key});

  @override
  State<RoutesPanel> createState() => _RoutesPanelState();
}

class _RoutesPanelState extends State<RoutesPanel> {
  bool isLoading = true;
  List<Map<String, dynamic>> routes = [];
  Set<String> favouriteStops = {};
  Set<String> favRoutes = {}; // pinned routes
  final Map<String, Map<String, dynamic>> stopInfoCache = {};
  final Map<String, List<Map<String, String>>> arrivalsCache = {};
  int? expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => isLoading = true);

    final favs = await FirestoreService.getFavouriteStops();
    favouriteStops = favs.map((f) => f['BusStopCode'] as String).toSet();

    final data = await FirestoreService.getOwnRoutes();
    routes = data;

    // sort pinned first, then by name
    routes.sort((a, b) {
      final aFav = favRoutes.contains(a['docID']);
      final bFav = favRoutes.contains(b['docID']);
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return (a['routename'] ?? '').toString().compareTo(
        (b['routename'] ?? '').toString(),
      );
    });

    setState(() => isLoading = false);
  }

  Future<Map<String, dynamic>> _getStopDetails(String stopCode) async {
    if (stopInfoCache.containsKey(stopCode)) {
      return stopInfoCache[stopCode]!;
    }

    for (int skip = 0; skip <= 5000; skip += 500) {
      final batch = await ApiServices.getBusStops(skip: skip);
      if (batch.isEmpty) break;

      final match = batch.firstWhere(
        (s) => s['BusStopCode'].toString() == stopCode,
        orElse: () => <String, dynamic>{},
      );

      if (match.isNotEmpty) {
        final details = Map<String, dynamic>.from(match);
        stopInfoCache[stopCode] = details;
        return details;
      }
    }

    final fallback = {
      'BusStopCode': stopCode,
      'Description': 'Unknown Stop',
      'RoadName': 'Unknown Rd',
    };
    stopInfoCache[stopCode] = fallback;
    return fallback;
  }

  Future<void> _loadArrivalsForStop(String stopCode) async {
    try {
      final data = await ApiServices.getBusArrivals(stopCode);
      final services = (data['Services'] ?? []).map<Map<String, String>>((s) {
        final svcNo = s['ServiceNo']?.toString() ?? '';
        final next1 = _formatEta(
          (s['NextBus'] ?? {})['EstimatedArrival'] ?? '',
        );
        final next2 = _formatEta(
          (s['NextBus2'] ?? {})['EstimatedArrival'] ?? '',
        );
        final next3 = _formatEta(
          (s['NextBus3'] ?? {})['EstimatedArrival'] ?? '',
        );
        return {
          'ServiceNo': svcNo,
          'Next1': next1,
          'Next2': next2,
          'Next3': next3,
        };
      }).toList();

      setState(() {
        arrivalsCache[stopCode] = services;
      });
    } catch (_) {
      setState(() {
        arrivalsCache[stopCode] = [];
      });
    }
  }

  String _formatEta(String iso) {
    if (iso.isEmpty) return 'No Est';
    final t = DateTime.tryParse(iso);
    if (t == null) return 'No Est';
    final mins = t.difference(DateTime.now()).inMinutes;
    return mins <= 0 ? 'Arriving' : '$mins min';
  }

  Color _etaColor(String eta) {
    if (eta == 'Arriving') return Colors.greenAccent;
    if (eta == 'No Est' || eta == 'Invalid') return Colors.white70;
    final mins = int.tryParse(eta.replaceAll(' min', '')) ?? 999;
    if (mins <= 5) return Colors.greenAccent;
    if (mins <= 10) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Future<void> _toggleFavourite(String stopCode, String stopName) async {
    if (favouriteStops.contains(stopCode)) {
      final favs = await FirestoreService.getFavouriteStops();
      final doc = favs.firstWhere((f) => f['BusStopCode'] == stopCode);
      final docID = doc['docID'];
      await FirestoreService.deleteFavouriteStop(docID);
      favouriteStops.remove(stopCode);
    } else {
      await FirestoreService.addFavouriteStop(
        busStopCode: stopCode,
        busStopName: stopName,
        favName: stopName,
        description: '',
      );
      favouriteStops.add(stopCode);
    }
    setState(() {});
  }

  Future<void> _toggleFavRoute(String id) async {
    setState(() {
      favRoutes.contains(id) ? favRoutes.remove(id) : favRoutes.add(id);
    });
    _loadRoutes();
  }

  Future<void> _editRoute(Map<String, dynamic> route) async {
    final nameC = TextEditingController(text: route['routename'] ?? '');
    final descC = TextEditingController(text: route['Description'] ?? '');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A0033),
        title: const Text("Edit Route", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Route Name",
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            TextField(
              controller: descC,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Description",
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white70),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFc349cc),
            ),
            child: const Text("Save"),
            onPressed: () async {
              await FirestoreService.updateOwnRoute(
                docID: route['docID'],
                routeName: nameC.text.trim(),
                stops: List<String>.from(route['stops'] ?? []),
                description: descC.text.trim(),
              );
              Navigator.pop(context);
              _loadRoutes();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRoute(String id) async {
    await FirestoreService.deleteOwnRoute(id);
    _loadRoutes();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (routes.isEmpty) {
      return Column(
        children: [
          _buildHeader(),
          const Expanded(
            child: Center(
              child: Text(
                'No routes yet. Tap + to create one.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: routes.length,
            itemBuilder: (context, routeIndex) {
              final route = routes[routeIndex];
              final stops = List<String>.from(route['stops'] ?? []);
              final isExpanded = expandedIndex == routeIndex;
              final isFav = favRoutes.contains(route['docID']);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A0033),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(
                          () => expandedIndex = isExpanded ? null : routeIndex,
                        );
                        if (!isExpanded) {
                          for (final stopCode in stops) {
                            _getStopDetails(stopCode);
                            _loadArrivalsForStop(stopCode);
                          }
                        }
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  route['routename'] ?? 'Unnamed Route',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFc349cc),
                                    fontSize: 16,
                                  ),
                                ),
                                if ((route['Description'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Text(
                                    route['Description'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.favorite,
                              color: isFav ? Colors.redAccent : Colors.grey,
                            ),
                            onPressed: () => _toggleFavRoute(route['docID']),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                    if (isExpanded) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white70),
                            onPressed: () => _editRoute(route),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.white70,
                            ),
                            onPressed: () => _deleteRoute(route['docID']),
                          ),
                        ],
                      ),
                      Column(
                        children: stops.map((stopCode) {
                          final stopData =
                              stopInfoCache[stopCode] ??
                              {'Description': 'Loading...', 'RoadName': ''};
                          final stopName =
                              (stopData['Description'] ?? 'Unknown') as String;
                          final roadName =
                              (stopData['RoadName'] ?? 'Unknown Rd') as String;
                          final arrivals = arrivalsCache[stopCode];
                          final isFavStop = favouriteStops.contains(stopCode);

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade800,
                                width: 0.6,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            stopName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$stopCode · $roadName',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _toggleFavourite(stopCode, stopName),
                                      icon: Icon(
                                        isFavStop
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                                if (arrivals == null)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: Text(
                                      'Loading arrivals...',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  )
                                else if (arrivals.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: Text(
                                      'No services found',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  )
                                else
                                  Column(
                                    children: [
                                      const SizedBox(height: 12),
                                      const Divider(
                                        color: Colors.grey,
                                        height: 1,
                                      ),
                                      const SizedBox(height: 8),
                                      ...arrivals.map(
                                        (svc) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
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
                                                  Text(
                                                    svc['Next1']!,
                                                    style: TextStyle(
                                                      color: _etaColor(
                                                        svc['Next1']!,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Text(
                                                    svc['Next2']!,
                                                    style: TextStyle(
                                                      color: _etaColor(
                                                        svc['Next2']!,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Text(
                                                    svc['Next3']!,
                                                    style: TextStyle(
                                                      color: _etaColor(
                                                        svc['Next3']!,
                                                      ),
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
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "My Routes",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadRoutes,
          ),
          IconButton(
            tooltip: 'Add Route',
            icon: const Icon(
              Icons.add_circle,
              color: Color(0xFFc349cc),
              size: 28,
            ),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/createRoute',
              ).then((_) => _loadRoutes());
            },
          ),
        ],
      ),
    );
  }
}
