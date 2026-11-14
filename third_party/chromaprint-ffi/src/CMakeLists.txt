cmake_minimum_required(VERSION 3.10)

project(chromaprint_library VERSION 0.0.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Chromaprint sources from git submodule at <plugin_root>/chromaprint/
set(CHROMAPRINT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../chromaprint/src")

set(CHROMAPRINT_SOURCES
  ${CHROMAPRINT_DIR}/audio_processor.cpp
  ${CHROMAPRINT_DIR}/chroma.cpp
  ${CHROMAPRINT_DIR}/chroma_resampler.cpp
  ${CHROMAPRINT_DIR}/chroma_filter.cpp
  ${CHROMAPRINT_DIR}/spectrum.cpp
  ${CHROMAPRINT_DIR}/fft.cpp
  ${CHROMAPRINT_DIR}/fft_lib_kissfft.cpp
  ${CHROMAPRINT_DIR}/fingerprinter.cpp
  ${CHROMAPRINT_DIR}/image_builder.cpp
  ${CHROMAPRINT_DIR}/simhash.cpp
  ${CHROMAPRINT_DIR}/silence_remover.cpp
  ${CHROMAPRINT_DIR}/fingerprint_calculator.cpp
  ${CHROMAPRINT_DIR}/fingerprint_compressor.cpp
  ${CHROMAPRINT_DIR}/fingerprint_decompressor.cpp
  ${CHROMAPRINT_DIR}/fingerprinter_configuration.cpp
  ${CHROMAPRINT_DIR}/fingerprint_matcher.cpp
  ${CHROMAPRINT_DIR}/chromaprint.cpp
  ${CHROMAPRINT_DIR}/utils/base64.cpp
  # Internal avresample (audio resampling)
  ${CHROMAPRINT_DIR}/avresample/resample2.c
  # KissFFT (bundled FFT library)
  ${CHROMAPRINT_DIR}/3rdparty/kissfft/kiss_fft.c
  ${CHROMAPRINT_DIR}/3rdparty/kissfft/kiss_fftr.c
)

add_library(chromaprint SHARED ${CHROMAPRINT_SOURCES})

set_target_properties(chromaprint PROPERTIES
  OUTPUT_NAME "chromaprint"
  POSITION_INDEPENDENT_CODE ON
)

target_include_directories(chromaprint BEFORE PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}  # for config.h
  ${CHROMAPRINT_DIR}
  ${CHROMAPRINT_DIR}/3rdparty/kissfft
)

target_compile_definitions(chromaprint PRIVATE
  DART_SHARED_LIB
  HAVE_CONFIG_H
  CHROMAPRINT_API_EXPORTS
  USE_KISSFFT=1
  USE_INTERNAL_AVRESAMPLE=1
  _SCL_SECURE_NO_WARNINGS
  __STDC_LIMIT_MACROS
  __STDC_CONSTANT_MACROS
)

find_package(Threads)
target_link_libraries(chromaprint PRIVATE m Threads::Threads)

if(ANDROID)
  target_link_options(chromaprint PRIVATE "-Wl,-z,max-page-size=16384")
endif()
