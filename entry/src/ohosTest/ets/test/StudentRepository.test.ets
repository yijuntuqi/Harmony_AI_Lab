import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { Database } from '../../../main/ets/data/Database';
import { TutorRepository } from '../../../main/ets/data/TutorRepository';
import { StudentInput } from '../../../main/ets/model/Types';

const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  .getApplicationContext().createModuleContext('entry');

async function openRepository(): Promise<TutorRepository> {
  const repository = new TutorRepository(context);
  await repository.init();
  return repository;
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
  describe('StudentRepository', () => {
    it('student_persists_after_reopen', 0, async () => {
      const repository = await openRepository();
      const studentId = await repository.createStudent({
        nickname: 'instrument-student-persist',
        subject: '数学',
        billingMode: 'POSTPAID',
        priceUnit: 'HOURLY',
        unitPriceFen: 10000
      });

      const reopened = await openRepository();
      const summary = await reopened.getStudentSummary(studentId);
      expect(summary.id).assertEqual(studentId);
      expect(summary.nickname).assertEqual('instrument-student-persist');
      expect(summary.subject).assertEqual('数学');
      expect(summary.billingMode).assertEqual('POSTPAID');
      expect(summary.priceUnit).assertEqual('HOURLY');
      expect(summary.unitPriceFen).assertEqual(10000);
      expect(summary.outstandingFen).assertEqual(0);
      expect(summary.remainingLessons).assertEqual(0);
      const students = await reopened.listStudents();
      expect(students.filter((student) => student.id === studentId).length).assertEqual(1);
    });

    it('payment_persists_after_reopen', 0, async () => {
      const repository = await openRepository();
      const studentId = await repository.createStudent({
        nickname: 'instrument-payment-persist',
        subject: '英语',
        billingMode: 'POSTPAID',
        priceUnit: 'PER_LESSON',
        unitPriceFen: 12000
      });
      const paymentId = await repository.recordPayment({
        studentId: studentId,
        date: '2026-11-08',
        amountFen: 12500,
        note: '首次收款'
      });

      const reopened = await openRepository();
      const store = await Database.open(context);
      const result = await store.querySql(
        'SELECT student_id, date, amount_fen, note, created_at FROM payments WHERE id = ?', [paymentId]);
      expect(result.goToFirstRow()).assertTrue();
      expect(result.getLong(0)).assertEqual(studentId);
      expect(result.getString(1)).assertEqual('2026-11-08');
      expect(result.getLong(2)).assertEqual(12500);
      expect(result.getString(3)).assertEqual('首次收款');
      expect(result.getLong(4) > 0).assertTrue();
      result.close();
      const summary = await reopened.getStudentSummary(studentId);
      expect(summary.outstandingFen).assertEqual(-12500);
    });

    it('topup_increases_remaining_lessons', 0, async () => {
      const repository = await openRepository();
      const studentId = await repository.createStudent({
        nickname: 'instrument-topup-persist',
        subject: '物理',
        billingMode: 'PREPAID',
        priceUnit: 'PER_LESSON',
        unitPriceFen: 13000
      });
      const topUpId = await repository.topUpPackage({
        studentId: studentId,
        date: '2026-11-09',
        lessons: 4,
        note: '四次课时包'
      });

      const reopened = await openRepository();
      const summary = await reopened.getStudentSummary(studentId);
      expect(summary.remainingLessons).assertEqual(4);
      const store = await Database.open(context);
      const result = await store.querySql(
        'SELECT student_id, date, lessons, note, created_at FROM package_topups WHERE id = ?', [topUpId]);
      expect(result.goToFirstRow()).assertTrue();
      expect(result.getLong(0)).assertEqual(studentId);
      expect(result.getString(1)).assertEqual('2026-11-09');
      expect(result.getLong(2)).assertEqual(4);
      expect(result.getString(3)).assertEqual('四次课时包');
      expect(result.getLong(4) > 0).assertTrue();
      result.close();
    });

    it('billing_switch_requires_zero_balance', 0, async () => {
      const repository = await openRepository();
      const studentId = await repository.createStudent({
        nickname: 'instrument-billing-switch',
        subject: '化学',
        billingMode: 'PREPAID',
        priceUnit: 'PER_LESSON',
        unitPriceFen: 14000
      });
      await repository.topUpPackage({
        studentId: studentId,
        date: '2026-11-10',
        lessons: 2,
        note: '未消费课时'
      });
      const changed: StudentInput = {
        nickname: 'instrument-billing-switch',
        subject: '化学',
        billingMode: 'POSTPAID',
        priceUnit: 'HOURLY',
        unitPriceFen: 15000
      };

      await expectRejects(async (): Promise<void> => {
        await repository.switchBilling(studentId, changed);
      });

      const reopened = await openRepository();
      const summary = await reopened.getStudentSummary(studentId);
      expect(summary.billingMode).assertEqual('PREPAID');
      expect(summary.priceUnit).assertEqual('PER_LESSON');
      expect(summary.unitPriceFen).assertEqual(14000);
      expect(summary.remainingLessons).assertEqual(2);
    });

    it('profile_edit_allowed_without_billing_switch', 0, async () => {
      const repository = await openRepository();
      const studentId = await repository.createStudent({
        nickname: 'instrument-profile-before',
        subject: '化学',
        billingMode: 'PREPAID',
        priceUnit: 'PER_LESSON',
        unitPriceFen: 14000
      });
      await repository.topUpPackage({
        studentId: studentId,
        date: '2026-11-10',
        lessons: 2,
        note: '未消费课时'
      });

      await repository.switchBilling(studentId, {
        nickname: 'instrument-profile-after',
        subject: '物理',
        billingMode: 'PREPAID',
        priceUnit: 'PER_LESSON',
        unitPriceFen: 16000
      });

      const summary = await repository.getStudentSummary(studentId);
      expect(summary.nickname).assertEqual('instrument-profile-after');
      expect(summary.subject).assertEqual('物理');
      expect(summary.unitPriceFen).assertEqual(16000);
      expect(summary.remainingLessons).assertEqual(2);
    });
  });
}
