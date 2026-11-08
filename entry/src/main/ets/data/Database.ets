import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'afterclass.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const SCHEMA: string[] = [
  `CREATE TABLE IF NOT EXISTS students (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nickname TEXT NOT NULL,
    subject TEXT NOT NULL,
    billing_mode TEXT NOT NULL CHECK (billing_mode IN ('POSTPAID', 'PREPAID')),
    price_unit TEXT NOT NULL CHECK (price_unit IN ('HOURLY', 'PER_LESSON')),
    unit_price_fen INTEGER NOT NULL,
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    date TEXT NOT NULL,
    amount_fen INTEGER NOT NULL,
    note TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS package_topups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    date TEXT NOT NULL,
    lessons INTEGER NOT NULL,
    note TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS lessons (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    request_id TEXT NOT NULL UNIQUE,
    date TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL,
    amount_fen INTEGER,
    deduction INTEGER,
    content TEXT NOT NULL,
    mastery TEXT NOT NULL,
    weak_points TEXT NOT NULL,
    note TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    deleted_at INTEGER
  )`,
  `CREATE TABLE IF NOT EXISTS feedbacks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lesson_id INTEGER NOT NULL UNIQUE REFERENCES lessons(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )`,
  'CREATE INDEX IF NOT EXISTS payments_student_id ON payments(student_id)',
  'CREATE INDEX IF NOT EXISTS package_topups_student_id ON package_topups(student_id)',
  'CREATE INDEX IF NOT EXISTS lessons_student_id ON lessons(student_id)'
];

export class Database {
  static async open(context: common.Context): Promise<relationalStore.RdbStore> {
    const store = await relationalStore.getRdbStore(context, STORE_CONFIG);
    await store.executeSql('PRAGMA foreign_keys = ON');
    for (const statement of SCHEMA) {
      await store.executeSql(statement);
    }
    const columns = await store.querySql('PRAGMA table_info(lessons)');
    let hasDeletedAt = false;
    while (columns.goToNextRow()) {
      if (columns.getString(1) === 'deleted_at') {
        hasDeletedAt = true;
      }
    }
    columns.close();
    if (!hasDeletedAt) {
      await store.executeSql('ALTER TABLE lessons ADD COLUMN deleted_at INTEGER');
    }
    return store;
  }
}
