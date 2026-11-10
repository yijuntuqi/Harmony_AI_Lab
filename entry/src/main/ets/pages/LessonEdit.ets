import { router } from '@kit.ArkUI';
import { calculateAmountFen } from '../domain/Billing';
import { LessonInput, StudentSummary } from '../model/Types';
import { TutorViewModel } from '../viewmodel/TutorViewModel';

interface LessonEditParams {
  studentId: number;
  lessonId?: number;
}

function today(): string {
  const date = new Date();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  return `${date.getFullYear()}-${month}-${day}`;
}

@Entry
@Component
struct LessonEdit {
  @State student: StudentSummary | null = null;
  @State date: string = today();
  @State durationMinutes: string = '60';
  @State amountYuan: string = '';
  @State deduction: string = '1';
  @State content: string = '';
  @State mastery: string = '基本掌握';
  @State weakPoints: string = '需要继续练习';
  @State note: string = '';
  @State loading: boolean = true;
  @State saving: boolean = false;
  @State saved: boolean = false;
  @State error: string = '';
  private studentId: number = 0;
  private lessonId: number = 0;
  private requestId: string = `${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
  private viewModel: TutorViewModel = new TutorViewModel(getContext(this));

  aboutToAppear(): void {
    const params = router.getParams() as LessonEditParams;
    this.studentId = params.studentId;
    this.lessonId = params.lessonId ?? 0;
    this.load();
  }

  build() {
    Column() {
      Row() {
        Button('返回')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor('#175CD3')
          .onClick(() => router.back())
        Text(this.lessonId > 0 ? '编辑课程' : '记一节课')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button(this.saved ? '已保存' : this.saving ? '保存中…' : '保存')
          .id('saveLesson')
          .type(ButtonType.Normal)
          .enabled(!this.loading && !this.saving && !this.saved)
          .onClick(() => this.save())
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      if (this.error.length > 0) {
        Text(this.error)
          .id('lessonEditError')
          .width('100%')
          .fontColor('#D92D20')
      }
      Scroll() {
        Column({ space: 10 }) {
          if (this.student !== null) {
            Text(`${this.student.nickname} · ${this.student.subject}`)
              .id('lessonStudent')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .width('100%')
            Text('上课日期')
              .width('100%')
            TextInput({ text: this.date })
              .id('lessonDate')
              .height(42)
              .onChange((value: string) => this.date = value)
            Text('实际上课时长（分钟）')
              .width('100%')
            TextInput({ text: this.durationMinutes })
              .id('lessonDuration')
              .height(42)
              .onChange((value: string) => this.durationMinutes = value)
            if (this.student.billingMode === 'POSTPAID') {
              Text('本次金额（元）')
                .width('100%')
              TextInput({ text: this.amountYuan })
                .id('lessonAmount')
                .height(42)
                .onChange((value: string) => this.amountYuan = value)
            } else {
              Text('本次扣课数量')
                .width('100%')
              TextInput({ text: this.deduction })
                .id('lessonDeduction')
                .height(42)
                .onChange((value: string) => this.deduction = value)
            }
            Text('课程内容')
              .width('100%')
            TextInput({ placeholder: '今天讲了什么', text: this.content })
              .id('lessonContent')
              .height(44)
              .onChange((value: string) => this.content = value)
            Text('掌握情况')
              .width('100%')
            TextInput({ text: this.mastery })
              .id('lessonMastery')
              .height(44)
              .onChange((value: string) => this.mastery = value)
            Text('薄弱点')
              .width('100%')
            TextInput({ text: this.weakPoints })
              .id('lessonWeakPoints')
              .height(44)
              .onChange((value: string) => this.weakPoints = value)
            Text('备注（可选）')
              .width('100%')
            TextInput({ placeholder: '其他需要记录的信息', text: this.note })
              .id('lessonNote')
              .height(44)
              .onChange((value: string) => this.note = value)
          }
        }
        .width('100%')
        .padding({ left: 4, right: 4, bottom: 20 })
      }
      .id('lessonFormScroll')
      .width('100%')
      .layoutWeight(1)
    }
    .id('lessonEditPage')
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, bottom: 12 })
    .backgroundColor('#F5F7FA')
  }

  private async load(): Promise<void> {
    this.loading = true;
    try {
      await this.viewModel.loadStudent(this.studentId);
      this.student = this.viewModel.currentStudent;
      if (this.lessonId > 0) {
        await this.viewModel.loadLesson(this.studentId, this.lessonId);
        const lesson = this.viewModel.currentLesson;
        if (lesson !== null) {
          this.requestId = lesson.requestId;
          this.date = lesson.date;
          this.durationMinutes = lesson.durationMinutes.toString();
          this.amountYuan = lesson.amountFen === null ? '' : TutorViewModel.formatFen(lesson.amountFen);
          this.deduction = lesson.deduction === null ? '1' : lesson.deduction.toString();
          this.content = lesson.content;
          this.mastery = lesson.mastery;
          this.weakPoints = lesson.weakPoints;
          this.note = lesson.note;
        }
      } else if (this.student !== null && this.student.billingMode === 'POSTPAID') {
        this.amountYuan = TutorViewModel.formatFen(calculateAmountFen(this.student.priceUnit,
          this.student.unitPriceFen, 60));
      }
      this.error = '';
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    } finally {
      this.loading = false;
    }
  }

  private async save(): Promise<void> {
    if (this.loading || this.saving || this.saved || this.student === null) {
      return;
    }
    this.getUIContext().getFocusController().clearFocus();
    this.saving = true;
    this.error = '';
    try {
      const input: LessonInput = {
        studentId: this.studentId,
        requestId: this.requestId,
        date: this.date,
        durationMinutes: Number(this.durationMinutes),
        amountFen: this.student.billingMode === 'POSTPAID' ? TutorViewModel.yuanToFen(this.amountYuan) : null,
        deduction: this.student.billingMode === 'PREPAID' ? Number(this.deduction) : null,
        content: this.content,
        mastery: this.mastery,
        weakPoints: this.weakPoints,
        note: this.note
      };
      if (this.lessonId > 0) {
        await this.viewModel.updateLesson(this.lessonId, input);
        this.saved = true;
        router.back();
      } else {
        const lessonId = await this.viewModel.saveLesson(input);
        this.saved = true;
        await router.replaceUrl({
          url: 'pages/Feedback',
          params: { studentId: this.studentId, lessonId: lessonId }
        });
      }
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    } finally {
      this.saving = false;
    }
  }
}
