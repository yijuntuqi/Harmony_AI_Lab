import { LessonInput } from '../model/Types';

export function formatParentFeedback(studentNickname: string, lesson: LessonInput): string {
  const lines: string[] = [
    `学生：${studentNickname}`,
    `日期：${lesson.date}`,
    `时长：${lesson.durationMinutes} 分钟`,
    `课程内容：${lesson.content}`,
    `掌握情况：${lesson.mastery}`,
    `薄弱点：${lesson.weakPoints}`
  ];
  if (lesson.note.length > 0) {
    lines.push(`备注：${lesson.note}`);
  }
  return lines.join('\n');
}
