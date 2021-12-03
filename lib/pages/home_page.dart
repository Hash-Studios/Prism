import 'package:flutter/material.dart';
import 'package:prism/controllers/theme_controller.dart';
import 'package:prism/services/logger.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    logger.d('App init done.');
  }

  void _incrementCounter() {
    // context.read<ThemeController>().setDarkIsTrueBlack(false);
    context.read<ThemeController>().setSchemeIndex(
          (context.read<ThemeController>().schemeIndex + 1) % 40,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prism'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 56 + 8,
        width: MediaQuery.of(context).size.width,
        child: BottomNavigationBar(
          selectedFontSize: 12,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              activeIcon: Icon(Icons.image),
              icon: Icon(Icons.image_outlined),
              label: 'Walls',
            ),
            BottomNavigationBarItem(
              activeIcon: Icon(Icons.imagesearch_roller),
              icon: Icon(Icons.imagesearch_roller_outlined),
              label: 'Setups',
            ),
            BottomNavigationBarItem(
              activeIcon: Icon(Icons.notifications),
              icon: Icon(Icons.notifications_outlined),
              label: 'Notifications',
            ),
            BottomNavigationBarItem(
              activeIcon: Icon(Icons.person),
              icon: Icon(Icons.person_outlined),
              label: 'Profile',
            ),
          ],
        ),
      ),
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Current theme index:',
                ),
                Text(
                  '${context.read<ThemeController>().schemeIndex}',
                  style: Theme.of(context).textTheme.headline4,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
