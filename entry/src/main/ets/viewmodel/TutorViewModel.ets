import { common } from '@kit.AbilityKit';
import { TutorRepository } from '../data/TutorRepository';
import { PaymentInput, StudentInput, StudentSummary, TopUpInput } from '../model/Types';

export class TutorViewModel {
  students: StudentSummary[] = [];
  currentStudent: StudentSummary | null = null;
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
    await this.loadStudents();
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
    await this.loadStudent(input.studentId);
  }

  async saveTopUp(input: TopUpInput): Promise<void> {
    if (!Number.isSafeInteger(input.lessons) || input.lessons <= 0) {
      throw new Error('充值课时必须是正整数');
    }
    const repository = await this.getRepository();
    await repository.topUpPackage(input);
    await this.loadStudent(input.studentId);
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
