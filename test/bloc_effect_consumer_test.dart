import 'package:bloc_after_effect/bloc_after_effect.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// --- Test bloc ---

abstract class TestEvent {}

abstract class TestEffect {}

class ShowMessage extends TestEffect {
  ShowMessage(this.text);
  final String text;
}

class TestBloc extends EffectBloc<TestEvent, int, TestEffect> {
  TestBloc() : super(0);

  void setState(int next) => emit(next);
  void triggerEffect(TestEffect effect) => emitEffect(effect);
}

void main() {
  group('BlocEffectConsumer', () {
    late TestBloc bloc;

    setUp(() {
      bloc = TestBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    testWidgets('builder rebuilds on state change', (tester) async {
      final built = <int>[];

      await tester.pumpWidget(
        BlocEffectConsumer<TestBloc, int, TestEffect>(
          bloc: bloc,
          builder: (context, state) {
            built.add(state);
            return const SizedBox();
          },
        ),
      );

      expect(built, [0]);

      bloc.setState(1);
      await tester.pumpAndSettle();
      bloc.setState(2);
      await tester.pumpAndSettle();

      expect(built, [0, 1, 2]);
    });

    testWidgets('state listener called when provided', (tester) async {
      final received = <int>[];

      await tester.pumpWidget(
        BlocEffectConsumer<TestBloc, int, TestEffect>(
          bloc: bloc,
          listener: (context, state) => received.add(state),
          builder: (context, state) => const SizedBox(),
        ),
      );

      // listener fires on changes, not initial build
      bloc.setState(1);
      await tester.pumpAndSettle();
      bloc.setState(2);
      await tester.pumpAndSettle();

      expect(received, [1, 2]);
    });

    testWidgets('state listener omitted works', (tester) async {
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        BlocEffectConsumer<TestBloc, int, TestEffect>(
          bloc: bloc,
          effectListener: (context, effect) => effects.add(effect),
          builder: (context, state) => const SizedBox(),
        ),
      );

      bloc.setState(5);
      bloc.triggerEffect(ShowMessage('hi'));
      await tester.pump();

      expect(effects, hasLength(1));
    });

    testWidgets('effectListener called on emitted effect', (tester) async {
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        BlocEffectConsumer<TestBloc, int, TestEffect>(
          bloc: bloc,
          effectListener: (context, effect) => effects.add(effect),
          builder: (context, state) => const SizedBox(),
        ),
      );

      bloc.triggerEffect(ShowMessage('hello'));
      await tester.pump();

      expect(effects, hasLength(1));
      expect((effects.first as ShowMessage).text, 'hello');
    });

    testWidgets('effectListener omitted works', (tester) async {
      final states = <int>[];

      await tester.pumpWidget(
        BlocEffectConsumer<TestBloc, int, TestEffect>(
          bloc: bloc,
          listener: (context, state) => states.add(state),
          builder: (context, state) => const SizedBox(),
        ),
      );

      // Emit an effect — should be silently dropped
      bloc.triggerEffect(ShowMessage('dropped'));
      bloc.setState(1);
      await tester.pump();

      expect(states, [1]);
    });

    testWidgets('both listeners together', (tester) async {
      final states = <int>[];
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        BlocEffectConsumer<TestBloc, int, TestEffect>(
          bloc: bloc,
          listener: (context, state) => states.add(state),
          effectListener: (context, effect) => effects.add(effect),
          builder: (context, state) => const SizedBox(),
        ),
      );

      bloc.setState(1);
      bloc.triggerEffect(ShowMessage('a'));
      await tester.pump();

      expect(states, [1]);
      expect(effects, hasLength(1));
    });

    testWidgets('listenWhen filters state listener', (tester) async {
      final received = <int>[];

      await tester.pumpWidget(
        BlocEffectConsumer<TestBloc, int, TestEffect>(
          bloc: bloc,
          listener: (context, state) => received.add(state),
          listenWhen: (prev, curr) => curr.isEven,
          builder: (context, state) => const SizedBox(),
        ),
      );

      bloc.setState(1);
      await tester.pumpAndSettle();
      bloc.setState(2);
      await tester.pumpAndSettle();
      bloc.setState(3);
      await tester.pumpAndSettle();
      bloc.setState(4);
      await tester.pumpAndSettle();

      expect(received, [2, 4]);
    });

    testWidgets('buildWhen filters builder', (tester) async {
      final built = <int>[];

      await tester.pumpWidget(
        BlocEffectConsumer<TestBloc, int, TestEffect>(
          bloc: bloc,
          buildWhen: (prev, curr) => curr.isEven,
          builder: (context, state) {
            built.add(state);
            return const SizedBox();
          },
        ),
      );

      // initial build from state 0
      expect(built, [0]);

      bloc.setState(1);
      await tester.pumpAndSettle();
      bloc.setState(2);
      await tester.pumpAndSettle();
      bloc.setState(3);
      await tester.pumpAndSettle();
      bloc.setState(4);
      await tester.pumpAndSettle();

      expect(built, [0, 2, 4]);
    });

    testWidgets('bloc switch re-subscribes effectListener', (tester) async {
      final effects = <TestEffect>[];
      final blocA = TestBloc();
      final blocB = TestBloc();
      addTearDown(() async {
        await blocA.close();
        await blocB.close();
      });

      Widget build(TestBloc b) => BlocEffectConsumer<TestBloc, int, TestEffect>(
            bloc: b,
            effectListener: (context, effect) => effects.add(effect),
            builder: (context, state) => const SizedBox(),
          );

      await tester.pumpWidget(build(blocA));
      blocA.triggerEffect(ShowMessage('from-a'));
      await tester.pump();
      expect(effects, hasLength(1));

      // Swap to blocB — old subscription must be cancelled
      await tester.pumpWidget(build(blocB));
      blocA.triggerEffect(ShowMessage('after-swap-from-a'));
      blocB.triggerEffect(ShowMessage('from-b'));
      await tester.pump();

      expect(effects, hasLength(2));
      expect((effects.last as ShowMessage).text, 'from-b');
    });

    testWidgets('no listener called after dispose', (tester) async {
      final states = <int>[];
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        BlocEffectConsumer<TestBloc, int, TestEffect>(
          bloc: bloc,
          listener: (context, state) => states.add(state),
          effectListener: (context, effect) => effects.add(effect),
          builder: (context, state) => const SizedBox(),
        ),
      );

      await tester.pumpWidget(const SizedBox());

      bloc.setState(1);
      bloc.triggerEffect(ShowMessage('late'));
      await tester.pump();

      expect(states, isEmpty);
      expect(effects, isEmpty);
    });
  });
}
