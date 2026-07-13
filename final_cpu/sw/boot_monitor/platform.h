#ifndef BOOT_PLATFORM_H
#define BOOT_PLATFORM_H

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;

#define MMIO32(a) (*(volatile u32 *)(a))
#define UART_DATA       0xbfafff10u
#define UART_STATUS     0xbfafff14u
#define UART_CTRL       0xbfafff18u
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

static inline void uart_putc(u8 value)
{
    while (!(MMIO32(UART_STATUS) & (1u << 8))) {}
    MMIO32(UART_DATA) = value;
}

static inline u8 uart_getc(void)
{
    while (!(MMIO32(UART_STATUS) & 1u)) {}
    return (u8)MMIO32(UART_DATA);
}

static inline int uart_available(void) { return (MMIO32(UART_STATUS) & 1u) != 0; }

#endif
