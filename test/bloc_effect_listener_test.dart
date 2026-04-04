import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_after_effect/bloc_after_effect.dart';

// --- Test bloc that exposes emitEffect publicly for testing ---

abstract class TestEvent {}

abstract class TestEffect {}

class ShowMessage extends TestEffect {
  ShowMessage(this.text);
  final String text;
}

class TestBloc extends EffectBloc<TestEvent, int, TestEffect> {
  TestBloc() : super(0);

  void triggerEffect(TestEffect effect) => emitEffect(effect);
}

void main() {
  group('BlocEffectListener', () {
    late TestBloc bloc;

    setUp(() {
      bloc = TestBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    testWidgets('calls listener when effect is emitted', (tester) async {
      final received = <TestEffect>[];

      await tester.pumpWidget(
        BlocProvider<TestBloc>.value(
          value: bloc,
          child: BlocEffectListener<TestBloc, TestEffect>(
            listener: (context, effect) => received.add(effect),
            child: const SizedBox(),
          ),
        ),
      );

      bloc.triggerEffect(ShowMessage('hello'));
      await tester.pump();

      expect(received, hasLength(1));
      expect((received.first as ShowMessage).text, 'hello');
    });

    testWidgets('uses explicit bloc when provided', (tester) async {
      final received = <TestEffect>[];

      await tester.pumpWidget(
        BlocEffectListener<TestBloc, TestEffect>(
          bloc: bloc,
          listener: (context, effect) => received.add(effect),
          child: const SizedBox(),
        ),
      );

      bloc.triggerEffect(ShowMessage('explicit'));
      await tester.pump();

      expect(received, hasLength(1));
      expect((received.first as ShowMessage).text, 'explicit');
    });

    testWidgets('does not call listener after dispose', (tester) async {
      final received = <TestEffect>[];

      await tester.pumpWidget(
        BlocEffectListener<TestBloc, TestEffect>(
          bloc: bloc,
          listener: (context, effect) => received.add(effect),
          child: const SizedBox(),
        ),
      );

      // Remove listener widget
      await tester.pumpWidget(const SizedBox());

      bloc.triggerEffect(ShowMessage('late'));
      await tester.pump();

      expect(received, isEmpty);
    });
  });
}
