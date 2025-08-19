import 'package:flutter/material.dart';
import '../services/apiservices.dart';

class TrainNewsPanel extends StatefulWidget {
  const TrainNewsPanel({super.key});

  @override
  State<TrainNewsPanel> createState() => _TrainNewsPanelState();
}

class _TrainNewsPanelState extends State<TrainNewsPanel> {
  bool isLoading = true;
  List<dynamic> alerts = [];

  @override
  void initState() {
    super.initState();
    _loadTrainNews();
  }

  Future<void> _loadTrainNews() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiServices.getTrainNews();
      setState(() {
        alerts = data;
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        alerts = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (alerts.isEmpty) {
      return const Center(
        child: Text('No News Today', style: TextStyle(color: Colors.white70)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrainNews,
      backgroundColor: const Color(0xFF2A0033),
      color: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          final status = alert['Status']?.toString() ?? '1';
          final line = alert['Line'] ?? '';
          final direction = alert['Direction'] ?? '';
          final stations = alert['Stations'] ?? '';
          final freeBus = alert['FreePublicBus'] ?? '';
          final freeShuttle = alert['FreeMRTShuttle'] ?? '';
          final shuttleDir = alert['MRTShuttleDirection'] ?? '';
          final message = alert['Message'] ?? '';
          final createdDate = alert['CreatedDate'] ?? '';

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A0033),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Line: $line | Status: ${status == '2' ? 'Disrupted' : 'Normal'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (direction.isNotEmpty)
                  Text(
                    'Direction: $direction',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                if (stations.isNotEmpty)
                  Text(
                    'Affected Stations: $stations',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                if (freeBus.isNotEmpty)
                  Text(
                    'Free Public Bus: $freeBus',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                if (freeShuttle.isNotEmpty)
                  Text(
                    'Free MRT Shuttle: $freeShuttle',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                if (shuttleDir.isNotEmpty)
                  Text(
                    'Shuttle Direction: $shuttleDir',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                const SizedBox(height: 6),
                if (message.isNotEmpty)
                  Text(
                    'Message: $message',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                if (createdDate.isNotEmpty)
                  Text(
                    'Updated: $createdDate',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
