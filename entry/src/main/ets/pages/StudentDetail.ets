import { router } from '@kit.ArkUI';
import { StudentSummary } from '../model/Types';
import { TutorViewModel } from '../viewmodel/TutorViewModel';

interface StudentDetailParams {
  studentId: number;
}

@Entry
@Component
struct StudentDetail {
  @State student: StudentSummary | null = null;
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
    Column({ space: 18 }) {
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
        Column({ space: 12 }) {
          Text(this.student.nickname)
            .id('detailNickname')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
          Text(this.student.subject)
            .id('detailSubject')
            .fontSize(18)
            .fontColor('#475467')
          Text(this.student.billingMode === 'POSTPAID' ? '后付' : '课时包')
            .id('detailBilling')
            .fontColor('#175CD3')
          Text(this.student.priceUnit === 'HOURLY' ? '按小时' : '按次')
            .fontColor('#475467')
          Text(`价格 ¥${TutorViewModel.formatFen(this.student.unitPriceFen)}`)
            .fontColor('#475467')
        }
        .width('100%')
        .padding(20)
        .borderRadius(12)
        .backgroundColor(Color.White)

        if (this.student.billingMode === 'POSTPAID') {
          Text(`待收金额 ¥${TutorViewModel.formatFen(this.student.outstandingFen)}`)
            .id('detailOutstanding')
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .padding(20)
            .borderRadius(12)
            .backgroundColor(Color.White)
          Button('登记收款')
            .id('addPayment')
            .width('100%')
            .height(48)
            .onClick(() => {
              router.pushUrl({ url: 'pages/PaymentEdit', params: { studentId: this.studentId } });
            })
        } else {
          Text(`剩余课时 ${this.student.remainingLessons}`)
            .id('detailRemaining')
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .padding(20)
            .borderRadius(12)
            .backgroundColor(Color.White)
          Button('课时包充值')
            .id('addTopUp')
            .width('100%')
            .height(48)
            .onClick(() => {
              router.pushUrl({ url: 'pages/TopUpEdit', params: { studentId: this.studentId } });
            })
        }
      }
      if (this.error.length > 0) {
        Text(this.error)
          .fontColor('#D92D20')
      }
    }
    .id('studentDetailPage')
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#F5F7FA')
  }

  private async loadStudent(): Promise<void> {
    try {
      await this.viewModel.loadStudent(this.studentId);
      this.student = this.viewModel.currentStudent;
      this.error = '';
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    }
  }
}
