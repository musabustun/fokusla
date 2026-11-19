import { toISODateTime, type BaseEntity, type EntityMap, type EntityName } from '@/domain'
import { DATA_EXPORT_FORMAT_VERSION, type DataExport, type LocalDataService } from '../localData'
import type { FokusDatabase } from './db'
import { isActive, type Clock } from './DexieRepository'

export class DexieLocalDataService implements LocalDataService {
  private readonly db: FokusDatabase
  private readonly now: Clock

  constructor(db: FokusDatabase, now: Clock) {
    this.db = db
    this.now = now
  }

  async exportAll(): Promise<DataExport> {
    const tables = this.db.tables
    const entries = await this.db.transaction('r', tables, () =>
      Promise.all(
        tables.map(async (table) => {
          const rows: BaseEntity[] = await table.toArray()
          return [table.name as EntityName, rows.filter(isActive)] as const
        }),
      ),
    )
    return {
      app: 'fokus',
      formatVersion: DATA_EXPORT_FORMAT_VERSION,
      exportedAt: toISODateTime(this.now()),
      entities: Object.fromEntries(entries) as { [K in EntityName]: EntityMap[K][] },
    }
  }

  async deleteAll(): Promise<void> {
    const tables = this.db.tables
    await this.db.transaction('rw', tables, () => Promise.all(tables.map((table) => table.clear())))
  }
}
