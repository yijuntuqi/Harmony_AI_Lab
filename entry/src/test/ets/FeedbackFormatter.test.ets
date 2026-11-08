import { describe, it, expect } from '@ohos/hypium';
import { LessonInput } from '../../main/ets/model/Types';
import { formatParentFeedback } from '../../main/ets/domain/FeedbackFormatter';

function lessonWithNote(note: string): LessonInput {
  return {
    studentId: 1,
    requestId: 'lesson-request-1',
    date: '2026-11-08',
    durationMinutes: 90,
    amountFen: 15000,
    deduction: null,
    content: '二次函数\n顶点坐标 & 图像',
    mastery: '能独立完成基础题',
    weakPoints: '符号变换需加强',
    note: note
  };
}

export default function testsuite() {
  describe('FeedbackFormatter', () => {
    it('feedback_preserves_multiline_text', 0, () => {
      const feedback: string = formatParentFeedback('小明', lessonWithNote('课后练习：第 3 题\n注意 <符号> & 单位'));
      expect(feedback).assertEqual('学生：小明\n日期：2026-11-08\n时长：90 分钟\n课程内容：二次函数\n顶点坐标 & 图像\n掌握情况：能独立完成基础题\n薄弱点：符号变换需加强\n备注：课后练习：第 3 题\n注意 <符号> & 单位');
    });

    it('feedback_omits_empty_notes', 0, () => {
      const feedback: string = formatParentFeedback('小明', lessonWithNote(''));
      expect(feedback).assertEqual('学生：小明\n日期：2026-11-08\n时长：90 分钟\n课程内容：二次函数\n顶点坐标 & 图像\n掌握情况：能独立完成基础题\n薄弱点：符号变换需加强');
    });
  });
}
