import studentRepositoryTests from './StudentRepository.test';
import lessonRepositoryTests from './LessonRepository.test';
import studentFlowTests from './StudentFlow.test';
import lessonFlowTests from './LessonFlow.test';

export default function testsuite() {
  studentRepositoryTests();
  lessonRepositoryTests();
  studentFlowTests();
  lessonFlowTests();
}
