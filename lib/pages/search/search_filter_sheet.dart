part of 'search_page.dart';

class _SearchFilterSheet extends StatelessWidget {
  const _SearchFilterSheet({
    required this.initialState,
    required this.initialNotShowWatched,
    required this.initialNotShowAbandoned,
  });

  final SearchFilterState initialState;
  final bool initialNotShowWatched;
  final bool initialNotShowAbandoned;

  @override
  Widget build(BuildContext context) {
    return SearchFilterPanel(
      initialState: initialState,
      initialNotShowWatched: initialNotShowWatched,
      initialNotShowAbandoned: initialNotShowAbandoned,
      onApply: (result) => Navigator.pop(context, result),
      onClose: () => Navigator.pop(context),
    );
  }
}
