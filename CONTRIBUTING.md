# 参与贡献

感谢你改进 `@hmkit/validator`。提交前请先搜索现有 Issue，较大的 API 变更建议先开 Issue 讨论。

## 本地开发

1. 使用 DevEco Studio 打开项目，并确认 SDK/工具链可用。
2. 运行 `./scripts/verify.sh`。
3. 新规则必须同时包含通过、失败和边界测试。
4. 用户可见变更需要更新中英文 README 与 `validator/CHANGELOG.md`。

测试门禁要求行覆盖率不低于 90%、函数不低于 80%、分支不低于 80%。仅在有明确原因时通过
`COVERAGE_MIN_LINES` / `COVERAGE_MIN_FUNCTIONS` / `COVERAGE_MIN_BRANCHES` 临时调整本地门槛，CI 使用默认值。

## 提交约定

- 保持一个提交只解决一个主题。
- 推荐使用 `feat:`、`fix:`、`docs:`、`test:`、`chore:` 前缀。
- 不提交真实手机号、身份证、银行卡、密钥、token 或其他个人信息。
- 不手工提交 `build/`、`.test/`、`oh_modules/` 或自动生成的 `BuildProfile.ets`。

## Pull Request 检查

- [ ] `./scripts/verify.sh` 通过
- [ ] 新行为有 Hypium 测试
- [ ] API 与中英文文档一致
- [ ] 不包含破坏性 API；如不可避免，已在 Issue 中说明迁移方案
