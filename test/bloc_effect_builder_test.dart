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
  group('BlocEffectBuilder', () {
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
        BlocEffectBuilder<TestBloc, int, TestEffect>(
          bloc: bloc,
          effectListener: (context, effect) {},
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

    testWidgets('effectListener called on emitted effect', (tester) async {
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        BlocEffectBuilder<TestBloc, int, TestEffect>(
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

    testWidgets('buildWhen filters builder', (tester) async {
      final built = <int>[];

      await tester.pumpWidget(
        BlocEffectBuilder<TestBloc, int, TestEffect>(
          bloc: bloc,
          effectListener: (context, effect) {},
          buildWhen: (prev, curr) => curr.isEven,
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

      Widget build(TestBloc b) => BlocEffectBuilder<TestBloc, int, TestEffect>(
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
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        BlocEffectBuilder<TestBloc, int, TestEffect>(
          bloc: bloc,
          effectListener: (context, effect) => effects.add(effect),
          builder: (context, state) => const SizedBox(),
        ),
      );

      await tester.pumpWidget(const SizedBox());

      bloc.triggerEffect(ShowMessage('late'));
      await tester.pump();

      expect(effects, isEmpty);
    });
  });
}
