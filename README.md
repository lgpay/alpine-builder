# alpine-builder

通用的 GitHub Actions Alpine 编译项目。

目标：在 `alpine` 容器里编译各种开源项目，输出适用于 Alpine Linux / musl 的二进制制品。当前内置了 `libfuse`、`libfuse2`、`ossfs`、`ossfs1` 四个项目预设，后续可以继续往 `projects/` 下加更多项目。

## 命名规则

### 项目命名规则

- **无数字后缀 = 最新版 / 默认主线**
  - `libfuse`：跟踪上游最新 libfuse 主线 tag
  - `ossfs`：跟踪上游最新 `v1.x` release
- **有数字后缀 = 特定兼容线 / 维护线 / 指定变体**
  - `libfuse2`：fuse2 / `libfuse.so.2` ABI 线
  - `ossfs1`：`main-v1` 维护线

说明：带数字后缀不一定表示“固定死某一个 tag”，也可以表示一条明确区分出来的兼容线或维护线。关键是它不再表示默认最新版主线。

## 现在支持

- `libfuse`、`libfuse2`、`ossfs`、`ossfs1` 自动跟踪各自对应的上游版本源并发布到 GitHub Release
- 手动指定源码 ref（tag / branch / commit）
- 支持 `x86_64`、`aarch64` 或双架构构建
- 在 Alpine 容器里构建，确保产物面向 musl 环境
- 输出简洁统一的 `tar.gz` 产物
- 支持多种常见构建系统：
  - meson
  - cmake
  - autotools
  - make

## 产物命名规则

所有构建产物统一为：

```text
<project>-<version>-alpine<alpine_version>-<arch>.tar.gz
```

例如：

- `libfuse-fuse-3.18.2-alpine3.20-x86_64.tar.gz`
- `libfuse-fuse-2.9.9-alpine3.20-x86_64.tar.gz`
- `ossfs-v1.91.10-alpine3.20-x86_64.tar.gz`
- `ossfs1-main-v1-alpine3.20-x86_64.tar.gz`

说明：

- `project` 字段始终来自 `PROJECT_NAME`，因此会严格遵循项目命名规则
- `version` 默认优先使用 workflow 已解析出的 `SOURCE_REF`
- 不再把工作区 `dirty` 状态带进产物文件名
- 不再生成 `.sha256` 附件

## 目录结构

```text
.
├── .github/workflows/libfuse-release.yml
├── .github/workflows/libfuse2-release.yml
├── .github/workflows/ossfs-release.yml
├── .github/workflows/ossfs1-release.yml
├── projects/
│   ├── libfuse/
│   │   └── project.env
│   ├── libfuse2/
│   │   └── project.env
│   ├── ossfs/
│   │   └── project.env
│   └── ossfs1/
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
- `SOURCE_SUBDIR`: 可选，源码子目录
- `PRE_BUILD_HOOK`: 可选，编译前执行的 shell 片段
- `POST_CLONE_HOOK`: 可选，clone / checkout 后执行的 shell 片段

## Release 工作流

### libfuse 自动发布 Release

workflow：`Auto release libfuse for Alpine`

它会：

1. 每天定时检查 `libfuse` 上游最新 tag
2. 如果当前仓库还没有对应 release
3. 自动构建 Alpine 版本二进制包
4. 自动发布到当前仓库的 GitHub Releases

可手动触发参数：

- `ref`: 手动指定 libfuse tag / branch / commit
- `alpine_version`: 指定 Alpine 版本
- `arch`: `x86_64` / `aarch64` / `all`
- `force=true`: 即使 release 已存在也强制重新构建

### libfuse2 自动发布 Release

workflow：`Auto release libfuse2 for Alpine`

它会：

1. 检查 `libfuse` 上游 `fuse-2.*` tag
2. 构建 `libfuse.so.2` 兼容的 Alpine 制品
3. 发布到当前仓库的 GitHub Releases

可手动触发参数：

- `ref`: 手动指定 libfuse2 tag / branch / commit
- `alpine_version`: 指定 Alpine 版本
- `arch`: `x86_64` / `aarch64` / `all`
- `force=true`: 即使 release 已存在也强制重新构建

### ossfs 自动发布 Release

workflow：`Auto release ossfs for Alpine`

它会：

1. 每天定时检查 `ossfs` 上游最新 `v1.x` release tag
2. 使用已发布的 `libfuse2` 制品满足 fuse2 / `libfuse.so.2` ABI 依赖
3. 自动构建 Alpine 版本二进制包
4. 自动发布到当前仓库的 GitHub Releases

可手动触发参数：

- `ref`: 手动指定 ossfs tag / branch / commit
- `alpine_version`: 指定 Alpine 版本
- `arch`: `x86_64` / `aarch64` / `all`
- `force=true`: 即使 release 已存在也强制重新构建

### ossfs1 自动发布 Release

workflow：`Auto release ossfs1 for Alpine`

它会：

1. 跟踪 `ossfs` 上游 `main-v1` 维护线
2. 使用已发布的 `libfuse2` 制品满足 fuse2 / `libfuse.so.2` ABI 依赖
3. 自动构建 Alpine 版本二进制包
4. 自动发布到当前仓库的 GitHub Releases

可手动触发参数：

- `ref`: 手动指定 ossfs1 tag / branch / commit
- `alpine_version`: 指定 Alpine 版本
- `arch`: `x86_64` / `aarch64` / `all`
- `force=true`: 即使 release 已存在也强制重新构建

## 当前内置项目

### libfuse

源码：<https://github.com/libfuse/libfuse>

默认设置：

- Build system: `meson`
- 默认 ref: 最新上游 tag
- 配置参数：`-Dexamples=false -Dtests=false`
- 支持自动跟踪上游 tag 并发布 Release

### libfuse2

源码：<https://github.com/libfuse/libfuse>

默认设置：

- Build system: `autotools`
- 默认 ref: `fuse-2.9.9`
- 目标 ABI：`libfuse.so.2`
- workflow 名称：`Auto release libfuse2 for Alpine`

### ossfs

源码：<https://github.com/aliyun/ossfs>

默认设置：

- Build system: `autotools`
- 默认 ref: 自动取上游最新 `v1.x` release
- 通过下载已发布的 `libfuse2` 制品来满足 `libfuse.so.2` / fuse2 ABI 依赖
- workflow 名称：`Auto release ossfs for Alpine`
- 适合维护最新版 ossfs 的 Alpine / musl 构建

### ossfs1

源码：<https://github.com/aliyun/ossfs>

默认设置：

- Build system: `autotools`
- 默认 ref: `main-v1`
- 通过下载已发布的 `libfuse2` 制品来满足 `libfuse.so.2` / fuse2 ABI 依赖
- 构建时会应用最小 Alpine 兼容补丁（通过 `POST_CLONE_HOOK`）
- workflow 名称：`Auto release ossfs1 for Alpine`
- 适合维护 `main-v1` 兼容线

## 注意

- 当前产出的是 `tar.gz` 二进制包，不是标准 `.apk` 安装包。
- `force=true` 会强制重新构建；如果目标 release 已存在，workflow 会覆盖上传同名 asset，并同步更新 release 标题与说明。
- release tag 与构建产物统一使用 `alpine<version>` 命名风格，例如：
  - `libfuse-fuse-3.18.2-alpine3.20`
  - `libfuse2-fuse-2.9.9-alpine3.20`
  - `ossfs-v1.91.10-alpine3.20`
  - `ossfs1-main-v1-alpine3.20`
- 构建产物文件名始终遵循 `<project>-<version>-alpine<alpine_version>-<arch>.tar.gz`，其中 `<project>` 必须与 `PROJECT_NAME` 保持一致。
- 如果某些项目安装逻辑特殊，可以扩展 `scripts/build-project.sh`，或者给项目增加专属脚本。
- `make install` / `autotools` 类项目差异很大，新增项目时建议先手动验证一次。

## 适合后续加的增强

- 已存在 release 时改为覆盖上传 asset，而不是直接失败
- 真正生成 `.apk`
- 更多项目预设
- 针对项目预设支持更细的自定义 build hook
