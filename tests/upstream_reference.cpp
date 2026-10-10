// Host-side oracle for the golden vectors in test_core.lua.
//
// This is intentionally small and dependency-free. Its integer expressions
// are copied from Ormer Modular Shoal commit
// 845b8d0bbbc6315ffa09fd3338137362695f0f1a. It lets maintainers regenerate
// reference values with an ordinary host compiler, without the disting NT SDK.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static inline uint32_t hash3(uint32_t a, uint32_t b, uint32_t c) {
  uint32_t h = a * 0x9E3779B1u ^ b * 0x85EBCA77u ^ c * 0xC2B2AE3Du;
  h ^= h >> 16; h *= 0x7FEB352Du;
  h ^= h >> 15; h *= 0x846CA68Bu;
  h ^= h >> 16;
  return h;
}

struct EvalConfig {
  uint32_t seed;
  int root, weight, noteAmount, octAmount, octave, transpose;
  const uint8_t* pcs;
  int scaleCount;
};

static int evaluate(const EvalConfig& cfg, int step) {
  int stable[3] = { 0, 0, 0 }, stableCount = 1;
  int bestT = -1, bt = 99, bestF = -1, bf = 99;
  for (int i = 1; i < cfg.scaleCount; ++i) {
    int pc = cfg.pcs[i];
    int d3 = abs(pc - 3), d4 = abs(pc - 4);
    if (d4 < d3) d3 = d4;
    if (d3 < bt) { bt = d3; bestT = i; }
    int d7 = abs(pc - 7);
    if (d7 < bf) { bf = d7; bestF = i; }
  }
  if (bestT > 0) stable[stableCount++] = bestT;
  if (bestF > 0 && bestF != bestT) stable[stableCount++] = bestF;

  uint32_t rb = hash3(cfg.seed, (uint32_t)step, 0xBA5Eu) & 1023;
  int degree = (int)((rb * (uint32_t)(2 * cfg.scaleCount)) >> 10) - cfg.scaleCount;
  int nMag = abs(cfg.noteAmount), oMag = abs(cfg.octAmount), o = 0;
  if (nMag > 0 && hash3(cfg.seed, (uint32_t)step, 0xA221u) % 100 < (uint32_t)nMag) {
    int reach = 1 + (nMag * 11) / 100;
    int d = 1 + (int)(hash3(cfg.seed, (uint32_t)step, 0x0007u) % (uint32_t)reach);
    degree += cfg.noteAmount > 0 ? d : -d;
  }
  if (oMag > 0 && hash3(cfg.seed, (uint32_t)step, 0x0C7Au) % 100 < (uint32_t)oMag) {
    int reach = 1 + (oMag * 4) / 100;
    o = 1 + (int)(hash3(cfg.seed, (uint32_t)step, 0x0C7Bu) % (uint32_t)reach);
    if (cfg.octAmount < 0) o = -o;
  }
  if (cfg.weight > 0 && hash3(cfg.seed, (uint32_t)step, 0x0337u) % 100 < (uint32_t)cfg.weight) {
    int q2 = degree / cfg.scaleCount;
    int r2 = degree - q2 * cfg.scaleCount;
    if (r2 < 0) { r2 += cfg.scaleCount; q2 -= 1; }
    int best = 0, bd = 99;
    for (int i = 0; i < stableCount; ++i) {
      int candidate = stable[i];
      for (int oc = 0; oc < 2; ++oc, candidate += cfg.scaleCount) {
        int distance = abs(r2 - candidate);
        if (distance < bd) { bd = distance; best = candidate; }
      }
    }
    degree = q2 * cfg.scaleCount + best;
  }
  degree += cfg.transpose;
  int q = degree / cfg.scaleCount;
  int r = degree - q * cfg.scaleCount;
  if (r < 0) { r += cfg.scaleCount; q -= 1; }
  int note = cfg.root + 12 * (cfg.octave + q + o) + cfg.pcs[r];
  while (note < 0) note += 12;
  while (note > 127) note -= 12;
  return note;
}

static void printMelody(const char* label, const EvalConfig& cfg) {
  printf("%s=", label);
  for (int step = 0; step < 16; ++step)
    printf("%s%d", step ? "," : "", evaluate(cfg, step));
  putchar('\n');
}

// Shoal's Tide keeps Chance/Tie on the rhythm step and rotates only pitch.
// This fixture deliberately includes rests, so the two streams cannot be
// mistaken for a whole-event rotation.
static void printTide(const EvalConfig& cfg) {
  printf("tide=");
  for (int tick = 0; tick < 15; ++tick) {
    int step = tick % 5;
    int pitchStep = (step + tick / 5) % 5;
    int fires = hash3(cfg.seed, (uint32_t)step, 0xF17Eu) % 100 < 58;
    int tie = hash3(cfg.seed, (uint32_t)step, 0x071Eu) % 100 < 43;
    int note = fires ? evaluate(cfg, pitchStep) : 0;
    printf("%s%d:%d:%d:%d:%d", tick ? "," : "",
      step, pitchStep, fires, tie, note);
  }
  putchar('\n');
}

struct Walk {
  int pos, dir, phase, pass, poolStart, poolLen, poolPos, dwell;
  uint32_t seed;
};

static uint32_t walkRng = 0x7A31C0DEu;
static uint32_t nextRng() {
  walkRng = walkRng * 1664525u + 1013904223u;
  return walkRng;
}

static void advancePosition(Walk& tr, int mode, int length) {
  if (tr.pos < 0) {
    tr.dir = 1; tr.phase = 0; tr.pass = 0; tr.dwell = 0; tr.poolPos = 0;
    tr.pos = mode == 12 ? (length - 1) / 2 : (mode == 1 ? length - 1 : 0);
  } else switch (mode) {
    case 0: tr.pos = (tr.pos + 1) % length; break;
    case 1: tr.pos = (tr.pos + length - 1) % length; break;
    case 2:
      if (tr.dir > 0) { if (tr.pos >= length - 1) tr.dir = -1; else tr.pos += 1; }
      else { if (tr.pos <= 0) tr.dir = 1; else tr.pos -= 1; }
      break;
    case 5:
      if (tr.dir > 0) { if (tr.pos >= length - 1) { tr.dir = -1; tr.pos -= 1; } else tr.pos += 1; }
      else { if (tr.pos <= 0) { tr.dir = 1; tr.pos += 1; } else tr.pos -= 1; }
      break;
    case 3: tr.pos = (int)((nextRng() >> 16) % (uint32_t)length); break;
    case 4: {
      uint32_t roll = (nextRng() >> 16) % 100;
      if (roll < 50) tr.pos = (tr.pos + 1) % length;
      else if (roll >= 75) tr.pos = (tr.pos + length - 1) % length;
      break;
    }
    case 8:
      if (tr.dwell == 0) {
        tr.poolLen = 3 + (int)((nextRng() >> 16) % 2);
        tr.poolStart = (int)((nextRng() >> 16) % (uint32_t)length);
        tr.dwell = tr.poolLen * (2 + (int)((nextRng() >> 16) % 3));
        tr.poolPos = 0;
      }
      tr.pos = (tr.poolStart + tr.poolPos) % length;
      tr.poolPos = (tr.poolPos + 1) % tr.poolLen;
      tr.dwell -= 1;
      break;
    case 9: {
      tr.phase = (tr.phase + 1) % (length * 2);
      uint32_t n = (uint32_t)tr.phase, p = n / 2;
      tr.pos = (int)(n % 2 == 0 ? p : (p + 2) % (uint32_t)length);
      break;
    }
    case 10: {
      uint32_t strength = 20 + hash3(tr.seed, 0x6E01u, 0) % 41;
      uint32_t key = ((uint32_t)tr.pass << 8) | (uint32_t)tr.pos;
      uint32_t roll = hash3(tr.seed, key, 0x6EA1u) % 100;
      tr.pos = roll < strength && tr.pos != 0 ? 0 : (tr.pos + 1) % length;
      break;
    }
    case 11: {
      tr.phase = (tr.phase + 1) % length;
      uint32_t n = (uint32_t)tr.phase;
      tr.pos = (int)(n % 2 == 0 ? n / 2 : (uint32_t)length - 1 - n / 2);
      break;
    }
    case 12: {
      tr.phase = (tr.phase + 1) % length;
      uint32_t n = (uint32_t)tr.phase;
      int k = (int)((n + 1) / 2), offset = (n & 1) ? k : -k;
      tr.pos = ((length - 1) + 2 * offset) / 2;
      break;
    }
    case 13:
      if (length > 1) {
        int next;
        do { next = (int)((nextRng() >> 16) % (uint32_t)length); } while (next == tr.pos);
        tr.pos = next;
      }
      break;
    case 14:
      tr.phase = (tr.phase + 1) % ((length - 1) * 2);
      tr.pos = tr.phase % 2 == 0 ? 0 : 1 + tr.phase / 2;
      break;
  }

  bool origin = mode == 1 ? tr.pos == length - 1
    : (mode == 9 || mode == 11 || mode == 12 || mode == 14) ? tr.phase == 0
    : (mode == 3 || mode == 4 || mode == 8 || mode == 13) ? true
    : tr.pos == 0;
  if (origin) tr.pass = (tr.pass + 1) & 0xffff;
}

static void printWalk(const char* label, int mode) {
  Walk tr = { -1, 1, 0, 0, 0, 0, 0, 0, 1 };
  walkRng = 0x7A31C0DEu;
  printf("%s=", label);
  for (int i = 0; i < 12; ++i) {
    advancePosition(tr, mode, 5);
    printf("%s%d", i ? "," : "", tr.pos);
  }
  putchar('\n');
}

int main() {
  printf("hash=%u,%u,%u,%u\n",
    hash3(0, 0, 0), hash3(1, 0, 0xBA5Eu),
    hash3(999, 63, 0xF17Eu), hash3(347, 0x020Cu, 0xA221u));

  const uint8_t major[] = { 0, 2, 4, 5, 7, 9, 11 };
  const uint8_t dorian[] = { 0, 2, 3, 5, 7, 9, 10 };
  EvalConfig defaults = { 1, 48, 0, 0, 0, 0, 0, major, 7 };
  EvalConfig variation = { 347, 60, 47, -63, 38, -1, 2, dorian, 7 };
  printMelody("major", defaults);
  printMelody("variation", variation);
  printTide(defaults);

  const char* names[] = { "forwards", "reverse", "pendulum", "random", "drunk",
    "pong", "tide", "shuffle", "pools", "stride", "gravity", "converge",
    "diverge", "skitter", "anchor" };
  const int modes[] = { 0, 1, 2, 5, 9, 10, 11, 12, 14, 3, 4, 8, 13 };
  for (unsigned i = 0; i < sizeof(modes) / sizeof(modes[0]); ++i)
    printWalk(names[modes[i]], modes[i]);

  // A compact cross-language check over 3,328 note evaluations. This covers
  // every scale plus negative/positive Note, Oct, octave, transpose, and
  // Weight values without checking thousands of literals into the project.
  const uint16_t masks[] = {
    0xFFF, 0xAB5, 0x5AD, 0x9AD, 0x6AD, 0x5AB, 0xAD5,
    0x6B5, 0x295, 0x4A9, 0x4E9, 0x18D, 0x4A3,
  };
  const uint32_t seeds[] = { 0, 1, 347, 999 };
  uint32_t digest = 2166136261u;
  for (unsigned si = 0; si < sizeof(seeds) / sizeof(seeds[0]); ++si) {
    for (int scale = 0; scale < 13; ++scale) {
      uint8_t pcs[12];
      int count = 0;
      for (int pc = 0; pc < 12; ++pc)
        if (masks[scale] & (1u << pc)) pcs[count++] = (uint8_t)pc;
      uint32_t seed = seeds[si];
      EvalConfig cfg = {
        seed,
        (int)((seed + (uint32_t)scale * 7u) % 128u),
        (int)((seed * 13u + (uint32_t)scale * 17u) % 101u),
        (int)((seed + (uint32_t)scale * 37u) % 201u) - 100,
        (int)((seed * 3u + (uint32_t)scale * 29u) % 201u) - 100,
        (int)((seed + (uint32_t)scale) % 7u) - 3,
        (int)((seed * 5u + (uint32_t)scale) % 15u) - 7,
        pcs, count,
      };
      for (int step = 0; step < 64; ++step)
        digest = (digest * 16777619u) ^ (uint32_t)evaluate(cfg, step);
    }
  }
  printf("eval-digest=%u\n", digest);
}
