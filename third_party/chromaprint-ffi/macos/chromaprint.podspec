#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint chromaprint.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'chromaprint'
  s.version          = '0.2.1'
  s.summary          = 'Dart FFI bindings for the Chromaprint audio fingerprinting library.'
  s.description      = <<-DESC
Wraps the Chromaprint C++ library (AcoustID) for audio fingerprinting
via Dart FFI. Generates compact fingerprints from raw PCM audio data
that can be used to identify audio recordings.
                       DESC
  s.homepage         = 'https://github.com/solearchitect/chromaprint'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }

  # ── Source files from the chromaprint git submodule ──────────
  s.source_files =
    '../chromaprint/src/*.cpp',
    '../chromaprint/src/utils/*.cpp',
    '../chromaprint/src/avresample/*.c',
    '../chromaprint/src/3rdparty/kissfft/kiss_fft.c',
    '../chromaprint/src/3rdparty/kissfft/kiss_fftr.c'

  s.exclude_files =
    '../chromaprint/src/*_test.cpp',
    '../chromaprint/src/fft_lib_avfft.cpp',
    '../chromaprint/src/fft_lib_avtx.cpp',
    '../chromaprint/src/fft_lib_fftw3.cpp',
    '../chromaprint/src/fft_lib_vdsp.cpp',
    '../chromaprint/src/cmd/**/*'

  s.public_header_files = '../chromaprint/src/chromaprint.h'

  # ── Compiler & linker settings ───────────────────────────────
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'HAVE_CONFIG_H=1 CHROMAPRINT_API_EXPORTS=1 USE_KISSFFT=1 USE_INTERNAL_AVRESAMPLE=1 _SCL_SECURE_NO_WARNINGS=1 __STDC_LIMIT_MACROS __STDC_CONSTANT_MACROS',
    'HEADER_SEARCH_PATHS' => '"$(PODS_ROOT)/chromaprint/../src" "$(PODS_ROOT)/chromaprint/../chromaprint/src" "$(PODS_ROOT)/chromaprint/../chromaprint/src/3rdparty/kissfft"',
  }

  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.11'
end
