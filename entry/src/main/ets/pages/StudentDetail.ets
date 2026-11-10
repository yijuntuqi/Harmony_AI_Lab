import { router } from '@kit.ArkUI';
import { StudentSummary } from '../model/Types';
import { RecordEntry, TutorViewModel } from '../viewmodel/TutorViewModel';

interface StudentDetailParams {
  studentId: number;
}

@Entry
@Component
struct StudentDetail {
  @State student: StudentSummary | null = null;
  @State records: RecordEntry[] = [];
  @State error: string = '';
  private studentId: number = 0;
  private viewModel: TutorViewModel = new TutorViewModel(getContext(this));

  aboutToAppear(): void {
    const params = router.getParams() as StudentDetailParams;
    this.studentId = params.studentId;
  }

  onPageShow(): void {
    if (this.studentId > 0) {
      this.loadStudent();
    }
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button('返回')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor('#175CD3')
          .onClick(() => router.back())
        Text('学生详情')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button('编辑')
          .id('editStudent')
          .type(ButtonType.Normal)
          .onClick(() => {
            router.pushUrl({ url: 'pages/StudentEdit', params: { studentId: this.studentId } });
          })
      }
      .width('100%')

      if (this.student !== null) {
        Column({ space: 6 }) {
          Text(this.student.nickname)
            .id('detailNickname')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
          Text(this.student.subject)
            .id('detailSubject')
            .fontSize(15)
            .fontColor('#475467')
          Row({ space: 8 }) {
            Text(this.student.billingMode === 'POSTPAID' ? '后付' : '课时包')
              .id('detailBilling')
              .fontColor('#175CD3')
            Text(this.student.priceUnit === 'HOURLY' ? '按小时' : '按次')
              .fontColor('#475467')
          }
          Text(`价格 ¥${TutorViewModel.formatFen(this.student.unitPriceFen)}`)
            .fontColor('#475467')
        }
        .width('100%')
        .padding(14)
        .borderRadius(12)
        .backgroundColor(Color.White)

        if (this.student.billingMode === 'POSTPAID') {
          Text(`待收金额 ¥${TutorViewModel.formatFen(this.student.outstandingFen)}`)
            .id('detailOutstanding')
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
          Button('登记收款')
            .id('addPayment')
            .width('100%')
            .height(44)
            .onClick(() => {
              router.pushUrl({ url: 'pages/PaymentEdit', params: { studentId: this.studentId } });
            })
        } else {
          Text(`剩余课时 ${this.student.remainingLessons}`)
            .id('detailRemaining')
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
          Button('课时包充值')
            .id('addTopUp')
            .width('100%')
            .height(44)
            .onClick(() => {
              router.pushUrl({ url: 'pages/TopUpEdit', params: { studentId: this.studentId } });
            })
        }
        Button('记一节课')
          .id('addLesson')
          .width('100%')
          .height(44)
          .onClick(() => {
            router.pushUrl({ url: 'pages/LessonEdit', params: { studentId: this.studentId } });
          })
      }

      if (this.records.length > 0) {
        List({ space: 10 }) {
          ForEach(this.records, (entry: RecordEntry) => {
            ListItem() {
              Column({ space: 6 }) {
                Text(entry.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                Text(entry.detail)
                  .fontSize(14)
                  .fontColor('#475467')
                  .width('100%')
                if (entry.feedback !== null) {
                  Text(entry.feedback)
                    .fontSize(13)
                    .fontColor('#667085')
                    .width('100%')
                }
                if (entry.kind === 'LESSON') {
                  Row({ space: 10 }) {
                    Button('反馈')
                      .id(`viewFeedback-${entry.id}`)
                      .type(ButtonType.Normal)
                      .onClick(() => {
                        router.pushUrl({
                          url: 'pages/Feedback',
                          params: { studentId: entry.studentId, lessonId: entry.id }
                        });
                      })
                    Button('编辑')
                      .id(`editLesson-${entry.id}`)
                      .type(ButtonType.Normal)
                      .onClick(() => {
                        router.pushUrl({
                          url: 'pages/LessonEdit',
                          params: { studentId: entry.studentId, lessonId: entry.id }
                        });
                      })
                    Button('删除')
                      .id(`deleteLesson-${entry.id}`)
                      .type(ButtonType.Normal)
                      .backgroundColor('#FEF3F2')
                      .fontColor('#D92D20')
                      .onClick(() => this.deleteLesson(entry.id))
                  }
                }
              }
              .width('100%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor(Color.White)
            }
          }, (entry: RecordEntry) => `${entry.kind}-${entry.id}`)
        }
        .id('detailLessonHistory')
        .width('100%')
        .layoutWeight(1)
      } else {
        Text('还没有记录，点击“记一节课”开始')
          .fontColor('#667085')
      }
      if (this.error.length > 0) {
        Text(this.error)
          .fontColor('#D92D20')
      }
    }
    .id('studentDetailPage')
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F5F7FA')
  }

  private async loadStudent(): Promise<void> {
    try {
      await this.viewModel.loadStudent(this.studentId);
      this.student = this.viewModel.currentStudent;
      await this.viewModel.loadRecords(this.studentId);
      this.records = this.viewModel.records;
      this.error = '';
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    }
  }

  private async deleteLesson(lessonId: number): Promise<void> {
    try {
      await this.viewModel.deleteLesson(lessonId);
      await this.loadStudent();
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    }
  }
}
