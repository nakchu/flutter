// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

void main() {
  // Intentionally fail the test. We want to see driver return a non-zero exit
  // code when this happens.
  throw 'Failed';
}
