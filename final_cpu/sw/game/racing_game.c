#include "racing_game_mmio.h"

#define OBS_X_START 799u
#define CAR_X_MIN   60u
#define CAR_X_MAX   160u
#define TICK_30HZ   3333333u
#define MAX_SPEED_LEVEL 10u

static unsigned int lfsr = 0xace1u;

static unsigned int rand2(void)
{
    unsigned int bit = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5)) & 1u;
    lfsr = (lfsr >> 1) | (bit << 15);
    return lfsr & 3u;
}

static unsigned int rand_lane(void)
{
    unsigned int lane = rand2();
    return (lane == 3u) ? 0u : lane;
}

static unsigned int bcd_add(unsigned int value, unsigned int add)
{
    unsigned int result = 0u;
    unsigned int carry = 0u;
    unsigned int shift;

    for (shift = 0u; shift < 32u; shift += 4u)
    {
        unsigned int digit = ((value >> shift) & 0xfu) + ((add >> shift) & 0xfu) + carry;
        if (digit >= 10u)
        {
            digit -= 10u;
            carry = 1u;
        }
        else
        {
            carry = 0u;
        }
        result |= (digit & 0xfu) << shift;
    }

    return result;
}

static void publish_state(unsigned int car_lane,
                          unsigned int obs_lane,
                          unsigned int obs_x,
                          unsigned int obs_active,
                          unsigned int bonus_lane,
                          unsigned int bonus_x,
                          unsigned int bonus_active,
                          unsigned int flags,
                          unsigned int score,
                          unsigned int score_bcd,
                          unsigned int speed_level,
                          unsigned int frame)
{
    MMIO32(GAME_CAR)    = car_lane & 3u;
    MMIO32(GAME_OBS)    = pack_obj(obs_lane, obs_x, obs_active);
    MMIO32(GAME_BONUS)  = pack_obj(bonus_lane, bonus_x, bonus_active);
    MMIO32(GAME_FLAGS)  = flags;
    MMIO32(GAME_SCORE)  = ((speed_level & 0xffffu) << 16) | (score & 0xffffu);
    MMIO32(NUM_DATA)    = score_bcd;
    MMIO32(GAME_COMMIT) = frame;
}

int main(void)
{
    unsigned int car_lane = 1u;
    unsigned int obs_lane = 0u;
    unsigned int obs_x = OBS_X_START;
    unsigned int bonus_lane = 1u;
    unsigned int bonus_x = OBS_X_START;
    unsigned int bonus_active = 0u;
    unsigned int paused = 0u;
    unsigned int over = 0u;
    unsigned int playing = 0u;
    unsigned int score = 0u;
    unsigned int score_bcd = 0u;
    unsigned int speed_level = 0u;
    unsigned int level_seconds = 0u;
    unsigned int frame = 0u;
    unsigned int last_timer = MMIO32(TIMER);
    unsigned int prev_keys = 0u;
    unsigned int sec_div = 0u;

    publish_state(car_lane, obs_lane, obs_x, 1u, bonus_lane, bonus_x,
                  bonus_active, GAME_ENABLE | GAME_BG_EN | GAME_BL_EN,
                  score, score_bcd, speed_level, frame++);

    for (;;)
    {
        unsigned int now = MMIO32(TIMER);
        unsigned int keys = MMIO32(BTN_KEY) & 0xffffu;
        unsigned int key_edge = keys & ~prev_keys;
        unsigned int flags = GAME_ENABLE | GAME_BG_EN | GAME_BL_EN;
        unsigned int accel = (keys & BTN_UP) != 0u;
        unsigned int speed = 6u + speed_level + (accel ? 4u : 0u);

        prev_keys = keys;

        if (key_edge != 0u && !playing)
        {
            playing = 1u;
            over = 0u;
            paused = 0u;
            score = 0u;
            score_bcd = 0u;
            speed_level = 0u;
            level_seconds = 0u;
            car_lane = 1u;
            obs_lane = rand_lane();
            obs_x = OBS_X_START;
            bonus_active = 0u;
        }

        if ((key_edge & BTN_DOWN) != 0u && playing && !over)
        {
            paused = !paused;
        }

        if ((key_edge & BTN_LEFT) != 0u && car_lane > 0u && playing && !over)
        {
            car_lane--;
        }
        if ((key_edge & BTN_RIGHT) != 0u && car_lane < 2u && playing && !over)
        {
            car_lane++;
        }

        if ((unsigned int)(now - last_timer) >= TICK_30HZ)
        {
            last_timer += TICK_30HZ;

            if (playing && !paused && !over)
            {
                if (obs_x > speed)
                {
                    obs_x -= speed;
                }
                else
                {
                    obs_x = OBS_X_START;
                    obs_lane = rand_lane();
                    if (!bonus_active && rand2() == 1u)
                    {
                        bonus_active = 1u;
                        bonus_lane = (obs_lane == 2u) ? 0u : (obs_lane + 1u);
                        bonus_x = OBS_X_START;
                    }
                }

                if (bonus_active)
                {
                    if (bonus_x > speed)
                    {
                        bonus_x -= speed;
                    }
                    else
                    {
                        bonus_active = 0u;
                    }
                }

                if (car_lane == obs_lane && obs_x > CAR_X_MIN && obs_x < CAR_X_MAX)
                {
                    over = 1u;
                }

                if (bonus_active && car_lane == bonus_lane &&
                    bonus_x > CAR_X_MIN && bonus_x < CAR_X_MAX)
                {
                    bonus_active = 0u;
                    score += 50u;
                    score_bcd = bcd_add(score_bcd, 0x50u);
                }

                sec_div++;
                if (sec_div >= 30u)
                {
                    sec_div = 0u;
                    score += 10u;
                    score_bcd = bcd_add(score_bcd, 0x10u);
                    level_seconds++;
                    if (level_seconds >= 3u && speed_level < MAX_SPEED_LEVEL)
                    {
                        level_seconds = 0u;
                        speed_level++;
                    }
                }
            }

            if (paused)
            {
                flags |= GAME_PAUSED;
            }
            if (over)
            {
                flags |= GAME_OVER;
            }

            publish_state(car_lane, obs_lane, obs_x, 1u, bonus_lane, bonus_x,
                          bonus_active, flags, score, score_bcd,
                          speed_level + (accel ? 1u : 0u), frame++);
        }
    }
}
