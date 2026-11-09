import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State lessonPlaceholder: string = '';

  build() {
    Column({ space: 20 }) {
      Text('课后记')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
      Text('本地记录学生、课时与账目')
        .fontSize(16)
        .fontColor('#667085')
      Button('记一节课')
        .id('homeLessonPlaceholder')
        .width('100%')
        .height(52)
        .onClick(() => {
          this.lessonPlaceholder = '记一节课功能将在后续提供';
        })
      Button('学生与账目')
        .id('homeStudents')
        .width('100%')
        .height(52)
        .type(ButtonType.Normal)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Students' });
        })
      if (this.lessonPlaceholder.length > 0) {
        Text(this.lessonPlaceholder)
          .id('lessonPlaceholderText')
          .fontColor('#667085')
      }
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F7FA')
  }
}
