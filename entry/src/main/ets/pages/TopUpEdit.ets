import { router } from '@kit.ArkUI';
import { TopUpInput } from '../model/Types';
import { TutorViewModel } from '../viewmodel/TutorViewModel';

interface TopUpEditParams {
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
struct TopUpEdit {
  @State lessons: string = '';
  @State date: string = today();
  @State note: string = '';
  @State saving: boolean = false;
  @State error: string = '';
  private studentId: number = 0;
  private viewModel: TutorViewModel = new TutorViewModel(getContext(this));

  aboutToAppear(): void {
    const params = router.getParams() as TopUpEditParams;
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
        Text('课时包充值')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank()
          .width(56)
      }
      .width('100%')
      Text('充值课时')
        .width('100%')
      TextInput({ placeholder: '正整数', text: this.lessons })
        .id('topUpLessons')
        .height(48)
        .type(InputType.Number)
        .onChange((value: string) => this.lessons = value)
      Text('日期')
        .width('100%')
      TextInput({ text: this.date })
        .id('topUpDate')
        .height(48)
        .onChange((value: string) => this.date = value)
      Text('备注（可选）')
        .width('100%')
      TextArea({ placeholder: '课时包说明', text: this.note })
        .id('topUpNote')
        .height(100)
        .onChange((value: string) => this.note = value)
      if (this.error.length > 0) {
        Text(this.error)
          .id('topUpError')
          .width('100%')
          .fontColor('#D92D20')
      }
      Button(this.saving ? '保存中…' : '保存充值')
        .id('saveTopUp')
        .width('100%')
        .height(48)
        .enabled(!this.saving)
        .onClick(() => this.save())
    }
    .id('topUpEditPage')
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
      const lessons = Number(this.lessons);
      const input: TopUpInput = {
        studentId: this.studentId,
        date: this.date,
        lessons: lessons,
        note: this.note
      };
      await this.viewModel.saveTopUp(input);
      router.back();
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    } finally {
      this.saving = false;
    }
  }
}
