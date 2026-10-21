# newapi-manager

`madfu-manager` skill 的规范存档：NewAPI 中转站（ai.aobzii.cn，香港服务器）与香港机基础运维的日常管理规则。

## 内容

- `madfu-manager/SKILL.md`：正文。三档分工（只读直查 / 低风险写说一声就做 / 高风险每次拍板）、服务器地址簿、巡检与异常报告、八步排查法、计费与渠道的实锤规则、备份升级回滚、报告一律用 answer-me-with-html 渲染等。
- `madfu-manager/skill.yaml`：skill 描述与触发词。
- `madfu-manager/scripts/health-check.sh`：只读巡检脚本，一次跑完服务、资源、双路 HTTP、证书、数据库与近 24 小时消费。
- `madfu-manager/scripts/backup-pull.sh`：用 SQLite backup API 把数据库备份拉回本地，保留 3 天。
- `madfu-manager/references/examples.md`：六个实战事例（多扣、空回、403、unlimited 误判、按次表达式、倍率缓存），每个含症状、查法、证据、结论与现状。

## 安装

把 `madfu-manager/` 整个目录放到 `~/workspace/custom-skills/` 下即可被 Muse 检索到。

## 注意

规范里只有服务器地址与操作规则，不含任何密钥、token 或密码。数据库备份含渠道 key 与密码哈希，切勿提交到本仓库。
