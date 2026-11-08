import { PriceUnit } from '../model/Types';

function validateDuration(durationMinutes: number): void {
  if (!Number.isFinite(durationMinutes) || durationMinutes <= 0) {
    throw new Error('Duration must be a positive finite number');
  }
}

function validateAmount(amountFen: number): void {
  if (!Number.isFinite(amountFen) || !Number.isInteger(amountFen) || amountFen < 0) {
    throw new Error('Amount must be a non-negative integer in fen');
  }
}

function validateDeduction(deduction: number): void {
  if (!Number.isFinite(deduction) || !Number.isInteger(deduction) || deduction <= 0) {
    throw new Error('Deduction must be a positive integer');
  }
}

export function calculateAmountFen(unit: PriceUnit, unitPriceFen: number, durationMinutes: number): number {
  validateDuration(durationMinutes);
  validateAmount(unitPriceFen);
  if (unit === 'HOURLY') {
    return Math.round(unitPriceFen * durationMinutes / 60);
  }
  return unitPriceFen;
}

export function validateLesson(durationMinutes: number, amountFen: number | null,
  deduction: number | null): void {
  validateDuration(durationMinutes);
  if (amountFen !== null) {
    validateAmount(amountFen);
  }
  if (deduction !== null) {
    validateDeduction(deduction);
  }
}

export function validatePackageDeduction(deduction: number, remainingLessons: number): void {
  validateDeduction(deduction);
  if (!Number.isFinite(remainingLessons) || !Number.isInteger(remainingLessons) || remainingLessons < 0) {
    throw new Error('Remaining lessons must be a non-negative integer');
  }
  if (deduction > remainingLessons) {
    throw new Error('Insufficient remaining lessons');
  }
}

export function canSwitchBilling(outstandingFen: number, remainingLessons: number): boolean {
  return outstandingFen === 0 && remainingLessons === 0;
}
