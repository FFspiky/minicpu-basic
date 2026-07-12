#include "racing_game_mmio.h"

#ifdef GAME_SIM_FAST
#define TICK_60HZ              1000u
#else
#define TICK_60HZ              1666667u
#endif
#define SCREEN_X_Q8            (799u << 8)
#define BASE_SPEED_Q8          (3u << 8)
#define ACCEL_BOOST_Q8         (1u << 8)
#define SPEED_RAMP_Q8          2u
#define CAR_STEP_Q8            (12u << 8)
#define CAR_X0                 100u
#define CAR_X1                 180u
#define CAR_HEIGHT             60u
#define OBS_WIDTH              44u
#define OBS_HEIGHT             44u
#define BONUS_WIDTH            36u
#define BONUS_HEIGHT           36u
#define GAME_WAIT              0u
#define GAME_RUN               1u
#define GAME_PAUSE_STATE       2u
#define GAME_OVER_STATE        3u

struct moving_object
{
    unsigned int lane;
    unsigned int x_q8;
    unsigned int active;
};

static unsigned int rng_state = 0x9e3779b9u;

static unsigned int rng_next(void)
{
    unsigned int x = rng_state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    rng_state = x ? x : 0x6d2b79f5u;
    return rng_state;
}

static unsigned int random_lane(void)
{
    unsigned int lane;
    do
    {
        lane = rng_next() & 3u;
    }
    while (lane == 3u);
    return lane;
}

static unsigned int lane_y(unsigned int lane)
{
    if (lane == 0u)
    {
        return 50u;
    }
    if (lane == 1u)
    {
        return 210u;
    }
    return 370u;
}

static unsigned int level_deadline_ticks(unsigned int level)
{
#ifdef GAME_SIM_FAST
    static const unsigned short deadlines[16] = {
        4u, 8u, 12u, 16u,
        20u, 24u, 28u, 32u,
        36u, 40u, 44u, 48u,
        52u, 56u, 60u, 64u
    };
#else
    static const unsigned short deadlines[16] = {
        240u, 480u, 720u, 960u,
        1260u, 1560u, 1920u, 2280u,
        2700u, 3120u, 3600u, 4500u,
        5700u, 7200u, 8880u, 10800u
    };
#endif
    return deadlines[level & 15u];
}

static unsigned int level_leds(unsigned int level)
{
    if (level == 0u)
    {
        return 0u;
    }
    if (level >= 16u)
    {
        return 0xffffu;
    }
    return (0xffffu << (16u - level)) & 0xffffu;
}

static unsigned int level_target_speed_q8(unsigned int level)
{
    static const unsigned short target_speed[17] = {
        768u, 896u, 1024u, 1152u, 1280u,
        1408u, 1536u, 1664u, 1792u, 1920u,
        2048u, 2304u, 2560u, 2816u, 3072u,
        3328u, 3584u
    };
    return target_speed[(level > 16u) ? 16u : level];
}

static unsigned int next_spawn_gap_q8(unsigned int level)
{
    unsigned int min_gap = 320u - (level << 3);
    unsigned int span = 127u - (level << 1);
    return (min_gap + (rng_next() % (span + 1u))) << 8;
}

static unsigned int next_bonus_ticks(void)
{
    unsigned int spread = rng_next() & 0xffu;
    return 360u + spread - (spread >> 4);
}

static unsigned int bcd_add(unsigned int value, unsigned int add)
{
    unsigned int result = 0u;
    unsigned int carry = 0u;
    unsigned int shift;

    for (shift = 0u; shift < 32u; shift += 4u)
    {
        unsigned int digit = ((value >> shift) & 0xfu) +
                             ((add >> shift) & 0xfu) + carry;
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

static unsigned int object_x(const struct moving_object *obj)
{
    unsigned int x = obj->x_q8 >> 8;
    return (x > 799u) ? 799u : x;
}

static unsigned int obstacle_hits_car(const struct moving_object *obs,
                                      unsigned int car_y_q8)
{
    unsigned int obs_x;
    unsigned int obs_y;
    unsigned int car_y;

    if (!obs->active)
    {
        return 0u;
    }

    obs_x = object_x(obs);
    obs_y = lane_y(obs->lane) + 8u;
    car_y = car_y_q8 >> 8;
    return (obs_x < CAR_X1) && (obs_x + OBS_WIDTH > CAR_X0) &&
           (car_y < obs_y + OBS_HEIGHT) && (car_y + CAR_HEIGHT > obs_y);
}

static unsigned int bonus_hits_car(const struct moving_object *bonus,
                                   unsigned int car_y_q8)
{
    unsigned int bonus_x;
    unsigned int bonus_y;
    unsigned int car_y;

    if (!bonus->active)
    {
        return 0u;
    }

    bonus_x = object_x(bonus);
    bonus_y = lane_y(bonus->lane) + 12u;
    car_y = car_y_q8 >> 8;
    return (bonus_x < CAR_X1) && (bonus_x + BONUS_WIDTH > CAR_X0) &&
           (car_y < bonus_y + BONUS_HEIGHT) && (car_y + CAR_HEIGHT > bonus_y);
}

static void publish_state(unsigned int car_lane,
                          unsigned int car_y_q8,
                          const struct moving_object obs[3],
                          const struct moving_object *bonus,
                          unsigned int flags,
                          unsigned int level,
                          unsigned int score,
                          unsigned int score_bcd,
                          unsigned int speed_q8,
                          unsigned int frame)
{
    MMIO32(GAME_CAR)   = pack_car(car_lane, car_y_q8 >> 8);
    MMIO32(GAME_OBS)   = pack_obj(obs[0].lane, object_x(&obs[0]), obs[0].active);
    MMIO32(GAME_OBS1)  = pack_obj(obs[1].lane, object_x(&obs[1]), obs[1].active);
    MMIO32(GAME_OBS2)  = pack_obj(obs[2].lane, object_x(&obs[2]), obs[2].active);
    MMIO32(GAME_BONUS) = pack_obj(bonus->lane, object_x(bonus), bonus->active);
    MMIO32(GAME_FLAGS) = flags |
                         ((level & 0x1fu) << GAME_LEVEL_SHIFT);
    MMIO32(GAME_SCORE) = ((speed_q8 & 0xffffu) << 16) | (score & 0xffffu);
    MMIO32(NUM_DATA)   = score_bcd;
    MMIO32(GAME_COMMIT) = frame;
}

int main(void)
{
    struct moving_object obs[3];
    struct moving_object bonus;
    unsigned int state = GAME_WAIT;
    unsigned int car_lane = 1u;
    unsigned int car_y_q8 = lane_y(1u) << 8;
    unsigned int level = 0u;
    unsigned int current_speed_q8 = BASE_SPEED_Q8;
    unsigned int score = 0u;
    unsigned int score_bcd = 0u;
    unsigned int frame = 0u;
    unsigned int last_timer = MMIO32(TIMER);
    unsigned int prev_keys = MMIO32(BTN_KEY) & 0xffffu;
    unsigned int start_armed = (prev_keys == 0u);
    unsigned int second_ticks = 0u;
    unsigned int active_ticks = 0u;
    unsigned int spawn_gap_q8 = 0u;
    unsigned int bonus_ticks = 0u;
    unsigned int last_spawn_lane = 3u;
    unsigned int lane_repeat = 0u;
    unsigned int i;

    for (i = 0u; i < 3u; i++)
    {
        obs[i].lane = i;
        obs[i].x_q8 = SCREEN_X_Q8;
        obs[i].active = 0u;
    }
    bonus.lane = 1u;
    bonus.x_q8 = SCREEN_X_Q8;
    bonus.active = 0u;

    MMIO32(LED_DATA) = 0u;
    publish_state(car_lane, car_y_q8, obs, &bonus,
                  GAME_ENABLE | GAME_BG_EN | GAME_BL_EN | GAME_WAITING,
                  level, score, score_bcd, current_speed_q8, frame++);

    for (;;)
    {
        unsigned int now = MMIO32(TIMER);
        unsigned int keys = MMIO32(BTN_KEY) & 0xffffu;
        unsigned int key_edge = keys & ~prev_keys;
        prev_keys = keys;

        if (keys == 0u)
        {
            start_armed = 1u;
        }
        if (start_armed &&
            ((state == GAME_WAIT && key_edge != 0u) ||
             (state != GAME_WAIT && (key_edge & BTN_RESTART) != 0u)))
        {
            rng_state ^= now ^ (keys << 16) ^ frame ^ 0xa5a55a5au;
            if (rng_state == 0u)
            {
                rng_state = 0x6d2b79f5u;
            }

            state = GAME_RUN;
            start_armed = 0u;
            car_lane = 1u;
            car_y_q8 = lane_y(1u) << 8;
            level = 0u;
            current_speed_q8 = BASE_SPEED_Q8;
            score = 0u;
            score_bcd = 0u;
            second_ticks = 0u;
            active_ticks = 0u;
            last_spawn_lane = 3u;
            lane_repeat = 0u;
            for (i = 0u; i < 3u; i++)
            {
                obs[i].lane = i;
                obs[i].x_q8 = SCREEN_X_Q8;
                obs[i].active = 0u;
            }
            obs[0].lane = random_lane();
            obs[0].active = 1u;
            last_spawn_lane = obs[0].lane;
            lane_repeat = 1u;
            spawn_gap_q8 = next_spawn_gap_q8(level);
            bonus.lane = 1u;
            bonus.x_q8 = SCREEN_X_Q8;
            bonus.active = 0u;
            bonus_ticks = next_bonus_ticks();
            MMIO32(LED_DATA) = 0u;
            publish_state(car_lane, car_y_q8, obs, &bonus,
                          GAME_ENABLE | GAME_BG_EN | GAME_BL_EN,
                          level, score, score_bcd, current_speed_q8, frame++);
            last_timer = now;
            continue;
        }
        if (state == GAME_RUN && (key_edge & BTN_DOWN) != 0u)
        {
            state = GAME_PAUSE_STATE;
            publish_state(car_lane, car_y_q8, obs, &bonus,
                          GAME_ENABLE | GAME_BG_EN | GAME_BL_EN | GAME_PAUSED,
                          level, score, score_bcd, current_speed_q8, frame++);
            continue;
        }
        else if (state == GAME_PAUSE_STATE && (key_edge & BTN_DOWN) != 0u)
        {
            state = GAME_RUN;
            last_timer = now;
            publish_state(car_lane, car_y_q8, obs, &bonus,
                          GAME_ENABLE | GAME_BG_EN | GAME_BL_EN,
                          level, score, score_bcd, current_speed_q8, frame++);
            continue;
        }

        if (state != GAME_RUN)
        {
            continue;
        }

        if ((key_edge & BTN_LEFT) != 0u && car_lane > 0u)
        {
            car_lane--;
        }
        if ((key_edge & BTN_RIGHT) != 0u && car_lane < 2u)
        {
            car_lane++;
        }

        if ((unsigned int)(now - last_timer) >= TICK_60HZ)
        {
            unsigned int target_speed_q8 = level_target_speed_q8(level);
            unsigned int move_speed_q8;
            unsigned int target_y_q8 = lane_y(car_lane) << 8;
            unsigned int active_count = 0u;
            unsigned int active_limit = (level < 4u) ? 2u : 3u;

            last_timer += TICK_60HZ;
            if (current_speed_q8 < target_speed_q8)
            {
                unsigned int delta = target_speed_q8 - current_speed_q8;
                current_speed_q8 += (delta > SPEED_RAMP_Q8) ? SPEED_RAMP_Q8 : delta;
            }
            else if (current_speed_q8 > target_speed_q8)
            {
                unsigned int delta = current_speed_q8 - target_speed_q8;
                current_speed_q8 -= (delta > SPEED_RAMP_Q8) ? SPEED_RAMP_Q8 : delta;
            }
            move_speed_q8 = current_speed_q8 + (((keys & BTN_UP) != 0u) ? ACCEL_BOOST_Q8 : 0u);

            if (car_y_q8 < target_y_q8)
            {
                unsigned int delta = target_y_q8 - car_y_q8;
                car_y_q8 += (delta > CAR_STEP_Q8) ? CAR_STEP_Q8 : delta;
            }
            else if (car_y_q8 > target_y_q8)
            {
                unsigned int delta = car_y_q8 - target_y_q8;
                car_y_q8 -= (delta > CAR_STEP_Q8) ? CAR_STEP_Q8 : delta;
            }

            for (i = 0u; i < 3u; i++)
            {
                if (obs[i].active)
                {
                    if (obs[i].x_q8 > move_speed_q8)
                    {
                        obs[i].x_q8 -= move_speed_q8;
                        active_count++;
                    }
                    else
                    {
                        obs[i].active = 0u;
                        obs[i].x_q8 = SCREEN_X_Q8;
                    }
                }
            }

            if (spawn_gap_q8 > move_speed_q8)
            {
                spawn_gap_q8 -= move_speed_q8;
            }
            else if (active_count < active_limit)
            {
                for (i = 0u; i < 3u; i++)
                {
                    if (!obs[i].active)
                    {
                        unsigned int lane = random_lane();
                        if (lane == last_spawn_lane && lane_repeat >= 2u)
                        {
                            lane++;
                            if (lane >= 3u)
                            {
                                lane = 0u;
                            }
                        }
                        if (lane == last_spawn_lane)
                        {
                            lane_repeat++;
                        }
                        else
                        {
                            last_spawn_lane = lane;
                            lane_repeat = 1u;
                        }
                        obs[i].lane = lane;
                        obs[i].x_q8 = SCREEN_X_Q8;
                        obs[i].active = 1u;
                        spawn_gap_q8 = next_spawn_gap_q8(level);
                        break;
                    }
                }
            }
            else
            {
                spawn_gap_q8 = 0u;
            }

            if (bonus.active)
            {
                if (bonus.x_q8 > move_speed_q8)
                {
                    bonus.x_q8 -= move_speed_q8;
                }
                else
                {
                    bonus.active = 0u;
                    bonus.x_q8 = SCREEN_X_Q8;
                    bonus_ticks = next_bonus_ticks();
                }
            }
            else if (bonus_ticks != 0u)
            {
                bonus_ticks--;
            }
            else
            {
                unsigned int blocked = 0u;
                unsigned int lane;
                for (i = 0u; i < 3u; i++)
                {
                    if (obs[i].active && object_x(&obs[i]) > 639u)
                    {
                        blocked |= 1u << obs[i].lane;
                    }
                }
                lane = random_lane();
                if ((blocked & (1u << lane)) != 0u)
                {
                    lane++;
                    if (lane >= 3u)
                    {
                        lane = 0u;
                    }
                }
                if ((blocked & (1u << lane)) == 0u)
                {
                    bonus.lane = lane;
                    bonus.x_q8 = SCREEN_X_Q8;
                    bonus.active = 1u;
                }
                else
                {
                    bonus_ticks = 60u;
                }
            }

            for (i = 0u; i < 3u; i++)
            {
                if (obstacle_hits_car(&obs[i], car_y_q8))
                {
                    state = GAME_OVER_STATE;
                }
            }
            if (bonus_hits_car(&bonus, car_y_q8))
            {
                bonus.active = 0u;
                bonus.x_q8 = SCREEN_X_Q8;
                bonus_ticks = next_bonus_ticks();
                score += 50u;
                score_bcd = bcd_add(score_bcd, 0x50u);
            }

            second_ticks++;
            active_ticks++;
            if (second_ticks >= 60u)
            {
                second_ticks = 0u;
                score += 10u;
                score_bcd = bcd_add(score_bcd, 0x10u);
            }

            if (level < 16u && active_ticks >= level_deadline_ticks(level))
            {
                level++;
                MMIO32(LED_DATA) = level_leds(level);
            }

            if (state == GAME_OVER_STATE)
            {
                start_armed = 0u;
                publish_state(car_lane, car_y_q8, obs, &bonus,
                              GAME_ENABLE | GAME_BG_EN | GAME_BL_EN | GAME_OVER,
                              level, score, score_bcd, move_speed_q8, frame++);
            }
            else
            {
                publish_state(car_lane, car_y_q8, obs, &bonus,
                              GAME_ENABLE | GAME_BG_EN | GAME_BL_EN,
                              level, score, score_bcd, move_speed_q8, frame++);
            }
        }
    }
}
