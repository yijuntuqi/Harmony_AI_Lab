import { router } from '@kit.ArkUI';
import { formatParentFeedback } from '../domain/FeedbackFormatter';
import { TutorViewModel } from '../viewmodel/TutorViewModel';

interface FeedbackParams {
  studentId: number;
  lessonId: number;
}

@Entry
@Component
struct Feedback {
  @State feedback: string = '';
  @State loading: boolean = true;
  @State copying: boolean = false;
  @State copied: boolean = false;
  @State error: string = '';
  private studentId: number = 0;
  private lessonId: number = 0;
  private viewModel: TutorViewModel = new TutorViewModel(getContext(this));

  aboutToAppear(): void {
    const params = router.getParams() as FeedbackParams;
    this.studentId = params.studentId;
    this.lessonId = params.lessonId;
    this.load();
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Button('返回')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor('#175CD3')
          .onClick(() => router.back())
        Text('家长反馈')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button(this.copying ? '复制中…' : '保存并复制')
          .id('copyFeedback')
          .type(ButtonType.Normal)
          .enabled(!this.loading && !this.copying)
          .onClick(() => this.copy())
      }
      .width('100%')
      Text('可编辑反馈文字，复制后自行粘贴到微信发送')
        .fontSize(14)
        .fontColor('#667085')
        .width('100%')
      TextArea({ text: this.feedback })
        .id('feedbackText')
        .width('100%')
        .height(360)
        .fontSize(16)
        .onChange((value: string) => {
          this.feedback = value;
          this.copied = false;
        })
      if (this.copied) {
        Text('已复制，可粘贴到微信')
          .id('copiedFeedback')
          .fontColor('#067647')
      }
      if (this.error.length > 0) {
        Text(this.error)
          .id('feedbackError')
          .fontColor('#D92D20')
      }
    }
    .id('feedbackPage')
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#F5F7FA')
  }

  private async load(): Promise<void> {
    this.loading = true;
    try {
      await this.viewModel.loadStudent(this.studentId);
      await this.viewModel.loadLesson(this.studentId, this.lessonId);
      const saved = await this.viewModel.getFeedback(this.lessonId);
      if (saved !== null) {
        this.feedback = saved;
      } else if (this.viewModel.currentStudent !== null && this.viewModel.currentLesson !== null) {
        this.feedback = formatParentFeedback(this.viewModel.currentStudent.nickname, this.viewModel.currentLesson);
      }
      this.error = '';
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    } finally {
      this.loading = false;
    }
  }

  private async copy(): Promise<void> {
    if (this.copying || this.loading) {
      return;
    }
    this.getUIContext().getFocusController().clearFocus();
    this.copying = true;
    this.error = '';
    try {
      await this.viewModel.saveFeedback(this.lessonId, this.feedback);
      await this.viewModel.copyFeedback(this.feedback);
      this.copied = true;
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    } finally {
      this.copying = false;
    }
  }
}
