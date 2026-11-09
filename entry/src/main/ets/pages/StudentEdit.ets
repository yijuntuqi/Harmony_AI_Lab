import { router } from '@kit.ArkUI';
import { BillingMode, PriceUnit, StudentInput } from '../model/Types';
import { TutorViewModel } from '../viewmodel/TutorViewModel';

interface StudentEditParams {
  studentId?: number;
}

@Entry
@Component
struct StudentEdit {
  @State nickname: string = '';
  @State subject: string = '';
  @State billingMode: BillingMode = 'POSTPAID';
  @State priceUnit: PriceUnit = 'HOURLY';
  @State unitPriceYuan: string = '100';
  @State saving: boolean = false;
  @State loading: boolean = false;
  @State error: string = '';
  private studentId: number = 0;
  private viewModel: TutorViewModel = new TutorViewModel(getContext(this));

  aboutToAppear(): void {
    const params = router.getParams() as StudentEditParams;
    if (params !== null && params !== undefined && params.studentId !== undefined) {
      this.studentId = params.studentId;
      this.loadStudent();
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Button('返回')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontColor('#175CD3')
            .onClick(() => router.back())
          Text(this.studentId > 0 ? '编辑学生' : '添加学生')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Button(this.saving ? '保存中…' : '保存')
            .id('saveStudent')
            .type(ButtonType.Normal)
            .enabled(!this.saving && !this.loading)
            .onClick(() => this.save())
        }
        .width('100%')

        Text('学生昵称')
          .width('100%')
        TextInput({ placeholder: '使用昵称或代号', text: this.nickname })
          .id('studentNickname')
          .height(48)
          .onChange((value: string) => this.nickname = value)
        Text('科目')
          .width('100%')
        TextInput({ placeholder: '例如：数学', text: this.subject })
          .id('studentSubject')
          .height(48)
          .onChange((value: string) => this.subject = value)
        Text('收费方式')
          .width('100%')
        Row({ space: 12 }) {
          Button('后付')
            .id('billingPostpaid')
            .layoutWeight(1)
            .type(ButtonType.Normal)
            .backgroundColor(this.billingMode === 'POSTPAID' ? '#175CD3' : '#E4E7EC')
            .onClick(() => this.billingMode = 'POSTPAID')
          Button('课时包')
            .id('billingPrepaid')
            .layoutWeight(1)
            .type(ButtonType.Normal)
            .backgroundColor(this.billingMode === 'PREPAID' ? '#175CD3' : '#E4E7EC')
            .fontColor(this.billingMode === 'PREPAID' ? Color.White : '#101828')
            .onClick(() => this.billingMode = 'PREPAID')
        }
        .width('100%')
        Text('计价方式')
          .width('100%')
        Row({ space: 12 }) {
          Button('按小时')
            .id('priceHourly')
            .layoutWeight(1)
            .type(ButtonType.Normal)
            .backgroundColor(this.priceUnit === 'HOURLY' ? '#175CD3' : '#E4E7EC')
            .onClick(() => this.priceUnit = 'HOURLY')
          Button('按次')
            .id('pricePerLesson')
            .layoutWeight(1)
            .type(ButtonType.Normal)
            .backgroundColor(this.priceUnit === 'PER_LESSON' ? '#175CD3' : '#E4E7EC')
            .fontColor(this.priceUnit === 'PER_LESSON' ? Color.White : '#101828')
            .onClick(() => this.priceUnit = 'PER_LESSON')
        }
        .width('100%')
        Text('默认价格（元）')
          .width('100%')
        TextInput({ placeholder: '例如：100.00', text: this.unitPriceYuan })
          .id('studentUnitPrice')
          .height(48)
          .onChange((value: string) => this.unitPriceYuan = value)
        if (this.error.length > 0) {
          Text(this.error)
            .id('studentEditError')
            .width('100%')
            .fontColor('#D92D20')
        }
      }
      .width('100%')
      .padding(20)
    }
    .id('studentEditPage')
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
  }

  private async loadStudent(): Promise<void> {
    this.loading = true;
    try {
      await this.viewModel.loadStudent(this.studentId);
      const student = this.viewModel.currentStudent;
      if (student !== null) {
        this.nickname = student.nickname;
        this.subject = student.subject;
        this.billingMode = student.billingMode;
        this.priceUnit = student.priceUnit;
        this.unitPriceYuan = TutorViewModel.formatFen(student.unitPriceFen);
      }
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    } finally {
      this.loading = false;
    }
  }

  private async save(): Promise<void> {
    if (this.saving || this.loading) {
      return;
    }
    this.getUIContext().getFocusController().clearFocus();
    this.saving = true;
    this.error = '';
    try {
      const input: StudentInput = {
        nickname: this.nickname.trim(),
        subject: this.subject.trim(),
        billingMode: this.billingMode,
        priceUnit: this.priceUnit,
        unitPriceFen: TutorViewModel.yuanToFen(this.unitPriceYuan)
      };
      if (this.studentId > 0) {
        await this.viewModel.switchBilling(this.studentId, input);
      } else {
        await this.viewModel.saveStudent(input);
      }
      router.back();
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    } finally {
      this.saving = false;
    }
  }
}
