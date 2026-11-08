import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { TutorRepository } from '../../../main/ets/data/TutorRepository';
import { LessonInput } from '../../../main/ets/model/Types';

const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  .getApplicationContext().createModuleContext('entry');

async function openRepository(): Promise<TutorRepository> {
  const repository = new TutorRepository(context);
  await repository.init();
  return repository;
}

async function createStudent(repository: TutorRepository, nickname: string,
  billingMode: 'POSTPAID' | 'PREPAID'): Promise<number> {
  return await repository.createStudent({
    nickname: nickname,
    subject: '数学',
    billingMode: billingMode,
    priceUnit: 'PER_LESSON',
    unitPriceFen: 10000
  });
}

function lessonInput(studentId: number, requestId: string, amountFen: number | null,
  deduction: number | null): LessonInput {
  return {
    studentId: studentId,
    requestId: requestId,
    date: '2026-11-08',
    durationMinutes: 60,
    amountFen: amountFen,
    deduction: deduction,
    content: '原始课程内容',
    mastery: '掌握良好',
    weakPoints: '分数运算',
    note: '原始备注'
  };
}

async function expectRejects(action: () => Promise<void>): Promise<void> {
  let threw = false;
  try {
    await action();
  } catch (error) {
    threw = true;
  }
  expect(threw).assertTrue();
}

export default function testsuite() {
  describe('LessonRepository', () => {
    it('postpaid_lesson_updates_outstanding', 0, async () => {
      const repository = await openRepository();
      const studentId = await createStudent(repository, 'instrument-postpaid-lesson', 'POSTPAID');
      const input = lessonInput(studentId, `postpaid-${Date.now()}`, 12345, null);

      const lessonId = await repository.createLesson(input);

      const summary = await repository.getStudentSummary(studentId);
      expect(summary.outstandingFen).assertEqual(12345);
      expect(summary.remainingLessons).assertEqual(0);
      const lessons = await repository.listLessons(studentId);
      expect(lessons.length).assertEqual(1);
      expect(lessons[0].id).assertEqual(lessonId);
      expect(lessons[0].requestId).assertEqual(input.requestId);
      expect(lessons[0].amountFen).assertEqual(12345);
      expect(lessons[0].deduction).assertNull();
      expect(lessons[0].content).assertEqual('原始课程内容');
    });

    it('prepaid_lesson_deducts_once', 0, async () => {
      const repository = await openRepository();
      const studentId = await createStudent(repository, 'instrument-prepaid-lesson', 'PREPAID');
      await repository.topUpPackage({ studentId: studentId, date: '2026-11-08', lessons: 5, note: '' });

      await repository.createLesson(lessonInput(studentId, `prepaid-${Date.now()}`, null, 2));

      const summary = await repository.getStudentSummary(studentId);
      expect(summary.remainingLessons).assertEqual(3);
      expect(summary.outstandingFen).assertEqual(0);
      const lessons = await repository.listLessons(studentId);
      expect(lessons.length).assertEqual(1);
      expect(lessons[0].deduction).assertEqual(2);
      expect(lessons[0].amountFen).assertNull();
    });

    it('lesson_edit_applies_only_delta', 0, async () => {
      const repository = await openRepository();
      const studentId = await createStudent(repository, 'instrument-lesson-edit', 'PREPAID');
      await repository.topUpPackage({ studentId: studentId, date: '2026-11-08', lessons: 10, note: '' });
      const lessonId = await repository.createLesson(
        lessonInput(studentId, `edit-${Date.now()}`, null, 2));
      const changed = lessonInput(studentId, `edit-unused-${Date.now()}`, null, 5);
      changed.content = '编辑后的课程内容';

      await repository.updateLesson(lessonId, changed);

      const summary = await repository.getStudentSummary(studentId);
      expect(summary.remainingLessons).assertEqual(5);
      const lessons = await repository.listLessons(studentId);
      expect(lessons.length).assertEqual(1);
      expect(lessons[0].deduction).assertEqual(5);
      expect(lessons[0].content).assertEqual('编辑后的课程内容');
    });

    it('lesson_delete_restores_balance', 0, async () => {
      const repository = await openRepository();
      const studentId = await createStudent(repository, 'instrument-lesson-delete', 'PREPAID');
      await repository.topUpPackage({ studentId: studentId, date: '2026-11-08', lessons: 5, note: '' });
      const lessonId = await repository.createLesson(
        lessonInput(studentId, `delete-${Date.now()}`, null, 3));
      await repository.saveFeedback(lessonId, '删除后仍保留的反馈');

      await repository.deleteLesson(lessonId);

      const summary = await repository.getStudentSummary(studentId);
      expect(summary.remainingLessons).assertEqual(5);
      expect((await repository.listLessons(studentId)).length).assertEqual(0);
      expect(await repository.getFeedback(lessonId)).assertEqual('删除后仍保留的反馈');
    });

    it('lesson_edit_overdraft_rolls_back', 0, async () => {
      const repository = await openRepository();
      const studentId = await createStudent(repository, 'instrument-lesson-overdraft', 'PREPAID');
      await repository.topUpPackage({ studentId: studentId, date: '2026-11-08', lessons: 3, note: '' });
      const requestId = `overdraft-${Date.now()}`;
      const lessonId = await repository.createLesson(lessonInput(studentId, requestId, null, 2));

      await expectRejects(async (): Promise<void> => {
        await repository.updateLesson(lessonId, lessonInput(studentId, requestId, null, 4));
      });

      const summary = await repository.getStudentSummary(studentId);
      expect(summary.remainingLessons).assertEqual(1);
      const lessons = await repository.listLessons(studentId);
      expect(lessons.length).assertEqual(1);
      expect(lessons[0].deduction).assertEqual(2);
      expect(lessons[0].content).assertEqual('原始课程内容');
    });

    it('lesson_create_is_idempotent', 0, async () => {
      const repository = await openRepository();
      const studentId = await createStudent(repository, 'instrument-lesson-idempotent', 'PREPAID');
      await repository.topUpPackage({ studentId: studentId, date: '2026-11-08', lessons: 5, note: '' });
      const input = lessonInput(studentId, `idempotent-${Date.now()}`, null, 2);

      const firstId = await repository.createLesson(input);
      const secondId = await repository.createLesson(input);

      expect(secondId).assertEqual(firstId);
      expect((await repository.getStudentSummary(studentId)).remainingLessons).assertEqual(3);
      expect((await repository.listLessons(studentId)).length).assertEqual(1);
    });

    it('feedback_is_independent_snapshot', 0, async () => {
      const repository = await openRepository();
      const studentId = await createStudent(repository, 'instrument-feedback-snapshot', 'POSTPAID');
      const requestId = `feedback-${Date.now()}`;
      const lessonId = await repository.createLesson(lessonInput(studentId, requestId, 10000, null));
      const snapshot = '家长反馈第一行\n手工修改：保留特殊字符 & < >';
      await repository.saveFeedback(lessonId, snapshot);
      const changed = lessonInput(studentId, requestId, 12000, null);
      changed.content = '来源课程的新内容';

      await repository.updateLesson(lessonId, changed);

      expect(await repository.getFeedback(lessonId)).assertEqual(snapshot);
      expect((await repository.listLessons(studentId))[0].content).assertEqual('来源课程的新内容');
      expect((await repository.getStudentSummary(studentId)).outstandingFen).assertEqual(12000);
    });
  });
}
