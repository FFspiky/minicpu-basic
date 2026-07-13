#ifndef BOOT_PLATFORM_H
#define BOOT_PLATFORM_H

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;

#define MMIO32(a) (*(volatile u32 *)(a))
#define UART_DATA       0xbfafff10u
#define UART_STATUS     0xbfafff14u
#define UART_CTRL       0xbfafff18u
#define TIMER_COUNTER   0xbfafe000u
#define SYSTEM_MODE     0xbfafff50u
#define DYNAMIC_END_PC  0xbfafff54u
#define ACTIVE_SLOT     0xbfafff58u
#define MENU_SELECTED   0xbfafff5cu
#define SLOT_VALID      0xbfafff60u
#define MENU_STATUS     0xbfafff64u
#define BTN_KEY         0xbfaff070u

#define NAND_CMD        0xbfafb000u
#define NAND_PAGE       0xbfafb004u
#define NAND_COLUMN     0xbfafb008u
#define NAND_LENGTH     0xbfafb00cu
#define NAND_STATUS     0xbfafb010u
#define NAND_ID0        0xbfafb014u
#define NAND_ID1        0xbfafb018u
#define NAND_BUFFER     0xbfafc000u

#define APP_START       0x1c010000u
#define APP_END         0x1c0f0000u
#define STACK_TOP       0x1c100000u
#define STACK_START     0x1c0f0000u

#define KEY_R           0x0200u
#define KEY_UP          0x0400u
#define KEY_ENTER       0x0800u
#define KEY_DOWN        0x4000u

#define UART_RX_VALID   (1u << 0)
#define UART_TX_READY   (1u << 8)
#define UART_TX_BUSY    (1u << 9)
#define UART_FRAME_ERR  (1u << 10)
#define UART_RX_OVERRUN (1u << 1)
#define UART_RX_ENABLE  (1u << 0)
#define UART_TX_ENABLE  (1u << 1)
#define UART_CLEAR_RX   (1u << 8)
#define UART_BYTE_TIMEOUT_TICKS 500000u /* 5 ms at the 100 MHz timer clock */

static inline u32 uart_status_stable(void)
{
    (void)MMIO32(UART_STATUS);
    return MMIO32(UART_STATUS);
}

static inline void uart_putc(u8 value)
{
    /*
     * TX_READY now describes space in the CONFREG transmit FIFO.  Waiting for
     * BUSY to rise and fall after every byte is both unnecessary and unsafe:
     * a stale registered BUSY sample can strand a long response forever.
     * Settle the registered status, then enqueue the byte.  The FIFO keeps
     * ordering while uart_tx shifts earlier bytes in the background.
     */
    while (!(uart_status_stable() & UART_TX_READY)) {}
    MMIO32(UART_DATA) = value;
}

static inline u8 uart_getc(void)
{
    /* The status register is returned through CONFREG's registered read
       path.  After popping one byte, a single read can still report the
       previous RX_VALID=1 and make the next receive consume an empty FIFO.
       Use the same settled sample as uart_available() for every byte. */
    while (!(uart_status_stable() & UART_RX_VALID)) {}
    return (u8)MMIO32(UART_DATA);
}

static inline int uart_getc_timeout(u8 *value, u32 timeout_ticks)
{
    u32 start = MMIO32(TIMER_COUNTER);
    while (!(uart_status_stable() & UART_RX_VALID))
        if ((u32)(MMIO32(TIMER_COUNTER) - start) >= timeout_ticks)
            return -1;
    *value = (u8)MMIO32(UART_DATA);
    return 0;
}

static inline void uart_clear_receive_errors(void)
{
    MMIO32(UART_STATUS) = UART_FRAME_ERR | UART_RX_OVERRUN;
}

static inline void uart_reset_receiver(void)
{
    MMIO32(UART_CTRL) = UART_CLEAR_RX | UART_TX_ENABLE | UART_RX_ENABLE;
    uart_clear_receive_errors();
}

static inline int uart_available(void)
{
    /* CONFREG MMIO reads return through a registered path.  A single status
       read can therefore retain RX_VALID from the byte just popped, causing
       the monitor to enter an empty receive and clear the following frame. */
    return (uart_status_stable() & UART_RX_VALID) != 0;
}

#endif
