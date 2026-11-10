import { pasteboard } from '@kit.BasicServicesKit';

export class Clipboard {
  static async copyText(text: string): Promise<void> {
    const board = pasteboard.getSystemPasteboard();
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    await board.setData(data);
  }
}
