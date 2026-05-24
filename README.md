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

## ossfs Alpine / musl 维护说明

`ossfs` 这个项目和 `libfuse/libfuse2` 不一样，它的上游构建默认依赖了一些 **glibc 取向的预编译依赖**，直接在 Alpine / musl 环境里构建时，最容易卡在接近完成阶段的链接错误，而不是一开始的源码编译错误。

### 这条线目前的策略

1. 先在 CI 里构建 musl 版 `libfuse`
2. 再把产出的 `libfuse-*.tar.gz` 注入 `ossfs` 构建流程
3. 在 `projects/ossfs/apply-patches.sh` 里统一做依赖替换和 musl 兼容补丁
4. 最终由 `ossfs-release.yml` 完成打包和 GitHub Release 发布

### 为什么不能直接使用上游预编译 libfuse

上游 `ossfs` 的 `dependencies/CMakeLists.txt` 默认引用的是固定的预编译 `libfuse` tarball，这个制品面向 glibc 环境。直接在 Alpine / musl 下使用时，典型问题包括：

- `GLIBC_*` 版本符号未定义
- `libc.so.6` / `libpthread.so.0` / `librt.so.1` / `libdl.so.2` 相关错误
- 最终 `ossfs2` 在 98% 左右链接失败

因此当前方案不是“修一下源码就行”，而是**先替换依赖来源，再处理源码兼容性**。

### 当前已知的 musl 兼容处理

`projects/ossfs/apply-patches.sh` 当前会处理：

- 用 CI 生成的 musl `libfuse` tarball 替换 upstream 预编译依赖
- 动态计算并替换 `libfuse` 的 MD5 校验值
- 将 `libfuse3.so.3.16.2` 引用改为 `libfuse3.so.3.18.2`
- 注入 `projects/ossfs/patches/musl_compat.cpp`
- 给 `ossfs` 源码补必要头文件与 musl 兜底实现，包括：
  - `time.h`
  - `sys/types.h`
  - `sys/stat.h`
  - `malloc.h`
  - `malloc_trim`
  - `mallopt`
  - `backtrace`
  - `backtrace_symbols`

### 维护建议

如果后续这条线再次失败，排查顺序建议固定为：

1. 先看 `libfuse` 是否成功构建
2. 再看 `ossfs` 是否正确拿到了新的 `libfuse-*.tar.gz`
3. 再看 `dependencies/CMakeLists.txt` 里的 MD5 / soname 是否已被补丁正确替换
4. 最后才看 `ossfs` 自身源码是否又引入了新的 musl 兼容问题

### 后续可继续优化的方向

- 把 `apply-patches.sh` 里的文本替换进一步收敛成正式 patch 文件
- 继续降低对 upstream 固定 prebuilt `libfuse` 目录结构的耦合
- 如果未来 upstream `ossfs` 支持系统/外部 `libfuse`，可以进一步简化当前补丁逻辑
