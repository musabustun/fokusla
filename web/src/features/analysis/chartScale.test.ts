import { describe, expect, it } from 'vitest'
import { netDomain, PAD_X, PAD_Y, PLOT, scaleX, scaleY } from './chartScale'

describe('netDomain', () => {
  it.each([
    [[], { min: 0, max: 1 }],
    [[0, 0], { min: 0, max: 1 }],
    [[5, 12.5], { min: 0, max: 12.5 }],
    [[-2, 8], { min: -2, max: 8 }],
    [[-3, -1], { min: -3, max: 0 }],
  ])('%o → %o', (nets, expected) => {
    expect(netDomain(nets)).toEqual(expected)
  })
})

describe('scaleX', () => {
  it.each([
    [0, 1, PLOT / 2],
    [0, 2, PAD_X],
    [1, 2, PLOT - PAD_X],
    [1, 3, PLOT / 2],
  ])('index %s / %s → %s', (index, count, expected) => {
    expect(scaleX(index, count)).toBeCloseTo(expected)
  })
})

describe('scaleY', () => {
  const domain = { min: -2, max: 8 }
  it.each([
    [8, PAD_Y],
    [-2, PLOT - PAD_Y],
    [3, PLOT / 2],
  ])('%s → %s', (value, expected) => {
    expect(scaleY(value, domain)).toBeCloseTo(expected)
  })
})
