import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_after_effect/bloc_after_effect.dart';

// --- Test events, states, effects ---

abstract class TestEvent {}

class IncrementEvent extends TestEvent {}

class TriggerEffectEvent extends TestEvent {
  TriggerEffectEvent(this.message);
  final String message;
}

abstract class TestEffect {}

class ShowSnackbar extends TestEffect {
  ShowSnackbar(this.message);
  final String message;
}

// --- Test bloc ---

class TestBloc extends EffectBloc<TestEvent, int, TestEffect> {
  TestBloc() : super(0) {
    on<IncrementEvent>((event, emit) => emit(state + 1));
    on<TriggerEffectEvent>((event, emit) {
      emitEffect(ShowSnackbar(event.message));
    });
  }
}

void main() {
  group('EffectBloc', () {
    late TestBloc bloc;

    setUp(() {
      bloc = TestBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    test('emitEffect sends effect through effects stream', () async {
      final effects = <TestEffect>[];
      bloc.effects.listen(effects.add);

      bloc.add(TriggerEffectEvent('hello'));

      await Future<void>.delayed(Duration.zero);
      expect(effects, hasLength(1));
      expect((effects.first as ShowSnackbar).message, 'hello');
    });

    test('effects stream is broadcast — multiple listeners receive', () async {
      final effects1 = <TestEffect>[];
      final effects2 = <TestEffect>[];

      bloc.effects.listen(effects1.add);
      bloc.effects.listen(effects2.add);

      bloc.add(TriggerEffectEvent('broadcast'));

      await Future<void>.delayed(Duration.zero);
      expect(effects1, hasLength(1));
      expect(effects2, hasLength(1));
    });

    test('state and effects work independently', () async {
      final effects = <TestEffect>[];
      bloc.effects.listen(effects.add);

      bloc.add(IncrementEvent());
      bloc.add(TriggerEffectEvent('effect'));
      bloc.add(IncrementEvent());

      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, 2);
      expect(effects, hasLength(1));
    });

    test('close disposes effects stream', () async {
      await bloc.close();

      expect(
        () => bloc.emitEffect(ShowSnackbar('late')),
        throwsStateError,
      );
    });
  });
}
