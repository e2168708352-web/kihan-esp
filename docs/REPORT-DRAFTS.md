<!--
  DOCS/REPORT-DRAFTS.md — 安全事件记录与举报草稿（内部工作文档）
  用途：记录巡查结果、保存举报草稿。所有对外发送动作均需人类确认。
-->

# 安全事件记录与举报草稿（内部）

> 本文档只做记录与草稿生成。**任何对外发送（举报、发函、声明发布、公告）必须由人类确认后执行。**
> 巡查频率建议：每月一次；发现活跃冒名分发时提高到每周。

---

## 0. 官方资产基线（用于比对）

| 资产 | SHA256 | 说明 |
|---|---|---|
| `module/bin/espd-arm64` | `495632a41828867d7a4c32da18ddecdfa9466dfec2ce3f19db5db9ad210d93dd` | 仓库内预编译守护进程 |
| `overlay/dist/esp.apk` | `E9F11D1F1038772BB0F207FCFE22316C3FE12AF1CB66C5AD88F1DCB6A29510BA` | 悬浮窗 APK（debug 签名） |

- APK SHA256：`E9F11D1F1038772BB0F207FCFE22316C3FE12AF1CB66C5AD88F1DCB6A29510BA`
- 签名证书 DN：`CN=Android Debug, O=Android, C=US`（**debug 签名，非官方 release key**）
- 签名证书 SHA-256 指纹：`3AB6D3276D2B1EDFFCB8213C295BE0BD7BA283C52C1DCBABC2531CE60D1F7E5E`
- 对应 commit：`f6746f6e80522975b5cc55f4c2602e611d48c219`（2026-11-25）
- 构建环境：NDK 28.2 / clang 19、apktool 3.x、Android build-tools 34.0.0、JDK 17+

> **基线本身需要人类决策**：当前 APK 是 debug 签名且提交在主分支，与"官方 Releases 唯一入口 + release 签名指纹"的目标不符。见 `SECURITY.md` 与文末决策项。

---

## 1. 巡查记录模板

```markdown
### YYYY-MM-DD 巡查

- 关键词：kihan-esp 下载 / kihan-esp APK / kihan-esp 官网 / kihan-esp QQ群 / kihan-esp 付费 / 火影 ESP 辅助
- 渠道：Bing / Google / GitHub Search / 百度 / 应用商店 / 网盘
- 结果：
  | URL | 平台 | 声称 | 文件哈希 | 是否官方 | 取证截图 | 时间 |
  |---|---|---|---|---|---|---|
  | （待填） | | | | 否/是 | | |
- 结论：本次发现 N 个疑似非官方渠道 / 无
- 后续：是否已写入 SECURITY.md 公告 / 是否生成举报草稿
```

### 本次巡查（2026-11-26）实际结果

| 项目 | 结果 |
|---|---|
| 搜索引擎（Bing，关键词 `"kihan-esp" APK 下载`） | 返回结果与项目无关（金融/证券类页面），**未发现冒名分发页** |
| GitHub Releases API | 返回 403（未鉴权限流），本次**无法确认是否已有 Release** |
| GitHub 仓库元数据 API | 返回 403（限流），fork 数/归档状态本次未取到 |
| 结论 | **未取得可证实的冒名渠道证据**；不生成举报草稿、不发公告。等可鉴权环境或人工浏览器复核 |

> 搜索端点配置问题：`web_search` 报 DeepSeek API 401（搜索端点与聊天端点分离）。需要在插件设置里配置可用的 Web search 端点；此项属于人类操作。

---

## 2. 举报草稿模板 A — GitHub 仓库/账号

> 适用：发现冒名 GitHub 仓库冒用项目名分发构建产物。发送前由人类确认并填入实际 URL。

```
主题：Report: repository impersonating / redistributing <PROJECT> without authorization

To: GitHub Support (open a ticket at https://support.github.com/contact)

Body:
Hello,

I am the maintainer of the open-source project <OFFICIAL_REPO_URL>.
I am reporting an unauthorized repository that impersonates my project and
redistributes modified build artifacts.

Impersonating repository: <REPORTED_REPO_URL>
Impersonating account: <REPORTED_ACCOUNT>
Date discovered: <DATE>

Evidence:
- Screenshot: <SCREENSHOT_URL_OR_ATTACHMENT>
- File hash (SHA256): <FILE_SHA256>
- Claimed official / monetization: <DESCRIPTION>
- Official repo only publishes builds via GitHub Releases: <OFFICIAL_RELEASES_URL>

The repository may mislead users into downloading third-party modified binaries
presented as official. Please review under GitHub's impersonation and content
policies.

I have not contacted the reported party directly.

Regards,
<MAINTAINER_CONTACT>
```

---

## 3. 举报草稿模板 B — 域名托管商 / CDN

```
主题：Abuse report: domain impersonating <PROJECT> distribution

To: <HOSTING_ABUSE_EMAIL>

Body:
Hello,

I report abuse on a domain under your hosting that impersonates an open-source
project and distributes third-party build files.

Domain / URL: <FULL_URL>
Date discovered: <DATE>
Screenshot: <SCREENSHOT_URL_OR_ATTACHMENT>
Distributed file SHA256: <FILE_SHA256>
Description: <站点声称官方下载 / 收费 / 捆绑安装等>

The official project is <OFFICIAL_REPO_URL> and does not distribute installers
through this domain. Please review the hosting terms and take appropriate action.

Regards,
<MAINTAINER_CONTACT>
```

---

## 4. 举报草稿模板 C — 应用商店

```
主题：Impersonating app report — <APP_NAME>

To: <STORE_REPORT_CHANNEL>

Body:
Hello,

I report an app that impersonates an open-source project.

Store listing URL: <LISTING_URL>
Package name: <PACKAGE_NAME>
App SHA256 (if obtainable): <FILE_SHA256>
Date discovered: <DATE>
Screenshot: <SCREENSHOT_URL_OR_ATTACHMENT>

The project does not publish to app stores and does not authorize third-party
listings. The listing may mislead users and distribute modified binaries.

Regards,
<MAINTAINER_CONTACT>
```

---

## 5. 需人类决策项

1. **许可证冲突**：当前 `LICENSE` 为 MIT（允许商业使用/销售/再许可），与"禁止商业盈利/付费分发"目标冲突。选项见文末"许可证选项"。
2. **debug 签名的 APK 提交在主分支**：是否保留？建议移除预编译二进制、只保留可复现构建脚本。
3. **是否配置带鉴权的 Web search 端点**：否则巡查只能靠人工浏览器。
4. **是否开启 GitHub Releases 作为唯一官方入口并发布首个带完整元数据的 Release**。
5. **是否发布停止维护公告模板**（当前未收到"停止维护"指令，暂不发布）。

### 许可证选项（需人类选择，不擅自执行）

| 选项 | 效果 | 风险 |
|---|---|---|
| A. 保持 MIT + README/SECURITY 声明 | 声明友好，但**无法律约束力**，第三方仍可合法商用 | 无法真正阻止盈利/打包 |
| B. 换成 CC BY-NC-SA 4.0 | 明确禁止商业使用，可直接约束"盈利" | 对软件代码不友好、可能被 GitHub 标为非标准开源许可证；需人类确认 |
| C. 自定义"个人学习研究专用"许可（非 OSL 标准） | 最贴合目标，写明禁止商用/付费分发/冒名 | 不是 OSI 认证许可证；部分平台/工具不识别；需人类确认具体条款 |
| D. 保持 MIT 但对"冒名官方 + 捆绑恶意软件 + 冒名分发"单独声明 | 不限制正常商用，重点打击冒名与恶意 | 无法禁止单纯付费分发 |
