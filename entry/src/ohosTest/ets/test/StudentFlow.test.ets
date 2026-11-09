import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { TutorRepository } from '../../../main/ets/data/TutorRepository';
import { BillingMode, PriceUnit, StudentInput, StudentSummary } from '../../../main/ets/model/Types';
import { TutorViewModel } from '../../../main/ets/viewmodel/TutorViewModel';

const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  .getApplicationContext().createModuleContext('entry');

async function openViewModel(): Promise<TutorViewModel> {
  const viewModel = new TutorViewModel(context);
  await viewModel.loadStudents();
  return viewModel;
}

async function createStudent(nickname: string, subject: string, billingMode: BillingMode,
  priceUnit: PriceUnit, unitPriceYuan: string): Promise<StudentSummary> {
  const viewModel = await openViewModel();
  await viewModel.saveStudent({
    nickname: nickname,
    subject: subject,
    billingMode: billingMode,
    priceUnit: priceUnit,
    unitPriceFen: TutorViewModel.yuanToFen(unitPriceYuan)
  });
  const matches = viewModel.students.filter((student) => student.nickname === nickname);
  expect(matches.length).assertEqual(1);
  return matches[0];
}

export default function testsuite() {
  describe('StudentFlow', () => {
    it('student_create_shows_nickname_and_subject', 0, async () => {
      const nickname = `flow-create-${Date.now()}`;
      const subject = `数学-${Date.now()}`;
      await createStudent(nickname, subject, 'POSTPAID', 'HOURLY', '100');

      const viewModel = await openViewModel();
      const student = viewModel.students.filter((item) => item.nickname === nickname)[0];
      expect(student.subject).assertEqual(subject);
      expect(student.billingMode).assertEqual('POSTPAID');
      expect(student.unitPriceFen).assertEqual(10000);
    });

    it('student_hourly_and_per_lesson_settings_save', 0, async () => {
      const hourlyName = `flow-hourly-${Date.now()}`;
      const perLessonName = `flow-per-lesson-${Date.now()}`;

      const hourly = await createStudent(hourlyName, '数学', 'POSTPAID', 'HOURLY', '88.50');
      const perLesson = await createStudent(perLessonName, '英语', 'POSTPAID', 'PER_LESSON', '120.75');

      expect(hourly.priceUnit).assertEqual('HOURLY');
      expect(hourly.unitPriceFen).assertEqual(8850);
      expect(perLesson.priceUnit).assertEqual('PER_LESSON');
      expect(perLesson.unitPriceFen).assertEqual(12075);
    });

    it('payment_updates_detail_outstanding', 0, async () => {
      const nickname = `flow-payment-${Date.now()}`;
      const created = await createStudent(nickname, '数学', 'POSTPAID', 'PER_LESSON', '100');
      const repository = new TutorRepository(context);
      await repository.init();
      await repository.createLesson({
        studentId: created.id,
        requestId: `flow-payment-lesson-${Date.now()}`,
        date: '2026-11-08',
        durationMinutes: 60,
        amountFen: 10000,
        deduction: null,
        content: '代数',
        mastery: '良好',
        weakPoints: '',
        note: ''
      });
      const viewModel = await openViewModel();

      await viewModel.savePayment({
        studentId: created.id,
        date: '2026-11-08',
        amountFen: TutorViewModel.yuanToFen('25.50'),
        note: '部分收款'
      });

      expect(viewModel.currentStudent).not().assertNull();
      expect(viewModel.currentStudent?.outstandingFen).assertEqual(7450);
    });

    it('topup_updates_detail_remaining_lessons', 0, async () => {
      const nickname = `flow-topup-${Date.now()}`;
      const created = await createStudent(nickname, '物理', 'PREPAID', 'PER_LESSON', '130');
      const viewModel = await openViewModel();

      await viewModel.saveTopUp({
        studentId: created.id,
        date: '2026-11-08',
        lessons: 3,
        note: '三次课时包'
      });

      expect(viewModel.currentStudent).not().assertNull();
      expect(viewModel.currentStudent?.remainingLessons).assertEqual(3);
    });

    it('billing_switch_error_preserves_balance', 0, async () => {
      const nickname = `flow-switch-${Date.now()}`;
      const created = await createStudent(nickname, '化学', 'PREPAID', 'PER_LESSON', '140');
      const viewModel = await openViewModel();
      await viewModel.saveTopUp({ studentId: created.id, date: '2026-11-08', lessons: 2, note: '' });
      const changed: StudentInput = {
        nickname: nickname,
        subject: '化学',
        billingMode: 'POSTPAID',
        priceUnit: 'HOURLY',
        unitPriceFen: 15000
      };
      let errorMessage = '';

      try {
        await viewModel.switchBilling(created.id, changed);
      } catch (error) {
        errorMessage = TutorViewModel.errorMessage(error as Object);
      }

      expect(errorMessage).assertEqual('有未结余额，不能切换收费方式');
      await viewModel.loadStudent(created.id);
      expect(viewModel.currentStudent?.billingMode).assertEqual('PREPAID');
      expect(viewModel.currentStudent?.remainingLessons).assertEqual(2);
    });
  });
}
