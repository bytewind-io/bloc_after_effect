import 'package:bloc_after_effect/bloc_after_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// --- Events ---

abstract class CounterEvent {}

class Increment extends CounterEvent {}

class SavePressed extends CounterEvent {}

// --- State ---

class CounterState {
  const CounterState({this.count = 0, this.isSaving = false});

  final int count;
  final bool isSaving;

  CounterState copyWith({int? count, bool? isSaving}) => CounterState(
        count: count ?? this.count,
        isSaving: isSaving ?? this.isSaving,
      );
}

// --- Effects ---

abstract class CounterEffect {}

class ShowSavedSnackBar extends CounterEffect {
  ShowSavedSnackBar(this.count);

  final int count;
}

class ShowErrorDialog extends CounterEffect {
  ShowErrorDialog(this.message);

  final String message;
}

// --- Bloc ---
class CounterBloc
    extends EffectBloc<CounterEvent, CounterState, CounterEffect> {
  CounterBloc() : super(const CounterState()) {
    on<Increment>((event, emit) {
      emit(state.copyWith(count: state.count + 1));
    });

    on<SavePressed>((event, emit) async {
      emit(state.copyWith(isSaving: true));

      // Simulate async save
      await Future<void>.delayed(const Duration(milliseconds: 500));

      emit(state.copyWith(isSaving: false));

      if (state.count > 10) {
        emitEffect(ShowErrorDialog('Count too high to save!'));
      } else {
        emitEffect(ShowSavedSnackBar(state.count));
      }
    });
  }
}

// --- App ---

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EffectBloc Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (_) => CounterBloc(),
        child: const CounterPage(),
      ),
    );
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EffectBloc Example')),
      body: Center(
        child: BlocEffectBuilder<CounterBloc, CounterState, CounterEffect>(
          effectListener: (context, effect) {
            if (effect is ShowSavedSnackBar) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saved! Count was ${effect.count}')),
              );
            } else if (effect is ShowErrorDialog) {
              showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Error'),
                  content: Text(effect.message),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          },
          builder: (context, state) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${state.count}',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 16),
                if (state.isSaving)
                  const CircularProgressIndicator()
                else
                  FilledButton(
                    onPressed: () =>
                        context.read<CounterBloc>().add(SavePressed()),
                    child: const Text('Save'),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<CounterBloc>().add(Increment()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
