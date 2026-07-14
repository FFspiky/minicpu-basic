#include <stdarg.h>

typedef unsigned int u32;

#define UART_DATA   (*(volatile u32 *)0xbfafff10u)
#define UART_STATUS (*(volatile u32 *)0xbfafff14u)
#define UART_TX_READY (1u << 8)

static u32 uart_status_stable(void)
{
    (void)UART_STATUS;
    return UART_STATUS;
}

static void uart_putc(char value)
{
    /* CONFREG queues writes in its TX FIFO.  BUSY edge polling can miss a
       registered transition and strand the application after VGA switches
       to RUNNING, so only wait for confirmed FIFO space before enqueueing. */
    while (!(uart_status_stable() & UART_TX_READY)) {}
    UART_DATA = (unsigned char)value;
}

int putchar(int value)
{
    if (value == '\n') uart_putc('\r');
    uart_putc((char)value);
    return value;
}

int puts(const char *text)
{
    while (*text) putchar(*text++);
    putchar('\n');
    return 0;
}

static int print_unsigned(u32 value, u32 radix, int uppercase)
{
    char buffer[32];
    int count = 0;
    int written = 0;
    const char *digits = uppercase ? "0123456789ABCDEF" : "0123456789abcdef";

    do {
        buffer[count++] = digits[value % radix];
        value /= radix;
    } while (value);
    while (count) {
        putchar(buffer[--count]);
        written++;
    }
    return written;
}

int print_int(int value)
{
    int written = 0;
    u32 magnitude;
    if (value < 0) {
        putchar('-');
        written++;
        magnitude = 0u - (u32)value;
    } else {
        magnitude = (u32)value;
    }
    return written + print_unsigned(magnitude, 10u, 0);
}

int printf(const char *format, ...)
{
    va_list arguments;
    int written = 0;
    va_start(arguments, format);
    while (*format) {
        if (*format != '%') {
            putchar(*format++);
            written++;
            continue;
        }
        format++;
        if (*format == '%') {
            putchar('%');
            written++;
        } else if (*format == 'd') {
            int value = va_arg(arguments, int);
            int count = print_int(value);
            written += count;
        } else if (*format == 'u') {
            written += print_unsigned(va_arg(arguments, u32), 10u, 0);
        } else if (*format == 'x' || *format == 'X') {
            int upper = (*format == 'X');
            written += print_unsigned(va_arg(arguments, u32), 16u, upper);
        } else if (*format == 'c') {
            putchar(va_arg(arguments, int));
            written++;
        } else if (*format == 's') {
            const char *text = va_arg(arguments, const char *);
            while (*text) {
                putchar(*text++);
                written++;
            }
        } else {
            putchar('%');
            putchar(*format);
            written += 2;
        }
        if (*format) format++;
    }
    va_end(arguments);
    return written;
}

void la32_program_exit(int status)
{
    printf("\n[program exited: %d]\n", status);
    uart_putc(4);
    for (;;) {}
}
