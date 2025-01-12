#!/usr/bin/env python
# Copyright 2015 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import argparse
import json
import os
import subprocess
import sys
import urllib2
from utils import commit
from utils import system
import patch

# //base and its dependencies
_base_deps = [
    'base',
    'testing',
    'third_party/ashmem',
    'third_party/libevent',
    'third_party/libxml', # via //base/test
    'third_party/modp_b64',
    'third_party/tcmalloc',
]

# //build and its dependencies
_build_deps = [
    'build',
    'third_party/android_testrunner',
    'third_party/binutils',
    'third_party/instrumented_libraries',
    'third_party/pymock',
    'tools/android',
    'tools/clang',
    'tools/generate_library_loader',
    'tools/gritsettings',
    'tools/valgrind',
]

_chromium_libs = [
    'url',
]

_third_party_deps = [
    'third_party/android_platform',
    'third_party/apple_apsl',
    'third_party/brotli',
    'third_party/expat',
    'third_party/freetype-android',
    'third_party/harfbuzz-ng',
    'third_party/iccjpeg',
    'third_party/jinja2',
    'third_party/jsr-305',
    'third_party/junit',
    'third_party/khronos',
    'third_party/libjpeg',
    'third_party/libpng',
    'third_party/libXNVCtrl',
    'third_party/markupsafe',
    'third_party/mesa',
    'third_party/mockito',
    'third_party/ots',
    'third_party/ply',
    'third_party/qcms',
    'third_party/re2',
    'third_party/robolectric',
    'third_party/zlib',
]

dirs_from_chromium = _base_deps + _build_deps + _chromium_libs + _third_party_deps

dirs_from_mojo = [
    'gpu',
    'mojo',
    'services/asset_bundle',
    'services/keyboard',
    'services/sensors',
]

# The contents of these files before the roll will be preserved after the roll,
# even though they live in directories rolled in from Chromium.
files_not_to_roll = [
    'build/config/ui.gni',
    'build/ls.py',
    'build/module_args/mojo.gni',
    'gpu/BUILD.gn',
    'tools/android/download_android_tools.py',
    'tools/android/VERSION_LINUX_NDK',
    'tools/android/VERSION_LINUX_SDK',
    'tools/android/VERSION_MACOSX_NDK',
    'tools/android/VERSION_MACOSX_SDK',
]


def rev(source_dir, dest_dir, dirs_to_rev, name):
    for d in dirs_to_rev:
      print "removing directory %s" % d
      try:
          system(["git", "rm", "-r", d], cwd=dest_dir)
      except subprocess.CalledProcessError:
          print "Could not remove %s" % d
      print "cloning directory %s" % d
      files = system(["git", "ls-files", d], cwd=source_dir)
      for f in files.splitlines():
          source_path = os.path.join(source_dir, f)
          if not os.path.isfile(source_path):
              continue
          dest_path = os.path.join(dest_dir, f)
          system(["mkdir", "-p", os.path.dirname(dest_path)], cwd=source_dir)
          system(["cp", source_path, dest_path], cwd=source_dir)
      system(["git", "add", d], cwd=dest_dir)

    for f in files_not_to_roll:
        system(["git", "checkout", "HEAD", f], cwd=dest_dir)

    system(["git", "add", "."], cwd=dest_dir)
    src_commit = system(["git", "rev-parse", "HEAD"], cwd=source_dir).strip()
    commit("Update to %s %s" % (name, src_commit), cwd=dest_dir)


def main():
  parser = argparse.ArgumentParser(description="Update the mojo repo's " +
      "snapshot of things imported from chromium.")
  parser.add_argument("--mojo-dir", type=str)
  parser.add_argument("--chromium-dir", type=str)
  parser.add_argument("--dest-dir", type=str)

  args = parser.parse_args()

  if args.mojo_dir:
      rev(args.mojo_dir, args.dest_dir, dirs_from_mojo, 'mojo')

      try:
          patch.patch_and_filter(args.dest_dir,
                                 os.path.join('patches', 'mojo'))
      except subprocess.CalledProcessError:
          print "ERROR: Roll failed due to a patch not applying"
          print "Fix the patch to apply, commit the result, and re-run this script"
          return 1

  if args.chromium_dir:
      rev(args.chromium_dir, args.dest_dir, dirs_from_chromium, 'chromium')

      try:
          patch.patch_and_filter(args.dest_dir,
                                 os.path.join('patches', 'chromium'))
      except subprocess.CalledProcessError:
          print "ERROR: Roll failed due to a patch not applying"
          print "Fix the patch to apply, commit the result, and re-run this script"
          return 1

  return 0


if __name__ == "__main__":
  sys.exit(main())
