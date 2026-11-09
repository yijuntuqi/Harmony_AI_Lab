import studentRepositoryTests from './StudentRepository.test';
import lessonRepositoryTests from './LessonRepository.test';
import studentFlowTests from './StudentFlow.test';

export default function testsuite() {
  studentRepositoryTests();
  lessonRepositoryTests();
  studentFlowTests();
}
