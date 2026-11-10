import { router } from '@kit.ArkUI';
import { StudentSummary } from '../model/Types';
import { TutorViewModel } from '../viewmodel/TutorViewModel';

@Entry
@Component
struct Students {
  @State students: StudentSummary[] = [];
  @State error: string = '';
  private viewModel: TutorViewModel = new TutorViewModel(getContext(this));
  private selectForLesson: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, boolean> | null;
    this.selectForLesson = params?.selectForLesson ?? false;
  }

  onPageShow(): void {
    this.loadStudents();
  }

  build() {
    Column() {
      Row() {
        Button('返回')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor('#175CD3')
          .onClick(() => router.back())
        Text('学生与账目')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button('添加')
          .id('addStudent')
          .type(ButtonType.Normal)
          .onClick(() => router.pushUrl({ url: 'pages/StudentEdit' }))
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      if (this.error.length > 0) {
        Text(this.error)
          .fontColor('#D92D20')
          .padding(12)
      }
      if (this.students.length === 0) {
        Column({ space: 12 }) {
          Text('还没有学生')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
          Text('点击右上角“添加”创建第一名学生')
            .fontColor('#667085')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.students, (student: StudentSummary) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Text(student.nickname)
                    .fontSize(20)
                    .fontWeight(FontWeight.Medium)
                  Blank()
                  Text(student.billingMode === 'POSTPAID' ? '后付' : '课时包')
                    .fontColor('#175CD3')
                }
                .width('100%')
                Text(student.subject)
                  .fontSize(15)
                  .fontColor('#475467')
                Text(student.priceUnit === 'HOURLY' ? '按小时' : '按次')
                  .fontSize(14)
                  .fontColor('#475467')
                Text(student.billingMode === 'POSTPAID' ?
                  `待收 ¥${TutorViewModel.formatFen(student.outstandingFen)}` :
                  `剩余 ${student.remainingLessons} 课时`)
                  .fontSize(15)
                  .fontColor('#101828')
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(16)
              .borderRadius(12)
              .backgroundColor(Color.White)
              .onClick(() => {
                router.pushUrl({
                  url: this.selectForLesson ? 'pages/LessonEdit' : 'pages/StudentDetail',
                  params: { studentId: student.id }
                });
              })
            }
          }, (student: StudentSummary) => student.id.toString())
        }
        .id('studentList')
        .width('100%')
        .layoutWeight(1)
      }
    }
    .id('studentsPage')
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, bottom: 20 })
    .backgroundColor('#F5F7FA')
  }

  private async loadStudents(): Promise<void> {
    try {
      await this.viewModel.loadStudents();
      this.students = this.viewModel.students.reverse();
      this.error = '';
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    }
  }
}
