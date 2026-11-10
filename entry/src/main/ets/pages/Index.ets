import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  build() {
    Column({ space: 20 }) {
      Text('课后记')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
      Text('本地记录学生、课时与账目')
        .fontSize(16)
        .fontColor('#667085')
      Button('记一节课')
        .id('homeLesson')
        .width('100%')
        .height(52)
        .type(ButtonType.Normal)
        .borderRadius(12)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Students', params: { selectForLesson: true } });
        })
      Button('学生与账目')
        .id('homeStudents')
        .width('100%')
        .height(52)
        .type(ButtonType.Normal)
        .borderRadius(12)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Students' });
        })
      Button('全部记录')
        .id('homeRecords')
        .width('100%')
        .height(52)
        .type(ButtonType.Normal)
        .borderRadius(12)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Records' });
        })
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F7FA')
  }
}
