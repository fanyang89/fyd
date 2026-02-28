cmake_minimum_required(VERSION 3.20)
project(fy-disks LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

# ── Dependencies ────────────────────────────────────────────────────────────

if(NOT DEFINED CPM_SOURCE_CACHE)
    if(DEFINED ENV{CPM_SOURCE_CACHE} AND NOT "$ENV{CPM_SOURCE_CACHE}" STREQUAL "")
        set(CPM_SOURCE_CACHE "$ENV{CPM_SOURCE_CACHE}")
    else()
        set(CPM_SOURCE_CACHE "${CMAKE_BINARY_DIR}/.cpm-cache")
    endif()
endif()
set(CPM_SOURCE_CACHE "${CPM_SOURCE_CACHE}" CACHE PATH "CPM source cache directory")

set(CPM_DOWNLOAD_VERSION 0.40.7)
set(CPM_DOWNLOAD_LOCATION "${CMAKE_BINARY_DIR}/cmake/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
if(NOT EXISTS "${CPM_DOWNLOAD_LOCATION}")
    file(DOWNLOAD
        "https://github.com/cpm-cmake/CPM.cmake/releases/download/v${CPM_DOWNLOAD_VERSION}/CPM.cmake"
        "${CPM_DOWNLOAD_LOCATION}"
        EXPECTED_HASH SHA256=c0fc82149e00c43a21febe7b2ca57b2ffea2b8e88ab867022c21d6b81937eb50
    )
endif()
include("${CPM_DOWNLOAD_LOCATION}")

CPMAddPackage(
    NAME CLI11
    GITHUB_REPOSITORY CLIUtils/CLI11
    GIT_TAG v2.6.2
    OPTIONS
        "CLI11_BUILD_TESTS OFF"
)

CPMAddPackage(
    NAME spdk
    GITHUB_REPOSITORY spdk/spdk
    GIT_TAG v26.01
    DOWNLOAD_ONLY YES
)

CPMAddPackage(
    NAME libiscsi
    GITHUB_REPOSITORY sahlberg/libiscsi
    GIT_TAG 1.20.3
    DOWNLOAD_ONLY YES
)

if(NOT CLI11_ADDED)
    message(FATAL_ERROR "Failed to fetch CLI11 from CPM")
endif()
if(NOT DEFINED spdk_SOURCE_DIR OR NOT EXISTS "${spdk_SOURCE_DIR}")
    message(FATAL_ERROR "Failed to fetch SPDK from CPM")
endif()
if(NOT DEFINED libiscsi_SOURCE_DIR OR NOT EXISTS "${libiscsi_SOURCE_DIR}")
    message(FATAL_ERROR "Failed to fetch libiscsi from CPM")
endif()

# ChDB shared library
find_library(CHDB_LIB chdb
    HINTS /usr/local/lib /usr/lib
    REQUIRED
)

# ChDB headers (chdb.h)
find_path(CHDB_INCLUDE_DIR chdb.h
    HINTS /usr/local/include /usr/include
    REQUIRED
)

# liburing
find_library(URING_LIB uring REQUIRED)
find_path(URING_INCLUDE_DIR liburing.h
    HINTS /usr/local/include /usr/include
    REQUIRED
)

# SPDK (built from CPM-downloaded source tree)
find_package(SPDK REQUIRED)

# ── Main executable ──────────────────────────────────────────────────────────

add_executable(fy-iscsi
    src/main.cpp
    src/meta.cpp
    src/vdisk_bdev.c
    src/startup.c
)

target_include_directories(fy-iscsi PRIVATE
    src/
    lib/
    ${CHDB_INCLUDE_DIR}
    ${URING_INCLUDE_DIR}
    ${SPDK_INCLUDE_DIRS}
    ${spdk_SOURCE_DIR}/lib/iscsi
    ${spdk_SOURCE_DIR}/lib/bdev
)

target_link_directories(fy-iscsi PRIVATE ${SPDK_LIBRARY_DIRS})

target_link_libraries(fy-iscsi PRIVATE
    CLI11::CLI11
    ${SPDK_LINK_LIBRARIES}
    ${CHDB_LIB}
    ${URING_LIB}
    pthread
    dl
    rt
)

# SPDK requires these compiler options
target_compile_options(fy-iscsi PRIVATE
    -march=native
    -D_GNU_SOURCE
)

# ── Tests ─────────────────────────────────────────────────────────────────

enable_testing()

find_library(ISCSI_LIB iscsi
    HINTS /usr/local/lib /usr/lib
          "${libiscsi_SOURCE_DIR}/lib/.libs"
)
find_path(ISCSI_INCLUDE_DIR iscsi/iscsi.h
    HINTS /usr/local/include /usr/include
          "${libiscsi_SOURCE_DIR}/include"
)

if(ISCSI_LIB AND ISCSI_INCLUDE_DIR)
    add_executable(iscsi_test test/iscsi_test.cpp)

    target_include_directories(iscsi_test PRIVATE
        ${ISCSI_INCLUDE_DIR}
    )

    target_link_libraries(iscsi_test PRIVATE
        ${ISCSI_LIB}
        pthread
    )

    target_compile_options(iscsi_test PRIVATE -D_GNU_SOURCE)

    add_test(NAME BasicIO
        COMMAND iscsi_test --addr 127.0.0.1 --port 3260 --case basic
    )
    add_test(NAME CrossSeg
        COMMAND iscsi_test --addr 127.0.0.1 --port 3260 --case cross_segment
    )
else()
    message(STATUS "libiscsi not found - skipping iscsi_test")
endif()
