import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:med_scheme/features/editor/data/services/custom_stamps_service.dart';
import 'package:med_scheme/features/editor/domain/entities/draw_action.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_bloc.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_event.dart';
import 'package:med_scheme/features/editor/presentation/widgets/toolbox/floating_toolbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    SharedPreferences.setMockInitialValues({});
  });

  group('CustomStampItem & Service Tests', () {
    test('CustomStampItem json serialization and deserialization', () {
      final item = CustomStampItem(
        id: 'stamp_1',
        name: 'Тестовый штамп',
        groupId: 'endometrioma',
        imagePath: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        createdAt: 1725530000000,
      );

      final jsonMap = item.toJson();
      expect(jsonMap['id'], 'stamp_1');
      expect(jsonMap['name'], 'Тестовый штамп');
      expect(jsonMap['groupId'], 'endometrioma');
      expect(jsonMap['imagePath'], startsWith('data:image/png;base64,'));

      final fromJson = CustomStampItem.fromJson(jsonMap);
      expect(fromJson.id, item.id);
      expect(fromJson.name, item.name);
      expect(fromJson.groupId, item.groupId);
      expect(fromJson.imagePath, item.imagePath);
      expect(fromJson.createdAt, item.createdAt);
    });

    test('CustomStampsService group operations and custom groups', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = CustomStampsService(prefs);

      // Initially empty
      final initialStamps = await service.loadCustomStamps();
      expect(initialStamps, isEmpty);

      final initialGroups = await service.loadCustomGroups();
      expect(initialGroups, isEmpty);

      // Add a custom group
      await service.addCustomGroup('Хирургия');
      final groupsAfter = await service.loadCustomGroups();
      expect(groupsAfter, contains('Хирургия'));

      // Add stamp with base64 data to custom group
      const base64Png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      final stamp = await service.addCustomStamp(
        name: 'Клипса',
        groupId: 'Хирургия',
        sourceFilePath: base64Png,
      );
      expect(stamp, isNotNull);
      expect(stamp!.name, 'Клипса');
      expect(stamp.groupId, 'Хирургия');

      var stamps = await service.loadCustomStamps();
      expect(stamps.length, 1);
      expect(stamps.first.name, 'Клипса');
      expect(stamps.first.groupId, 'Хирургия');

      // Update stamp group to endometrioma
      await service.updateCustomStampGroup(stamp.id, 'endometrioma');
      stamps = await service.loadCustomStamps();
      expect(stamps.first.groupId, 'endometrioma');

      // Delete stamp
      await service.deleteCustomStamp(stamp.id);
      stamps = await service.loadCustomStamps();
      expect(stamps, isEmpty);
    });
  });

  group('DrawBloc Custom Stamp Grouping Integration Tests', () {
    late DrawBloc drawBloc;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      drawBloc = DrawBloc();
    });

    tearDown(() {
      drawBloc.close();
    });

    test('AddCustomStampItemEvent adds stamp to state and selects it', () async {
      const base64Png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

      final expectation = expectLater(
        drawBloc.stream,
        emitsThrough(predicate<dynamic>((state) {
          return state.customStampItems.isNotEmpty &&
              state.customStampItems.first.name == 'Штамп 1';
        })),
      );

      drawBloc.add(AddCustomStampItemEvent(
        name: 'Штамп 1',
        groupId: 'custom_stamps',
        sourceFilePath: base64Png,
      ));

      await expectation;

      final state = drawBloc.state;
      expect(state.customStampItems.length, 1);
      expect(state.customStampItems.first.groupId, 'custom_stamps');
      expect(state.activeStampItem?.name, 'Штамп 1');
      expect(state.currentTool, ToolType.customStamp);
    });

    test('CreateCustomGroupEvent and UpdateCustomStampGroupEvent work correctly', () async {
      final expGroup = expectLater(
        drawBloc.stream,
        emitsThrough(predicate<dynamic>((state) {
          return state.customGroups.contains('Новая Группа');
        })),
      );
      drawBloc.add(CreateCustomGroupEvent('Новая Группа'));
      await expGroup;

      const base64Png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      final expStamp = expectLater(
        drawBloc.stream,
        emitsThrough(predicate<dynamic>((state) {
          return state.customStampItems.any((s) => s.name == 'Штамп 2');
        })),
      );
      drawBloc.add(AddCustomStampItemEvent(
        name: 'Штамп 2',
        groupId: 'endometrioma',
        sourceFilePath: base64Png,
      ));
      await expStamp;

      final stampId = drawBloc.state.customStampItems.first.id;
      final expUpdate = expectLater(
        drawBloc.stream,
        emitsThrough(predicate<dynamic>((state) {
          final s = state.customStampItems.firstWhere((item) => item.id == stampId);
          return s.groupId == 'Новая Группа';
        })),
      );
      drawBloc.add(UpdateCustomStampGroupEvent(
        id: stampId,
        newGroupId: 'Новая Группа',
      ));
      await expUpdate;

      // Delete stamp
      final expDelete = expectLater(
        drawBloc.stream,
        emitsThrough(predicate<dynamic>((state) {
          return state.customStampItems.isEmpty;
        })),
      );
      drawBloc.add(DeleteCustomStampItemEvent(stampId));
      await expDelete;
    });
  });

  group('FloatingToolbox Dynamic Grouping UI Tests', () {
    testWidgets('Single-item group renders standalone without chevron; multi-item group has chevron', (tester) async {
      final drawBloc = DrawBloc();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: drawBloc,
              child: FloatingToolbox(
                currentTool: ToolType.pencil,
                orientation: ToolboxOrientation.verticalLeft,
                onToolSelected: (_) {},
                onDragUpdate: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Find Endometrioma button (it has 1 item by default, so it is standalone with 'Эндомет.')
      expect(find.text('Эндомет.'), findsOneWidget);

      // Now add a custom stamp into the 'endometrioma' group
      final stamp = CustomStampItem(
        id: 'stamp_endo',
        name: 'Эндо-штамп',
        groupId: 'endometrioma',
        imagePath: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        createdAt: 1725530000000,
      );

      // Manually emit state with this stamp in endometrioma
      drawBloc.emit(drawBloc.state.copyWith(
        customStampItems: [stamp],
      ));

      await tester.pump();

      // Now endometrioma has 2 items -> it renders as an expandable group with chevron (keyboard_arrow_down in vertical)
      expect(find.byIcon(Icons.keyboard_arrow_down), findsWidgets);

      // Now remove the stamp from endometrioma by updating state back to empty
      drawBloc.emit(drawBloc.state.copyWith(
        customStampItems: [],
      ));

      await tester.pump();

      // Back to standalone tool button
      expect(find.text('Эндомет.'), findsOneWidget);

      drawBloc.close();
    });

    testWidgets('Custom group is displayed when created (empty, 1 item, multiple items)', (tester) async {
      final drawBloc = DrawBloc();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: drawBloc,
              child: FloatingToolbox(
                currentTool: ToolType.pencil,
                orientation: ToolboxOrientation.verticalLeft,
                onToolSelected: (_) {},
                onDragUpdate: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // 1. Create a custom group 'Лимфоузлы' with no stamps yet
      drawBloc.emit(drawBloc.state.copyWith(
        customGroups: ['Лимфоузлы'],
        customStampItems: [],
      ));
      await tester.pumpAndSettle();

      // The group must be displayed! (Formatted vertically as 'Лимфоу.')
      expect(find.text('Лимфоу.', skipOffstage: false), findsOneWidget);

      // 2. Add 1 stamp into 'Лимфоузлы'
      final stamp1 = CustomStampItem(
        id: 'stamp_lymph_1',
        name: 'Узел 1',
        groupId: 'Лимфоузлы',
        imagePath: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );

      drawBloc.emit(drawBloc.state.copyWith(
        customGroups: ['Лимфоузлы'],
        customStampItems: [stamp1],
      ));
      await tester.pump();

      // Still standalone, displayed with group label
      expect(find.text('Лимфоу.', skipOffstage: false), findsOneWidget);

      // 3. Add 2nd stamp into 'Лимфоузлы'
      final stamp2 = CustomStampItem(
        id: 'stamp_lymph_2',
        name: 'Узел 2',
        groupId: 'Лимфоузлы',
        imagePath: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );

      drawBloc.emit(drawBloc.state.copyWith(
        customGroups: ['Лимфоузлы'],
        customStampItems: [stamp1, stamp2],
      ));
      await tester.pump();

      // Multi-item custom group has expand chevron and group label
      expect(find.text('Лимфоу.', skipOffstage: false), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down, skipOffstage: false), findsWidgets);

      drawBloc.close();
    });

    testWidgets('Custom groups appear BEFORE the tool for adding stamps', (tester) async {
      final drawBloc = DrawBloc();

      // Create a custom group 'Хирургия'
      drawBloc.emit(drawBloc.state.copyWith(
        customGroups: ['Хирургия'],
        customStampItems: [],
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: drawBloc,
              child: FloatingToolbox(
                currentTool: ToolType.pencil,
                orientation: ToolboxOrientation.horizontal,
                onToolSelected: (_) {},
                onDragUpdate: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find custom group widget and add stamp button widget
      final customGroupFinder = find.text('Хирургия', skipOffstage: false);
      final addStampFinder = find.text('Штамп', skipOffstage: false);

      expect(customGroupFinder, findsOneWidget);
      expect(addStampFinder, findsOneWidget);

      final customGroupPos = tester.getTopLeft(customGroupFinder);
      final addStampPos = tester.getTopLeft(addStampFinder);

      // In horizontal orientation, custom group must appear before (x < x) the add stamp tool
      expect(customGroupPos.dx, lessThan(addStampPos.dx));

      drawBloc.close();
    });
  });
}
