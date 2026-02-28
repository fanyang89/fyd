# fy-disks

## Build system

This project uses [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake) for dependency source management.
All third-party sources are fetched by CPM and cached locally.

Dependencies and pinned tags:

- CLI11: `v2.6.2`
- SPDK: `v26.01` (fetched by CPM, built separately)
- libiscsi: `1.20.3` (fetched by CPM, built separately)

## CPM cache

By default, the cache directory is:

- `${build_dir}/.cpm-cache`

You can override it with either:

- CMake variable: `-DCPM_SOURCE_CACHE=/abs/path/to/cache`
- Environment variable: `CPM_SOURCE_CACHE=/abs/path/to/cache`

## Configure

```bash
cmake -S . -B build
```

After configure, CPM has downloaded dependency source trees.

## Build external dependencies from CPM source trees

SPDK must be built before configuring this project successfully.
The build expects SPDK `pkg-config` files under `build/lib/pkgconfig`.

Example (replace paths with your actual CPM cache location):

```bash
# Build SPDK from CPM source tree
cd <CPM_SOURCE_CACHE>/spdk/<version-or-hash>
./configure --with-shared
make -j

# Build libiscsi from CPM source tree (optional, only for iscsi_test)
cd <CPM_SOURCE_CACHE>/libiscsi/<version-or-hash>
./autogen.sh
./configure
make -j
```

Then configure this project with:

```bash
cmake -S . -B build -DSPDK_PKG_CONFIG_PATH=<spdk-build-dir>/build/lib/pkgconfig
cmake --build build -j
```

If `libiscsi` is not available, `iscsi_test` is skipped automatically.
