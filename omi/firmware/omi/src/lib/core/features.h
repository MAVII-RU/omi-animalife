#ifndef FEATURES_H
#define FEATURES_H

#include <stdint.h>

/**
 * @brief Defines the bitmask for available Omi features.
 */
typedef enum {
    ANIMALIFE_FEATURE_SPEAKER = (1 << 0),
    ANIMALIFE_FEATURE_ACCELEROMETER = (1 << 1),
    ANIMALIFE_FEATURE_BUTTON = (1 << 2),
    ANIMALIFE_FEATURE_BATTERY = (1 << 3),
    ANIMALIFE_FEATURE_USB = (1 << 4),
    ANIMALIFE_FEATURE_HAPTIC = (1 << 5),
    ANIMALIFE_FEATURE_OFFLINE_STORAGE = (1 << 6),
    ANIMALIFE_FEATURE_LED_DIMMING = (1 << 7),
    ANIMALIFE_FEATURE_MIC_GAIN = (1 << 8),
} animalife_feature_t;

#endif // FEATURES_H
