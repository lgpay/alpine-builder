# alpine-builder

通用的 GitHub Actions Alpine 编译项目。

目标：在 `alpine` 容器里编译各种开源项目，输出适用于 Alpine Linux / musl 的二进制制品。当前内置了 `libfuse` 和 `ossfs` 两个示例，后续可以继续往 `projects/` 下加更多项目预设。

## 现在支持

- 手动选择要编译的项目预设
- 手动指定源码 ref（tag / branch / commit）
- 支持 `x86_64`、`aarch64` 或双架构构建
- 在 Alpine 容器里构建，确保产物是 musl 环境
- 输出 tar.gz artifact
- 自动生成 `.sha256` 校验文件
- `libfuse` 自动跟踪上游 tag，并自动发布到 GitHub Release
- `ossfs` 自动跟踪上游 tag，并自动发布到 GitHub Release
- 支持多种常见构建系统：
  - meson
  - cmake
  - autotools
  - make

## 目录结构

```text
.
├── .github/workflows/build.yml
├── .github/workflows/libfuse-release.yml
├── .github/workflows/ossfs-release.yml
├── projects/
│   ├── libfuse/
│   │   └── project.env
│   └── ossfs/
│       └── project.env
├── scripts/
│   ├── build-project.sh
│   └── package.sh
└── README.md
```

## 如何新增一个项目

在 `projects/<项目名>/project.env` 新建一个预设文件。

例如：

```env
PROJECT_NAME=zstd
SOURCE_REPO=https://github.com/facebook/zstd.git
SOURCE_REF=dev
BUILD_SYSTEM=make
INSTALL_PREFIX=/usr
CONFIGURE_ARGS=''
BUILD_ARGS=''
INSTALL_ARGS='PREFIX=/usr'
PACKAGE_DIRS='bin lib include share'
APK_BUILD_DEPS='bash build-base git tar file ca-certificates'
```

### 字段说明

- `PROJECT_NAME`: 项目名
- `SOURCE_REPO`: git 仓库地址
- `SOURCE_REF`: 默认源码版本
- `BUILD_SYSTEM`: `meson` / `cmake` / `autotools` / `make`
- `INSTALL_PREFIX`: 安装前缀，通常 `/usr`
- `CONFIGURE_ARGS`: 配置阶段参数
- `BUILD_ARGS`: 编译阶段参数
- `INSTALL_ARGS`: 安装阶段参数
- `PACKAGE_DIRS`: 打包哪些目录，空格分隔
- `APK_BUILD_DEPS`: Alpine 下需要安装的依赖包

## 使用方式

### 通用手动构建

1. 推送到 GitHub 仓库
2. 打开 `Actions`
3. 运行 `Build Alpine package`
4. 填写参数：
   - `project`: 例如 `libfuse`
   - `ref`: 可选，覆盖默认 ref
   - `alpine_version`: 例如 `3.20`
   - `arch`: `x86_64` / `aarch64` / `all`

完成后会在 Artifacts 中得到：

- `<project>-alpine-<git-sha>-apk<alpine-version>-<arch>.tar.gz`
- 对应的 `.sha256` 校验文件

### libfuse 自动发布 Release

仓库内额外提供了一个 workflow：`Auto release libfuse for Alpine`

它会：

1. 每天定时检查 `libfuse` 上游最新 tag
2. 如果当前仓库还没有对应 release
3. 自动构建 Alpine 版本二进制包
4. 自动发布到当前仓库的 GitHub Releases

也可以手动触发，并支持：

- `ref`: 手动指定 libfuse tag / branch / commit
- `alpine_version`: 指定 Alpine 版本
- `arch`: `x86_64` / `aarch64` / `all`
- `force=true`: 即使 release 已存在也强制重新构建

### ossfs 自动发布 Release

仓库内额外提供了一个 workflow：`Auto release ossfs for Alpine`

它会：

1. 每天定时检查 `ossfs` 上游最新 tag
2. 如果当前仓库还没有对应 release
3. 自动构建 Alpine 版本二进制包
4. 自动发布到当前仓库的 GitHub Releases

也可以手动触发，并支持：

- `ref`: 手动指定 ossfs tag / branch / commit
- `alpine_version`: 指定 Alpine 版本
- `arch`: `x86_64` / `aarch64` / `all`
- `force=true`: 即使 release 已存在也强制重新构建

## 当前内置项目

### libfuse

源码：<https://github.com/libfuse/libfuse>

默认设置：

- Build system: `meson`
- 默认 ref: `master`
- 配置参数：`'-Dexamples=false -Dtests=false'`
- 支持自动跟踪上游 tag 并发布 Release
- 自动附带多架构构建产物和 `.sha256` 校验文件

### ossfs

源码：<https://github.com/aliyun/ossfs>

默认设置：

- Build system: `cmake`
- 默认 ref: `main`
- 产物会包含：
  - `/usr/local/bin/ossfs2`
  - `/usr/sbin/mount.ossfs2`
  - `/usr/local/lib64/ossfs2/libfuse3.so.3`
- 针对项目自带的预置依赖 tarball 直接在 Alpine 容器内编译
- 说明：上游 README 明确写了 aarch64 目前仅官方支持 Alibaba Cloud Linux 3；这里仍然保留通用构建能力，但 ARM 产物建议自行验证运行兼容性

## 注意

- 这套东西当前产出的是 `tar.gz` 二进制包，不是标准 `.apk` 安装包。
- 如果某些项目安装逻辑特殊，可以单独扩展 `scripts/build-project.sh`，或者给项目增加专属脚本。
- `make install` 类项目差异很大，新增项目时建议先本地验证一遍。

## 适合后续加的增强

- 真正生成 `.apk`
- 多架构矩阵（x86_64 / aarch64）
- 自动发布 GitHub Release
- 针对项目预设支持自定义 build hook
