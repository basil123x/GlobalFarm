import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/utils/item_media_url_util.dart';

class ItemModel {
  final String id;
  final String idx;
  final String storeid;
  final String name;
  final String nameEn;
  final String price;
  final int quantity;
  final String description;
  final String descriptionArb;
  final int views;
  final List<String> media;
  final SellerModel seller;
  final InteractionsModel interactions;

  ItemModel({
    required this.id,
    required this.idx,
    required this.storeid,
    required this.name,
    required this.nameEn,
    required this.price,
    required this.quantity,
    required this.description,
    required this.descriptionArb,
    required this.views,
    required this.media,
    required this.seller,
    required this.interactions,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    final storeId = json['storeid']?.toString() ?? AppConfig.storeId;
    final itemId = json['id'].toString();
    final itemIdx = json['idx']?.toString() ?? '';
    final List<String> mediaList = [];

    if (json['media'] is List) {
      mediaList.addAll(
        (json['media'] as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .map(
              (url) => ItemMediaUrlUtil.normalizeMediaUrl(
                url: url,
                storeId: storeId,
                itemId: itemId,
                itemIdx: itemIdx,
              ),
            ),
      );
    } else if (json['media'] != null && json['media'].toString().isNotEmpty) {
      final mediaValue = json['media'].toString();
      if (mediaValue.startsWith('http')) {
        mediaList.addAll(
          mediaValue
              .split(',')
              .map((file) => file.trim())
              .where((file) => file.isNotEmpty)
              .map(
                (url) => ItemMediaUrlUtil.normalizeMediaUrl(
                  url: url,
                  storeId: storeId,
                  itemId: itemId,
                  itemIdx: itemIdx,
                ),
              ),
        );
      } else {
        mediaList.addAll(
          ItemMediaUrlUtil.mediaUrlsFromDbValue(
            mediaValue: mediaValue,
            storeId: storeId,
            itemId: itemId,
            itemIdx: itemIdx,
          ),
        );
      }
    }

    if (mediaList.isEmpty) {
      // لا نضيف placeholder وهمي — MediaViewer يفحص S3 عند الحاجة
    }

    return ItemModel(
      id: json['id'].toString(),
      idx: json['idx']?.toString() ?? '',
      storeid: json['storeid']?.toString() ?? AppConfig.storeId,
      name: json['name']?.toString() ?? '',
      nameEn: json['eng']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
      quantity: int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      description: json['description']?.toString() ?? '',
      descriptionArb: json['description_arb']?.toString() ?? '',
      views: int.tryParse(json['views']?.toString() ?? '0') ?? 0,
      media: mediaList,
      seller: SellerModel.fromJson(
        json['seller'] is Map<String, dynamic>
            ? json['seller'] as Map<String, dynamic>
            : json['seller'] is Map
            ? Map<String, dynamic>.from(json['seller'] as Map)
            : const <String, dynamic>{},
      ),
      interactions: InteractionsModel.fromJson(json['interactions'] ?? {}),
    );
  }

  String localizedName(String lang) =>
      lang == 'ar' ? name : (nameEn.isNotEmpty ? nameEn : name);

  String localizedDescription(String lang) => lang == 'ar'
      ? (descriptionArb.isNotEmpty ? descriptionArb : description)
      : description;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idx': idx,
      'storeid': storeid,
      'name': name,
      'eng': nameEn,
      'price': price,
      'quantity': quantity,
      'description': description,
      'description_arb': descriptionArb,
      'views': views,
      'media': media,
      'seller': seller.toJson(),
      'interactions': interactions.toJson(),
    };
  }
}

class SellerModel {
  final String id;
  final String uid;
  final String name;
  final String avatar;
  String token;
  bool isFollowing;

  SellerModel({
    required this.id,
    required this.uid,
    required this.name,
    required this.avatar,
    this.token = "",
    this.isFollowing = false,
  });

  factory SellerModel.fromJson(Map<String, dynamic> json) {
    return SellerModel(
      id: json['id']?.toString() ?? '',
      uid: json['uid']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      isFollowing: json['isFollowing'] == true || json['isFollowing'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'uid': uid, 'name': name, 'avatar': avatar};
  }
}

class InteractionsModel {
  int likes;
  int comments;
  int shares;
  int cartQuantity;
  bool isLiked;

  InteractionsModel({
    required this.likes,
    required this.comments,
    required this.shares,
    required this.cartQuantity,
    this.isLiked = false,
  });

  factory InteractionsModel.fromJson(Map<String, dynamic> json) {
    return InteractionsModel(
      likes: int.tryParse(json['likes']?.toString() ?? '0') ?? 0,
      comments: int.tryParse(json['comments']?.toString() ?? '0') ?? 0,
      shares: int.tryParse(json['shares']?.toString() ?? '0') ?? 0,
      cartQuantity: int.tryParse(json['cartQuantity']?.toString() ?? '0') ?? 0,
      isLiked:
          (json['isLiked'] == 1 ||
          json['isLiked'] == true ||
          json['is_liked'] == 1 ||
          json['is_liked'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'cartQuantity': cartQuantity,
      'isLiked': isLiked,
    };
  }
}

class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String comment;
  final String createdAt;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.comment,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final userId =
        json['userId']?.toString() ??
        json['uid']?.toString() ??
        json['user_id']?.toString() ??
        '';
    return CommentModel(
      id: json['id']?.toString() ?? '',
      userId: userId,
      userName:
          json['userName']?.toString() ??
          json['user_name']?.toString() ??
          json['Fullname']?.toString() ??
          '',
      userAvatar:
          json['userAvatar']?.toString() ?? json['user_avatar']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      createdAt:
          json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
    );
  }
}

class UserProfileModel {
  final String id;
  final String name;
  final String phone;
  final String type;
  final String uid;
  final String avatar;
  final int itemsCount;

  UserProfileModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.type,
    required this.uid,
    required this.avatar,
    required this.itemsCount,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      type: json['type'] ?? '',
      uid: json['uid'] ?? '',
      avatar: json['avatar'] ?? '',
      itemsCount:
          int.tryParse(
            json['items_count']?.toString() ??
                json['itemsCount']?.toString() ??
                '0',
          ) ??
          0,
    );
  }
}

class UserProfileItemsModel {
  final String id;
  final String name;
  final String price;
  final int views;
  final List<String> media;

  UserProfileItemsModel({
    required this.id,
    required this.name,
    required this.price,
    required this.views,
    required this.media,
  });

  factory UserProfileItemsModel.fromJson(Map<String, dynamic> json) {
    return UserProfileItemsModel(
      id: json['id'].toString(),
      name: json['name'],
      price: json['price'],
      views: int.tryParse(json['views'].toString()) ?? 0,
      media: json['media'],
    );
  }
}
