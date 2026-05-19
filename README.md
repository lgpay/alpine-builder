# alpine-builder

通用的 GitHub Actions Alpine 编译项目。

目标：在 `alpine` 容器里编译各种开源项目，输出适用于 Alpine Linux / musl 的二进制制品。当前内置了 `libfuse` 示例，后续可以继续往 `projects/` 下加更多项目预设。

## 现在支持

- 手动选择要编译的项目预设
- 手动指定源码 ref（tag / branch / commit）
- 在 Alpine 容器里构建，确保产物是 musl 环境
- 输出 tar.gz artifact
- 支持多种常见构建系统：
  - meson
  - cmake
  - autotools
  - make

## 目录结构

```text
.
├── .github/workflows/build.yml
├── projects/
│   └── libfuse/
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
CONFIGURE_ARGS=
BUILD_ARGS=
INSTALL_ARGS=PREFIX=/usr
PACKAGE_DIRS=bin lib include share
APK_BUILD_DEPS=bash build-base git tar file ca-certificates
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

1. 推送到 GitHub 仓库
2. 打开 `Actions`
3. 运行 `Build Alpine package`
4. 填写参数：
   - `project`: 例如 `libfuse`
   - `ref`: 可选，覆盖默认 ref
   - `alpine_version`: 例如 `3.20`

完成后会在 Artifacts 中得到：

- `<project>-alpine-<git-sha>-apk<alpine-version>`

## 当前内置项目

### libfuse

源码：<https://github.com/libfuse/libfuse>

默认设置：

- Build system: `meson`
- 默认 ref: `master`
- 配置参数：`-Dexamples=false -Dtests=false`

## 注意

- 这套东西当前产出的是 `tar.gz` 二进制包，不是标准 `.apk` 安装包。
- 如果某些项目安装逻辑特殊，可以单独扩展 `scripts/build-project.sh`，或者给项目增加专属脚本。
- `make install` 类项目差异很大，新增项目时建议先本地验证一遍。

## 适合后续加的增强

- 真正生成 `.apk`
- 多架构矩阵（x86_64 / aarch64）
- 自动发布 GitHub Release
- 针对项目预设支持自定义 build hook
