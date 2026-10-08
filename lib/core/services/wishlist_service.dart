import 'package:flutter/foundation.dart';
import 'package:GlobalFarm/core/models/item_model.dart';

/// In-memory wishlist so likes from Home/Categories appear instantly.
class WishlistService extends ChangeNotifier {
  WishlistService._();
  static final WishlistService instance = WishlistService._();

  final Map<String, ItemModel> _itemsById = {};

  List<ItemModel> get items => _itemsById.values.toList(growable: false);

  bool contains(String itemId) => _itemsById.containsKey(itemId);

  void upsertLiked(ItemModel item) {
    // Keep a snapshot so later unlikes on another screen stay consistent.
    _itemsById[item.id] = item;
    item.interactions.isLiked = true;
    notifyListeners();
  }

  void removeLiked(String itemId) {
    if (_itemsById.remove(itemId) != null) {
      notifyListeners();
    }
  }

  void setLiked(ItemModel item, bool liked) {
    if (liked) {
      upsertLiked(item);
    } else {
      removeLiked(item.id);
    }
  }

  /// Replace cache after a full server fetch (keeps UI in sync).
  void replaceAll(List<ItemModel> liked) {
    _itemsById
      ..clear()
      ..addEntries(liked.map((e) {
        e.interactions.isLiked = true;
        return MapEntry(e.id, e);
      }));
    notifyListeners();
  }

  void clear() {
    if (_itemsById.isEmpty) return;
    _itemsById.clear();
    notifyListeners();
  }
}
