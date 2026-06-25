# 信息处理训练模式 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 7 种思维训练模式基础上，新增第 8 种模式「信息处理」，包含 4 个递进子阶段（关键词提取 → 一句话总结 → 三点复述 → 计时复述+评论），AI 全流程（生成素材 + 评分反馈）+ 12 篇预置题库。

**Architecture:** 所有改动在单文件 `index.html` 中。新增 `infoProcess` 条目到 `TOPICS`/`SCORING_DIMS`/`getUserFieldLabel`/`buildInputs`/`buildTopicPrompt`/`buildScoringPrompt`/`showReview`，新增 `currentInfoStage` 全局状态管理子阶段，阶段 4 增加阅读+输出双倒计时。

**Tech Stack:** 单文件 HTML + 原生 JS + CSS，Anthropic Messages API（兼容 DeepSeek），localStorage 持久化。

## Global Constraints

- 不引入任何新依赖，纯原生 JS
- 不破坏现有 7 种模式的任何功能
- CSS 沿用 `:root` 变量（`--gold`, `--bg-card`, `--text-dim` 等）
- API 调用复用现有 `getApiKey()`/`getApiUrl()`/`getModel()` 和 fetch 模式
- 设计风格与现有 `.topic-card`、`.input-group`、`.answer-block` 保持一致
- 阶段名使用中文：关键词提取、一句话总结、三点复述、计时复述+评论
- 模式图标使用 📡
- 阅读限时 180 秒（3 分钟），输出限时 180 秒（3 分钟）

---

### Task 1: 添加 CSS 样式（阶段 Tabs + 倒计时 + 素材展示区）

**Files:**
- Modify: `index.html` — 在 `<style>` 块内，约在 `.home-reading-card:hover` 之后（line ~458）插入

**Interfaces:**
- Produces: CSS classes `.info-stages`, `.info-stage-tab`, `.info-stage-tab.active`, `.info-material`, `.countdown-bar`, `.countdown-bar.warn`, `.stage-desc`
- Consumes: 无（纯 CSS）

- [ ] **Step 1: 在 `<style>` 尾部（`</style>` 之前）添加 CSS**

插入位置：约 line 458（`.home-reading-card:hover { border-color: var(--gold-dim); }` 之后）

```css
/* Info Process Mode */
.info-stages {
  display: flex; gap: 6px; overflow-x: auto; margin-bottom: 16px;
  padding-bottom: 4px; -webkit-overflow-scrolling: touch;
}
.info-stages::-webkit-scrollbar { display: none; }
.info-stage-tab {
  flex-shrink: 0; padding: 8px 14px; border-radius: 20px;
  border: 1px solid var(--border); background: var(--bg-card);
  color: var(--text-dim); font-size: .78rem; cursor: pointer;
  font-family: inherit; white-space: nowrap; transition: all .2s;
}
.info-stage-tab.active {
  background: var(--gold); color: #fff; border-color: var(--gold);
  font-weight: 600;
}
.info-stage-tab:active { transform: scale(.95); }
.info-stage-tab .stage-num {
  display: inline-block; width: 18px; height: 18px; border-radius: 50%;
  background: var(--bg-input); color: var(--text-dim); font-size: .65rem;
  line-height: 18px; text-align: center; margin-right: 4px;
}
.info-stage-tab.active .stage-num { background: rgba(255,255,255,.3); color: #fff; }

.info-material {
  background: var(--bg-input); border: 1px solid var(--border);
  border-radius: var(--radius-sm); padding: 16px; margin-bottom: 16px;
  font-size: .9rem; line-height: 1.9; color: var(--text);
  white-space: pre-wrap; max-height: 300px; overflow-y: auto;
}
.info-material .material-label {
  font-size: .72rem; color: var(--text-dim); margin-bottom: 10px;
  display: flex; align-items: center; gap: 6px;
}
.info-material .material-label .beta-badge {
  background: var(--border); color: var(--text-dim); font-size: .65rem;
  padding: 2px 8px; border-radius: 10px;
}

.countdown-bar {
  display: flex; align-items: center; gap: 10px; padding: 10px 16px;
  background: var(--bg-card); border: 1px solid var(--border);
  border-radius: var(--radius-sm); margin-bottom: 12px; font-size: .85rem;
}
.countdown-bar .cd-icon { font-size: 1.1rem; }
.countdown-bar .cd-time { font-weight: 700; color: var(--gold); font-variant-numeric: tabular-nums; }
.countdown-bar .cd-label { color: var(--text-dim); font-size: .75rem; }
.countdown-bar.warn .cd-time { color: #d47878; animation: pulse 1s ease-in-out infinite; }
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: .4; } }

.stage-desc {
  font-size: .72rem; color: var(--text-dim); margin-bottom: 12px;
  padding: 6px 12px; background: var(--bg-input); border-radius: 8px;
}
```

- [ ] **Step 2: 提交**

```bash
cd /Users/panhao/Documents/思维训练 && git add index.html && git commit -m "style: add info-process mode CSS (stage tabs, countdown, material)"
```

---

### Task 2: 添加 TOPICS.infoProcess 数据（预设题库 + 4 个阶段定义）

**Files:**
- Modify: `index.html` — 在 `TOPICS` 对象末尾，`essence` 定义结束后（约 line 1320，`};` 之前）插入

**Interfaces:**
- Produces: `TOPICS.infoProcess` 包含 title, icon, hint, aiHint, instruction, stages 数组, items 数组（12 项）
- Consumes: 后续所有 task 依赖此数据

- [ ] **Step 1: 在 `TOPICS` 对象闭合 `};` 前添加 infoProcess**

插入位置：找到 `const TOPICS = {` 的闭合 `};`，在其之前添加。约 line 1320（essence 的 `]}` 之后、`};` 之前）。

```javascript
  infoProcess: {
    title: '信息处理',
    icon: '📡',
    hint: '提取关键词 → 总结 → 复述 → 评论',
    aiHint: 'AI实时生成素材 · 四阶递进 · 智能评分',
    instruction: '读一段材料，按阶段要求处理信息。四个阶段难度递进，可从任意阶段开始。',
    stages: [
      { key: 'extract', label: '关键词提取', desc: '阅读短文，提取3-5个核心关键词' },
      { key: 'summarize', label: '一句话总结', desc: '阅读短文，用一句话概括核心内容' },
      { key: 'retell', label: '三点复述', desc: '阅读对话/观点，用三点框架复述' },
      { key: 'retellTimed', label: '计时复述+评论', desc: '限时阅读后复述内容+附个人评论' },
    ],
    items: [
      // === Stage 1: 关键词提取（3篇） ===
      {
        id: 'ip1', stage: 'extract',
        topic: '阅读以下短文，提取3-5个关键词',
        material: '东京银座的森冈书店，每周只卖一本书。店主森冈督行把15平米的店面清空，只放一张桌子、一本书、一个展览。书每周换一次，展览围绕那本书的主题来做——如果是摄影集，墙上挂原作；如果是小说，摆出作者手稿的复制品。结果呢？这家"什么都买不到"的书店不仅活下来了，还成了全球爱书人的朝圣地。顾客进来不是为了"逛"，是为了"遇见"——他们信任店主的选书品味，愿意为这一本书专程跑一趟。',
        structure: { keywords: ['森冈书店', '每周一书', '策展式零售', '信任', '稀缺'] }
      },
      {
        id: 'ip2', stage: 'extract',
        topic: '阅读以下短文，提取3-5个关键词',
        material: '宜家创始人英格瓦·坎普拉德在17岁时创立了宜家，但他最被低估的决策发生在他中年时期：他决定把公司所有权放进一个复杂的基金会+信托结构里，确保任何人都无法拆分或卖掉宜家。他说："宜家应该是一只永远不需要上市的公牛。"这个结构让宜家避免了大多数家族企业"富不过三代"的诅咒——不是因为后代无能，而是因为制度确保了长期主义永远战胜短期利益。',
        structure: { keywords: ['宜家', '所有权结构', '长期主义', '制度设计', '永续经营'] }
      },
      {
        id: 'ip3', stage: 'extract',
        topic: '阅读以下短文，提取3-5个关键词',
        material: '心理学家亚当·格兰特在《离经叛道》中讲过一个实验：让两组人评估同一个商业计划。A组看到的是一个"经验丰富的创业者"的提案，B组看到的是"新手创业者"的提案——但两份提案内容完全相同。结果A组的评分显著更高。格兰特把这种现象叫"地位启发式"——我们不是评估想法本身，而是评估提出想法的人。这对表达者的启示是：在你开口之前，听众已经根据"你是谁"在打分。你的第一句话如果不能建立可信度，整个表达就在走下坡路。',
        structure: { keywords: ['地位启发式', '可信度', '第一印象', '认知偏差', '表达策略'] }
      },
      // === Stage 2: 一句话总结（3篇） ===
      {
        id: 'ip4', stage: 'summarize',
        topic: '阅读以下短文，用一句话总结核心内容（不超过50字）',
        material: '日本设计师原研哉为无印良品做了一套"地平线"系列海报。他带着团队跑到玻利维亚的乌尤尼盐沼——世界上最大的盐原，天地之间只有一条无尽的地平线。拍了整整三天，最终选了一张：画面中只有一个极小的、远远的人影站在地平线上，其余全是天空和盐原。原研哉解释说："无印良品的本质不是'没有设计'，而是'空'——空不是无，是容纳一切的容器。消费者填进去的，才是最终的设计。"这张海报没有产品、没有logo，但看到它的人都记住了无印良品。',
        structure: { summary: '无印良品用"空"而非"无"定义品牌：空是容纳消费者参与的容器，而非缺少设计。' }
      },
      {
        id: 'ip5', stage: 'summarize',
        topic: '阅读以下短文，用一句话总结核心内容（不超过50字）',
        material: '斯坦福大学教授杰弗里·菲佛在《权力》一书中指出：大多数人在职场中被低估，不是能力问题，是"可见性"问题。他追踪了500名中层管理者5年，发现晋升最快的人并非绩效最高，而是那些"关键决策者知道他们在做什么"的人。菲佛的建议是：每完成一个项目，不要让结果自己说话——要主动让关键人物知道"这个成果是因为我做了什么"。这听起来像自我推销，但数据表明：不这样做的人，平均比懂得做的人晚晋升3-5年。',
        structure: { summary: '职场晋升的关键不是绩效高低，而是关键决策者是否知道你的贡献——可见性比能力更重要。' }
      },
      {
        id: 'ip6', stage: 'summarize',
        topic: '阅读以下短文，用一句话总结核心内容（不超过50字）',
        material: '加州大学洛杉矶分校的阿尔伯特·梅拉比安教授提出了著名的"7-38-55法则"：在情感和态度的沟通中，语言内容只占7%的影响力，语调占38%，而面部表情和肢体语言占55%。这个法则后来被广泛误读为"沟通中语言不重要"，但梅拉比安自己澄清过：这个比例只适用于"说话内容和语气表情不一致时"的判断场景。当一个人嘴上说"我没事"但语气低沉、表情痛苦时，你信的是那55%。但当你做一场路演或汇报时，内容的逻辑结构仍然是最重要的——只是如果逻辑崩了，再好的表情也救不了。',
        structure: { summary: '"7-38-55法则"只适用于言行不一致时的判断，不代表语言内容不重要——正式表达中逻辑结构仍是根基。' }
      ],
      // === Stage 3: 三点复述（3篇） ===
      {
        id: 'ip7', stage: 'retell',
        topic: '阅读以下对话，用三点框架复述设计师的核心观点',
        material: '客户：我想把客厅和阳台之间的墙打掉，做一个开放式的大空间。\n设计师：您平时在客厅主要做什么？\n客户：看电视、喝茶、偶尔接待朋友。\n设计师：阳台呢？\n客户：晾衣服，还有我喜欢种一些花草。\n设计师：如果打通了，湿衣服的水汽会飘到客厅——您的沙发和地板长期接触潮湿空气，寿命会缩短。另外，您种花需要阳光直射，打通后客厅的窗帘如果拉上了，花就晒不到太阳；如果不拉窗帘，看电视又反光。不如这样：保留这面墙的60%，把上半部分做成玻璃隔断——既有通透感，又隔离了水汽，阳台还是阳台，采光也不受影响。\n客户：原来还能这样！这个好。',
        structure: { points: ['设计师没有直接否定客户的想法，而是先从了解客户的行为习惯入手，用"您平时做什么"替代"这样做不好"', '用生活化的后果（水汽伤沙发、反光影响看电视）替代了专业术语（通风、照度），让客户自己感受到打通的风险', '给方案不是简单的是或否，而是保留客户"通透"的核心需求，用玻璃隔断的折中方案达成了两种需求的平衡'] }
      },
      {
        id: 'ip8', stage: 'retell',
        topic: '阅读以下观点陈述，用三点框架复述',
        material: '很多人以为写作能力=文字技巧，但真正的写作能力是思考能力。第一，写作强迫你把模糊的直觉变成清晰的句子——这个过程本身就是思考的深化。你脑子里觉得"我懂了"，但写出来发现只有半页纸，说明你没懂透。第二，写作创造了一个"外部记忆体"——你可以把复杂的论证链条卸载到纸上，然后站在纸外审视它。这就像把脑子里的东西掏出来摆在桌上，用第三者的眼光看。第三，写作是唯一可以让思考跨越时间的工具——你一个月前写的分析，今天还能用它来决策；而你一个月前想的东西，可能早就被新的想法覆盖了。所以写作不是"把想好的写下来"，是"通过写来想清楚"。',
        structure: { points: ['写作的本质不是文字技巧，是思考工具——写作迫使模糊直觉变成清晰句子，深化思考本身', '写作创造"外部记忆体"，让你能跳出自己的大脑，以第三者视角审视自己的论证链条', '写作是唯一让思考跨越时间的工具——写下来的思考不会被遗忘或覆盖，可以持续服务于决策'] }
      },
      {
        id: 'ip9', stage: 'retell',
        topic: '阅读以下对话，用三点框架复述演讲者的核心观点',
        material: '主持人：你反复提到"讲故事"对表达很重要，但很多人觉得"我又不是做销售的，为什么要学讲故事？"\n嘉宾：因为你每天都在说服别人——说服老板给你预算、说服同事配合你、说服家人支持你的决定。数据只能说服大脑，故事才能说服人心。大脑听到数据时在做运算——"这个数字大还是小？对比基准是什么？"大脑听到故事时在做体验——"这个人在那个场景里是什么感觉？"运算会被遗忘，体验会被记住。这就是为什么所有伟大的演讲，你记住的都是里面的故事，而不是里面的数据。',
        structure: { points: ['人人都在说服：不是只有销售需要故事，职场中争取预算、协调同事、家庭决策都需要讲故事', '数据和故事的心理机制不同：数据触发大脑的"运算模式"（易忘），故事触发"体验模式"（易记）', '所有伟大演讲的共性：人们记住的不是数据而是故事，因为故事让人进入场景而非旁观分析'] }
      ],
      // === Stage 4: 计时复述+评论（3篇） ===
      {
        id: 'ip10', stage: 'retellTimed',
        topic: '阅读以下采访片段，限时复述核心内容并附上你的评论',
        material: '记者：你做了十年投资人，最看重的创始人特质是什么？\n投资人：很多人以为我要说"远见"或者"执行力"。但我真正看的是"复述能力"——创始人能不能在听完我一个问题后，用他自己的话重新组织一遍再回答。这听起来简单，实际很难。大部分人是直接回答，但没复述的那一步，你不知道他是否真的理解了你的问题。那些先复述再回答的创始人，谈判效率高出至少一倍——因为双方不会在"你到底有没有听懂我的意思"上浪费时间。\n记者：这个判断标准有点出乎意料。\n投资人：对，因为"听懂"这件事被严重高估了。你需要一个人把他说的话还原出来，才能知道他听到的和你说的是不是一回事。',
        structure: { retelling: '一位投资人说，他最看重的创始人特质不是远见或执行力，而是"复述能力"——能否在回答问题前先用自己的话复述一遍对方的问题。这能验证双方是否真的理解一致，避免在误解基础上沟通。', comment: '投资人的视角非常务实：沟通效率的本质不是"说了多少"，而是"对方听懂了多少"。复述是最低成本的验证机制——把理解外化，让误解在开口前就被发现，而不是在结果的偏差中才发现。' }
      },
      {
        id: 'ip11', stage: 'retellTimed',
        topic: '阅读以下辩论片段，限时复述核心内容并附上你的评论',
        material: '正方：应该让AI参与教育评分，因为它完全客观，不会因为学生的性别、外貌、过往成绩产生偏见。\n反方：你犯了两个错误。第一，AI 不是"完全客观"——AI 学的是人类的数据，人类数据里充满了偏见。如果历史上女性在数学领域被低估，AI 学到的就是"女生数学差"。你把偏见自动化了，不是消除了。第二，教育的核心不是"打分准确"——教育的核心是"激发"。一个老师给你打70分但告诉你"你第三段论证非常精彩，我看到了你的进步"；AI 给你打85分但只给一个冰冷的数字。哪个更能让你明天继续努力？',
        structure: { retelling: '反方从两个角度反驳AI评分：第一，AI学习的恰恰是人类有偏见的数据，AI评分只是把偏见自动化而非消除；第二，教育的核心是激发而非精准打分，人类的鼓励性反馈对学习动力的影响远大于AI的冰冷分数。', comment: '反方的反驳很精彩——他不仅攻击了"AI客观"的前提（数据本身有偏见），还重新定义了评估的目的（激发 > 精确）。这是一种高级的辩论策略：不是和对手在同一个战场纠缠，而是把战场移到更根本的问题上。' }
      },
      {
        id: 'ip12', stage: 'retellTimed',
        topic: '阅读以下采访片段，限时复述核心内容并附上你的评论',
        material: '记者：你做管理咨询二十年，看过无数公司的内部会议。你觉得最无效的会议有什么共同特征？\n顾问：最无效的会议有一个明显的信号——"轮流发言制"。就是每个人按顺序汇报自己的进展，其他人安静地等。这种会议的本质是"同步信息"，而同步信息完全可以用一个共享文档替代。真正有效的会议只做一件事：做决策。把需要决策的议题丢到桌上，所有利益相关方一起讨论、争吵、达成结论。如果一个会议结束后你无法说出"我们决定了什么"，这个会议就是在浪费所有人的时间。\n记者：那汇报怎么办？\n顾问：写下来，会议前发出去，让大家带着"已读完"的假设进入会议室。会议的前5分钟只用来提问澄清，然后立刻进入决策环节。',
        structure: { retelling: '管理顾问认为最无效的会议特征是"轮流汇报"，本质是把同步信息（可用文档替代）和做决策混在一起。真正有效的会议只有一个目的：做决策。信息同步应在会前通过文档完成，会议只用来讨论和决定。', comment: '这个洞察很锋利——它重新定义了会议的价值。不是"我们开了会"就是好的，而是"我们做了决定"才是好的。把同步和决策分开，其实是在保护所有人的时间——信息可以异步消费，但决策需要同步碰撞。' }
      }
    ]
  }
```

**注意**：这段代码加在 `essence` 定义的闭合 `}` 和 `TOPICS` 总闭合 `};` 之间。

- [ ] **Step 2: 提交**

```bash
cd /Users/panhao/Documents/思维训练 && git add index.html && git commit -m "data: add infoProcess mode with 12 preset items across 4 stages"
```

---

### Task 3: 添加 SCORING_DIMS + getUserFieldLabel + 状态变量

**Files:**
- Modify: `index.html` — 三处改动

**Interfaces:**
- Produces: `SCORING_DIMS.infoProcess` (4 组评分维度), `getUserFieldLabel` 新 key 映射, `currentInfoStage` 全局状态
- Consumes: 后续 buildInputs/buildScoringPrompt/showReview 依赖

- [ ] **Step 1: 在 SCORING_DIMS 对象中添加 infoProcess**

插入位置：约 line 2074（`essence` 评分维度闭合 `]` 后、`};` 前）

```javascript
  infoProcess: [
    { key: 'accuracy', label: '信息准确度', desc: '提取的关键信息是否准确、不曲解原意' },
    { key: 'completeness', label: '信息完整度', desc: '是否覆盖了核心信息，有无重大遗漏' },
    { key: 'conciseness', label: '简洁度', desc: '表达是否简洁精准，无冗余废话' }
  ]
```

- [ ] **Step 2: 在 ALL_DIM_KEYS 中添加新维度 key**

找到 `const ALL_DIM_KEYS = [...]`（约 line 2078），在数组末尾添加 `'accuracy', 'completeness', 'conciseness'`。

```javascript
const ALL_DIM_KEYS = ['structure', 'logic', 'depth', 'comprehensiveness', 'insight', 'persuasiveness', 'connection', 'creativity', 'fluency', 'expression', 'diagnosis', 'reasoning', 'strategy', 'script', 'penetration', 'clarity', 'accuracy', 'completeness', 'conciseness'];
```

- [ ] **Step 3: 在 getUserFieldLabel 中添加新 key 映射**

插入位置：约 line 3085（`if (key === 'thinkingPath') return '思考路径';` 之后，`return key;` 之前）

```javascript
  if (key === 'keywords') return '关键词';
  if (key === 'summary') return '一句话总结';
  if (key === 'point1') return '要点一';
  if (key === 'point2') return '要点二';
  if (key === 'point3') return '要点三';
  if (key === 'retelling') return '复述内容';
  if (key === 'comment') return '个人评论';
```

- [ ] **Step 4: 添加全局状态变量**

插入位置：约 line 3517（`let readingState = ...` 之后）

```javascript
let currentInfoStage = 'extract'; // current sub-stage for infoProcess mode
```

- [ ] **Step 5: 提交**

```bash
cd /Users/panhao/Documents/思维训练 && git add index.html && git commit -m "feat: add scoring dims, field labels, and state for infoProcess"
```

---

### Task 4: 修改 buildInputs 支持 infoProcess

**Files:**
- Modify: `index.html` — `buildInputs` 函数（约 line 1839-1875）

**Interfaces:**
- Consumes: `TOPICS.infoProcess`, `currentInfoStage`
- Produces: 4 种输入布局（关键词提取 / 一句话总结 / 三点复述 / 计时复述+评论）

- [ ] **Step 1: 在 buildInputs 中添加 infoProcess 分支**

在 `buildInputs` 函数的 `if/else if` 链末尾（约 line 1874 `}` 之后），添加新的分支。在 `else if (type === 'essence')` 闭合后：

```javascript
  } else if (type === 'infoProcess') {
    const stage = currentInfoStage;
    // Show material (the article/script to read)
    const materialDiv = document.createElement('div');
    materialDiv.className = 'info-material';
    const data = TOPICS.infoProcess;
    const stageInfo = data.stages.find(s => s.key === stage);
    
    // Audio beta badge for stage 3 & 4
    const audioBeta = (stage === 'retell' || stage === 'retellTimed')
      ? '<span class="beta-badge">🔊 模拟听读材料（Beta）</span>' : '';
    
    materialDiv.innerHTML = `
      <div class="material-label">📄 阅读材料${audioBeta}</div>
      <div>${item.material || '（AI 正在生成素材…）'}</div>
    `;
    container.appendChild(materialDiv);
    
    // Stage description
    const descDiv = document.createElement('div');
    descDiv.className = 'stage-desc';
    descDiv.textContent = '📌 ' + (stageInfo ? stageInfo.desc : '');
    container.appendChild(descDiv);
    
    // Inputs per stage
    if (stage === 'extract') {
      addInput(container, '提取关键词', '输入3-5个核心关键词，用逗号或空格分隔', 'keywords', false);
    } else if (stage === 'summarize') {
      addInput(container, '一句话总结', '用一句话概括全文核心内容（不超过50字）', 'summary', true);
    } else if (stage === 'retell') {
      addInput(container, '要点一', '第一个核心要点', 'point1', true);
      addInput(container, '要点二', '第二个核心要点', 'point2', true);
      addInput(container, '要点三', '第三个核心要点', 'point3', true);
    } else if (stage === 'retellTimed') {
      addInput(container, '复述内容', '用自己的话复述原文核心内容', 'retelling', true);
      addInput(container, '个人评论', '你对这个观点/事件的看法和分析', 'comment', true);
    }
  }
```

- [ ] **Step 2: 提交**

```bash
cd /Users/panhao/Documents/思维训练 && git add index.html && git commit -m "feat: add buildInputs for infoProcess with 4 stage layouts"
```

---

### Task 5: 修改 startExercise 支持 infoProcess 的阶段选择

**Files:**
- Modify: `index.html` — `startExercise` 函数（约 line 1768）和 `buildInputs` 调用处（约 line 1835）

**Interfaces:**
- Consumes: `currentInfoStage`, `TOPICS.infoProcess`
- Produces: 阶段 tab 渲染 + 切换逻辑, `nextItem` 按阶段过滤

- [ ] **Step 1: 在 startExercise 中添加阶段 tabs 渲染**

在 `startExercise` 函数中，`buildInputs(type, currentItem)` 调用之前（约 line 1835），添加阶段 tab 渲染：

```javascript
  // InfoProcess: render stage tabs
  const stageTabsDiv = document.getElementById('ex-stage-tabs');
  if (type === 'infoProcess') {
    currentInfoStage = currentInfoStage || 'extract';
    const data = TOPICS[type];
    stageTabsDiv.style.display = '';
    stageTabsDiv.innerHTML = data.stages.map((s, i) =>
      `<button class="info-stage-tab${s.key === currentInfoStage ? ' active' : ''}" onclick="switchInfoStage('${s.key}')">
        <span class="stage-num">${i + 1}</span>${s.label}
      </button>`
    ).join('');
  } else {
    stageTabsDiv.style.display = 'none';
  }
```

- [ ] **Step 2: 在 HTML 中添加 stage tabs 容器**

在 exercise screen 的 HTML 中（约 line 537-565），在 `.ex-header` 和 `.topic-card` 之间添加：

```html
  <div id="ex-stage-tabs" class="info-stages" style="display:none"></div>
```

插入位置：约 line 541（`<div class="ex-header">` 闭合后，`.topic-card` 之前）

- [ ] **Step 3: 修改 nextItem 调用支持阶段过滤**

在 `startExercise` 函数中，对于 infoProcess 的自主练习模式，需要过滤 item：

找到 `currentItem = nextItem(type);`（约 line 1796），在此之前添加过滤逻辑。对于 infoProcess：

```javascript
  // For infoProcess autonomous: filter items by current stage
  if (type === 'infoProcess' && !isAI) {
    const stageItems = data.items.filter(it => it.stage === currentInfoStage);
    if (!stageItems.length) {
      toast('该阶段暂无预设题目，请切换阶段或使用 AI 驱动');
      showScreen('home');
      return;
    }
    // Pick next from filtered items (simple random, avoiding same as last)
    currentItem = stageItems[Math.floor(Math.random() * stageItems.length)];
  }
```

**注意**：infoProcess 模式不使用 `nextItem`/`itemQueues` 系统（因为每个阶段只有 3 题），改用简单随机 + 避免连续重复。`forceItemId` 逻辑保持不变。

- [ ] **Step 4: 添加 switchInfoStage 全局函数**

在 `startExercise` 附近（约 line 1837 之后）添加：

```javascript
function switchInfoStage(stageKey) {
  if (currentType !== 'infoProcess') return;
  currentInfoStage = stageKey;
  startExercise('infoProcess');
}
```

- [ ] **Step 5: 修改 showReview 中 currentType 检查**

`showReview` 中判断 `currentType` 来决定如何显示参考结构。infoProcess 也会有自己的结构显示（Task 7 处理），此处只确保不 fall through。

- [ ] **Step 6: 提交**

```bash
cd /Users/panhao/Documents/思维训练 && git add index.html && git commit -m "feat: add stage tabs and switching for infoProcess mode"
```

---

### Task 6: 添加 buildTopicPrompt 对 infoProcess 的支持

**Files:**
- Modify: `index.html` — `buildTopicPrompt` 函数（约 line 2188）

**Interfaces:**
- Consumes: `currentInfoStage`, `TOPICS.infoProcess`
- Produces: 4 种 AI 出题 prompt（对应 4 个阶段）

- [ ] **Step 1: 在 buildTopicPrompt 中添加 infoProcess 分支**

在 `buildTopicPrompt` 函数的 `if/else` 链末尾（约 line 2275 `return '';` 之前）添加：

```javascript
  if (type === 'infoProcess') {
    const stage = currentInfoStage || 'extract';
    const stageInfo = data.stages.find(s => s.key === stage);
    
    if (stage === 'extract') {
      return base + `生成一个适合"关键词提取"训练的阅读材料：
{
  "topic": "阅读以下短文，提取3-5个关键词",
  "material": "<一篇约300字的短文，领域随机（科普/商业/心理/设计/社会现象等），内容有明确的核心信息点>",
  "stage": "extract",
  "structure": { "keywords": ["<关键词1>", "<关键词2>", "<关键词3>", "<关键词4>", "<关键词5>"] }
}
要求：短文有实质信息量，关键词能准确代表核心内容。用中文，直接返回JSON。`;
    }
    
    if (stage === 'summarize') {
      return base + `生成一个适合"一句话总结"训练的阅读材料：
{
  "topic": "阅读以下短文，用一句话总结核心内容（不超过50字）",
  "material": "<一篇约300-500字的短文，有明确的核心观点或事件，信息密度适中>",
  "stage": "summarize",
  "structure": { "summary": "<一句话总结，覆盖核心信息，不超过50字>" }
}
要求：短文不能太散（多个不相关的点），要有一个贯穿的核心主题。用中文，直接返回JSON。`;
    }
    
    if (stage === 'retell') {
      return base + `生成一个适合"三点复述"训练的素材：
{
  "topic": "<训练标题，如'阅读以下对话，用三点框架复述核心观点'>",
  "material": "<一段模拟对话/观点陈述/访谈，约500字。可以是两个人辩论、专家讲解、或者一段有结构的观点输出。内容有明确的信息层次，适合被拆成3个要点>",
  "stage": "retell",
  "structure": { "points": ["<要点1>", "<要点2>", "<要点3>"] }
}
要求：素材有明显的3层信息结构，复述时要能自然拆成3个要点。领域随机但内容有讨论价值。用中文，直接返回JSON。`;
    }
    
    if (stage === 'retellTimed') {
      return base + `生成一个适合"计时复述+评论"训练的素材：
{
  "topic": "<训练标题>",
  "material": "<一段模拟采访/辩论/演讲片段，约600字。内容有观点冲突或反直觉洞察，适合引发评论>",
  "stage": "retellTimed",
  "structure": { "retelling": "<参考复述：准确概括原文核心>", "comment": "<参考评论：对观点的分析和见解>" }
}
要求：素材要有一定的观点张力——有值得评论的"抓手"。不能是平淡的信息陈述。用中文，直接返回JSON。`;
    }
    
    return '';
  }
```

**注意**：`base` 变量已经定义了 `你是思维训练出题专家。为「${data.title}」模式生成一道新题目。模式说明：${data.instruction}`。

- [ ] **Step 2: 修改 generateAiTopic 解析 infoProcess 返回**

`generateAiTopic` 函数（约 line 2278）中的 JSON 解析和 item 构建部分已经通用（通过 `parsed.topic`, `parsed.structure` 等字段）。但需要确保 `material` 和 `stage` 字段被保留。

在 `generateAiTopic` 中（约 line 2353-2356，复制额外字段的区域），添加：

```javascript
    if (parsed.material) item.material = parsed.material;
    if (parsed.stage) item.stage = parsed.stage;
```

- [ ] **Step 3: 提交**

```bash
cd /Users/panhao/Documents/思维训练 && git add index.html && git commit -m "feat: add AI topic generation prompts for infoProcess 4 stages"
```

---

### Task 7: 添加 showReview 参考结构展示 + buildScoringPrompt 对 infoProcess 的支持

**Files:**
- Modify: `index.html` — `showReview` 函数（约 line 1947）和 `buildScoringPrompt` 函数（约 line 2365）

**Interfaces:**
- Consumes: `currentType === 'infoProcess'`, `currentItem.structure`
- Produces: 4 种参考结构展示 + 评分 prompt 中的参考结构格式化

- [ ] **Step 1: 在 showReview 中添加 infoProcess 参考结构展示**

在 `showReview` 函数的 `else if` 链末尾（约 line 1993 `}` 后），添加：

```javascript
  } else if (currentType === 'infoProcess') {
    const stage = currentItem.stage || 'extract';
    if (stage === 'extract' && struct.keywords) {
      html += `<div class="answer-block structure-ref"><div class="block-label">参考关键词</div><div class="block-content">${struct.keywords.join('、')}</div></div>`;
    } else if (stage === 'summarize' && struct.summary) {
      html += `<div class="answer-block structure-ref"><div class="block-label">参考总结</div><div class="block-content">${struct.summary}</div></div>`;
    } else if (stage === 'retell' && struct.points) {
      struct.points.forEach((p, i) => {
        html += `<div class="answer-block structure-ref"><div class="block-label">参考要点${i + 1}</div><div class="block-content">${p}</div></div>`;
      });
    } else if (stage === 'retellTimed') {
      if (struct.retelling) {
        html += `<div class="answer-block structure-ref"><div class="block-label">参考复述</div><div class="block-content">${struct.retelling}</div></div>`;
      }
      if (struct.comment) {
        html += `<div class="answer-block structure-ref"><div class="block-label">参考评论</div><div class="block-content">${struct.comment}</div></div>`;
      }
    }
  }
```

- [ ] **Step 2: 在 buildScoringPrompt 中添加 infoProcess 评分上下文（含素材原文）**

在 `buildScoringPrompt` 函数中，需要在 prompt 里包含素材原文，AI 才能准确评估用户的提取/总结是否正确。修改方案：

在 `buildScoringPrompt` 的 `else if` 链末尾（约 line 2396 `}` 后），添加参考结构格式化：

```javascript
  } else if (entry.type === 'infoProcess') {
    const stage = struct._stage || currentItem?.stage || 'extract';
    if (stage === 'extract') {
      refLines = `参考关键词：${(struct.keywords || []).join('、')}`;
    } else if (stage === 'summarize') {
      refLines = `参考总结：${struct.summary || ''}`;
    } else if (stage === 'retell') {
      refLines = (struct.points || []).map((p, i) => `要点${i + 1}：${p}`).join('\n');
    } else if (stage === 'retellTimed') {
      refLines = `参考复述：${struct.retelling || ''}\n参考评论：${struct.comment || ''}`;
    }
  }
```

**注意 1**：评分时 AI 需要看到素材原文才能准确评估。需要在 `buildScoringPrompt` 的 prompt 模板中，对于 infoProcess 类型，在「用户回答」之前插入「阅读材料」部分：

```javascript
// In buildScoringPrompt, after answerLines is built, add material for infoProcess:
let materialSection = '';
if (entry.type === 'infoProcess' && entry._item.material) {
  materialSection = `\n【阅读材料】\n${entry._item.material}\n`;
}
// Then use materialSection in the final prompt template after the topic line
```

完整的 infoProcess prompt 模板需要修改——在 `【题目】` 和 `【用户回答】` 之间插入 `【阅读材料】`。由于 `buildScoringPrompt` 返回的是整个 prompt 字符串，在 return 语句中调整：

```javascript
// In the return statement, change:
// 【题目】
// ${topic}
// to:
// 【题目】
// ${topic}
// ${materialSection}
```

**注意 2**：`buildScoringPrompt` 中 `struct` 来自 `entry._item.structure`。取 stage 需要从 `entry._item` 读取（stage 在 item 上而非 structure 上）：

```javascript
  } else if (entry.type === 'infoProcess') {
    const itemStage = entry._item?.stage || 'extract';
    if (itemStage === 'extract') {
      refLines = `参考关键词：${(struct.keywords || []).join('、')}`;
    } else if (itemStage === 'summarize') {
      refLines = `参考总结：${struct.summary || ''}`;
    } else if (itemStage === 'retell') {
      refLines = (struct.points || []).map((p, i) => `要点${i + 1}：${p}`).join('\n');
    } else if (itemStage === 'retellTimed') {
      refLines = `参考复述：${struct.retelling || ''}\n参考评论：${struct.comment || ''}`;
    }
  }
```

- [ ] **Step 3: 提交**

```bash
cd /Users/panhao/Documents/思维训练 && git add index.html && git commit -m "feat: add review display and scoring prompt for infoProcess"
```

---

### Task 8: 阶段 4 计时器（阅读倒计时 + 输出倒计时）

**Files:**
- Modify: `index.html` — 新增计时器函数，修改 submitExercise 和 buildInputs

**Interfaces:**
- Consumes: `currentInfoStage`, `currentType`
- Produces: `startReadingTimer()`, `startOutputTimer()`, `clearInfoTimers()`

- [ ] **Step 1: 在 buildInputs 中为阶段 4 添加倒计时区域**

在 `buildInputs` 函数的 `infoProcess` 分支中，阶段 4（retellTimed）添加倒计时 DOM：

在 `addInput` 调用之前，添加：

```javascript
    if (stage === 'retellTimed') {
      const countdownDiv = document.createElement('div');
      countdownDiv.id = 'info-countdown';
      countdownDiv.className = 'countdown-bar';
      countdownDiv.innerHTML = '<span class="cd-icon">⏳</span><span class="cd-label">阅读倒计时</span><span class="cd-time">3:00</span>';
      container.appendChild(countdownDiv);
    }
```

- [ ] **Step 2: 在 startExercise 中启动阅读倒计时**

在 `buildInputs` 调用之后（约 line 1836），对于 infoProcess retellTimed：

```javascript
  // InfoProcess stage 4: start reading timer
  if (type === 'infoProcess' && currentInfoStage === 'retellTimed') {
    clearInfoTimers();
    startReadingTimer();
  }
```

- [ ] **Step 3: 添加计时器全局函数**

在 `startExercise` 函数附近添加三个新函数：

```javascript
let _infoReadingTimer = null;
let _infoOutputTimer = null;
let _infoReadingSeconds = 180;
let _infoOutputSeconds = 180;

function clearInfoTimers() {
  if (_infoReadingTimer) { clearInterval(_infoReadingTimer); _infoReadingTimer = null; }
  if (_infoOutputTimer) { clearInterval(_infoOutputTimer); _infoOutputTimer = null; }
  _infoReadingSeconds = 180;
  _infoOutputSeconds = 180;
}

function startReadingTimer() {
  _infoReadingSeconds = 180;
  const cdEl = document.getElementById('info-countdown');
  if (!cdEl) return;
  
  _infoReadingTimer = setInterval(() => {
    _infoReadingSeconds--;
    const min = Math.floor(_infoReadingSeconds / 60);
    const sec = _infoReadingSeconds % 60;
    cdEl.innerHTML = `<span class="cd-icon">📖</span><span class="cd-label">阅读倒计时</span><span class="cd-time">${min}:${sec.toString().padStart(2, '0')}</span>`;
    
    if (_infoReadingSeconds <= 30) cdEl.classList.add('warn');
    
    if (_infoReadingSeconds <= 0) {
      clearInterval(_infoReadingTimer);
      _infoReadingTimer = null;
      cdEl.classList.remove('warn');
      cdEl.innerHTML = '<span class="cd-icon">✏️</span><span class="cd-label">请开始复述+评论</span><span class="cd-time">3:00</span>';
      startOutputTimer();
    }
  }, 1000);
}

function startOutputTimer() {
  _infoOutputSeconds = 180;
  const cdEl = document.getElementById('info-countdown');
  if (!cdEl) return;
  
  _infoOutputTimer = setInterval(() => {
    _infoOutputSeconds--;
    const min = Math.floor(_infoOutputSeconds / 60);
    const sec = _infoOutputSeconds % 60;
    cdEl.innerHTML = `<span class="cd-icon">✏️</span><span class="cd-label">输出倒计时</span><span class="cd-time">${min}:${sec.toString().padStart(2, '0')}</span>`;
    
    if (_infoOutputSeconds <= 30) cdEl.classList.add('warn');
    
    if (_infoOutputSeconds <= 0) {
      clearInterval(_infoOutputTimer);
      _infoOutputTimer = null;
      cdEl.classList.remove('warn');
      cdEl.innerHTML = '<span class="cd-icon">⏰</span><span class="cd-label">时间到</span><span class="cd-time">0:00</span>';
      submitExercise(); // Auto-submit when time is up
    }
  }, 1000);
}
```

- [ ] **Step 4: 在 submitExercise 和 confirmBack 中清理计时器**

在 `submitExercise` 函数开头（约 line 1896）添加：`clearInfoTimers();`
在 `confirmBack` 函数中（约 line 2031），`showScreen('home')` 之前添加：`clearInfoTimers();`

- [ ] **Step 5: 在 stopTimer（全局）中也清理 info timers**

找到 `stopTimer` 函数，添加 `clearInfoTimers();`。

- [ ] **Step 6: 提交**

```bash
cd /Users/panhao/Documents/思维训练 && git add index.html && git commit -m "feat: add stage 4 dual countdown timer for infoProcess"
```

---

### Task 9: 积分测试与调试

**Files:**
- Modify: `index.html`

- [ ] **Step 1: 验证自主练习赛道流程**

1. 启动 dev server：`cd /Users/panhao/Documents/思维训练 && python3 -m http.server 8000`
2. 打开 `http://localhost:8000`
3. 选择「自主练习」赛道
4. 点击「信息处理」卡片
5. 确认阶段 tabs 显示，依次点击 4 个阶段
6. 每个阶段：填写内容 → 提交 → 查看参考结构 → 手动评分 → 保存
7. 返回首页确认队列状态显示正确

- [ ] **Step 2: 验证 AI 驱动赛道流程**

1. 设置 API Key
2. 切换到 AI 驱动赛道
3. 进入信息处理 → 每个阶段各做一次
4. 确认 AI 生成素材成功，显示在阅读材料区域
5. 确认 AI 评分正常返回，显示评分结果
6. 确认阶段 4 倒计时正常：阅读 3 分钟倒计时 → 自动切换输出倒计时 → 到时自动提交

- [ ] **Step 3: 验证无回归**

1. 测试现有 7 种模式各一道题（AI 赛道 + 自主赛道）
2. 测试阅览室正常加载
3. 测试设置页面、统计数据正常

- [ ] **Step 4: 修复问题并提交最终版本**

```bash
cd /Users/panhao/Documents/思维训练 && git add index.html && git commit -m "fix: infoProcess mode testing fixes and polish"
```

---

### Task 10: 部署到 GitHub Pages

**Files:**
- Modify: 无

- [ ] **Step 1: 推送到远程仓库**

```bash
cd /Users/panhao/Documents/思维训练 && git push origin main
```

- [ ] **Step 2: 验证线上版本**

打开 GitHub Pages URL，重复 Task 9 的验证流程。

- [ ] **Step 3: 提交最终验证结果**

截图确认线上版本四个阶段均可正常使用。
