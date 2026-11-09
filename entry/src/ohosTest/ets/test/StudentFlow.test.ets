import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit';
import { TutorRepository } from '../../../main/ets/data/TutorRepository';
import { BillingMode, PriceUnit, StudentInput } from '../../../main/ets/model/Types';
import { TutorViewModel } from '../../../main/ets/viewmodel/TutorViewModel';

const BUNDLE_NAME = 'com.yijuntuqi.afterclass';
const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  .getApplicationContext().createModuleContext('entry');
let driver = Driver.create();
const perLessonNickname = `flow-per-lesson-${Date.now()}`;
const topUpNickname = `flow-topup-${Date.now()}`;

class RefreshFailureViewModel extends TutorViewModel {
  async loadStudents(): Promise<void> {
    throw new Error('Refresh failed after write');
  }

  async loadStudent(studentId: number): Promise<void> {
    throw new Error('Refresh failed after write');
  }
}

async function clickComponent(component: Component): Promise<void> {
  await component.click();
}

async function launchApp(): Promise<void> {
  driver = Driver.create();
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  await delegator.executeShellCommand(`aa start -a EntryAbility -b ${BUNDLE_NAME}`, 10);
  await driver.delayMs(500);
  for (let attempt = 0; attempt < 6; attempt++) {
    const home = await driver.findComponents(ON.id('homeStudents')) as Array<Component> | null;
    if (home !== null && home.length > 0) {
      return;
    }
    const launcherIcon = await driver.findComponents(ON.text('课后记')) as Array<Component> | null;
    if (launcherIcon !== null && launcherIcon.length > 0) {
      await clickComponent(launcherIcon[0]);
      await driver.delayMs(1000);
      continue;
    }
    await driver.pressBack();
    await driver.delayMs(500);
  }
  await driver.waitForComponent(ON.id('homeStudents'), 5000);
}

async function acceptImePermission(): Promise<void> {
  const buttons = await driver.findComponents(ON.id('Paf.Permission.button_confirm')) as Array<Component> | null;
  if (buttons !== null && buttons.length > 0) {
    await clickComponent(buttons[0]);
    await driver.delayMs(300);
  }
}

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
  await clickComponent(await find(id));
}

async function navigate(id: string): Promise<void> {
  await click(id);
  driver = Driver.create();
}

async function input(id: string, text: string): Promise<void> {
  await acceptImePermission();
  await (await find(id)).inputText(text);
  await driver.delayMs(200);
  const next = await driver.findComponents(ON.text('下一步')) as Array<Component> | null;
  if (next !== null && next.length > 0) {
    await clickComponent(next[0]);
    await driver.delayMs(500);
  }
}

async function createStudent(nickname: string, subject: string, billingMode: BillingMode,
  priceUnit: PriceUnit): Promise<void> {
  await click('homeStudents');
  await find('studentsPage');
  await click('addStudent');
  await find('studentEditPage');
  await click(billingMode === 'POSTPAID' ? 'billingPostpaid' : 'billingPrepaid');
  await click(priceUnit === 'HOURLY' ? 'priceHourly' : 'pricePerLesson');
  await input('studentNickname', nickname);
  await input('studentSubject', subject);
  await click('saveStudent');
  await find('studentsPage');
}

async function findStudentRow(nickname: string): Promise<Component> {
  await find('studentList');
  for (let attempt = 0; attempt < 30; attempt++) {
    const matches = await driver.findComponents(ON.text(nickname)) as Array<Component> | null;
    if (matches !== null && matches.length > 0) {
      return matches[0];
    }
    await driver.delayMs(100);
  }
  throw new Error(`Student not found: ${nickname}`);
}

async function openStudent(nickname: string): Promise<void> {
  await clickComponent(await findStudentRow(nickname));
  await find('studentDetailPage');
  await driver.delayMs(500);
}

export default function testsuite() {
  describe('StudentFlow', () => {
    it('student_create_shows_nickname_and_subject', 0, async () => {
      const nickname = `flow-create-${Date.now()}`;
      const subject = `Subject-${Date.now()}`;
      await launchApp();

      await createStudent(nickname, subject, 'POSTPAID', 'HOURLY');

      await findStudentRow(nickname);
      await driver.assertComponentExist(ON.text(subject));
    });

    it('student_hourly_setting_visible_on_detail', 0, async () => {
      const nickname = `flow-hourly-${Date.now()}`;
      await launchApp();
      await createStudent(nickname, 'Math', 'POSTPAID', 'HOURLY');

      await openStudent(nickname);

      await driver.assertComponentExist(ON.text('按小时'));
      await driver.assertComponentExist(ON.text('价格 ¥100.00'));
    });

    it('student_per_lesson_setting_visible_on_detail', 0, async () => {
      await launchApp();
      await createStudent(perLessonNickname, 'English', 'POSTPAID', 'PER_LESSON');

      await openStudent(perLessonNickname);

      await driver.assertComponentExist(ON.text('按次'));
      await driver.assertComponentExist(ON.text('价格 ¥100.00'));
    });

    it('payment_updates_detail_outstanding', 0, async () => {
      await driver.assertComponentExist(ON.text('待收金额 ¥0.00'));
      await navigate('addPayment');
      await find('paymentEditPage');
      await input('paymentAmount', '25.50');
      await click('savePayment');

      await driver.waitForComponent(ON.text('待收金额 ¥-25.50'), 5000);
      await driver.assertComponentExist(ON.id('studentDetailPage'));
    });

    it('topup_student_created_on_page', 0, async () => {
      await launchApp();
      await createStudent(topUpNickname, 'Physics', 'PREPAID', 'PER_LESSON');
      await findStudentRow(topUpNickname);
    });

    it('topup_updates_detail_remaining_lessons', 0, async () => {
      await launchApp();
      await click('homeStudents');
      await find('studentsPage');
      await openStudent(topUpNickname);
      await navigate('addTopUp');
      await find('topUpEditPage');
      await input('topUpLessons', '3');
      await click('saveTopUp');

      await driver.waitForComponent(ON.text('剩余课时 3'), 5000);
      await driver.assertComponentExist(ON.id('studentDetailPage'));
    });

    it('billing_switch_error_keeps_edit_page_visible', 0, async () => {
      const nickname = topUpNickname;
      await navigate('editStudent');
      await find('studentEditPage');
      await click('billingPostpaid');
      await click('saveStudent');

      await driver.waitForComponent(ON.id('studentEditError'), 5000);
      await driver.assertComponentExist(ON.text('有未结余额，不能切换收费方式'));
      await driver.assertComponentExist(ON.id('studentEditPage'));
      expect(await (await driver.findComponent(ON.id('studentNickname'))).getText()).assertEqual(nickname);
      await driver.pressBack();
      await driver.assertComponentExist(ON.id('studentDetailPage'));
      await driver.assertComponentExist(ON.text('课时包'));
    });

    it('writes_succeed_when_refresh_fails', 0, async () => {
      const nickname = `flow-refresh-${Date.now()}`;
      const viewModel = new RefreshFailureViewModel(context);
      const input: StudentInput = {
        nickname: nickname,
        subject: '生物',
        billingMode: 'PREPAID',
        priceUnit: 'PER_LESSON',
        unitPriceFen: TutorViewModel.yuanToFen('100.00')
      };

      await viewModel.saveStudent(input);

      const repository = new TutorRepository(context);
      await repository.init();
      const students = (await repository.listStudents()).filter((student) => student.nickname === nickname);
      expect(students.length).assertEqual(1);
      const studentId = students[0].id;
      await viewModel.savePayment({ studentId: studentId, date: '2026-11-08', amountFen: 500, note: '' });
      await viewModel.saveTopUp({ studentId: studentId, date: '2026-11-08', lessons: 2, note: '' });

      const saved = await repository.getStudentSummary(studentId);
      expect(saved.outstandingFen).assertEqual(-500);
      expect(saved.remainingLessons).assertEqual(2);
    });
  });
}
