import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef MainPageState = ({int index, String? search, String? ranking_category});

extension MainPageStateCopy on MainPageState {
  MainPageState copyWith({
    int? index,
    String? search,
    String? ranking_category,
  }) {
    return (
      index: index ?? this.index,
      search: search ?? this.search,
      ranking_category: ranking_category ?? this.ranking_category,
    );
  }
}

final kInitialMainPageState = (
  index: 0,
  search: null,
  ranking_category: null,
);

final mainPageProvider = StateProvider<MainPageState>(
  (ref) => kInitialMainPageState,
);