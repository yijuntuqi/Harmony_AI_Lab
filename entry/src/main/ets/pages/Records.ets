import { router } from '@kit.ArkUI';
import { RecordEntry, TutorViewModel } from '../viewmodel/TutorViewModel';

@Entry
@Component
struct Records {
  @State records: RecordEntry[] = [];
  @State error: string = '';
  private viewModel: TutorViewModel = new TutorViewModel(getContext(this));

  onPageShow(): void {
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
        Text('全部记录')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('')
          .width(48)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      if (this.records.length === 0) {
        Text('还没有课后、收款或充值记录')
          .fontColor('#667085')
      } else {
        List({ space: 12 }) {
          ForEach(this.records, (entry: RecordEntry) => {
            ListItem() {
              Column({ space: 8 }) {
                Text(entry.title)
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                Text(entry.detail)
                  .fontColor('#475467')
                  .width('100%')
                if (entry.feedback !== null) {
                  Text(entry.feedback)
                    .fontSize(14)
                    .fontColor('#667085')
                    .width('100%')
                }
                if (entry.kind === 'LESSON') {
                  Row({ space: 12 }) {
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
              .padding(16)
              .borderRadius(12)
              .backgroundColor(Color.White)
            }
          }, (entry: RecordEntry) => `${entry.kind}-${entry.id}`)
        }
        .id('recordList')
        .width('100%')
        .layoutWeight(1)
      }
      if (this.error.length > 0) {
        Text(this.error)
          .fontColor('#D92D20')
      }
    }
    .id('recordsPage')
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, bottom: 20 })
    .backgroundColor('#F5F7FA')
  }

  private async load(): Promise<void> {
    try {
      await this.viewModel.loadRecords();
      this.records = this.viewModel.records;
      this.error = '';
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    }
  }

  private async deleteLesson(lessonId: number): Promise<void> {
    try {
      await this.viewModel.deleteLesson(lessonId);
      await this.load();
    } catch (error) {
      this.error = TutorViewModel.errorMessage(error as Object);
    }
  }
}
