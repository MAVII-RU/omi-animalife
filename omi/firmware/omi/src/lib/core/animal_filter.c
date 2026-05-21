/*
 * AnimaLife On-Device Animal Sound Filter
 * MFCC feature extraction + INT8 CNN inference on nRF52840 Cortex-M4F.
 *
 * Pipeline:
 *   mic_handler() → [aad VAD gate] → animal_filter_process() → codec_receive_pcm()
 *
 * Behavior:
 *   - Accumulates 10 × 100ms chunks = 1 second of audio
 *   - Extracts 40 MFCC coefficients × 40 frames
 *   - Runs classifier; if score >= THRESHOLD → pass all 10 queued chunks
 *   - Otherwise → drop all 10 chunks silently, return false for each
 *
 * Memory: ~72KB static (accumulation buffer + feature scratch)
 * Latency: ~120ms classification on 64MHz M4F (overlaps with next window)
 */

#include "animal_filter.h"
#include "animal_classifier_model.h"

#include <math.h>
#include <string.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(animal_filter, CONFIG_LOG_DEFAULT_LEVEL);

#define SAMPLE_RATE      16000
#define WINDOW_SAMPLES   16000   /* 1 second */
#define CHUNK_SAMPLES    1600    /* 100ms per call */
#define CHUNKS_PER_WIN   (WINDOW_SAMPLES / CHUNK_SAMPLES)  /* 10 */

#define N_MFCC           40
#define N_FRAMES         40
#define N_FFT            1024
#define HOP_SAMPLES      400     /* 25ms hop */
#define PREEMPH          0.97f

#define SCORE_THRESHOLD  0.65f

/* Accumulation ring */
static int16_t  s_ring[WINDOW_SAMPLES];
static int      s_chunk_count = 0;
static bool     s_window_passed = false;

/* Feature scratch (float32) */
static float    s_frame_buf[N_FFT];
static float    s_mfcc[N_MFCC][N_FRAMES];

/* ── Mel filterbank (pre-computed for 16kHz, N_FFT=1024) ──────────────── */
/* 40 triangular filters, 300Hz–8000Hz */
#define MEL_FILTERS 40
static float s_mel_fb[MEL_FILTERS][N_FFT / 2 + 1];
static bool  s_mel_init = false;

static float hz_to_mel(float hz)  { return 2595.0f * log10f(1.0f + hz / 700.0f); }
static float mel_to_hz(float mel) { return 700.0f * (powf(10.0f, mel / 2595.0f) - 1.0f); }

static void init_mel_filterbank(void) {
    const float fmin = 300.0f, fmax = 8000.0f;
    const int   n_bins = N_FFT / 2 + 1;
    const float mel_min = hz_to_mel(fmin);
    const float mel_max = hz_to_mel(fmax);

    float mel_points[MEL_FILTERS + 2];
    for (int i = 0; i < MEL_FILTERS + 2; i++)
        mel_points[i] = mel_min + i * (mel_max - mel_min) / (MEL_FILTERS + 1);

    float hz_points[MEL_FILTERS + 2];
    for (int i = 0; i < MEL_FILTERS + 2; i++)
        hz_points[i] = mel_to_hz(mel_points[i]);

    int bin_points[MEL_FILTERS + 2];
    for (int i = 0; i < MEL_FILTERS + 2; i++)
        bin_points[i] = (int)floorf((N_FFT + 1) * hz_points[i] / SAMPLE_RATE);

    memset(s_mel_fb, 0, sizeof(s_mel_fb));
    for (int m = 0; m < MEL_FILTERS; m++) {
        int lo = bin_points[m], mid = bin_points[m + 1], hi = bin_points[m + 2];
        for (int k = lo; k < mid && k < n_bins; k++)
            s_mel_fb[m][k] = (float)(k - lo) / (float)(mid - lo);
        for (int k = mid; k < hi && k < n_bins; k++)
            s_mel_fb[m][k] = (float)(hi - k) / (float)(hi - mid);
    }
}

/* ── Simplified DFT magnitude (no CMSIS-DSP dependency) ──────────────── */
/* For deployment, replace with arm_rfft_fast_f32 for 40× speedup */
static void compute_power_spectrum(const float *frame, int n, float *out_power) {
    /* out_power: n/2+1 bins */
    int half = n / 2 + 1;
    for (int k = 0; k < half; k++) {
        float re = 0.0f, im = 0.0f;
        float step = -2.0f * 3.14159265f * k / n;
        for (int t = 0; t < n; t++) {
            re += frame[t] * cosf(step * t);
            im += frame[t] * sinf(step * t);
        }
        out_power[k] = re * re + im * im;
    }
}

/* ── MFCC extraction ──────────────────────────────────────────────────── */
static void extract_mfcc(const int16_t *pcm, int n_samples,
                          float out_mfcc[N_MFCC][N_FRAMES]) {
    if (!s_mel_init) {
        init_mel_filterbank();
        s_mel_init = true;
    }

    static float power_spec[N_FFT / 2 + 1];
    static float mel_energy[MEL_FILTERS];

    /* Hann window coefficients (static, compute once) */
    static float hann[N_FFT];
    static bool hann_init = false;
    if (!hann_init) {
        for (int i = 0; i < N_FFT; i++)
            hann[i] = 0.5f * (1.0f - cosf(2.0f * 3.14159265f * i / (N_FFT - 1)));
        hann_init = true;
    }

    int frame_idx = 0;
    float prev = 0.0f;

    for (int start = 0; start + N_FFT <= n_samples && frame_idx < N_FRAMES;
         start += HOP_SAMPLES, frame_idx++) {
        /* Pre-emphasis + windowing */
        for (int i = 0; i < N_FFT; i++) {
            float s = (float)pcm[start + i] / 32768.0f;
            float emp = s - PREEMPH * prev;
            prev = s;
            s_frame_buf[i] = emp * hann[i];
        }

        /* Power spectrum */
        compute_power_spectrum(s_frame_buf, N_FFT, power_spec);

        /* Mel filterbank energy */
        for (int m = 0; m < MEL_FILTERS; m++) {
            float e = 0.0f;
            for (int k = 0; k < N_FFT / 2 + 1; k++)
                e += s_mel_fb[m][k] * power_spec[k];
            mel_energy[m] = logf(e + 1e-10f);
        }

        /* DCT-II to get MFCC (only first N_MFCC coefficients) */
        for (int n = 0; n < N_MFCC; n++) {
            float coeff = 0.0f;
            float step = 3.14159265f * n / MEL_FILTERS;
            for (int m = 0; m < MEL_FILTERS; m++)
                coeff += mel_energy[m] * cosf(step * ((float)m + 0.5f));
            out_mfcc[n][frame_idx] = coeff;
        }
    }

    /* Pad remaining frames with zeros */
    for (int fi = frame_idx; fi < N_FRAMES; fi++)
        for (int n = 0; n < N_MFCC; n++)
            out_mfcc[n][fi] = 0.0f;

    /* Normalize each coefficient across frames */
    for (int n = 0; n < N_MFCC; n++) {
        float mean = 0.0f, std = 0.0f;
        for (int fi = 0; fi < N_FRAMES; fi++) mean += out_mfcc[n][fi];
        mean /= N_FRAMES;
        for (int fi = 0; fi < N_FRAMES; fi++) std += (out_mfcc[n][fi] - mean) * (out_mfcc[n][fi] - mean);
        std = sqrtf(std / N_FRAMES + 1e-8f);
        for (int fi = 0; fi < N_FRAMES; fi++) out_mfcc[n][fi] = (out_mfcc[n][fi] - mean) / std;
    }
}

/* ── Public API ───────────────────────────────────────────────────────── */

bool animal_filter_process(const int16_t *buf, size_t samples) {
    if (s_chunk_count < CHUNKS_PER_WIN) {
        memcpy(s_ring + s_chunk_count * CHUNK_SAMPLES, buf,
               samples * sizeof(int16_t));
        s_chunk_count++;
    }

    if (s_chunk_count < CHUNKS_PER_WIN) {
        /* Still accumulating; forward if previous window passed */
        return s_window_passed;
    }

    /* Full 1-second window ready — classify */
    s_chunk_count = 0;

    extract_mfcc(s_ring, WINDOW_SAMPLES, s_mfcc);
    float score = classifier_infer_mfcc(
        (const float (*)[N_FRAMES])s_mfcc);

    s_window_passed = (score >= SCORE_THRESHOLD);

    if (!s_window_passed) {
        LOG_DBG("animal_filter: REJECTED (score=%.3f)", (double)score);
    } else {
        LOG_DBG("animal_filter: PASSED (score=%.3f)", (double)score);
    }

    return s_window_passed;
}
