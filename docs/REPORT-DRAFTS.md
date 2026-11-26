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
| `module/bin/espd-arm64` | `202F6D59DD1C274E60C2516A11916F8343F17B151F5E759BCC84018D58EECB33` | 仓库内预编译守护进程（39,712 B，当前源码重编） |
| `overlay/dist/esp.apk` | `E61BE0464501E54BD9A64302215A061341618329605C0982B26CA4B2B6DBDBAB` | 悬浮窗 APK（debug 签名） |

- APK SHA256：`E61BE0464501E54BD9A64302215A061341618329605C0982B26CA4B2B6DBDBAB`
- 签名证书 DN：`CN=Android Debug, O=Android, C=US`（**debug 签名，非官方 release key**）
- 签名证书 SHA-256 指纹：`3AB6D3276D2B1EDFFCB8213C295BE0BD7BA283C52C1DCBABC2531CE60D1F7E5E`
- 对应 commit：`a2d20f6c2c4aaa0eaeea5b8afb670a37633df32d`（2026-11-26）
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

### 巡查记录 2026-11-26（两次）

第一次（哈希未鉴权环境）：

| 项目 | 结果 |
|---|---|
| 搜索引擎（Bing，关键词 `"kihan-esp" APK 下载`） | 返回结果与项目无关（金融/证券类页面），**未发现冒名分发页** |
| GitHub Releases API | 返回 403（未鉴权限流），本次无法确认是否已有 Release |
| GitHub 仓库元数据 API | 返回 403（限流），fork 数/归档状态未取到 |

第二次（浏览器直连仓库页面复核）：

| 项目 | 结果 |
|---|---|
| 仓库页面内嵌元数据 | `forksCount=0`、`stargazerCount=0`、`watcherCount=0`、`isArchived=false` |
| GitHub 全站仓库搜索 `kihan-esp` / `kihan esp` | 只有官方仓库 `e2168708352-web/kihan-esp` 本身，无同名/仿冒仓库 |
| Bing：`kihan-esp` + QQ群 / 网盘 / 付费 | 无相关结果（返回无关内容） |
| Bing：`site:pan.baidu.com` / `site:qq.com` + `kihan-esp` | 「没有与此相关的结果」 |
| Bing：`火影忍者手游 ESP 下载` | 「没有与此相关的结果」 |
| Google：`kihan-esp` 及组合词 | 搜索端点返回跳转页，无有效结果 |
| Releases 页面 | `NO_RELEASES`（官方入口存在但尚未发布任何产物） |

**结论**：两次巡查均**未取得可证实的冒名渠道证据**；不生成举报草稿、不发公告。0 fork、0 star、0 冒名仓库、0 可检索到的第三方分发页。

> 搜索端点配置问题：`web_search` 报 DeepSeek API 401（搜索端点与聊天端点分离）。需要在插件设置里配置可用的 Web search 端点；此项属于人类操作。
> 搜索盲区：私聊、封闭 QQ 群、未索引的网盘分享、刚上线未收录的页面，公开搜索查不到。「没搜到」≠「绝对没人分发」。

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

## 5. 决策记录

| # | 决策项 | 状态 | 结果 |
|---|---|---|---|
| 1 | 许可证类型 | ✅ 已执行（2026-11-26） | 由 MIT 改为「个人学习与研究专用许可协议 v1.0」（选项 C 的落地形式）。见 `LICENSE` |
| 2 | 预编译二进制在主分支 | ✅ 已执行（2026-11-26） | `module/bin/espd-arm64`、`overlay/dist/esp.apk` 取消跟踪并加入 `.gitignore`，仅随 Release 发布 |
| 3 | 首个官方 Release | ✅ 已执行（2026-11-26） | 发布 `v2.0.0`，含 SHA256 / 签名指纹 / 构建 commit / 构建环境 |
| 4 | 带鉴权的 Web search 端点 | ⏳ 待人类 | 未配置，巡查目前靠人工浏览器 |
| 5 | 停止维护公告 | ⏳ 未触发 | 未收到"停止维护"指令 |

### 历史选项记录（保留备查）

| 选项 | 效果 | 风险 |
|---|---|---|
| A. 保持 MIT + README/SECURITY 声明 | 声明友好，但**无法律约束力** | 无法真正阻止盈利/打包 |
| B. 换成 CC BY-NC-SA 4.0 | 明确禁止商业使用 | 对软件代码不友好 |
| C. 自定义"个人学习研究专用"许可 | 最贴合目标 ✅ 已采用 | 非 OSI 认证许可 |
| D. 保持 MIT + 仅打击冒名 | 不限制正常商用 | 无法禁止单纯付费分发 |
