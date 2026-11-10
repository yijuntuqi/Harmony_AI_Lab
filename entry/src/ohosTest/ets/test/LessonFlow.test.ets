import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry, Component, Driver, MatchPattern, ON } from '@kit.TestKit';
import { TutorRepository } from '../../../main/ets/data/TutorRepository';
import { LessonInput, StudentSummary } from '../../../main/ets/model/Types';

const BUNDLE_NAME = 'com.yijuntuqi.afterclass';
let driver = Driver.create();
const suffix = Date.now();
const postpaidNickname = `lesson-postpaid-${suffix}`;
const prepaidNickname = `lesson-prepaid-${suffix}`;
const postpaidContent = `Postpaid content ${suffix}`;
const prepaidContent = `Prepaid content ${suffix}`;
const manualFeedback = `Manual feedback ${suffix}`;
let postpaidStudentId = 0;
let prepaidStudentId = 0;
let doubleStudentId = 0;
let insufficientStudentId = 0;
let editStudentId = 0;
let editLessonId = 0;

async function find(id: string): Promise<Component> {
  for (let attempt = 0; attempt < 30; attempt++) {
    const matches = await driver.findComponents(ON.id(id)) as Array<Component> | null;
    if (matches !== null && matches.length > 0) {
      return matches[0];
    }
    await driver.delayMs(100);
  }
  throw new Error(`Component not found: ${id}`);
}

async function click(id: string): Promise<void> {
  await (await find(id)).click();
}

async function navigate(id: string): Promise<void> {
  await click(id);
  driver = Driver.create();
}

async function acceptImePermission(): Promise<void> {
  const buttons = await driver.findComponents(ON.id('Paf.Permission.button_confirm')) as Array<Component> | null;
  if (buttons !== null && buttons.length > 0) {
    await buttons[0].click();
    await driver.delayMs(200);
  }
}

async function input(id: string, text: string): Promise<void> {
  await acceptImePermission();
  await (await find(id)).inputText(text);
  await driver.delayMs(100);
  const next = await driver.findComponents(ON.text('下一步')) as Array<Component> | null;
  if (next !== null && next.length > 0) {
    await next[0].click();
    await driver.delayMs(200);
  }
}

async function launchApp(): Promise<void> {
  driver = Driver.create();
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  await delegator.executeShellCommand(`aa start -a EntryAbility -b ${BUNDLE_NAME}`, 10);
  await driver.delayMs(300);
  for (let attempt = 0; attempt < 6; attempt++) {
    const home = await driver.findComponents(ON.id('homeStudents')) as Array<Component> | null;
    if (home !== null && home.length > 0) {
      return;
    }
    await driver.pressBack();
    await driver.delayMs(200);
  }
  await driver.waitForComponent(ON.id('homeStudents'), 3000);
}

async function openStudent(nickname: string): Promise<void> {
  await navigate('homeStudents');
  await find('studentsPage');
  for (let attempt = 0; attempt < 30; attempt++) {
    const matches = await driver.findComponents(ON.text(nickname)) as Array<Component> | null;
    if (matches !== null && matches.length > 0) {
      await matches[0].click();
      await find('studentDetailPage');
      return;
    }
    await driver.delayMs(100);
  }
  throw new Error(`Student not found: ${nickname}`);
}

async function startLesson(nickname: string): Promise<void> {
  await openStudent(nickname);
  await navigate('addLesson');
  await find('lessonEditPage');
}

async function fillLesson(content: string): Promise<void> {
  await input('lessonContent', content);
}

async function repository(): Promise<TutorRepository> {
  const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
  const result = new TutorRepository(ability.context);
  await result.init();
  return result;
}

async function createStudent(nickname: string, billingMode: 'POSTPAID' | 'PREPAID'): Promise<StudentSummary> {
  await launchApp();
  const repo = await repository();
  const id = await repo.createStudent({
    nickname: nickname,
    subject: 'Math',
    billingMode: billingMode,
    priceUnit: 'PER_LESSON',
    unitPriceFen: 10000
  });
  return await repo.getStudentSummary(id);
}

function lessonInput(studentId: number, requestId: string, content: string,
  amountFen: number | null, deduction: number | null): LessonInput {
  return {
    studentId: studentId,
    requestId: requestId,
    date: '2026-11-08',
    durationMinutes: 60,
    amountFen: amountFen,
    deduction: deduction,
    content: content,
    mastery: 'Good',
    weakPoints: 'Practice',
    note: ''
  };
}

export default function testsuite() {
  describe('LessonFlow', () => {
    it('postpaid_lesson_form_opens', 0, async () => {
      const student = await createStudent(postpaidNickname, 'POSTPAID');
      postpaidStudentId = student.id;
      const repo = await repository();
      await repo.recordPayment({ studentId: student.id, date: '2026-11-08', amountFen: 2550, note: 'Part payment' });
      await startLesson(postpaidNickname);
      expect(await (await find('lessonAmount')).getText()).assertEqual('100.00');
    });

    it('postpaid_lesson_fields_fill', 0, async () => {
      await fillLesson(postpaidContent);
      await input('lessonAmount', '120.50');
      expect(await (await find('lessonContent')).getText()).assertEqual(postpaidContent);
    });

    it('postpaid_lesson_generates_feedback', 0, async () => {
      await click('saveLesson');
      await find('feedbackPage');
      const feedback = await (await find('feedbackText')).getText();
      expect(feedback.includes(postpaidContent)).assertTrue();
      expect(feedback.includes(postpaidNickname)).assertTrue();
    });

    it('postpaid_feedback_edits', 0, async () => {
      await input('feedbackText', manualFeedback);
      expect(await (await find('feedbackText')).getText()).assertEqual(manualFeedback);
    });

    it('postpaid_feedback_copies', 0, async () => {
      await click('copyFeedback');
      await find('copiedFeedback');
    });

    it('postpaid_detail_updates', 0, async () => {
      await driver.pressBack();
      await find('studentDetailPage');
      await driver.waitForComponent(ON.text('待收金额 ¥95.00'), 3000);
      await find('detailLessonHistory');
      await driver.assertComponentExist(ON.text(postpaidContent, MatchPattern.CONTAINS));
      await driver.assertComponentExist(ON.text('收款 ¥25.50'));
    });

    it('prepaid_lesson_form_opens', 0, async () => {
      const student = await createStudent(prepaidNickname, 'PREPAID');
      prepaidStudentId = student.id;
      const repo = await repository();
      await repo.topUpPackage({ studentId: student.id, date: '2026-11-08', lessons: 3, note: 'Starter pack' });
      await startLesson(prepaidNickname);
      expect(await (await find('lessonDeduction')).getText()).assertEqual('1');
    });

    it('prepaid_lesson_fields_fill', 0, async () => {
      await fillLesson(prepaidContent);
      await input('lessonDeduction', '1');
      expect(await (await find('lessonContent')).getText()).assertEqual(prepaidContent);
    });

    it('prepaid_lesson_generates_feedback', 0, async () => {
      await click('saveLesson');
      await find('feedbackPage');
      const feedback = await (await find('feedbackText')).getText();
      expect(feedback.includes(prepaidContent)).assertTrue();
    });

    it('prepaid_feedback_copies', 0, async () => {
      await click('copyFeedback');
      await find('copiedFeedback');
    });

    it('prepaid_detail_updates', 0, async () => {
      await driver.pressBack();
      await find('studentDetailPage');
      await driver.waitForComponent(ON.text('剩余课时 2'), 3000);
      await find('detailLessonHistory');
      await driver.assertComponentExist(ON.text(prepaidContent, MatchPattern.CONTAINS));
      await (await find('detailLessonHistory')).scrollSearch(ON.text('充值 3 课时'));
    });

    it('double_save_form_ready', 0, async () => {
      const student = await createStudent(`lesson-double-${suffix}`, 'POSTPAID');
      doubleStudentId = student.id;
      await startLesson(student.nickname);
      await fillLesson(`Double ${suffix}`);
    });

    it('double_save_creates_one_lesson', 0, async () => {
      const save = await find('saveLesson');
      await save.doubleClick();
      await find('feedbackPage');
      const repo = await repository();
      const lessons = await repo.listLessons(doubleStudentId);
      expect(lessons.length).assertEqual(1);
      expect((await repo.getStudentSummary(doubleStudentId)).outstandingFen).assertEqual(10000);
    });

    it('insufficient_form_ready', 0, async () => {
      const student = await createStudent(`lesson-insufficient-${suffix}`, 'PREPAID');
      insufficientStudentId = student.id;
      const repo = await repository();
      await repo.topUpPackage({ studentId: student.id, date: '2026-11-08', lessons: 1, note: '' });
      await startLesson(student.nickname);
      await fillLesson(`Insufficient ${suffix}`);
      await input('lessonDeduction', '2');
    });

    it('insufficient_lessons_keeps_form', 0, async () => {
      await click('saveLesson');
      await find('lessonEditError');
      await find('lessonEditPage');
      expect(await (await find('lessonContent')).getText()).assertEqual(`Insufficient ${suffix}`);
      expect(await (await find('lessonDeduction')).getText()).assertEqual('2');
      const repo = await repository();
      expect((await repo.getStudentSummary(insufficientStudentId)).remainingLessons).assertEqual(1);
    });

    it('lesson_edit_form_ready', 0, async () => {
      const student = await createStudent(`lesson-edit-${suffix}`, 'POSTPAID');
      editStudentId = student.id;
      const repo = await repository();
      editLessonId = await repo.createLesson(lessonInput(student.id, `edit-${suffix}`, `Original ${suffix}`, 10000, null));
      await repo.saveFeedback(editLessonId, manualFeedback);
      await openStudent(student.nickname);
      await navigate(`editLesson-${editLessonId}`);
      await find('lessonEditPage');
    });

    it('lesson_edit_saves', 0, async () => {
      await input('lessonContent', `Edited ${suffix}`);
      await click('saveLesson');
      await find('studentDetailPage');
    });

    it('lesson_edit_preserves_feedback_snapshot', 0, async () => {
      await navigate(`viewFeedback-${editLessonId}`);
      await find('feedbackPage');
      expect(await (await find('feedbackText')).getText()).assertEqual(manualFeedback);
      const repo = await repository();
      expect((await repo.listLessons(editStudentId))[0].content).assertEqual(`Edited ${suffix}`);
    });

    it('lesson_delete_restores_detail_balance', 0, async () => {
      const student = await createStudent(`lesson-delete-${suffix}`, 'PREPAID');
      const repo = await repository();
      await repo.topUpPackage({ studentId: student.id, date: '2026-11-08', lessons: 2, note: '' });
      const lessonId = await repo.createLesson(lessonInput(student.id, `delete-${suffix}`, `Delete ${suffix}`, null, 1));
      await openStudent(student.nickname);
      await find('detailRemaining');
      await click(`deleteLesson-${lessonId}`);
      await driver.waitForComponent(ON.text('剩余课时 2'), 3000);
      expect((await repo.listLessons(student.id)).length).assertEqual(0);
    });

    it('records_and_feedback_visible_after_reopen', 0, async () => {
      const setup = await repository();
      await setup.recordPayment({ studentId: postpaidStudentId, date: '2026-11-08', amountFen: 2600, note: 'Latest' });
      await launchApp();
      await navigate('homeRecords');
      await find('recordsPage');
      await driver.assertComponentExist(ON.text(`Edited ${suffix}`, MatchPattern.CONTAINS));
      await driver.assertComponentExist(ON.text(manualFeedback));
      await driver.assertComponentExist(ON.text('收款 ¥26.00'));
    });

    it('records_show_payment_topup_and_persist', 0, async () => {
      await driver.assertComponentExist(ON.text('充值 2 课时'));
      const repo = await repository();
      expect((await repo.listLessons(postpaidStudentId)).length).assertEqual(1);
      expect((await repo.listLessons(prepaidStudentId)).length).assertEqual(1);
    });
  });
}
