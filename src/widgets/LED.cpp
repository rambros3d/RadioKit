#include "LED.h"

RadioKit_LED::RadioKit_LED()
    : _color(LED_OFF)
{
    typeId = RADIOKIT_TYPE_LED;
}

void RadioKit_LED::serializeOutput(uint8_t* buf) const {
    buf[0] = (uint8_t)_color;
}
