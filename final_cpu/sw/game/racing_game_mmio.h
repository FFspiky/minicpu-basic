#ifndef RACING_GAME_MMIO_H
#define RACING_GAME_MMIO_H

#define MMIO32(addr) (*(volatile unsigned int *)(addr))

#define GAME_CAR       0xbfaf9000u
#define GAME_OBS       0xbfaf9010u
#define GAME_BONUS     0xbfaf9020u
#define GAME_FLAGS     0xbfaf9030u
#define GAME_SCORE     0xbfaf9040u
#define GAME_COMMIT    0xbfaf9050u
#define LCD_STATUS     0xbfaf9060u
#define BTN_KEY        0xbfaff070u
#define TIMER          0xbfafe000u

#define BTN_UP         0x0400u
#define BTN_LEFT       0x2000u
#define BTN_DOWN       0x4000u
#define BTN_RIGHT      0x8000u

#define GAME_ENABLE    0x00000001u
#define GAME_PAUSED    0x00000002u
#define GAME_OVER      0x00000004u
#define GAME_BG_EN     0x00000008u
#define GAME_BL_EN     0x00000010u

static inline unsigned int pack_obj(unsigned int lane, unsigned int x, unsigned int active)
{
    return ((active & 1u) << 31) | ((x & 0x0fffu) << 4) | (lane & 3u);
}

#endif
