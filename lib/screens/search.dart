import 'package:flutter/material.dart';
import '../services/apiservices.dart';

class SearchPanel extends StatefulWidget {
  const SearchPanel({super.key});

  @override
  State<SearchPanel> createState() => SearchPanelState();
}

class SearchPanelState extends State<SearchPanel> {
  final TextEditingController searchController = TextEditingController();

  List<dynamic> allStops = [];
  List<dynamic> allServices = [];
  Map<String, List<Map<String, String>>> arrivalsCache = {};
  Set<String> expandedStops = {};

  bool hasFetched = false;
  bool isLoading = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);

    List<dynamic> stops = [];
    for (int skip = 0; skip <= 5000; skip += 500) {
      final batch = await ApiServices.getBusStops(skip: skip);
      if (batch.isEmpty) break;
      stops.addAll(batch);
    }

    final services = await ApiServices.getBusServices();

    setState(() {
      allStops = stops;
      allServices = services;
      hasFetched = true;
      isLoading = false;
    });
  }

  Future<void> _loadArrivals(String stopCode) async {
    if (arrivalsCache.containsKey(stopCode)) return;

    try {
      final data = await ApiServices.getBusArrivals(stopCode);
      final services = data['Services'] as List<dynamic>;
      final parsed = services.map((svc) {
        final svcNo = svc['ServiceNo']?.toString() ?? '';
        final next1 = _calculateEta(
          (svc['NextBus']?['EstimatedArrival']) ?? '',
        );
        final next2 = _calculateEta(
          (svc['NextBus2']?['EstimatedArrival']) ?? '',
        );
        final next3 = _calculateEta(
          (svc['NextBus3']?['EstimatedArrival']) ?? '',
        );
        return {
          'ServiceNo': svcNo,
          'Next1': next1,
          'Next2': next2,
          'Next3': next3,
        };
      }).toList();

      setState(() {
        arrivalsCache[stopCode] = parsed;
      });
    } catch (_) {
      setState(() {
        arrivalsCache[stopCode] = [];
      });
    }
  }

  String _calculateEta(String isoTime) {
    if (isoTime.isEmpty) return 'No Est';
    final dt = DateTime.tryParse(isoTime)?.toLocal();
    if (dt == null) return 'Invalid';
    final diff = dt.difference(DateTime.now()).inMinutes;
    if (diff <= 0) return 'Arriving';
    return '$diff min';
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
    final query = searchController.text.trim().toLowerCase();

    final filteredStops = allStops.where((stop) {
      final desc = (stop['Description'] ?? '').toLowerCase();
      final code = (stop['BusStopCode'] ?? '').toLowerCase();
      return desc.contains(query) || code.contains(query);
    }).toList();

    final filteredServices = allServices.where((svc) {
      final svcNo = (svc['ServiceNo'] ?? '').toLowerCase();
      return svcNo.contains(query);
    }).toList();

    return Material(
      color: Colors.transparent,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: searchController,
            onChanged: (val) async {
              if (val.isNotEmpty && !hasFetched) {
                await _fetchData();
              } else {
                setState(() {});
              }
            },
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Search for bus stops or services',
              hintStyle: TextStyle(color: Colors.white54),
              prefixIcon: Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Color(0xFF2A0033),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else if (query.isEmpty)
            const Center(
              child: Text(
                'Start typing to search',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else ...[
            if (filteredStops.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 12),
                child: Text(
                  'Bus Stops',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ...filteredStops.map((stop) {
              final stopCode = stop['BusStopCode'];
              final desc = stop['Description'];
              final road = stop['RoadName'];
              final services = arrivalsCache[stopCode];

              return GestureDetector(
                onTap: () async {
                  setState(() {
                    if (expandedStops.contains(stopCode)) {
                      expandedStops.remove(stopCode);
                    } else {
                      expandedStops.add(stopCode);
                    }
                  });
                  if (!arrivalsCache.containsKey(stopCode)) {
                    await _loadArrivals(stopCode);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A0033),
                    borderRadius: BorderRadius.circular(12),
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
                                  desc,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$stopCode · $road',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            expandedStops.contains(stopCode)
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.white54,
                          ),
                        ],
                      ),
                      if (expandedStops.contains(stopCode))
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
            }),
            if (filteredServices.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 20),
                child: Text(
                  'Bus Services',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ...filteredServices.map(
              (svc) => ListTile(
                title: Text(
                  'Service ${svc['ServiceNo']}',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Operator: ${svc['Operator']}',
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
            ),
            if (filteredStops.isEmpty && filteredServices.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    'No results found.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
