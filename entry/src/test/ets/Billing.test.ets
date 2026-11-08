import { describe, it, expect } from '@ohos/hypium';
import {
  calculateAmountFen,
  validateLesson,
  validatePackageDeduction,
  canSwitchBilling
} from '../../main/ets/domain/Billing';

function expectThrows(action: () => void): void {
  let threw = false;
  try {
    action();
  } catch (error) {
    threw = true;
  }
  expect(threw).assertTrue();
}

export default function testsuite() {
  describe('Billing', () => {
    it('billing_calculates_hourly_and_per_lesson', 0, () => {
      expect(calculateAmountFen('HOURLY', 10000, 90)).assertEqual(15000);
      expect(calculateAmountFen('PER_LESSON', 12000, 90)).assertEqual(12000);
    });

    it('billing_rounds_half_up', 0, () => {
      expect(calculateAmountFen('HOURLY', 100, 20)).assertEqual(33);
    });

    it('billing_rejects_invalid_numbers', 0, () => {
      expectThrows((): void => {
        calculateAmountFen('HOURLY', 10000, 0);
      });
      expectThrows((): void => {
        calculateAmountFen('HOURLY', 10000, -60);
      });
      expectThrows((): void => validateLesson(0, 1000, null));
      expectThrows((): void => validateLesson(-60, 1000, null));
      expectThrows((): void => validateLesson(60, -1, null));
      expectThrows((): void => validateLesson(60, null, 1.5));
      expectThrows((): void => validateLesson(Number.NaN, 1000, null));
      expectThrows((): void => validateLesson(60, Number.POSITIVE_INFINITY, null));
      expectThrows((): void => validateLesson(60, null, Number.NaN));
    });

    it('package_rejects_overdraft', 0, () => {
      expectThrows((): void => validatePackageDeduction(2, 1));
    });

    it('billing_switch_requires_zero_balance', 0, () => {
      expect(canSwitchBilling(0, 0)).assertTrue();
      expect(canSwitchBilling(1, 0)).assertFalse();
      expect(canSwitchBilling(0, 1)).assertFalse();
      expect(canSwitchBilling(1, 1)).assertFalse();
    });
  });
}
