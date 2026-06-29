# 自动发布到 OHPM —— 配置说明

`publish-ohpm.yml` 的作用:**推送 `v*` tag → 自动打包 HAR → 自动 `ohpm publish` 到鸿蒙中心仓。**

> 为什么用 self-hosted runner(你自己的 Mac)?
> 鸿蒙的 `ohpm` CLI、SDK、hvigor 都是华为门禁下载的,GitHub 托管的 Linux runner 拿不到完整工具链。
> self-hosted 直接复用你本机 DevEco 已装好的一切 + 已配置好的发布密钥(`~/.ohpm/.ohpmrc` 里的 `key_path` / `publish_id`),改动最小、最可靠。

---

## 一次性配置(只做一次)

### 1. 在你的 Mac 上注册 self-hosted runner
GitHub 仓库页 → **Settings → Actions → Runners → New self-hosted runner** → 选 **macOS / ARM64**,
按页面给的命令在你 Mac 上执行(大致如下,以页面实际为准):

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
# 页面会给具体下载链接和带 token 的 config 命令:
curl -o actions-runner-osx-arm64.tar.gz -L <页面给的下载地址>
tar xzf actions-runner-osx-arm64.tar.gz
./config.sh --url https://github.com/lxshwyan/harmony-validator --token <页面给的token>
# 加 macOS / arm64 标签时,labels 里确保有 self-hosted 和 macOS
```

跑起来(两种方式任选):
```bash
./run.sh                      # 前台运行(关终端就停)
# 或装成后台常驻服务:
./svc.sh install && ./svc.sh start
```
> runner 必须在线,workflow 触发时你的 Mac 要开机联网。

### 2. 配置仓库 Secret(存私钥 passphrase)
GitHub 仓库页 → **Settings → Secrets and variables → Actions → New repository secret**
- Name: `OHPM_KEY_PASSPHRASE`
- Value: 你生成发布密钥时设的 passphrase(若当时没设密码,**留空**即可)

> 私钥本身**不用**进 Secret —— 它已经在你 Mac 本地 `~/.ohpm/.ohpmrc` 的 `key_path` 指向处,
> self-hosted runner 跑在同一台机器上直接复用。私钥永远不离开本机。

### 3. 确认本机 ohpm 已配好(之前发 0.1.0 时已配)
```bash
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm config list | grep -E 'key_path|publish_id'
```
能看到 `key_path` 和 `publish_id` 就 OK。

---

## 日常发新版(每次迭代就这 4 步)

```bash
# 1. 改代码,把 validator/oh-package.json5 的 version 升号(如 0.1.1 -> 0.1.2)
#    并更新 validator/CHANGELOG.md

# 2. 提交并推送源码到 GitHub
git add -A && git commit -m "feat: xxx" && git push

# 3. 打 tag(版本号要和 oh-package.json5 里的 version 完全一致)
git tag v0.1.2
git push origin v0.1.2        # ← 这一步触发自动发布

# 4. 去 Actions 页面看运行日志;成功后去 OHPM 个人中心等审核
```

workflow 会自动:校验 tag 与 version 一致 → `hvigorw assembleHar` 打包 → `ohpm publish` 发布。

> 也可以在仓库 **Actions → Publish to OHPM → Run workflow** 手动触发(`workflow_dispatch`)。

---

## 排错
| 现象 | 处理 |
|---|---|
| workflow 一直 queued 不动 | self-hosted runner 没在线;到 Mac 上 `cd ~/actions-runner && ./run.sh` |
| `private key content error` | Secret `OHPM_KEY_PASSPHRASE` 填错;改对再重跑 |
| `tag 与 version 不一致` 报错 | 先把 oh-package.json5 的 version 和 tag 对齐 |
| node 崩(V8 栈) | runner 的 PATH 串到系统新版 node;workflow 已强制用 DevEco node18,一般不会发生 |
| 找不到 HAR | MODULE 名与 build-profile.json5 里的模块名不符;改 workflow 顶部 `MODULE` |

---

## 安全提醒
- ✅ 私钥不进仓库、不进 Secret,只在本机。
- ✅ passphrase 走 GitHub Secret(加密存储,日志里不显示)。
- ⚠️ self-hosted runner 会执行仓库里的 workflow —— 这是**公开仓**,若将来接受外部 PR,
  注意别让不可信 PR 触发 self-hosted runner(GitHub 默认对 fork PR 有保护,但发布类 workflow 建议只允许 tag 触发,本 workflow 已是如此)。
