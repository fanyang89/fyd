# FindSPDK.cmake
# Locates SPDK libraries via pkg-config.
#
# Resolution order for pkg-config path:
#   1) SPDK_PKG_CONFIG_PATH (explicit user override)
#   2) ${spdk_SOURCE_DIR}/build/lib/pkgconfig (when SPDK is fetched by CPM)
#   3) Existing PKG_CONFIG_PATH from the environment
#
# Sets:
#   SPDK_FOUND
#   SPDK_INCLUDE_DIRS
#   SPDK_LINK_LIBRARIES   (full link flags including --whole-archive wrapping)
#   SPDK_LIBRARY_DIRS

find_package(PkgConfig REQUIRED)

# Allow override via cmake -DSPDK_PKG_CONFIG_PATH=...
if(NOT SPDK_PKG_CONFIG_PATH)
    if(DEFINED spdk_SOURCE_DIR AND EXISTS "${spdk_SOURCE_DIR}/build/lib/pkgconfig")
        set(SPDK_PKG_CONFIG_PATH "${spdk_SOURCE_DIR}/build/lib/pkgconfig")
    endif()
endif()

if(SPDK_PKG_CONFIG_PATH)
    set(ENV{PKG_CONFIG_PATH} "${SPDK_PKG_CONFIG_PATH}:$ENV{PKG_CONFIG_PATH}")
endif()

set(_spdk_modules
    spdk_iscsi
    spdk_scsi
    spdk_bdev
    spdk_thread
    spdk_app_rpc
    spdk_env_dpdk
    spdk_log
    spdk_util
    spdk_json
    spdk_jsonrpc
    spdk_rpc
    spdk_trace
    spdk_sock
    spdk_notify
    spdk_dma
)

# Collect include dirs and link flags from each module
set(SPDK_INCLUDE_DIRS "")
set(SPDK_LINK_LIBRARIES "")
set(SPDK_LIBRARY_DIRS "")
set(SPDK_FOUND TRUE)

foreach(_mod ${_spdk_modules})
    pkg_check_modules(_SPDK_MOD ${_mod})
    if(_SPDK_MOD_FOUND)
        list(APPEND SPDK_INCLUDE_DIRS ${_SPDK_MOD_INCLUDE_DIRS})
        list(APPEND SPDK_LIBRARY_DIRS ${_SPDK_MOD_LIBRARY_DIRS})
        list(APPEND SPDK_LINK_LIBRARIES ${_SPDK_MOD_LINK_LIBRARIES})
    else()
        message(WARNING "SPDK module ${_mod} not found via pkg-config")
    endif()
endforeach()

list(REMOVE_DUPLICATES SPDK_INCLUDE_DIRS)
list(REMOVE_DUPLICATES SPDK_LIBRARY_DIRS)

if(NOT SPDK_LINK_LIBRARIES)
    set(SPDK_FOUND FALSE)
    if(FindSPDK_FIND_REQUIRED)
        message(FATAL_ERROR "SPDK not found. Build SPDK in the CPM source cache first (e.g. <cache>/spdk/<version>/build/lib/pkgconfig), or set -DSPDK_PKG_CONFIG_PATH=<spdk-build>/lib/pkgconfig")
    endif()
endif()

mark_as_advanced(SPDK_INCLUDE_DIRS SPDK_LINK_LIBRARIES SPDK_LIBRARY_DIRS)
