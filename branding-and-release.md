# KubeMD — 品牌与发布设计（skill 独立仓库）

> 状态：**定稿（2026-08-16）**——用户授权"看着来"，选用 **KubeMD**；README-en 已品牌化；GIF 录制已派发
> 原则：品牌名好记好念（英文世界秒懂），SKILL name 保留功能语义（DSH 生态可被发现）

## 1. 名字候选（按推荐排序）

| 候选 | 含义 | 评价 |
|---|---|---|
| **KubeMD** ⭐推荐 | Kubernetes + MD（Medical Doctor）——"K8s 急诊医生" | 短、押韵、英文秒懂；直接对标 KubeShark 的记忆点结构（Kube+X）；"the doctor for your cluster" 一句话讲清 |
| kubetriage | triage（分诊） | 运维圈术语、专业，但音节长、门槛高一点 |
| kubedx | dx = diagnosis 医学缩写 | 酷、工程师感，但过于冷门，路人看不懂 |
| PodDoc / kubecheck | 直白 | 平淡，无记忆点 |

**SKILL name 保持** `dsh-k8s-diagnosis`（kebab-case + dsh/k8s/diagnosis 三个关键词 = DSH 生态搜索友好），品牌名做传播层。

## 2. 仓库名与品牌映射

- 仓库（organizational 下）：`guiyi-labs/kubemd`
- SKILL 目录名：`~/.dsh/skills/dsh-k8s-diagnosis`（安装路径不变，品牌名只用于 README/传播）
- 一句话定位（English）：**"The Kubernetes surge doctor — evidence-first runtime diagnosis with case memory."**
- 一句话定位（中文）：**"K8s 急诊医生——证据优先的运行时故障诊断，带案例记忆。"**

## 3. topics（GitHub 仓库标签，SEO + 生态露出）

```
kubernetes  k8s  diagnosis  troubleshooting  sre  devops  dsh
deepseek-harness  aiops  incident-response  observability  golang
```

## 4. 视觉概念（logo 方向，后置）

- 概念：**医生听诊器挂在 K8s helm（舵/头盔）上**，或听诊器听诊 Pod 立方体
- 配色：医疗蓝 + DSH badge 蓝（#4D6BFE）呼应
- 用 ASCII 版占位即可，正式 logo 后置（不阻塞发布）

## 5. 发布检查清单（skill 独立仓库）

- [x] SKILL.md / 5 playbooks / signal-map / 2 scripts
- [x] LICENSE（Apache-2.0）
- [x] .gitignore
- [x] cases.yaml 示例（verification: pending，待真实案例替换）
- [x] README-en.md（品牌版，待同步到 README.md）
- [ ] 命令真实验证（aiops Agent 进行中）
- [ ] 验证通过 → 按最终命令修正 playbook
- [ ] topics 设置 + 仓库描述（英文）
- [ ] dsh badge 放入 README（官方 shields.io URL 已备）
- [ ] 创建仓库 + 推送

## 6. 分发渠道（发布日动作）

| 渠道 | 内容 | 优先级 |
|---|---|---|
| DSH 生态 | README 注明 `~/.dsh/skills/` 即用 + dsh badge | P0 |
| r/kubernetes + r/kubernetes-operators | Show 帖 + 30s GIF | P1 |
| r/devops / r/sre | 排障方法论角度（反馈环 + 案例记忆） | P1 |
| 掘金/V2EX/B 站 | 中文章节（从毕设诊断逻辑讲起） | P1 |
| HN（Show HN） | 与 CLI 双线合一时再上（等 `go install` 可用） | P2 |

## 7. 与 CLI 的品牌衔接

- CLI 命名 `aiops`（平台品牌）不变；skill 品牌 KubeMD 独立
- README 互相引用：CLI（自动化入口）↔ skill（agent 引导入口）
- 故事统一：**"同一个诊断内核，两个入口"**

## 8. 待用户确认

1. 名字选 **KubeMD**？还是 kubetriage / 其他？
2. 若定了，README-en.md 的品牌区（标题/定位段）我统一切换