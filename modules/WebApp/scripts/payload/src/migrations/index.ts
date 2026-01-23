import * as migration_20260123_initial from './20260123_initial'

export const migrations = [
  {
    name: '20260123_initial',
    up: migration_20260123_initial.up,
    down: migration_20260123_initial.down,
  },
]
