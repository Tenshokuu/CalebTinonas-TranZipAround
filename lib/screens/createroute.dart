// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../services/apiservices.dart';
import '../services/firestore_service.dart';

class CreateRoutePage extends StatefulWidget {
  const CreateRoutePage({super.key});

  @override
  State<CreateRoutePage> createState() => _CreateRoutePageState();
}

class _CreateRoutePageState extends State<CreateRoutePage> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController routeNameController = TextEditingController();
  final TextEditingController routeDescController = TextEditingController();

  List<dynamic> allStops = [];
  List<dynamic> filteredStops = [];
  Map<String, List<Map<String, String>>> arrivalsCache = {};
  Set<String> selectedStops = {};

  bool isLoading = false;
  bool hasFetched = false;

  @override
  void dispose() {
    searchController.dispose();
    routeNameController.dispose();
    routeDescController.dispose();
    super.dispose();
  }

  Future<void> _fetchStops() async {
    setState(() => isLoading = true);

    List<dynamic> stops = [];
    for (int skip = 0; skip <= 5000; skip += 500) {
      final batch = await ApiServices.getBusStops(skip: skip);
      if (batch.isEmpty) break;
      stops.addAll(batch);
    }

    setState(() {
      allStops = stops;
      isLoading = false;
      hasFetched = true;
    });
  }

  void _filterStops(String query) {
    if (!hasFetched) return;

    if (query.isEmpty) {
      setState(() => filteredStops = []);
      return;
    }

    final lower = query.toLowerCase();
    setState(() {
      filteredStops = allStops.where((stop) {
        return stop['Description'].toString().toLowerCase().contains(lower) ||
            stop['BusStopCode'].toString().contains(query);
      }).toList();
    });

    _fetchArrivalsForFiltered();
  }

  Future<void> _fetchArrivalsForFiltered() async {
    for (var stop in filteredStops) {
      final code = stop['BusStopCode'];
      if (arrivalsCache.containsKey(code)) continue;

      try {
        final data = await ApiServices.getBusArrivals(code);
        final services = data['Services'] ?? [];

        arrivalsCache[code] = services.map<Map<String, String>>((srv) {
          final est = srv['NextBus']['EstimatedArrival'];
          String arrivalText;
          if (est == null || est.isEmpty) {
            arrivalText = 'No Est';
          } else {
            final eta = DateTime.parse(
              est,
            ).difference(DateTime.now()).inMinutes;
            arrivalText = eta <= 0 ? 'Arr' : '$eta min';
          }
          return {'service': srv['ServiceNo'] ?? '', 'arrival': arrivalText};
        }).toList();
      } catch (_) {
        arrivalsCache[code] = [];
      }
    }
    setState(() {});
  }

  Future<void> _createRoute() async {
    final name = routeNameController.text.trim();
    final desc = routeDescController.text.trim();

    if (name.isEmpty || selectedStops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please enter a route name and select at least 1 stop.",
          ),
        ),
      );
      return;
    }

    await FirestoreService.addOwnRoute(
      routeName: name,
      description: desc,
      stops: selectedStops.toList(),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _fetchStops();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A0033),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Create Route",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2A0033),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: routeNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Route Name",
                      labelStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: routeDescController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Description (optional)",
                      labelStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A0033),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                onChanged: _filterStops,
                decoration: const InputDecoration(
                  hintText: "Search bus stop by name or code",
                  hintStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.search, color: Colors.white70),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: Column(
                children: [
                
                  if (selectedStops.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A0033),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Stops Added",
                              style: TextStyle(
                                color: Color(0xFFc349cc),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: selectedStops.map((code) {
                                final stop = allStops.firstWhere(
                                  (s) => s['BusStopCode'] == code,
                                  orElse: () => {'Description': 'Unknown'},
                                );
                                return Chip(
                                  backgroundColor: Colors.black.withOpacity(
                                    0.4,
                                  ),
                                  label: Text(
                                    "${stop['Description']} ($code)",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  onDeleted: () {
                                    setState(() => selectedStops.remove(code));
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredStops.length,
                              itemBuilder: (context, index) {
                                final stop = filteredStops[index];
                                final code = stop['BusStopCode'];
                                final desc = stop['Description'];
                                final road = stop['RoadName'];
                                final arrivals = arrivalsCache[code] ?? [];
                                final isSelected = selectedStops.contains(code);

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A0033),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              "$desc ($code) · $road",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isSelected
                                                  ? Icons.check_circle
                                                  : Icons.add_circle_outline,
                                              color: isSelected
                                                  ? Colors.green
                                                  : Colors.white70,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                if (isSelected) {
                                                  selectedStops.remove(code);
                                                } else {
                                                  selectedStops.add(code);
                                                }
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      if (arrivals.isNotEmpty) ...[
                                        const Divider(
                                          color: Colors.grey,
                                          height: 8,
                                        ),
                                        ...arrivals.map(
                                          (bus) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  "Bus ${bus['service']}",
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                                Text(
                                                  bus['arrival']!,
                                                  style: const TextStyle(
                                                    color: Colors.greenAccent,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFc349cc),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _createRoute,
                child: const Text(
                  "Create Route",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
