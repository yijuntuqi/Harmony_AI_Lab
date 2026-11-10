import { common } from '@kit.AbilityKit';
import { TutorRepository, LessonRecord } from '../data/TutorRepository';
import { formatParentFeedback } from '../domain/FeedbackFormatter';
import {
  LessonInput,
  PaymentInput,
  StudentInput,
  StudentSummary,
  TopUpInput
} from '../model/Types';
import { Clipboard } from '../service/Clipboard';

export type RecordKind = 'LESSON' | 'PAYMENT' | 'TOP_UP';

export interface RecordEntry {
  kind: RecordKind;
  id: number;
  studentId: number;
  date: string;
  createdAt: number;
  title: string;
  detail: string;
  feedback: string | null;
}

export class TutorViewModel {
  students: StudentSummary[] = [];
  currentStudent: StudentSummary | null = null;
  currentLesson: LessonRecord | null = null;
  records: RecordEntry[] = [];
  private repository: TutorRepository;
  private initialization: Promise<void> | null = null;

  constructor(context: common.Context) {
    this.repository = new TutorRepository(context);
  }

  async loadStudents(): Promise<void> {
    const repository = await this.getRepository();
    this.students = await repository.listStudents();
  }

  async loadStudent(studentId: number): Promise<void> {
    const repository = await this.getRepository();
    this.currentStudent = await repository.getStudentSummary(studentId);
  }

  async saveStudent(input: StudentInput): Promise<void> {
    TutorViewModel.validateStudent(input);
    const repository = await this.getRepository();
    await repository.createStudent(input);
  }

  async switchBilling(studentId: number, input: StudentInput): Promise<void> {
    TutorViewModel.validateStudent(input);
    const repository = await this.getRepository();
    await repository.switchBilling(studentId, input);
    await this.loadStudent(studentId);
  }

  async savePayment(input: PaymentInput): Promise<void> {
    if (!Number.isSafeInteger(input.amountFen) || input.amountFen <= 0) {
      throw new Error('收款金额必须大于 0');
    }
    const repository = await this.getRepository();
    await repository.recordPayment(input);
  }

  async saveTopUp(input: TopUpInput): Promise<void> {
    if (!Number.isSafeInteger(input.lessons) || input.lessons <= 0) {
      throw new Error('充值课时必须是正整数');
    }
    const repository = await this.getRepository();
    await repository.topUpPackage(input);
  }

  async saveLesson(input: LessonInput): Promise<number> {
    const repository = await this.getRepository();
    const student = await repository.getStudentSummary(input.studentId);
    const lessonId = await repository.createLesson(input);
    if (await repository.getFeedback(lessonId) === null) {
      await repository.saveFeedback(lessonId, formatParentFeedback(student.nickname, input));
    }
    return lessonId;
  }

  async updateLesson(lessonId: number, input: LessonInput): Promise<void> {
    const repository = await this.getRepository();
    await repository.updateLesson(lessonId, input);
  }

  async deleteLesson(lessonId: number): Promise<void> {
    const repository = await this.getRepository();
    await repository.deleteLesson(lessonId);
  }

  async loadLesson(studentId: number, lessonId: number): Promise<void> {
    const repository = await this.getRepository();
    const lessons = await repository.listLessons(studentId);
    this.currentLesson = lessons.find((lesson: LessonRecord) => lesson.id === lessonId) ?? null;
    if (this.currentLesson === null) {
      throw new Error('课程记录不存在');
    }
  }

  async getFeedback(lessonId: number): Promise<string | null> {
    const repository = await this.getRepository();
    return await repository.getFeedback(lessonId);
  }

  async saveFeedback(lessonId: number, content: string): Promise<void> {
    const repository = await this.getRepository();
    await repository.saveFeedback(lessonId, content);
  }

  async copyFeedback(text: string): Promise<void> {
    await Clipboard.copyText(text);
  }

  async loadRecords(studentId: number = 0): Promise<void> {
    const repository = await this.getRepository();
    const students = studentId > 0 ? [await repository.getStudentSummary(studentId)] : await repository.listStudents();
    const entries: RecordEntry[] = [];
    for (const student of students) {
      const lessons = await repository.listLessons(student.id);
      for (const lesson of lessons) {
        const billing = lesson.amountFen !== null ? `金额 ¥${TutorViewModel.formatFen(lesson.amountFen)}` :
          `扣课 ${lesson.deduction} 课时`;
        entries.push({
          kind: 'LESSON',
          id: lesson.id,
          studentId: student.id,
          date: lesson.date,
          createdAt: lesson.createdAt,
          title: `${student.nickname} · ${lesson.content}`,
          detail: `${lesson.date} · ${billing}`,
          feedback: await repository.getFeedback(lesson.id)
        });
      }
      const payments = await repository.listPayments(student.id);
      for (const payment of payments) {
        entries.push({
          kind: 'PAYMENT',
          id: payment.id,
          studentId: student.id,
          date: payment.date,
          createdAt: payment.createdAt,
          title: `${student.nickname} · 收款`,
          detail: `收款 ¥${TutorViewModel.formatFen(payment.amountFen)}`,
          feedback: null
        });
      }
      const topUps = await repository.listTopUps(student.id);
      for (const topUp of topUps) {
        entries.push({
          kind: 'TOP_UP',
          id: topUp.id,
          studentId: student.id,
          date: topUp.date,
          createdAt: topUp.createdAt,
          title: `${student.nickname} · 课时包充值`,
          detail: `充值 ${topUp.lessons} 课时`,
          feedback: null
        });
      }
    }
    entries.sort((left: RecordEntry, right: RecordEntry) => right.createdAt - left.createdAt);
    this.records = entries;
  }

  static yuanToFen(yuan: string): number {
    const value = yuan.trim();
    if (!/^\d+(\.\d{1,2})?$/.test(value)) {
      throw new Error('请输入有效金额，最多两位小数');
    }
    const parts = value.split('.');
    const fraction = parts.length === 2 ? parts[1].padEnd(2, '0') : '00';
    const fen = Number(parts[0]) * 100 + Number(fraction);
    if (!Number.isSafeInteger(fen)) {
      throw new Error('金额超出支持范围');
    }
    return fen;
  }

  static formatFen(fen: number): string {
    const sign = fen < 0 ? '-' : '';
    const absolute = Math.abs(fen);
    return `${sign}${Math.floor(absolute / 100)}.${(absolute % 100).toString().padStart(2, '0')}`;
  }

  static errorMessage(error: Object): string {
    const message = error instanceof Error ? error.message : '';
    if (message.includes('Cannot switch billing with a non-zero balance')) {
      return '有未结余额，不能切换收费方式';
    }
    if (message.includes('Insufficient remaining lessons')) {
      return '剩余课时不足，请先充值或调整扣课数量';
    }
    if (message.includes('Duration must be')) {
      return '上课时长必须大于 0';
    }
    if (message.includes('Deduction must be')) {
      return '扣课数量必须是正整数';
    }
    return message.length > 0 ? message : '保存失败，请重试';
  }

  private async getRepository(): Promise<TutorRepository> {
    if (this.initialization === null) {
      this.initialization = this.repository.init();
    }
    await this.initialization;
    return this.repository;
  }

  private static validateStudent(input: StudentInput): void {
    if (input.nickname.trim().length === 0 || input.subject.trim().length === 0) {
      throw new Error('请填写学生昵称和科目');
    }
    if (!Number.isSafeInteger(input.unitPriceFen) || input.unitPriceFen < 0) {
      throw new Error('课时价格必须是非负整数分');
    }
  }
}
