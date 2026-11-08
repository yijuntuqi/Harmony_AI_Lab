import { describe, it, expect } from '@ohos/hypium';
import billingTests from './Billing.test';
import feedbackFormatterTests from './FeedbackFormatter.test';

export default function testsuite() {
  describe('localUnitTest', () => {
    it('assertContain', 0, () => {
      const value = 'abc';
      expect(value).assertContain('b');
      expect(value).assertEqual('abc');
    });
  });
  billingTests();
  feedbackFormatterTests();
}
