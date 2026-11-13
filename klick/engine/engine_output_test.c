/* SPDX-License-Identifier: GPL-2.0-or-later
 * Licence of the program this interface drives (klick).
 * The choice of the output device, without playing anything: the engine opens the output of the system, moves to the same device
 * by its number, goes back to following the system, and refuses a device that does not exist. Needs an output device. */
#include "klick_engine.h"

#include <stdio.h>
#include <string.h>

static int failures = 0;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); ++failures; } } while (0)

int main(void)
{
    char error[256] = "";
    KlickEngine *e = klick_engine_create(0, 48000, error, sizeof(error));
    if (!e) { printf("no output device (%s): nothing to test\n", error); return 0; }

    uint32_t device = klick_engine_output_device(e);
    CHECK(device != 0);
    CHECK(klick_engine_follow_system_output(e, error, sizeof(error)) == 0);          /* still the system's */

    CHECK(klick_engine_set_output_device(e, device, error, sizeof(error)) == 1);      /* the same, named */
    CHECK(klick_engine_output_device(e) == device);
    CHECK(klick_engine_output_latency(e) > 0);

    CHECK(klick_engine_set_output_device(e, 0, error, sizeof(error)) == 1);           /* back to the system */
    CHECK(klick_engine_output_device(e) == device);

    CHECK(klick_engine_set_output_device(e, 0x7fffff00u, error, sizeof(error)) == 0); /* not a device */
    CHECK(strlen(error) > 0);
    CHECK(klick_engine_output_device(e) == device);                                   /* the one that played stays */

    klick_engine_destroy(e);
    printf(failures ? "FAILED: %d\n" : "OK: output device\n", failures);
    return failures ? 1 : 0;
}
