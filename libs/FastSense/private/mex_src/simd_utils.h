#ifndef SIMD_UTILS_H
#define SIMD_UTILS_H

#include <math.h>
#include <stddef.h>

/*
 * simd_utils.h — Compile-time SIMD abstraction for FastSense MEX files.
 *
 * Provides unified operations on packed doubles:
 *   - AVX2:  4 doubles per vector  (__m256d)
 *   - SSE2:  2 doubles per vector  (__m128d)
 *   - NEON:  2 doubles per vector  (float64x2_t)
 *   - Scalar fallback if none detected
 */

/* ============================================================
 * AVX2 path (x86_64 with -mavx2)
 * ============================================================ */
#if defined(__AVX2__)

#include <immintrin.h>

#define SIMD_WIDTH 4
typedef __m256d simd_double;

static inline simd_double simd_load(const double *p) { return _mm256_loadu_pd(p); }
static inline void simd_store(double *p, simd_double v) { _mm256_storeu_pd(p, v); }
static inline simd_double simd_set1(double v) { return _mm256_set1_pd(v); }
static inline simd_double simd_min(simd_double a, simd_double b) { return _mm256_min_pd(a, b); }
static inline simd_double simd_max(simd_double a, simd_double b) { return _mm256_max_pd(a, b); }
static inline simd_double simd_sub(simd_double a, simd_double b) { return _mm256_sub_pd(a, b); }
static inline simd_double simd_mul(simd_double a, simd_double b) { return _mm256_mul_pd(a, b); }

/* Absolute value: clear sign bit */
static inline simd_double simd_abs(simd_double a) {
    __m256d sign_mask = _mm256_set1_pd(-0.0);
    return _mm256_andnot_pd(sign_mask, a);
}

/* Horizontal max of 4 doubles */
static inline double simd_hmax(simd_double v) {
    /* [a b c d] */
    __m128d lo = _mm256_castpd256_pd128(v);    /* [a b] */
    __m128d hi = _mm256_extractf128_pd(v, 1);  /* [c d] */
    __m128d m = _mm_max_pd(lo, hi);            /* [max(a,c) max(b,d)] */
    __m128d s = _mm_unpackhi_pd(m, m);         /* [max(b,d) max(b,d)] */
    __m128d r = _mm_max_pd(m, s);
    return _mm_cvtsd_f64(r);
}

/* Horizontal min of 4 doubles */
static inline double simd_hmin(simd_double v) {
    __m128d lo = _mm256_castpd256_pd128(v);
    __m128d hi = _mm256_extractf128_pd(v, 1);
    __m128d m = _mm_min_pd(lo, hi);
    __m128d s = _mm_unpackhi_pd(m, m);
    __m128d r = _mm_min_pd(m, s);
    return _mm_cvtsd_f64(r);
}

/* ============================================================
 * SSE2 path (x86_64 without AVX2)
 * ============================================================ */
#elif defined(__SSE2__) || (defined(_M_AMD64) || defined(_M_X64))

#include <emmintrin.h>

#define SIMD_WIDTH 2
typedef __m128d simd_double;

static inline simd_double simd_load(const double *p) { return _mm_loadu_pd(p); }
static inline void simd_store(double *p, simd_double v) { _mm_storeu_pd(p, v); }
static inline simd_double simd_set1(double v) { return _mm_set1_pd(v); }
static inline simd_double simd_min(simd_double a, simd_double b) { return _mm_min_pd(a, b); }
static inline simd_double simd_max(simd_double a, simd_double b) { return _mm_max_pd(a, b); }
static inline simd_double simd_sub(simd_double a, simd_double b) { return _mm_sub_pd(a, b); }
static inline simd_double simd_mul(simd_double a, simd_double b) { return _mm_mul_pd(a, b); }

static inline simd_double simd_abs(simd_double a) {
    __m128d sign_mask = _mm_set1_pd(-0.0);
    return _mm_andnot_pd(sign_mask, a);
}

static inline double simd_hmax(simd_double v) {
    __m128d s = _mm_unpackhi_pd(v, v);
    __m128d r = _mm_max_pd(v, s);
    return _mm_cvtsd_f64(r);
}

static inline double simd_hmin(simd_double v) {
    __m128d s = _mm_unpackhi_pd(v, v);
    __m128d r = _mm_min_pd(v, s);
    return _mm_cvtsd_f64(r);
}

/* ============================================================
 * ARM NEON path (Apple Silicon, ARM64)
 * ============================================================ */
#elif defined(__ARM_NEON) || defined(__aarch64__)

#include <arm_neon.h>

#define SIMD_WIDTH 2
typedef float64x2_t simd_double;

static inline simd_double simd_load(const double *p) { return vld1q_f64(p); }
static inline void simd_store(double *p, simd_double v) { vst1q_f64(p, v); }
static inline simd_double simd_set1(double v) { return vdupq_n_f64(v); }
static inline simd_double simd_min(simd_double a, simd_double b) { return vminq_f64(a, b); }
static inline simd_double simd_max(simd_double a, simd_double b) { return vmaxq_f64(a, b); }
static inline simd_double simd_sub(simd_double a, simd_double b) { return vsubq_f64(a, b); }
static inline simd_double simd_mul(simd_double a, simd_double b) { return vmulq_f64(a, b); }
static inline simd_double simd_abs(simd_double a) { return vabsq_f64(a); }

static inline double simd_hmax(simd_double v) {
    return vmaxvq_f64(v);
}

static inline double simd_hmin(simd_double v) {
    return vminvq_f64(v);
}

/* ============================================================
 * Scalar fallback
 * ============================================================ */
#else

#define SIMD_WIDTH 1

typedef double simd_double;

static inline simd_double simd_load(const double *p) { return *p; }
static inline void simd_store(double *p, simd_double v) { *p = v; }
static inline simd_double simd_set1(double v) { return v; }
static inline simd_double simd_min(simd_double a, simd_double b) { return a < b ? a : b; }
static inline simd_double simd_max(simd_double a, simd_double b) { return a > b ? a : b; }
static inline simd_double simd_sub(simd_double a, simd_double b) { return a - b; }
static inline simd_double simd_mul(simd_double a, simd_double b) { return a * b; }
static inline simd_double simd_abs(simd_double a) { return fabs(a); }
static inline double simd_hmax(simd_double v) { return v; }
static inline double simd_hmin(simd_double v) { return v; }

#endif

#endif /* SIMD_UTILS_H */
