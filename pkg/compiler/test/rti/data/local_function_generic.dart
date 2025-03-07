// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart = 2.7

import 'package:compiler/src/util/testing.dart';

method1() {
  /*spec.direct,explicit=[local.T*],needsArgs,needsSignature*/
  /*prod.needsArgs,needsSignature*/
  T local<T>(T t) => t;
  return local;
}

@pragma('dart2js:noInline')
test(o) => o is S Function<S>(S);

main() {
  makeLive(test(method1()));
}
