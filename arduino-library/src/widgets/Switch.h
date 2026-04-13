/**
 * Switch.h
 * Compatibility stub — RK_ToggleButton is the v2.0 replacement.
 * This file is kept so existing code that includes Switch.h still compiles.
 */
#pragma once
#include "Button.h"
// RK_ToggleButton replaces RadioKit_Switch.
// Define RadioKit_Switch as an alias for source-level compatibility.
using RadioKit_Switch = RK_ToggleButton;
