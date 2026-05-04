/**
 * Multiple.h
 * RK_MultipleButton — radio-group (single select)
 * RK_MultipleSelect  — checkbox-group (multi select)
 */

#ifndef RADIOKIT_WIDGET_MULTIPLE_H
#define RADIOKIT_WIDGET_MULTIPLE_H

#include "Widget.h"
#include <initializer_list>

struct RK_Item {
  const char *label = nullptr;
  const char *icon = nullptr;
  uint8_t pos = 255;
};

struct RK_MultipleProps {
  const char *label = nullptr;
  const char *icon = nullptr;
  uint8_t x = 0;
  uint8_t y = 0;
  int16_t rotation = 0; ///< Rotation in degrees.
  uint8_t height = 10;
  uint8_t width = 0;
  uint8_t style = 0;
  uint8_t variant = 0;
  uint8_t value = 0;
  std::initializer_list<RK_Item> items = {};
};

class RadioKit_Multiple : public RadioKit_Widget {
public:
    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    uint16_t serializeStrings(uint8_t* buf) const override;
    void serializeInput(uint8_t* buf)          const override;
    void serializeOutput(uint8_t*)           const override {}
    void deserializeInput(const uint8_t* buf)      override;

    uint8_t get()          const { return props.value; }
    bool    get(uint8_t i) const { return (props.value & (1 << i)) != 0; }
    void    clear();
    void    add(const RK_Item& item);
    void    remove(uint8_t index);
    void    setIcon(const char* val);

    RK_MultipleProps props;

protected:
    float defaultAspect() const override { return 1.0f; }
    RK_Item  _pool[RADIOKIT_MAX_ITEMS];
    uint8_t  _poolCount = 0;

    void _initFromProps(const RK_MultipleProps& p, uint8_t tid);
};

class RK_MultipleButton : public RadioKit_Multiple {
public:
    RK_MultipleButton(RK_MultipleProps p);
};

class RK_MultipleSelect : public RadioKit_Multiple {
public:
    RK_MultipleSelect(RK_MultipleProps p);
};

#endif // RADIOKIT_WIDGET_MULTIPLE_H
