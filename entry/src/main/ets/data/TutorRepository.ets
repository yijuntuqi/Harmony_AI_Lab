import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { canSwitchBilling, validateLesson, validatePackageDeduction } from '../domain/Billing';
import {
  BillingMode,
  LessonInput,
  PaymentInput,
  PaymentRecord,
  PriceUnit,
  StudentInput,
  StudentSummary,
  TopUpInput,
  TopUpRecord
} from '../model/Types';
import { Database } from './Database';

const SUMMARY_SELECT = `SELECT
  s.id, s.nickname, s.subject, s.billing_mode, s.price_unit, s.unit_price_fen,
  COALESCE((SELECT SUM(l.amount_fen) FROM lessons l
    WHERE l.student_id = s.id AND l.deleted_at IS NULL), 0) -
    COALESCE((SELECT SUM(p.amount_fen) FROM payments p WHERE p.student_id = s.id), 0) AS outstanding_fen,
  COALESCE((SELECT SUM(t.lessons) FROM package_topups t WHERE t.student_id = s.id), 0) -
    COALESCE((SELECT SUM(l.deduction) FROM lessons l
      WHERE l.student_id = s.id AND l.deleted_at IS NULL), 0) AS remaining_lessons
  FROM students s`;

const LESSON_SELECT = `SELECT
  id, student_id, request_id, date, duration_minutes, amount_fen, deduction,
  content, mastery, weak_points, note, created_at FROM lessons`;

export interface LessonRecord extends LessonInput {
  id: number;
  createdAt: number;
}

export class TutorRepository {
  private context: common.Context;
  private store: relationalStore.RdbStore | null = null;

  constructor(context: common.Context) {
    this.context = context;
  }

  async init(): Promise<void> {
    this.store = await Database.open(this.context);
  }

  async createStudent(input: StudentInput): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      nickname: input.nickname,
      subject: input.subject,
      billing_mode: input.billingMode,
      price_unit: input.priceUnit,
      unit_price_fen: input.unitPriceFen,
      created_at: Date.now()
    };
    return await this.getStore().insert('students', values);
  }

  async listStudents(): Promise<StudentSummary[]> {
    const result = await this.getStore().querySql(`${SUMMARY_SELECT} ORDER BY s.id`);
    const students: StudentSummary[] = [];
    while (result.goToNextRow()) {
      students.push(TutorRepository.readSummary(result));
    }
    result.close();
    return students;
  }

  async getStudentSummary(studentId: number): Promise<StudentSummary> {
    const result = await this.getStore().querySql(`${SUMMARY_SELECT} WHERE s.id = ?`, [studentId]);
    if (!result.goToFirstRow()) {
      result.close();
      throw new Error('Student not found');
    }
    const summary = TutorRepository.readSummary(result);
    result.close();
    return summary;
  }

  async recordPayment(input: PaymentInput): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      student_id: input.studentId,
      date: input.date,
      amount_fen: input.amountFen,
      note: input.note,
      created_at: Date.now()
    };
    return await this.getStore().insert('payments', values);
  }

  async topUpPackage(input: TopUpInput): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      student_id: input.studentId,
      date: input.date,
      lessons: input.lessons,
      note: input.note,
      created_at: Date.now()
    };
    return await this.getStore().insert('package_topups', values);
  }

  async switchBilling(studentId: number, input: StudentInput): Promise<void> {
    const transaction = await this.getStore().createTransaction();
    try {
      const summary = await TutorRepository.readSummaryInTransaction(transaction, studentId);
      if (summary.billingMode !== input.billingMode &&
        !canSwitchBilling(summary.outstandingFen, summary.remainingLessons)) {
        throw new Error('Cannot switch billing with a non-zero balance');
      }
      const values: relationalStore.ValuesBucket = {
        nickname: input.nickname,
        subject: input.subject,
        billing_mode: input.billingMode,
        price_unit: input.priceUnit,
        unit_price_fen: input.unitPriceFen
      };
      const predicates = new relationalStore.RdbPredicates('students');
      predicates.equalTo('id', studentId);
      const changed = await transaction.update(values, predicates);
      if (changed !== 1) {
        throw new Error('Student not found');
      }
      await transaction.commit();
    } catch (error) {
      await transaction.rollback();
      TutorRepository.rethrow(error, 'Billing switch failed');
    }
  }

  async createLesson(input: LessonInput): Promise<number> {
    const transaction = await this.getStore().createTransaction();
    try {
      const existing = await transaction.querySql('SELECT id FROM lessons WHERE request_id = ?', [input.requestId]);
      if (existing.goToFirstRow()) {
        const lessonId = existing.getLong(0);
        existing.close();
        await transaction.commit();
        return lessonId;
      }
      existing.close();
      const summary = await TutorRepository.readSummaryInTransaction(transaction, input.studentId);
      TutorRepository.validateLessonForMode(input, summary, 0);
      const values = TutorRepository.lessonValues(input);
      values.created_at = Date.now();
      const lessonId = await transaction.insert('lessons', values);
      await transaction.commit();
      return lessonId;
    } catch (error) {
      await transaction.rollback();
      TutorRepository.rethrow(error, 'Lesson creation failed');
    }
  }

  async updateLesson(lessonId: number, input: LessonInput): Promise<void> {
    const transaction = await this.getStore().createTransaction();
    try {
      const original = await TutorRepository.readLessonInTransaction(transaction, lessonId);
      if (input.studentId !== original.studentId) {
        throw new Error('Cannot move a lesson to another student');
      }
      const summary = await TutorRepository.readSummaryInTransaction(transaction, original.studentId);
      TutorRepository.validateLessonForMode(input, summary, original.deduction ?? 0);
      const predicates = new relationalStore.RdbPredicates('lessons');
      predicates.equalTo('id', lessonId);
      predicates.isNull('deleted_at');
      const values = TutorRepository.lessonValues(input);
      values.request_id = original.requestId;
      const changed = await transaction.update(values, predicates);
      if (changed !== 1) {
        throw new Error('Lesson not found');
      }
      await transaction.commit();
    } catch (error) {
      await transaction.rollback();
      TutorRepository.rethrow(error, 'Lesson update failed');
    }
  }

  async deleteLesson(lessonId: number): Promise<void> {
    const transaction = await this.getStore().createTransaction();
    try {
      const lesson = await TutorRepository.readLessonInTransaction(transaction, lessonId);
      await TutorRepository.readSummaryInTransaction(transaction, lesson.studentId);
      const predicates = new relationalStore.RdbPredicates('lessons');
      predicates.equalTo('id', lessonId);
      predicates.isNull('deleted_at');
      const changed = await transaction.update({ deleted_at: Date.now() }, predicates);
      if (changed !== 1) {
        throw new Error('Lesson not found');
      }
      await transaction.commit();
    } catch (error) {
      await transaction.rollback();
      TutorRepository.rethrow(error, 'Lesson deletion failed');
    }
  }

  async listLessons(studentId: number = 0): Promise<LessonRecord[]> {
    const result = studentId > 0 ? await this.getStore().querySql(
      `${LESSON_SELECT} WHERE student_id = ? AND deleted_at IS NULL ORDER BY date DESC, id DESC`, [studentId]) :
      await this.getStore().querySql(`${LESSON_SELECT} WHERE deleted_at IS NULL ORDER BY date DESC, id DESC`);
    const lessons: LessonRecord[] = [];
    while (result.goToNextRow()) {
      lessons.push(TutorRepository.readLesson(result));
    }
    result.close();
    return lessons;
  }

  async listPayments(studentId: number): Promise<PaymentRecord[]> {
    const result = await this.getStore().querySql(
      'SELECT id, student_id, date, amount_fen, note, created_at FROM payments WHERE student_id = ? ORDER BY date DESC, id DESC',
      [studentId]);
    const payments: PaymentRecord[] = [];
    while (result.goToNextRow()) {
      payments.push({
        id: result.getLong(0),
        studentId: result.getLong(1),
        date: result.getString(2),
        amountFen: result.getLong(3),
        note: result.getString(4),
        createdAt: result.getLong(5)
      });
    }
    result.close();
    return payments;
  }

  async listTopUps(studentId: number): Promise<TopUpRecord[]> {
    const result = await this.getStore().querySql(
      'SELECT id, student_id, date, lessons, note, created_at FROM package_topups WHERE student_id = ? ORDER BY date DESC, id DESC',
      [studentId]);
    const topUps: TopUpRecord[] = [];
    while (result.goToNextRow()) {
      topUps.push({
        id: result.getLong(0),
        studentId: result.getLong(1),
        date: result.getString(2),
        lessons: result.getLong(3),
        note: result.getString(4),
        createdAt: result.getLong(5)
      });
    }
    result.close();
    return topUps;
  }

  async saveFeedback(lessonId: number, content: string): Promise<void> {
    const now = Date.now();
    await this.getStore().insert('feedbacks', {
      lesson_id: lessonId,
      content: content,
      created_at: now,
      updated_at: now
    }, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  async getFeedback(lessonId: number): Promise<string | null> {
    const result = await this.getStore().querySql('SELECT content FROM feedbacks WHERE lesson_id = ?', [lessonId]);
    if (!result.goToFirstRow()) {
      result.close();
      return null;
    }
    const content = result.getString(0);
    result.close();
    return content;
  }

  private getStore(): relationalStore.RdbStore {
    if (this.store === null) {
      throw new Error('TutorRepository.init() must be called first');
    }
    return this.store;
  }

  private static async readSummaryInTransaction(transaction: relationalStore.Transaction,
    studentId: number): Promise<StudentSummary> {
    const result = await transaction.querySql(`${SUMMARY_SELECT} WHERE s.id = ?`, [studentId]);
    if (!result.goToFirstRow()) {
      result.close();
      throw new Error('Student not found');
    }
    const summary = TutorRepository.readSummary(result);
    result.close();
    return summary;
  }

  private static async readLessonInTransaction(transaction: relationalStore.Transaction,
    lessonId: number): Promise<LessonRecord> {
    const result = await transaction.querySql(`${LESSON_SELECT} WHERE id = ? AND deleted_at IS NULL`, [lessonId]);
    if (!result.goToFirstRow()) {
      result.close();
      throw new Error('Lesson not found');
    }
    const lesson = TutorRepository.readLesson(result);
    result.close();
    return lesson;
  }

  private static validateLessonForMode(input: LessonInput, summary: StudentSummary,
    previousDeduction: number): void {
    validateLesson(input.durationMinutes, input.amountFen, input.deduction);
    if (summary.billingMode === 'POSTPAID') {
      if (input.amountFen === null || input.deduction !== null) {
        throw new Error('Postpaid lessons require an amount and no deduction');
      }
      return;
    }
    if (input.deduction === null || input.amountFen !== null) {
      throw new Error('Prepaid lessons require a deduction and no amount');
    }
    validatePackageDeduction(input.deduction, summary.remainingLessons + previousDeduction);
  }

  private static lessonValues(input: LessonInput): relationalStore.ValuesBucket {
    return {
      student_id: input.studentId,
      request_id: input.requestId,
      date: input.date,
      duration_minutes: input.durationMinutes,
      amount_fen: input.amountFen,
      deduction: input.deduction,
      content: input.content,
      mastery: input.mastery,
      weak_points: input.weakPoints,
      note: input.note
    };
  }

  private static readSummary(result: relationalStore.ResultSet): StudentSummary {
    return {
      id: result.getLong(0),
      nickname: result.getString(1),
      subject: result.getString(2),
      billingMode: result.getString(3) as BillingMode,
      priceUnit: result.getString(4) as PriceUnit,
      unitPriceFen: result.getLong(5),
      outstandingFen: result.getLong(6),
      remainingLessons: result.getLong(7)
    };
  }

  private static readLesson(result: relationalStore.ResultSet): LessonRecord {
    return {
      id: result.getLong(0),
      studentId: result.getLong(1),
      requestId: result.getString(2),
      date: result.getString(3),
      durationMinutes: result.getLong(4),
      amountFen: result.isColumnNull(5) ? null : result.getLong(5),
      deduction: result.isColumnNull(6) ? null : result.getLong(6),
      content: result.getString(7),
      mastery: result.getString(8),
      weakPoints: result.getString(9),
      note: result.getString(10),
      createdAt: result.getLong(11)
    };
  }

  private static rethrow(error: Object, fallback: string): never {
    if (error instanceof Error) {
      throw error;
    }
    throw new Error(fallback);
  }
}
