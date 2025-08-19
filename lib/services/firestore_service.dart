import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static final _userID = FirebaseAuth.instance.currentUser!.uid;

  // 1. Add Favourite Stop
  static Future<void> addFavouriteStop({
    required String busStopCode,
    required String busStopName,
    required String favName,
    required String description,
  }) async {
    await _db.collection('favourites').add({
      'userID': _userID,
      'BusStopCode': busStopCode,
      'BusStopName': busStopName,
      'FavName': favName,
      'Description': description,
    });
  }

  // 2. Get All Favourite Stops
  static Future<List<Map<String, dynamic>>> getFavouriteStops() async {
    final snapshot = await _db
        .collection('favourites')
        .where('userID', isEqualTo: _userID)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // 3. Update FavName + Description
  static Future<void> updateFavouriteStop({
    required String docID,
    required String favName,
    required String description,
  }) async {
    await _db.collection('favourites').doc(docID).update({
      'FavName': favName,
      'Description': description,
    });
  }

  // 4. Delete Favourite Stop
  static Future<void> deleteFavouriteStop(String docID) async {
    await _db.collection('favourites').doc(docID).delete();
  }

  // 5. Add Own Route
  static Future<void> addOwnRoute({
    required String routeName,
    required List<String> stops,
    String description = '',
  }) async {
    await _db.collection('ownroutes').add({
      'userID': _userID,
      'routename': routeName,
      'Description': description,
      'stops': stops,
    });
  }

  // 6. Get Own Routes
  static Future<List<Map<String, dynamic>>> getOwnRoutes() async {
    final snapshot = await _db
        .collection('ownroutes')
        .where('userID', isEqualTo: _userID)
        .get();

    return snapshot.docs
        .map((doc) => {...doc.data(), 'docID': doc.id})
        .toList();
  }

  // 7. Update Route (by doc ID)
  static Future<void> updateOwnRoute({
    required String docID,
    required String routeName,
    required List<String> stops,
    String description = '',
  }) async {
    await _db.collection('ownroutes').doc(docID).update({
      'routename': routeName,
      'Description': description,
      'stops': stops,
    });
  }

  // 8. Delete Route
  static Future<void> deleteOwnRoute(String docID) async {
    await _db.collection('ownroutes').doc(docID).delete();
  }

  // === Fav MRTs ===

  // 9. Add Favourite MRT
  static Future<void> addFavouriteMrt({
    required String stationCode,
    required String description,
  }) async {
    await _db.collection('favmrts').add({
      'userID': _userID,
      'StationCode': stationCode,
      'Description': description,
    });
  }

  // 10. Get Favourite MRTs
  static Future<List<Map<String, dynamic>>> getFavouriteMrts() async {
    final snapshot = await _db
        .collection('favmrts')
        .where('userID', isEqualTo: _userID)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['docID'] = doc.id;
      return data;
    }).toList();
  }

  // 11. Update Favourite MRT
  static Future<void> updateFavouriteMrt({
    required String docID,
    required String description,
  }) async {
    await _db.collection('favmrts').doc(docID).update({
      'Description': description,
    });
  }

  // 12, Delete Favourite MRT 
  static Future<void> deleteFavouriteMrt(String docID) async {
    await _db.collection('favmrts').doc(docID).delete();
  }
}
