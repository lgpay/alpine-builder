# alpine-builder

通用的 GitHub Actions Alpine 编译项目。

用于在 `alpine` 容器里编译开源项目，产出适用于 Alpine Linux / musl 的二进制制品。

## 当前项目

- `libfuse`：最新版主线
- `libfuse2`：2.x 兼容线
- `ossfs`：最新版 release 线
- `ossfs1`：1.x release 线

## 命名规则

- 无数字后缀：默认主线 / 最新版
- 有数字后缀：特定版本线 / 兼容线

## 产物命名规则

统一格式：

```text
<project>-<version>-alpine<alpine_version>-<arch>.tar.gz
```

示例：

- `libfuse-fuse-3.18.2-alpine3.20-x86_64.tar.gz`
- `libfuse2-fuse-2.9.9-alpine3.20-x86_64.tar.gz`
- `ossfs-v2.0.7-alpine3.20-x86_64.tar.gz`
- `ossfs1-v1.91.10-alpine3.20-x86_64.tar.gz`

对应 release tag 示例：

- `libfuse-fuse-3.18.2-alpine3.20`
- `libfuse2-fuse-2.9.9-alpine3.20`
- `ossfs-v2.0.7-alpine3.20`
- `ossfs1-v1.91.10-alpine3.20`

## 目录

```text
projects/
.github/workflows/
scripts/
README.md
```
