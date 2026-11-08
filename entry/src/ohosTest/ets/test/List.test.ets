import studentRepositoryTests from './StudentRepository.test';
import lessonRepositoryTests from './LessonRepository.test';

export default function testsuite() {
  studentRepositoryTests();
  lessonRepositoryTests();
}
