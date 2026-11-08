# 课后记首版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个本地运行的 HarmonyOS 一对一家教课后记录 App，支持后付、课时包、学情记录、家长反馈复制和历史查询。

**Architecture:** 使用单模块 Stage 工程。ArkUI 页面通过 `TutorViewModel` 调用 `TutorRepository`；金额计算、输入校验和反馈模板保持为无系统依赖的纯 ArkTS，本地数据通过 `relationalStore` 保存，课程与账目变化在同一数据库事务中提交。

**Tech Stack:** HarmonyOS Compatible SDK 26.0.0、ArkTS、ArkUI、relationalStore、DECC-ArkTSUnit/Hypium、hvigorw 6.26.9、DevEco Studio 自带 Node.js 与 ohpm。

**Spec:** `docs/superpowers/specs/2026-11-08-post-class-record-design.md`

## Global Constraints

- 工程根目录固定为 `D:/Harmony_AI_Lab/AfterClass`；E 盘仅保留空的 `Harmony_AI_Lab` 集合目录。
- 首版仅支持个人一对一家教，不加入班课、复杂课表、账号、云同步、AI、PDF、真实支付、广告或应用内付费。
- 核心流程离线可用，不申请网络、相机、麦克风、定位、NFC 或蓝牙权限。
- 金额以整数分保存，禁止以浮点数持久化金额；课时以整数保存。
- 后付支持按小时和按次定价；金额与扣课数保存前均可修正。
- 课时余额不足时阻止新增或修改；收费方式切换前必须结清待收金额或用完剩余课时。
- 家长反馈保存为独立快照，来源课程编辑不得覆盖反馈。
- 所有命令在工程根目录执行；Git Bash 中先执行 `export DEVECO_HOME='D:/Applications/Huawei/DevEco Studio'`。
- 构建命令统一为 `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" <task> --no-daemon`，不得用静态检查代替实际构建。
- 每个任务完成后只提交该任务相关文件，提交信息使用 Conventional Commits。

## Review Focus

- 零值、负数、非整数课时和非有限金额必须被拒绝；Task 2 的 `billing_rejects_invalid_numbers` 固定该行为。
- 历史课程编辑导致课时超扣也必须回滚；Task 4 的 `lesson_edit_overdraft_rolls_back` 固定该行为。
- 连续提交同一表单不得生成两条课程或重复扣账；Task 4 的 `lesson_create_is_idempotent` 与 Task 6 的重复点击验证共同覆盖。
- 收费方式切换不能丢失未结余额；Task 3 的 `billing_switch_requires_zero_balance` 固定该行为。
- 多行文本、特殊字符和反馈手工编辑不得被后续课程编辑覆盖；Task 2 的 `feedback_preserves_multiline_text` 与 Task 4 的 `feedback_is_independent_snapshot` 固定该行为。

---

### Task 1: 可构建的 Empty Ability 工程

**Files:**
- Create: `AppScope/app.json5`、`AppScope/resources/base/element/string.json`、`AppScope/resources/base/media/app_icon.png`
- Create: `build-profile.json5`、`hvigorfile.ts`、`oh-package.json5`、`.gitignore`
- Create: `entry/build-profile.json5`、`entry/hvigorfile.ts`、`entry/oh-package.json5`、`entry/src/main/module.json5`
- Create: `entry/src/main/ets/entryability/EntryAbility.ets`、`entry/src/main/ets/pages/Index.ets`
- Create: `entry/src/main/resources/base/profile/main_pages.json`、默认字符串/颜色资源、`entry/src/test/ets/List.test.ets`

**Interfaces:**
- Produces: HarmonyOS Stage 单模块工程，bundleName 暂定 `com.yijuntuqi.afterclass`，应用名 `课后记`，模块名 `entry`，主页面路由 `pages/Index`。
- Produces: 后续任务使用的构建、Local Test 与 Instrument Test 命令。

- [ ] **Step 1: 创建标准 Empty Ability 工程骨架**

按官方 Stage 目录结构创建上述文件，Compatible SDK 使用 `26.0.0`，保持默认 `default` product 与 target；`module.json5` 不声明任何敏感权限。`.gitignore` 排除 `.idea/`、`.hvigor/`、`oh_modules/`、各模块 `build/`、本地签名文件和系统临时文件。

- [ ] **Step 2: 安装工程依赖**

Run: `powershell.exe -NoProfile -Command '& "D:\Applications\Huawei\DevEco Studio\tools\ohpm\bin\ohpm.bat" install --all'`
Expected: 命令退出码为 0，生成锁文件和依赖目录；若模板无三方依赖，不新增依赖。

- [ ] **Step 3: 验证首次构建与 Local Test 入口**

Run: `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" clean assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`
Expected: `BUILD SUCCESSFUL`，生成 debug HAP。

Run: `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" test --mode module -p product=default -p module=entry@default --no-daemon`
Expected: 默认 Local Test 执行成功；若模板没有测试任务，先按官方 Local Test 模板补齐 `entry/src/test/ets/List.test.ets`，不得改用其他测试框架。

- [ ] **Step 4: 初始化本地版本控制并提交骨架**

Run: `git init && git add AppScope entry build-profile.json5 hvigorfile.ts oh-package.json5 oh-package-lock.json5 .gitignore && git commit -m "chore: initialize HarmonyOS project"`
Expected: 生成一次本地提交，不配置远端、不提交构建产物或签名材料。

### Task 2: 金额、课时与反馈领域规则

**Files:**
- Create: `entry/src/main/ets/model/Types.ets`
- Create: `entry/src/main/ets/domain/Billing.ets`
- Create: `entry/src/main/ets/domain/FeedbackFormatter.ets`
- Create: `entry/src/test/ets/Billing.test.ets`、`entry/src/test/ets/FeedbackFormatter.test.ets`
- Modify: `entry/src/test/ets/List.test.ets`

**Interfaces:**
- Produces: `BillingMode = 'POSTPAID' | 'PREPAID'`、`PriceUnit = 'HOURLY' | 'PER_LESSON'`。
- Produces: `StudentInput`、`LessonInput`、`PaymentInput`、`TopUpInput` 等 ArkTS interface；所有金额字段名以 `Fen` 结尾，课程创建包含 `requestId: string`。
- Produces: `calculateAmountFen(unit: PriceUnit, unitPriceFen: number, durationMinutes: number): number`。
- Produces: `validateLesson(durationMinutes: number, amountFen: number | null, deduction: number | null): void`。
- Produces: `validatePackageDeduction(deduction: number, remainingLessons: number): void`。
- Produces: `canSwitchBilling(outstandingFen: number, remainingLessons: number): boolean`。
- Produces: `formatParentFeedback(studentNickname: string, lesson: LessonInput): string`。

- [ ] **Step 1: 写失败的 Local Test**

使用 `@ohos/hypium` 的 `describe/it/expect`，加入以下测试并注册到 `List.test.ets`：

```ts
it('billing_calculates_hourly_and_per_lesson', () => {
  expect(calculateAmountFen('HOURLY', 10000, 90)).assertEqual(15000)
  expect(calculateAmountFen('PER_LESSON', 12000, 90)).assertEqual(12000)
})
```

`billing_rounds_half_up`：100 分/小时、20 分钟结果为 33 分。`billing_rejects_invalid_numbers`：零/负时长、负金额、非整数课时、非有限数字均抛出异常。`package_rejects_overdraft`：剩余 1 课时时扣 2 抛出异常。`billing_switch_requires_zero_balance`：只有待收金额和剩余课时同时为 0 才返回 true。`feedback_preserves_multiline_text`：课程内容与备注中的换行、中文和特殊字符原样出现在反馈中。

- [ ] **Step 2: 运行测试并确认失败**

Run: `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" test --mode module -p product=default -p module=entry@default --no-daemon`
Expected: 因领域函数尚未实现而 FAIL。

- [ ] **Step 3: 实现纯 ArkTS 领域函数**

按上述签名实现；小时金额使用 `Math.round(unitPriceFen * durationMinutes / 60)`，按次金额不随时长变化。反馈模板固定包含学生昵称、日期、时长、课程内容、掌握情况、薄弱点，空备注不生成备注行，不调用网络或 AI。

- [ ] **Step 4: 运行测试并确认通过**

Run: 同 Step 2。
Expected: 所有 Billing 与 FeedbackFormatter Local Test PASS。

- [ ] **Step 5: 提交**

Run: `git add entry/src/main/ets/model entry/src/main/ets/domain entry/src/test && git commit -m "feat: add tutoring billing rules"`

### Task 3: 学生、收款与课时包持久化

**Files:**
- Create: `entry/src/main/ets/data/Database.ets`
- Create: `entry/src/main/ets/data/TutorRepository.ets`
- Create: `entry/src/ohosTest/ets/test/StudentRepository.test.ets`、`entry/src/ohosTest/ets/test/List.test.ets`
- Modify: `entry/src/main/ets/model/Types.ets`

**Interfaces:**
- Consumes: Task 2 的 `StudentInput`、`PaymentInput`、`TopUpInput`、`BillingMode`。
- Produces: `TutorRepository.init(): Promise<void>`、`createStudent(input: StudentInput): Promise<number>`、`listStudents(): Promise<StudentSummary[]>`。
- Produces: `recordPayment(input: PaymentInput): Promise<number>`、`topUpPackage(input: TopUpInput): Promise<number>`。
- Produces: `getStudentSummary(studentId: number): Promise<StudentSummary>`、`switchBilling(studentId: number, input: StudentInput): Promise<void>`。
- Produces: `StudentSummary` 包含 `outstandingFen: number` 与 `remainingLessons: number`，余额由明细计算，不单独保存可漂移的汇总值。

- [ ] **Step 1: 准备模拟器并写失败的 Instrument Test**

通过 DevEco Studio `Tools > Device Manager` 创建并启动手机模拟器。Run: `"$DEVECO_HOME/sdk/default/openharmony/toolchains/hdc.exe" list targets`；Expected: 至少一个设备，不再是 `[Empty]`。

在 `StudentRepository.test.ets` 写 `student_persists_after_reopen`、`payment_persists_after_reopen`、`topup_increases_remaining_lessons`、`billing_switch_requires_zero_balance`。每个测试使用独立学生昵称；重启测试重新获取 RdbStore 后断言原学生与收款/充值明细仍存在；非零余额切换收费方式必须抛出异常且原模式不变。

- [ ] **Step 2: 运行 Instrument Test 并确认失败**

Run: `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" onDeviceTest -p module=entry -p coverage=false --no-daemon`
Expected: 测试发现 `TutorRepository` 尚未实现而 FAIL，且 hdc 已识别模拟器。

- [ ] **Step 3: 实现数据库结构与学生账目操作**

`Database.ets` 创建 `students`、`payments`、`package_topups`、`lessons`、`feedbacks` 表及必要索引。`students` 保存昵称、科目、当前收费模式、价格单位和整数分价格；收款与课时包充值分别保存日期、金额/课时、备注和时间戳。

`TutorRepository` 使用 `@kit.ArkData` 的 `relationalStore`，所有多表写操作使用 `createTransaction()`，成功后 commit、异常时 rollback。汇总使用明细查询；切换模式前在同一事务内检查两个余额均为 0。

- [ ] **Step 4: 运行测试并确认通过**

Run: 同 Step 2。
Expected: 四个测试 PASS，无失败或数据库未关闭错误。

- [ ] **Step 5: 提交**

Run: `git add entry/src/main/ets/model/Types.ets entry/src/main/ets/data entry/src/ohosTest && git commit -m "feat: persist students and tutoring ledgers"`

### Task 4: 课后记录事务与反馈快照

**Files:**
- Modify: `entry/src/main/ets/data/Database.ets`
- Modify: `entry/src/main/ets/data/TutorRepository.ets`
- Create: `entry/src/ohosTest/ets/test/LessonRepository.test.ets`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`

**Interfaces:**
- Consumes: Task 2 的 `LessonInput` 与 Task 3 的 `TutorRepository`。
- Produces: `createLesson(input: LessonInput): Promise<number>`、`updateLesson(lessonId: number, input: LessonInput): Promise<void>`、`deleteLesson(lessonId: number): Promise<void>`。
- Produces: `listLessons(studentId: number): Promise<LessonRecord[]>`、`saveFeedback(lessonId: number, content: string): Promise<void>`、`getFeedback(lessonId: number): Promise<string | null>`。

- [ ] **Step 1: 写失败的课程事务测试**

注册以下测试：`postpaid_lesson_updates_outstanding`、`prepaid_lesson_deducts_once`、`lesson_edit_applies_only_delta`、`lesson_delete_restores_balance`、`lesson_edit_overdraft_rolls_back`、`lesson_create_is_idempotent`、`feedback_is_independent_snapshot`。

关键断言：同一 `requestId` 连续调用两次返回同一 lessonId 且只扣一次；编辑后只应用金额/课时差值；超扣编辑抛出异常且原课程与余额不变；保存反馈后编辑来源课程，反馈文字保持原值。

- [ ] **Step 2: 运行 Instrument Test 并确认失败**

Run: `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" onDeviceTest -p module=entry -p coverage=false --no-daemon`
Expected: 新课程方法未实现而 FAIL。

- [ ] **Step 3: 实现课程与反馈事务**

为 `lessons.request_id` 建唯一约束。创建表单生成一次 `requestId`，重复创建遇到相同标识时读取并返回原 lessonId。新增、编辑、删除课程时，在单个事务中读取学生当前模式和余额、校验输入、写课程并保证汇总可追溯；不得先提交课程再单独扣课。

`feedbacks.lesson_id` 唯一，保存独立文字快照；课程更新与删除不得自动改写反馈内容，删除课程时保留反馈历史所需的最小课程快照字段。

- [ ] **Step 4: 运行测试并确认通过**

Run: 同 Step 2。
Expected: Task 3 与 Task 4 的全部 Instrument Test PASS。

- [ ] **Step 5: 提交**

Run: `git add entry/src/main/ets/data entry/src/ohosTest && git commit -m "feat: add transactional post-class records"`

### Task 5: 学生与账目页面

**Files:**
- Create: `entry/src/main/ets/viewmodel/TutorViewModel.ets`
- Create: `entry/src/main/ets/pages/Students.ets`、`entry/src/main/ets/pages/StudentEdit.ets`、`entry/src/main/ets/pages/StudentDetail.ets`
- Create: `entry/src/main/ets/pages/PaymentEdit.ets`、`entry/src/main/ets/pages/TopUpEdit.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`、`entry/src/main/resources/base/profile/main_pages.json`
- Create: `entry/src/ohosTest/ets/test/StudentFlow.test.ets`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`

**Interfaces:**
- Consumes: Task 3 的 `TutorRepository` 全部学生与账目接口。
- Produces: `TutorViewModel.loadStudents(): Promise<void>`、`saveStudent(input: StudentInput): Promise<void>`、`savePayment(input: PaymentInput): Promise<void>`、`saveTopUp(input: TopUpInput): Promise<void>`。
- Produces: 页面路由 `pages/Students`、`pages/StudentEdit`、`pages/StudentDetail`、`pages/PaymentEdit`、`pages/TopUpEdit`。

- [ ] **Step 1: 写失败的学生流程测试**

`StudentFlow.test.ets` 覆盖：创建后付学生后列表显示昵称与科目；按小时/按次设置能保存；登记收款后详情显示新的待收金额；课时包充值后显示剩余课时；非零余额切换模式时显示错误且不离开页面。

- [ ] **Step 2: 运行测试并确认失败**

Run: `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" onDeviceTest -p module=entry -p coverage=false --no-daemon`
Expected: 页面与 ViewModel 尚未实现而 FAIL。

- [ ] **Step 3: 实现学生与账目 UI**

使用 ArkUI 表单和导航实现五个页面；首页提供学生入口与“记一节课”占位入口。保存期间禁用按钮，失败时保留表单内容。金额以元输入、在 ViewModel 边界转换为整数分；学生只需昵称、科目和收费设置，其他信息可选。

- [ ] **Step 4: 验证页面流程与构建**

Run: 同 Step 2。
Expected: StudentFlow 与既有测试全部 PASS。

Run: `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 5: 提交**

Run: `git add entry/src/main entry/src/ohosTest && git commit -m "feat: add student and ledger screens"`

### Task 6: 课后闭环、历史与反馈复制

**Files:**
- Create: `entry/src/main/ets/pages/LessonEdit.ets`、`entry/src/main/ets/pages/Feedback.ets`、`entry/src/main/ets/pages/Records.ets`
- Create: `entry/src/main/ets/service/Clipboard.ets`
- Modify: `entry/src/main/ets/viewmodel/TutorViewModel.ets`、`entry/src/main/ets/pages/Index.ets`、`entry/src/main/ets/pages/StudentDetail.ets`
- Modify: `entry/src/main/resources/base/profile/main_pages.json`
- Create: `entry/src/ohosTest/ets/test/LessonFlow.test.ets`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`

**Interfaces:**
- Consumes: Task 2 的 `formatParentFeedback`、Task 4 的课程与反馈接口、Task 5 的 `TutorViewModel`。
- Produces: `saveLesson(input: LessonInput): Promise<number>`、`copyFeedback(text: string): Promise<void>`；页面路由 `pages/LessonEdit`、`pages/Feedback`、`pages/Records`。
- Produces: `Clipboard.copyText(text: string): Promise<void>`，只封装系统剪贴板，不读取剪贴板。

- [ ] **Step 1: 写失败的端到端课程流程测试**

`LessonFlow.test.ets` 覆盖后付与课时包两条流程：选择学生、填写课程、保存、出现反馈、复制文字、详情显示新余额。另覆盖连续点击保存只产生一条记录、余额不足保留表单、编辑课程不覆盖反馈快照、重启应用后记录仍存在。

- [ ] **Step 2: 运行测试并确认失败**

Run: `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" onDeviceTest -p module=entry -p coverage=false --no-daemon`
Expected: 课程页面尚未实现而 FAIL。

- [ ] **Step 3: 实现课后闭环与历史页面**

课程表单进入时生成一次 `requestId`，保存期间禁用按钮，成功后锁定该表单结果。金额或扣课数按学生设置预填且可编辑；保存后进入反馈页，反馈可编辑并用 `Clipboard` 复制。Records 与学生详情展示课程、收款、课时包和反馈历史；编辑与删除入口调用 Task 4 事务接口。

- [ ] **Step 4: 运行全部测试与模拟器验收**

Run: `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" test --mode module -p product=default -p module=entry@default --no-daemon`
Expected: 全部 Local Test PASS。

Run: `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" onDeviceTest -p module=entry -p coverage=false --no-daemon`
Expected: 全部 Instrument Test PASS。

在模拟器断网后重复两条核心流程，Expected: 创建学生、记课、收款/扣课、历史与反馈复制全部可用。

- [ ] **Step 5: 提交**

Run: `git add entry/src/main entry/src/ohosTest && git commit -m "feat: complete post-class recording workflow"`

### Task 7: 发布候选验证与上架材料

**Files:**
- Modify: `AppScope/app.json5`、应用名称/图标资源、`entry/src/main/module.json5`（仅在验收发现配置问题时）
- Create: `docs/release/privacy-policy.md`、`docs/release/store-listing.md`、`docs/release/manual-checklist.md`
- Modify: `build-profile.json5`（仅在用户完成签名配置后）

**Interfaces:**
- Consumes: 前六个任务的可运行 App 与全部测试。
- Produces: 可提交的发布候选包、与实际行为一致的中文隐私说明、商店介绍和人工验收清单。

- [ ] **Step 1: 清理构建并执行完整回归**

Run: `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" clean --no-daemon && node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" test --mode module -p product=default -p module=entry@default --no-daemon && node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" onDeviceTest -p module=entry -p coverage=false --no-daemon`
Expected: 清理成功，全部测试 PASS。

- [ ] **Step 2: 按设计文档执行人工验收**

逐项执行设计文档第 10 节的 7 个场景，并额外检查空状态、长文本、金额元/分转换、编辑删除一致性、断网和强制重启。把实际结果记录在 `manual-checklist.md`；任何失败都回到所属任务修复，不标记发布候选完成。

- [ ] **Step 3: 构建发布候选包**

Run: `node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" assembleApp --mode project -p product=default -p buildMode=release --no-daemon`
Expected: `BUILD SUCCESSFUL` 并生成 APP 包。未配置签名时允许生成 unsigned 包用于构建验证，但不得称为可上架签名包。

- [ ] **Step 4: 准备真实上架材料**

隐私说明明确：数据本地保存、无账号、无云端上传、无第三方分析、无广告、卸载或清除数据可能丢失记录。商店文案不得包含 AI、自动微信发送或支付功能。图标、截图、版本号和应用简介保持真实一致。

- [ ] **Step 5: 用户参与签名与提交**

由用户确认华为开发者账号、最终 bundleName、签名材料、协议和隐私政策托管方式；任何登录、协议签署、付费或最终提交审核均先征求用户确认。未完成这些外部步骤时，只能报告“发布候选已验证”，不能报告“已上架”。

- [ ] **Step 6: 提交发布准备改动**

Run: `git add AppScope entry/src/main build-profile.json5 docs/release && git commit -m "chore: prepare release candidate"`
Expected: 签名密钥、证书、密码、个人账号信息和本地构建产物均不在提交中。
