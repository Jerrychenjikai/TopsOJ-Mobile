import 'package:flutter_riverpod/flutter_riverpod.dart';

final mainPageProvider = StateProvider<({int index, String? search})>((ref) => (index: 0, search: null));