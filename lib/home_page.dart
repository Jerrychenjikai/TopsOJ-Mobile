import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          // Assuming each card needs at least 250px width for readability
          int columns = (constraints.maxWidth / 250).floor();
          if (columns < 1) columns = 1;
          if (columns > 3) columns = 3; // Limit to max 3 since we have only 3 cards

          return SafeArea( // Wrap with SafeArea to handle notches and insets
            child: GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 1.5, // Adjust ratio for card content
              ),
              itemCount: 3, // 3 cards as per request (2~3)
              itemBuilder: (context, index) {
                return Card(
                  elevation: 4.0,
                  color: Theme.of(context).colorScheme.surface, // Use theme surface color for cards
                  shadowColor: Theme.of(context).colorScheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Card ${index + 1}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface, // Use theme text color
                              ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'This is some fake information for card ${index + 1}. '
                          'It includes a title and a description to demonstrate the layout.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface, // Use theme text color
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}