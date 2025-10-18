// lib/pages/explore_tab_shell.dart
import 'package:flutter/material.dart';
import 'explore_page.dart';
import 'hashtag_feed_page.dart';

// lib/pages/explore_tab_shell.dart
class ExploreTabShell extends StatelessWidget {
  const ExploreTabShell({super.key, required this.navKey});
  final GlobalKey<NavigatorState> navKey;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !(await navKey.currentState!.maybePop()),
      child: Navigator(
        key: navKey,
        onGenerateRoute: (settings) {
          if (settings.name == HashtagFeedPage.routeName) {
            final tag = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => HashtagFeedPage(hashtag: tag),
              settings: settings,
            );
          }
          return MaterialPageRoute(
            builder: (_) => const ExplorePage(),
            settings: const RouteSettings(name: '/explore/root'),
          );
        },
      ),
    );
  }
}