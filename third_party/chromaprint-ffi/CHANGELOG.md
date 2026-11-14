## 0.2.1

* Update README and CHANGELOG.

## 0.2.0

* Add iOS support (CocoaPods, static linking via DynamicLibrary.process).
* Add macOS support (same approach as iOS).
* Rewrite ios/ and macos/ podspecs to compile C++ sources from the git submodule.
* Remove chromaprint/ exclusion from .pubignore so submodule sources ship with the package.

## 0.1.2

* Fix CI publish workflow: remove incompatible `--ignore-warnings` flag.

## 0.1.1

* Fix pub.dev invalid changelog format.

## 0.1.0

* Initial release of Dart FFI bindings for Chromaprint.
* `Chromaprint` class for generating audio fingerprints from raw PCM data.
* `encodeFingerprint`, `decodeFingerprint`, `hashFingerprint` utility functions.
* Platform support for Android and Linux.
* Bundles Chromaprint v1.6.0 (compiled from source via git submodule).
