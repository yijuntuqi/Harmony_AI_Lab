import { router } from '@kit.ArkUI';
import { PaymentInput } from '../model/Types';
import { TutorViewModel } from '../viewmodel/TutorViewModel';

interface PaymentEditParams {
  studentId: number;
}

function today(): string {
  const date = new Date();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  return `${date.getFullYear()}-${month}-${day}`;
}

@Entry
@Component
struct PaymentEdit {
  @State amountYuan: string = '';
  @State date: string = today();
  @State note: string = '';
  @State saving: boolean = false;
  @State error: string = '';
  private studentId: number = 0;
  private viewModel: TutorViewModel = new TutorViewModel(getContext(this));

  aboutToAppear(): void {
    const params = router.getParams() as PaymentEditParams;
    this.studentId = params.studentId;
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Button('返回')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor('#175CD3')
          .onClick(() => router.back())
        Text('登记收款')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank()
          .width(56)
      }
      .width('100%')
      Text('收款金额（元）')
        .width('100%')
      TextInput({ placeholder: '例如：100.00', text: this.amountYuan })
        .id('paymentAmount')
        .height(48)
        .type(InputType.NUMBER_DECIMAL)
        .onChange((value: string) => this.amountYuan = value)
      Text('日期')
        .width('100%')
      TextInput({ text: this.date })
        .id('paymentDate')
        .height(48)
        .onChange((value: string) => this.date = value)
      Text('备注（可选）')
        .width('100%')
      TextArea({ placeholder: '收款说明', text: this.note })
        .id('paymentNote')
        .height(100)
        .onChange((value: string) => this.note = value)
      if (this.error.length > 0) {
        Text(this.error)
          .id('paymentError')
          .width('100%')
          .fontColor('#D92D20')
      }
      Button(this.saving ? '保存中…' : '保存收款')
        .id('savePayment')
        .width('100%')
        .height(48)
        .enabled(!this.saving)
        .onClick(() => this.save())
    }
    .id('paymentEditPage')
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#F5F7FA')
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    this.error = '';
    try {
      const input: PaymentInput = {
        studentId: this.studentId,
        date: this.date,
        amountFen: TutorViewModel.yuanToFen(this.amountYuan),
        note: this.note
      };
      await this.viewModel.savePayment(input);
      router.back();
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    } finally {
      this.saving = false;
    }
  }
}
