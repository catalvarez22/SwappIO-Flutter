import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/AppUserModel.dart';
import '../model/CharityModel.dart';
import '../model/ChatChannelModel.dart';
import '../model/ChatMessageModel.dart';
import '../model/DropoffPointModel.dart';
import '../model/ProductModel.dart';
import 'FirestoreServiceViewModel.dart';

class FirebaseFirestoreServiceViewModel implements FirestoreServiceViewModel {
  FirebaseFirestoreServiceViewModel();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _products => _db.collection('products');
  CollectionReference<Map<String, dynamic>> get _charities => _db.collection('charities');
  CollectionReference<Map<String, dynamic>> get _dropOffPoints => _db.collection('dropoff_points');
  CollectionReference<Map<String, dynamic>> get _chats => _db.collection('chats');

  @override
  Future<void> saveUserData({
    required String id,
    required String name,
    required String lastname,
    required String email,
  }) async {
    await _users.doc(id).set({
      'name': name.trim(),
      'lastname': lastname.trim(),
      'email': email.trim(),
      'location': 'Bogota, CO',
      'balance': 0,
      'number': '',
      'rating': 4.8,
      'ratingCount': 0,
      'soldCount': 0,
      'purchases': const <String>[],
      'listings': const <String>[],
      'favorites': const <String>[],
      'followers': const <String>[],
      'following': const <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<ProductModel> createProduct({
    required String title,
    required String brand,
    required double price,
    required String size,
    required String condition,
    required String description,
    required String location,
    required List<String> tags,
    required List<String> images,
    double? latitude,
    double? longitude,
  }) async {
    final userAuth = _currentUserOrThrow();
    final docRef = _products.doc();
    final now = DateTime.now();
    final normalizedImages = _sanitizeImages(images);

    final data = <String, dynamic>{
      'name': title.trim(),
      'brand': brand.trim().isEmpty ? null : brand.trim(),
      'price': price,
      'size': size,
      'condition': condition,
      'description': description.trim(),
      'location': location.trim(),
      'styleTags': tags,
      'ownerId': userAuth.uid,
      'status': 'available',
      'images': normalizedImages,
      'discount': 0,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();
    batch.set(docRef, data);
    batch.set(
      _users.doc(userAuth.uid),
      {
        'listings': FieldValue.arrayUnion([docRef.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    return ProductModel(
      id: docRef.id,
      name: title.trim(),
      price: price,
      size: size,
      images: normalizedImages,
      location: location.trim(),
      description: description.trim(),
      condition: condition,
      ownerId: userAuth.uid,
      brand: brand.trim().isEmpty ? null : brand.trim(),
      styleTags: tags,
      status: ProductStatus.available,
      createdAt: now,
      updatedAt: now,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<void> deleteProduct(String productId) async {
    final userAuth = _currentUserOrThrow();
    final productRef = _products.doc(productId);
    final productDoc = await productRef.get();
    if (!productDoc.exists) {
      throw Exception('El producto ya no existe.');
    }

    final product = _productFromDoc(productDoc);
    if (product.ownerId != userAuth.uid) {
      throw Exception('Solo puedes eliminar tus propias publicaciones.');
    }

    final favoriteUsers = await _users.where('favorites', arrayContains: productId).get();
    final batch = _db.batch();
    batch.delete(productRef);
    batch.set(
      _users.doc(userAuth.uid),
      {
        'listings': FieldValue.arrayRemove([productId]),
        'favorites': FieldValue.arrayRemove([productId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    for (final userDoc in favoriteUsers.docs) {
      batch.update(userDoc.reference, {
        'favorites': FieldValue.arrayRemove([productId]),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> purchaseProduct(String productId) async {
    final userAuth = _currentUserOrThrow();
    final buyerRef = _users.doc(userAuth.uid);
    final productRef = _products.doc(productId);

    await _db.runTransaction((transaction) async {
      final productDoc = await transaction.get(productRef);
      if (!productDoc.exists) {
        throw Exception('El producto ya no esta disponible.');
      }
      final product = _productFromDoc(productDoc);
      if (product.ownerId == userAuth.uid) {
        throw Exception('No puedes comprar tu propia publicacion.');
      }
      if (product.status != ProductStatus.available) {
        throw Exception('El producto ya no esta disponible.');
      }

      final buyerDoc = await transaction.get(buyerRef);
      final buyerBalance = _toDouble(buyerDoc.data()?['balance']);
      if (buyerBalance < product.price) {
        throw Exception('No tienes saldo suficiente para completar la compra.');
      }

      final sellerRef = _users.doc(product.ownerId);
      transaction.set(
        buyerRef,
        {
          'balance': FieldValue.increment(-product.price),
          'purchases': FieldValue.arrayUnion([productId]),
          'favorites': FieldValue.arrayRemove([productId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(
        sellerRef,
        {
          'balance': FieldValue.increment(product.price),
          'soldCount': FieldValue.increment(1),
          'listings': FieldValue.arrayRemove([productId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.update(productRef, {
        'status': 'sold',
        'buyerId': userAuth.uid,
        'soldAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> donateProduct({
    required String productId,
    required String charityId,
  }) async {
    final userAuth = _currentUserOrThrow();
    final productRef = _products.doc(productId);
    final charityDoc = await _charities.doc(charityId).get();
    if (!charityDoc.exists) {
      throw Exception('La fundacion seleccionada no existe.');
    }

    await _db.runTransaction((transaction) async {
      final productDoc = await transaction.get(productRef);
      if (!productDoc.exists) {
        throw Exception('La prenda ya no esta disponible.');
      }
      final product = _productFromDoc(productDoc);
      if (product.ownerId != userAuth.uid) {
        throw Exception('Solo puedes donar prendas de tus publicaciones.');
      }
      if (product.status != ProductStatus.available) {
        throw Exception('La prenda ya no esta disponible para donar.');
      }

      transaction.update(productRef, {
        'status': 'donated',
        'donatedToCharityId': charityId,
        'donatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        _users.doc(userAuth.uid),
        {
          'listings': FieldValue.arrayRemove([productId]),
          'favorites': FieldValue.arrayRemove([productId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<AppUserModel> getCurrentUser() async {
    final userAuth = _currentUserOrThrow();
    final doc = await _users.doc(userAuth.uid).get();

    if (!doc.exists) {
      await saveUserData(
        id: userAuth.uid,
        name: 'Usuario',
        lastname: 'Nuevo',
        email: userAuth.email ?? '',
      );
      final createdDoc = await _users.doc(userAuth.uid).get();
      return _userFromDoc(createdDoc, fallbackId: userAuth.uid);
    }

    return _userFromDoc(doc, fallbackId: userAuth.uid);
  }

  @override
  Future<AppUserModel> getUserById(String userId) async {
    final doc = await _users.doc(userId).get();
    if (!doc.exists) {
      return AppUserModel(
        id: userId,
        name: 'Vendedor',
        lastname: 'Desconocido',
        email: 'no-reply@swapio.app',
        location: 'Sin ubicacion',
        balance: 0,
        memberSince: DateTime.now(),
      );
    }
    return _userFromDoc(doc, fallbackId: userId);
  }

  @override
  Future<void> withdrawBalance(double amount) async {
    final userAuth = _currentUserOrThrow();
    if (amount <= 0) {
      throw Exception('El monto a retirar debe ser mayor a cero.');
    }

    final userRef = _users.doc(userAuth.uid);
    await _db.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      final balance = _toDouble(userDoc.data()?['balance']);
      if (balance < amount) {
        throw Exception('No tienes saldo suficiente para retirar ese monto.');
      }
      transaction.set(
        userRef,
        {
          'balance': FieldValue.increment(-amount),
          'lastWithdrawalAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<List<String>> getProductTags() async {
    return const ['All', 'Trending', 'Dresses', 'Shoes', 'Jackets', 'Accessories', 'Pants'];
  }

  @override
  Future<List<ProductModel>> getTrendingProducts() async {
    final snapshot = await _products.get();
    final products = snapshot.docs
        .map(_productFromDoc)
        .where((product) => product.status == ProductStatus.available)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return products;
  }

  @override
  Future<List<ProductModel>> getProductsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];

    final Map<String, ProductModel> loadedProducts = {};
    for (var index = 0; index < ids.length; index += 10) {
      final chunk = ids.sublist(
        index,
        index + 10 > ids.length ? ids.length : index + 10,
      );
      final snapshot = await _products
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        loadedProducts[doc.id] = _productFromDoc(doc);
      }
    }

    return ids
        .map((id) => loadedProducts[id])
        .whereType<ProductModel>()
        .toList();
  }

  @override
  Future<List<ProductModel>> getProductsForUser(String userId) async {
    final snapshot = await _products.where('ownerId', isEqualTo: userId).get();
    final products = snapshot.docs
        .map(_productFromDoc)
        .where((product) => product.status == ProductStatus.available)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return products;
  }

  @override
  Future<List<ProductModel>> getSuggestions(String productId) async {
    final currentProduct = await getProductById(productId);
    final trending = await getTrendingProducts();
    final suggestions = trending.where((product) {
      if (product.id == productId) return false;
      if (product.ownerId == currentProduct.ownerId) return false;
      return product.styleTags.any(currentProduct.styleTags.contains);
    }).toList();

    if (suggestions.isNotEmpty) {
      return suggestions.take(4).toList();
    }
    return trending.where((product) => product.id != productId).take(4).toList();
  }

  @override
  Future<ProductModel> getProductById(String productId) async {
    final doc = await _products.doc(productId).get();
    if (!doc.exists) {
      throw Exception('El producto que buscas ya no existe.');
    }
    return _productFromDoc(doc);
  }

  @override
  Future<List<CharityModel>> getCharities() async {
    final snapshot = await _charities.get();
    return snapshot.docs.map(_charityFromDoc).toList();
  }

  @override
  Future<CharityModel> getCharityById(String charityId) async {
    final doc = await _charities.doc(charityId).get();
    if (!doc.exists) {
      throw Exception('La fundacion solicitada no existe.');
    }
    return _charityFromDoc(doc);
  }

  @override
  Future<List<DropoffPointModel>> getDropOffPoints() async {
    final snapshot = await _dropOffPoints.get();
    return snapshot.docs.map(_dropOffPointFromDoc).toList();
  }

  @override
  Future<List<ChatChannelModel>> getChatsForCurrentUser() async {
    final userAuth = FirebaseAuth.instance.currentUser;
    if (userAuth == null) return const [];

    final snapshot = await _chats
        .where('participantIds', arrayContains: userAuth.uid)
        .get();
    final chats = snapshot.docs.map(_chatFromDoc).toList()
      ..sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
    return chats;
  }

  @override
  Future<ChatChannelModel> getChatById(String chatId) async {
    final chatDoc = await _chats.doc(chatId).get();
    if (!chatDoc.exists) {
      throw Exception('La conversacion ya no existe.');
    }

    final messagesSnapshot = await _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .get();

    return _chatFromDoc(
      chatDoc,
      messages: _normalizeMessages(
        messagesSnapshot.docs.map(_messageFromDoc).toList(),
      ),
    );
  }

  @override
  Future<String> startChatForProduct(String productId) async {
    final userAuth = _currentUserOrThrow();
    final product = await getProductById(productId);
    if (product.ownerId == userAuth.uid) {
      throw Exception('No puedes iniciar un chat con tu propia publicacion.');
    }

    final existingChats = await _chats
        .where('relatedProductId', isEqualTo: productId)
        .where('participantIds', arrayContains: userAuth.uid)
        .get();

    for (final chatDoc in existingChats.docs) {
      final participantIds = _stringList(chatDoc.data()['participantIds']);
      if (participantIds.contains(product.ownerId)) {
        return chatDoc.id;
      }
    }

    final currentUser = await getCurrentUser();
    final seller = await getUserById(product.ownerId);
    final chatRef = _chats.doc();
    final messageRef = chatRef.collection('messages').doc();
    const initialText = 'Hola! Estoy interesado en tu producto.';

    final batch = _db.batch();
    batch.set(chatRef, {
      'participantIds': [currentUser.id, seller.id],
      'participantNames': {
        currentUser.id: currentUser.fullName,
        seller.id: seller.fullName,
      },
      'participantProfilePics': {
        currentUser.id: currentUser.profilePictureUrl,
        seller.id: seller.profilePictureUrl,
      },
      'lastMessage': initialText,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'unreadCount': 1,
      'relatedProductId': product.id,
      'relatedProductName': product.name,
      'relatedProductPrice': product.price,
      'relatedProductImage': product.images.isEmpty ? null : product.images.first,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(messageRef, {
      'senderId': currentUser.id,
      'text': initialText,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    await batch.commit();

    return chatRef.id;
  }

  @override
  Future<void> sendMessage(String chatId, String text) async {
    final userAuth = _currentUserOrThrow();
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) return;

    final timestamp = FieldValue.serverTimestamp();
    await _chats.doc(chatId).collection('messages').add({
      'senderId': userAuth.uid,
      'text': cleanedText,
      'timestamp': timestamp,
      'isRead': false,
    });
    await _chats.doc(chatId).set({
      'lastMessage': cleanedText,
      'lastMessageTimestamp': timestamp,
      'unreadCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> toggleFavorite(String productId) async {
    final userAuth = _currentUserOrThrow();
    final userRef = _users.doc(userAuth.uid);
    final userDoc = await userRef.get();
    final favorites = _stringList(userDoc.data()?['favorites']);
    final alreadyFavorite = favorites.contains(productId);

    await userRef.set({
      'favorites': alreadyFavorite
          ? FieldValue.arrayRemove([productId])
          : FieldValue.arrayUnion([productId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> toggleFollow(String sellerId) async {
    final userAuth = _currentUserOrThrow();
    if (sellerId == userAuth.uid) {
      throw Exception('No puedes seguir tu propio perfil.');
    }

    final currentUserRef = _users.doc(userAuth.uid);
    final sellerRef = _users.doc(sellerId);

    await _db.runTransaction((transaction) async {
      final currentUserDoc = await transaction.get(currentUserRef);
      final following = _stringList(currentUserDoc.data()?['following']);
      final isFollowing = following.contains(sellerId);

      transaction.set(
        currentUserRef,
        {
          'following': isFollowing
              ? FieldValue.arrayRemove([sellerId])
              : FieldValue.arrayUnion([sellerId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(
        sellerRef,
        {
          'followers': isFollowing
              ? FieldValue.arrayRemove([userAuth.uid])
              : FieldValue.arrayUnion([userAuth.uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  User _currentUserOrThrow() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesion para continuar.');
    }
    return user;
  }

  AppUserModel _userFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String fallbackId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUserModel(
      id: doc.id.isEmpty ? fallbackId : doc.id,
      name: _asString(data['name'], fallback: 'Usuario'),
      lastname: _asString(data['lastname']),
      email: _asString(data['email']),
      location: _asString(data['location'], fallback: 'Sin especificar'),
      balance: _toDouble(data['balance']),
      memberSince: _parseDate(data['createdAt']),
      profilePictureUrl: _nullableString(data['profilePictureUrl']),
      number: _asString(data['number']),
      rating: _toDouble(data['rating'], fallback: 4.8),
      ratingCount: _toInt(data['ratingCount']),
      soldCount: _toInt(data['soldCount']),
      purchases: _stringList(data['purchases']),
      listings: _stringList(data['listings']),
      favorites: _stringList(data['favorites']),
      followers: _stringList(data['followers']),
      following: _stringList(data['following']),
    );
  }

  ProductModel _productFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ProductModel(
      id: doc.id,
      name: _asString(data['name'], fallback: 'Sin nombre'),
      price: _toDouble(data['price']),
      size: _asString(data['size'], fallback: 'N/A'),
      images: _sanitizeImages(_stringList(data['images'])),
      location: _asString(data['location'], fallback: 'Sin ubicacion'),
      description: _asString(data['description']),
      condition: _asString(data['condition'], fallback: 'Desconocida'),
      ownerId: _asString(data['ownerId']),
      discount: _toDouble(data['discount']),
      brand: _nullableString(data['brand']),
      latitude: _nullableDouble(data['latitude']),
      longitude: _nullableDouble(data['longitude']),
      styleTags: _stringList(data['styleTags']),
      status: _productStatus(data['status']),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  CharityModel _charityFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CharityModel(
      id: doc.id,
      name: _asString(data['name'], fallback: 'Fundacion sin nombre'),
      location: _asString(data['location'], fallback: 'Sin ubicacion'),
      description: _asString(data['description']),
      impact: _asString(data['impact']),
      distance: _asString(data['distance']),
      tags: _stringList(data['tags']),
      email: _asString(data['email']),
      number: _asString(data['number']),
      website: _asString(data['website']),
    );
  }

  DropoffPointModel _dropOffPointFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return DropoffPointModel(
      id: doc.id,
      name: _asString(data['name'], fallback: 'Punto de entrega'),
      address: _asString(data['address'], fallback: 'Direccion no disponible'),
      city: _asString(data['city'], fallback: 'Ciudad'),
      latitude: _toDouble(data['latitude']),
      longitude: _toDouble(data['longitude']),
      opensAt: _asString(data['opensAt'], fallback: '00:00'),
      closesAt: _asString(data['closesAt'], fallback: '00:00'),
    );
  }

  ChatChannelModel _chatFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    List<ChatMessageModel> messages = const [],
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ChatChannelModel(
      id: doc.id,
      participantIds: _stringList(data['participantIds']),
      participantNames: _stringMap(data['participantNames']),
      participantProfilePics: _nullableStringMap(data['participantProfilePics']),
      lastMessage: _asString(data['lastMessage']),
      lastMessageTimestamp: _parseDate(data['lastMessageTimestamp']),
      unreadCount: _toInt(data['unreadCount']),
      relatedProductId: _nullableString(data['relatedProductId']),
      relatedProductName: _nullableString(data['relatedProductName']),
      relatedProductPrice: _nullableDouble(data['relatedProductPrice']),
      relatedProductImage: _nullableString(data['relatedProductImage']),
      messages: messages,
    );
  }

  ChatMessageModel _messageFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ChatMessageModel(
      id: doc.id,
      senderId: _asString(data['senderId']),
      text: _asString(data['text']),
      timestamp: _parseDate(data['timestamp']),
      isRead: data['isRead'] == true,
    );
  }

  List<ChatMessageModel> _normalizeMessages(List<ChatMessageModel> messages) {
    final unique = <String, ChatMessageModel>{};
    for (final message in messages) {
      final key =
          '${message.id}_${message.senderId}_${message.timestamp.toIso8601String()}_${message.text}';
      unique[key] = message;
    }
    final normalized = unique.values.toList();
    normalized.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return normalized;
  }

  List<String> _sanitizeImages(List<String> images) {
    final normalized = images
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (normalized.isEmpty) {
      return const ['#90CAF9', '#E3F2FD'];
    }
    return normalized;
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  Map<String, String> _stringMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
      );
    }
    return const {};
  }

  Map<String, String?> _nullableStringMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item?.toString()),
      );
    }
    return const {};
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? fallback : stringValue;
  }

  String? _nullableString(dynamic value) {
    if (value == null) return null;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  ProductStatus _productStatus(dynamic value) {
    switch (_asString(value)) {
      case 'sold':
        return ProductStatus.sold;
      case 'donated':
        return ProductStatus.donated;
      default:
        return ProductStatus.available;
    }
  }
}
