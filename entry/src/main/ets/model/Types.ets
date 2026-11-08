export type BillingMode = 'POSTPAID' | 'PREPAID';
export type PriceUnit = 'HOURLY' | 'PER_LESSON';

export interface StudentInput {
  nickname: string;
  subject: string;
  billingMode: BillingMode;
  priceUnit: PriceUnit;
  unitPriceFen: number;
}

export interface StudentSummary extends StudentInput {
  id: number;
  outstandingFen: number;
  remainingLessons: number;
}

export interface LessonInput {
  studentId: number;
  requestId: string;
  date: string;
  durationMinutes: number;
  amountFen: number | null;
  deduction: number | null;
  content: string;
  mastery: string;
  weakPoints: string;
  note: string;
}

export interface PaymentInput {
  studentId: number;
  date: string;
  amountFen: number;
  note: string;
}

export interface TopUpInput {
  studentId: number;
  date: string;
  lessons: number;
  note: string;
}
