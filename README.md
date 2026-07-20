# Temper Calc

Temper Calc 是面向 Android 和 iOS 的离线正则律（regular temperament）计算器，使用 Flutter 开发。应用移植了 [Sin-tel/temper](https://github.com/Sin-tel/temper) 的计算方法和 temperament family 数据，不需要连接服务器即可完成计算与搜索。

## 功能范围

- 通过 EDO/EDT 映射或 comma 列表定义 temperament。
- 设置 prime limit 或有理数 subgroup、生成元规约方式、调律权重和可选目标音程。
- 显示 rank、subgroup、family、comma basis、EDO join、mapping、生成元、调律值、误差、prime 映射和 badness。
- 按 Cangwu badness 或 Dirichlet badness 搜索不同 rank 的 temperament，并打开候选项详情。
- 计算、搜索和 family 查询均在设备本地完成。

## 输入语法

| 输入 | 支持形式 | 示例 |
| --- | --- | --- |
| Prime limit / subgroup | 单个整数表示 prime limit；多个整数或有理数可用点、逗号、分号或空格分隔 | `19`、`2.3.5.7`、`2.5/3.7/3` |
| EDO/EDT | 普通 EDO、wart notation、显式 map 调整；列表可用逗号、分号、空格或 `&` 分隔 | `12, 31`、`17c`、`17[+5]` |
| Comma / target interval | 比例、square superparticular 或整数向量 | `81/80`、`S6`、`[-4 4 -1]` |

搜索页同时填写 EDO 和 comma 时以 EDO 为准。计算页通过 EDO / Commas 模式选择决定采用哪组输入。

## 平台要求

- Android 10（API 29）及以上
- iOS 16.0 及以上
- Android application ID / iOS bundle identifier：`com.pythonanywhere.sintel`
- 应用名称：`Temper Calc`

## 开发与测试

安装 Flutter SDK 并连接模拟器或真机后执行：

```shell
flutter pub get
flutter run
```

提交前运行静态分析和测试：

```shell
flutter analyze
flutter test
```

Android 正式签名时，将 `android/key.properties.example` 复制为被 Git 忽略的
`android/key.properties`，填写 upload keystore 信息后执行：

```shell
flutter build appbundle --release --build-name 1.0.0 --build-number 1
```

iOS 正式归档需先在 Xcode 中为 `com.pythonanywhere.sintel` 配置有效的
Apple Distribution 证书和 provisioning profile。

## 上游项目与许可

- 上游源码：[Sin-tel/temper](https://github.com/Sin-tel/temper)
- 上游在线版本：[sintel.pythonanywhere.com](https://sintel.pythonanywhere.com/)
- 上游作者：Sintel
- 上游许可：MIT License

第三方版权与完整许可证文本见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
