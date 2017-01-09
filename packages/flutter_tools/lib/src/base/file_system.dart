// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as path;

import 'context.dart';

export 'package:file/file.dart';
export 'package:file/local.dart';

const FileSystem _kLocalFs = const LocalFileSystem();

/// Currently active implementation of the file system.
///
/// By default it uses local disk-based implementation. Override this in tests
/// with [MemoryFileSystem].
FileSystem get fs => context == null ? _kLocalFs : context[FileSystem];

/// Create the ancestor directories of a file path if they do not already exist.
void ensureDirectoryExists(String filePath) {
  String dirPath = path.dirname(filePath);

  if (fs.isDirectorySync(dirPath))
    return;
  fs.directory(dirPath).createSync(recursive: true);
}

/// Recursively copies a folder from `srcPath` to `destPath`
void copyFolderSync(String srcPath, String destPath) {
  Directory srcDir = fs.directory(srcPath);
  if (!srcDir.existsSync())
    throw new Exception('Source directory "${srcDir.path}" does not exist, nothing to copy');

  Directory destDir = fs.directory(destPath);
  if (!destDir.existsSync())
    destDir.createSync(recursive: true);

  srcDir.listSync().forEach((FileSystemEntity entity) {
    String newPath = path.join(destDir.path, path.basename(entity.path));
    if (entity is File) {
      File newFile = fs.file(newPath);
      newFile.writeAsBytesSync(entity.readAsBytesSync());
    } else if (entity is Directory) {
      copyFolderSync(entity.path, newPath);
    } else {
      throw new Exception('${entity.path} is neither File nor Directory');
    }
  });
}
