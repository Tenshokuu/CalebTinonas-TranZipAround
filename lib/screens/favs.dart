import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/apiservices.dart';

class FavsPanel extends StatefulWidget {
  const FavsPanel({super.key});

  @override
  State<FavsPanel> createState() => _FavsPanelState();
}

class _FavsPanelState extends State<FavsPanel> {
  final user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> favourites = [];
  Map<String, List<Map<String, String>>> arrivals = {};
  bool isLoading = true;
  int? expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('favourites')
        .where('UserID', isEqualTo: user!.uid)
        .get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'code': data['BusStopCode'] ?? '',
        'desc': data['BusStopName'] ?? '',
        'favname': data['FavName'] ?? '',
        'description': data['Description'] ?? '',
      };
    }).toList();

    setState(() {
      favourites = items;
    });

    for (final fav in items) {
      try {
        final code = fav['code'];
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
          arrivals[fav['code']] = [];
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

  Future<void> _deleteFavourite(String id) async {
    await FirebaseFirestore.instance.collection('favourites').doc(id).delete();
    setState(() {
      favourites.removeWhere((f) => f['id'] == id);
    });
  }

  Future<void> _editFavourite(Map<String, dynamic> fav) async {
    final TextEditingController nameCtrl = TextEditingController(
      text: fav['favname'],
    );
    final TextEditingController descCtrl = TextEditingController(
      text: fav['description'],
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Edit Favourite',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Favourite Name',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newDesc = descCtrl.text.trim();
              await FirebaseFirestore.instance
                  .collection('favourites')
                  .doc(fav['id'])
                  .update({'FavName': newName, 'Description': newDesc});

              setState(() {
                fav['favname'] = newName;
                fav['description'] = newDesc;
              });

              // ignore: use_build_context_synchronously
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (favourites.isEmpty) {
      return const Center(
        child: Text(
          'No favourites saved.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: favourites.length,
      itemBuilder: (context, index) {
        final fav = favourites[index];
        final code = fav['code'];
        final isExpanded = expandedIndex == index;
        final services = arrivals[code];

        return GestureDetector(
          onTap: () {
            setState(() {
              expandedIndex = isExpanded ? null : index;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            fav['favname'].isEmpty
                                ? fav['desc']
                                : fav['favname'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${fav['desc']} (${fav['code']})',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          if (fav['description'].toString().trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                fav['description'],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editFavourite(fav),
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.amberAccent,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteFavourite(fav['id']),
                      icon: const Icon(
                        Icons.favorite,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
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
                                            color: _etaColor(svc['Next1']!),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          svc['Next2']!,
                                          style: TextStyle(
                                            color: _etaColor(svc['Next2']!),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          svc['Next3']!,
                                          style: TextStyle(
                                            color: _etaColor(svc['Next3']!),
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
    );
  }
}
