import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { canSwitchBilling } from '../domain/Billing';
import {
  BillingMode,
  PaymentInput,
  PriceUnit,
  StudentInput,
  StudentSummary,
  TopUpInput
} from '../model/Types';
import { Database } from './Database';

const SUMMARY_SELECT = `SELECT
  s.id, s.nickname, s.subject, s.billing_mode, s.price_unit, s.unit_price_fen,
  COALESCE((SELECT SUM(l.amount_fen) FROM lessons l WHERE l.student_id = s.id), 0) -
    COALESCE((SELECT SUM(p.amount_fen) FROM payments p WHERE p.student_id = s.id), 0) AS outstanding_fen,
  COALESCE((SELECT SUM(t.lessons) FROM package_topups t WHERE t.student_id = s.id), 0) -
    COALESCE((SELECT SUM(l.deduction) FROM lessons l WHERE l.student_id = s.id), 0) AS remaining_lessons
  FROM students s`;

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
      const result = await transaction.querySql(`${SUMMARY_SELECT} WHERE s.id = ?`, [studentId]);
      if (!result.goToFirstRow()) {
        result.close();
        throw new Error('Student not found');
      }
      const outstandingFen = result.getLong(6);
      const remainingLessons = result.getLong(7);
      result.close();
      if (!canSwitchBilling(outstandingFen, remainingLessons)) {
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
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('Billing switch failed');
    }
  }

  private getStore(): relationalStore.RdbStore {
    if (this.store === null) {
      throw new Error('TutorRepository.init() must be called first');
    }
    return this.store;
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
}
