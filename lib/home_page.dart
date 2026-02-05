import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:TopsOJ/index_providers.dart';
import 'package:TopsOJ/basic_func.dart';
import "package:TopsOJ/perfect_square.dart";

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // You can access Riverpod providers here if needed, e.g., ref.watch(someProvider);
    // For now, assuming no specific providers are required.

    return Container(
      color: Theme.of(context).colorScheme.background, // Use theme background color
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate number of columns based on screen width
          int columns = (constraints.maxWidth / 400).floor();
          if (columns < 1) columns = 1;
          if (columns > 2) columns = 2; // Limit to max 2 to match Bootstrap col-lg-6 (2 columns on large screens)

          // Define per-card data to match HTML
          final List<String> emojis = ['🎯', '📆', '🎮'];
          final List<String> titles = [
            'Practice Problems',
            'Problem of the Day',
            'Math Games',
          ];
          final List<String> descriptions = [
            'Explore thousands of curated problems from major contests and filter by your favourite category.',
            'POTDs are currently being shared directly in our Discord community while we refresh the on-site experience.',
            'Level up your instincts with interactive games focused on speed, precision, and mental agility.',
          ];
          final List<Color> iconColors = [
            Colors.blue,
            Colors.pink,
            Colors.green,
          ];
          final List<Color> buttonOutlineColors = [
            Colors.blue,
            Colors.grey,
            Colors.green,
          ];

          // Function to build a single card widget
          Widget buildCardWidget(int index) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0), // Inner padding to match card-body p-4 (~16px)
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: iconColors[index].withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            emojis[index],
                            style: TextStyle(fontSize: 24, color: iconColors[index]),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          titles[index],
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      descriptions[index],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 16.0),
                    if (index == 0) ...[
                      // Buttons for Practice Problems
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(color: Colors.blue),
                            ),
                            onPressed: () {
                              ref.read(mainPageProvider.notifier).update((state) => (
                                index: 1,
                                search: null,
                              ));
                            },
                            child: const Text('All Problems', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          /*OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(color: Colors.grey),
                            ),
                            onPressed: () {
                              //add code to jump
                            },
                            child: const Text('Global Rankings', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),*/
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      // Accordion for categories
                      ExpansionTile(
                        title: const Text('MAA Categories'),
                        collapsedShape: const Border(),           // 收起时无边框
                        shape: const Border(),
                        children: [
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: [
                              'AMC 8',
                              'AMC 10A',
                              'AMC 10B',
                              'AMC 12A',
                              'AMC 12B',
                              'AIME I',
                              'AIME II'
                            ].map((cat) => OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: const StadiumBorder(),
                                side: BorderSide(color: Colors.grey),
                              ),
                              onPressed: () {
                                ref.read(mainPageProvider.notifier).update((state) => (
                                  index: 1,
                                  search: cat,
                                ));
                              },
                              child: Text(cat),
                            )).toList(),
                          ),
                        ],
                      ),
                      ExpansionTile(
                        title: const Text('CEMC Categories'),
                        collapsedShape: const Border(),
                        shape: const Border(),
                        children: [
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: [
                              'Pascal',
                              'Cayley',
                              'Fermat'
                            ].map((cat) => OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: const StadiumBorder(),
                                side: BorderSide(color: Colors.grey),
                              ),
                              onPressed: () {
                                ref.read(mainPageProvider.notifier).update((state) => (
                                  index: 1,
                                  search: cat,
                                ));
                              },
                              child: Text(cat),
                            )).toList(),
                          ),
                        ],
                      ),
                    ] else if (index == 1) ...[
                      // Buttons for POTD
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(color: Colors.grey),
                            ),
                            onPressed: () {
                              launchURL(context, "https://discord.com/invite/zUdmCWPT3f");
                            },
                            child: const Text('View POTDs on Discord', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(color: Colors.grey),
                            ),
                            onPressed: () {
                              ref.read(mainPageProvider.notifier).update((state) => (
                                index: 1,
                                search: "potd",
                              ));
                            },
                            child: const Text('View earlier POTDs on site', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Join the discussion, get hints, and see the latest POTD drops in the #potd Discord channel.',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ] else if (index == 2) ...[
                      // List for Math Games
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Chip(
                                label: const Text('Mental Math'),
                                backgroundColor: Colors.green.withOpacity(0.1),
                                labelStyle: const TextStyle(color: Colors.green),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(child: const Text('Train your brain with custom drills.'),),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            children: [
                              Chip(
                                label: const Text('Triangulate'),
                                backgroundColor: Colors.green.withOpacity(0.1),
                                labelStyle: const TextStyle(color: Colors.green),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(child: const Text('Race to locate triangle centers.'),),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            children: [
                              Chip(
                                label: const Text('Be Perfect²'),
                                backgroundColor: Colors.green.withOpacity(0.1),
                                labelStyle: const TextStyle(color: Colors.green),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(child: const Text('Master perfect squares lightning fast.'),),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      // Game buttons
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(color: Colors.green),
                            ),
                            onPressed: () {
                              //add code to jump
                            },
                            child: const Text('Mental Math'),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(color: Colors.green),
                            ),
                            onPressed: () {
                              //add code to jump
                            },
                            child: const Text('Triangulate'),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(color: Colors.green),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => BePerfectWidget()),
                              );
                            },
                            child: const Text('Be Perfect²'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      // Ranking buttons
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(color: Colors.grey),
                            ),
                            onPressed: () {
                              //add code to jump
                            },
                            child: const Text('Triangulate Rankings'),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(color: Colors.grey),
                            ),
                            onPressed: () {
                              //add code to jump
                            },
                            child: const Text('Mental Math Rankings'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          // Function to add separators between widgets
          List<Widget> withSeparators(List<Widget> widgets) {
            if (widgets.isEmpty) return [];
            List<Widget> result = [widgets[0]];
            for (var i = 1; i < widgets.length; i++) {
              result.add(const SizedBox(height: 16.0));
              result.add(widgets[i]);
            }
            return result;
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: columns >= 2
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: withSeparators([0].map(buildCardWidget).toList()),
                            ),
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: withSeparators([1,2].map(buildCardWidget).toList()),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: withSeparators([0, 1, 2].map(buildCardWidget).toList()),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}