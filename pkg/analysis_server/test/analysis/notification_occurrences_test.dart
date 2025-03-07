// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analysis_server/protocol/protocol.dart';
import 'package:analysis_server/protocol/protocol_constants.dart';
import 'package:analysis_server/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../analysis_abstract.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AnalysisNotificationOccurrencesTest);
  });
}

@reflectiveTest
class AnalysisNotificationOccurrencesTest extends AbstractAnalysisTest {
  late List<Occurrences> occurrencesList;
  late Occurrences testOccurrences;

  final Completer<void> _resultsAvailable = Completer();

  /// Asserts that there is an offset of [search] in [testOccurrences].
  void assertHasOffset(String search) {
    var offset = findOffset(search);
    expect(testOccurrences.offsets, contains(offset));
  }

  /// Validates that there is a region at the offset of [search] in [testFile].
  /// If [length] is not specified explicitly, then length of an identifier
  /// from [search] is used.
  void assertHasRegion(String search, [int length = -1]) {
    var offset = findOffset(search);
    if (length == -1) {
      length = findIdentifierLength(search);
    }
    findRegion(offset, length, true);
  }

  /// Finds an [Occurrences] with the given [offset] and [length].
  ///
  /// If [exists] is `true`, then fails if such [Occurrences] does not exist.
  /// Otherwise remembers this it into [testOccurrences].
  ///
  /// If [exists] is `false`, then fails if such [Occurrences] exists.
  void findRegion(int offset, int length, [bool? exists]) {
    for (var occurrences in occurrencesList) {
      if (occurrences.length != length) {
        continue;
      }
      for (var occurrenceOffset in occurrences.offsets) {
        if (occurrenceOffset == offset) {
          if (exists == false) {
            fail('Not expected to find (offset=$offset; length=$length) in\n'
                '${occurrencesList.join('\n')}');
          }
          testOccurrences = occurrences;
          return;
        }
      }
    }
    if (exists == true) {
      fail('Expected to find (offset=$offset; length=$length) in\n'
          '${occurrencesList.join('\n')}');
    }
  }

  Future prepareOccurrences() {
    addAnalysisSubscription(AnalysisService.OCCURRENCES, testFile);
    return _resultsAvailable.future;
  }

  @override
  void processNotification(Notification notification) {
    if (notification.event == ANALYSIS_NOTIFICATION_OCCURRENCES) {
      var params = AnalysisOccurrencesParams.fromNotification(notification);
      if (params.file == testFile) {
        occurrencesList = params.occurrences;
        _resultsAvailable.complete();
      }
    }
  }

  @override
  Future<void> setUp() async {
    super.setUp();
    await createProject();
  }

  Future<void> test_afterAnalysis() async {
    addTestFile('''
main() {
  var vvv = 42;
  print(vvv);
}
''');
    await waitForTasksFinished();
    await prepareOccurrences();
    assertHasRegion('vvv =');
    expect(testOccurrences.element.kind, ElementKind.LOCAL_VARIABLE);
    expect(testOccurrences.element.name, 'vvv');
    assertHasOffset('vvv = 42');
    assertHasOffset('vvv);');
  }

  Future<void> test_field() async {
    addTestFile('''
class A {
  int fff;
  A(this.fff); // constructor
  main() {
    fff = 42;
    print(fff); // print
  }
}
''');
    await prepareOccurrences();
    assertHasRegion('fff;');
    expect(testOccurrences.element.kind, ElementKind.FIELD);
    assertHasOffset('fff); // constructor');
    assertHasOffset('fff = 42;');
    assertHasOffset('fff); // print');
  }

  Future<void> test_field_unresolved() async {
    addTestFile('''
class A {
  A(this.noSuchField);
}
''');
    // no checks for occurrences, just ensure that there is no NPE
    await prepareOccurrences();
  }

  Future<void> test_localVariable() async {
    addTestFile('''
main() {
  var vvv = 42;
  vvv += 5;
  print(vvv);
}
''');
    await prepareOccurrences();
    assertHasRegion('vvv =');
    expect(testOccurrences.element.kind, ElementKind.LOCAL_VARIABLE);
    expect(testOccurrences.element.name, 'vvv');
    assertHasOffset('vvv = 42');
    assertHasOffset('vvv += 5');
    assertHasOffset('vvv);');
  }

  Future<void> test_memberField() async {
    addTestFile('''
class A<T> {
  T fff;
}
main() {
  var a = new A<int>();
  var b = new A<String>();
  a.fff = 1;
  b.fff = 2;
}
''');
    await prepareOccurrences();
    assertHasRegion('fff;');
    expect(testOccurrences.element.kind, ElementKind.FIELD);
    assertHasOffset('fff = 1;');
    assertHasOffset('fff = 2;');
  }

  Future<void> test_memberMethod() async {
    addTestFile('''
class A<T> {
  T mmm() {}
}
main() {
  var a = new A<int>();
  var b = new A<String>();
  a.mmm(); // a
  b.mmm(); // b
}
''');
    await prepareOccurrences();
    assertHasRegion('mmm() {}');
    expect(testOccurrences.element.kind, ElementKind.METHOD);
    assertHasOffset('mmm(); // a');
    assertHasOffset('mmm(); // b');
  }

  Future<void> test_parameter_named() async {
    addTestFile('''
void f(int aaa, int bbb, {int? ccc, int? ddd}) {
  ccc;
  ddd;
}

void g() {
  f(0, ccc: 2, 1, ddd: 3);
}
''');
    await prepareOccurrences();

    assertHasRegion('ccc: 2');
    expect(testOccurrences.element.kind, ElementKind.PARAMETER);
    assertHasOffset('ccc,');
    assertHasOffset('ccc;');
    assertHasOffset('ccc: 2');

    assertHasRegion('ddd: 3');
    expect(testOccurrences.element.kind, ElementKind.PARAMETER);
    assertHasOffset('ddd})');
    assertHasOffset('ddd;');
    assertHasOffset('ddd: 3');
  }

  Future<void> test_topLevelVariable() async {
    addTestFile('''
var VVV = 1;
main() {
  VVV = 2;
  print(VVV);
}
''');
    await prepareOccurrences();
    assertHasRegion('VVV = 1;');
    expect(testOccurrences.element.kind, ElementKind.TOP_LEVEL_VARIABLE);
    assertHasOffset('VVV = 2;');
    assertHasOffset('VVV);');
  }

  Future<void> test_type_class() async {
    addTestFile('''
main() {
  int a = 1;
  int b = 2;
  int c = 3;
}
int VVV = 4;
''');
    await prepareOccurrences();
    assertHasRegion('int a');
    expect(testOccurrences.element.kind, ElementKind.CLASS);
    expect(testOccurrences.element.name, 'int');
    assertHasOffset('int a');
    assertHasOffset('int b');
    assertHasOffset('int c');
    assertHasOffset('int VVV');
  }

  Future<void> test_type_dynamic() async {
    addTestFile('''
main() {
  dynamic a = 1;
  dynamic b = 2;
}
dynamic V = 3;
''');
    await prepareOccurrences();
    var offset = findOffset('dynamic a');
    findRegion(offset, 'dynamic'.length, false);
  }

  Future<void> test_type_void() async {
    addTestFile('''
void main() {
}
''');
    await prepareOccurrences();
    var offset = findOffset('void main()');
    findRegion(offset, 'void'.length, false);
  }
}
