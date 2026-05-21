#pragma once

#include <stdint.h>
#include <stdbool.h>

/*
 * AnimaLife On-Device Animal Sound Filter
 * Accumulates 1 second of audio, runs MFCC + tiny CNN classifier,
 * gates transmission if score < threshold.
 *
 * Place in mic_handler() AFTER aad_process_audio(), BEFORE codec_receive_pcm().
 */

/* Returns true if this 100ms chunk should be forwarded to the codec.
 * Internally accumulates chunks until 1 second is ready, then classifies.
 * All chunks within a confirmed 1-second animal window are forwarded.
 * Chunks in a rejected window are silently dropped.
 */
bool animal_filter_process(const int16_t *buf, size_t samples);
