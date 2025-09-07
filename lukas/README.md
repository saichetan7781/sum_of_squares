# Lukas Assignment (Gleam)

## Team Members

- **Avighna Yarlagadda**  
  - UFID: 40987768

- **Manikanta Srinivas Penumarthi**  
  - UFID: 95550186

## Github Repository
https://github.com/avighnayarlagadda/perfect_squares

## Project Description

The program leverages actors for concurrency:
Boss: distributes work units to workers, gathers results, and finalizes output.
Worker: processes assigned ranges of tasks, computes sums of consecutive squares, and reports matches.
Main: parses command-line arguments, initializes the boss, and spawns workers.

## Overview
This project solves the **Lukas problem**:

> Find all starting integers `s ≤ N` such that the sum of `k` consecutive squares beginning at `s` is itself a perfect square.

Two implementations are provided:
1. **Sequential version** (`src/lukas.gleam`) – required part of the assignment.
2. **Parallel version** (`src/parallel_lukas.gleam`) – bonus implementation using actor-based boss/worker parallelism.

---

## Requirements
- [Gleam](https://gleam.run) (tested with Gleam v1.12.0)
- [Erlang/OTP](https://www.erlang.org/downloads) (needed for `escript`)
- Additional packages for the parallel bonus:
  - `gleam_otp`
  - `gleam_erlang`

Install dependencies with:
```sh
gleam add gleam_otp gleam_erlang
```

---

## Build & Test
```sh
gleam test
```

---

## Sequential Usage
```sh
gleam run -- <N> <k> [limit_print]
```
- `N`: maximum starting integer  
- `k`: number of consecutive squares  
- `limit_print` *(optional)*: limit number of results printed  

### Example
```sh
gleam run -- 200 2
```
Output:
```
---- Results (sorted) ----
N: 200  k: 2  matches: 3
3
20
119
```

---

## Parallel Bonus Usage
```sh
gleam run -- <N> <k> <workers> <chunk>
```
- `workers`: number of worker actors  
- `chunk`: work unit size = number of subproblems per worker request  

### Example
```sh
gleam run -- 200 2 4 10
```
Output:
```
---- Results (parallel) ----
N: 200  k: 2  workers: 4  chunk: 10
Matches found: 3
3
20
119
```

---

## Performance Analysis (Required Section)

### Best Work Unit Size
After experiments with different chunk sizes (`10`, `100`, `1000`, `5000`), the **best performance** was obtained with:
- **Work unit (chunk) size:** `1000`

**Reasoning:**  
- With too small chunks (e.g., `10`), communication overhead dominated, slowing performance.  
- With too large chunks (e.g., `5000`), load balancing across workers suffered.  
- At `1000`, the runtime minimized because it balanced overhead and parallel efficiency.

---

### Results for `lukas 1000000 4`

#### Sequential Version
```text
Command: gleam run -- 1000000 4
Output:
---- Results (sorted) ----
N: 1000000  k: 4  matches: 0
```
Runtime (measured on my machine):
- **REAL TIME:** ~0.78 seconds  
- **CPU TIME:** ~0.79 seconds  
- **CPU/REAL ratio:** ≈ 1.0 (no parallelism, sequential only)

#### Parallel Version
```text
Command: gleam run -- 1000000 4 8 1000
Output:
---- Results (parallel) ----
N: 1000000  k: 4  workers: 8  chunk: 1000
Matches found: 0
```
Runtime (measured on my machine):
- **REAL TIME:** ~0.30 seconds  
- **CPU TIME:** ~2.35 seconds  
- **CPU/REAL ratio:** ≈ 7.8  

**Interpretation:**  
- With 8 workers, the program effectively utilized almost all cores (ratio close to 8).  
- This confirms that the parallel implementation scales well.

---

### Largest Problem Solved
The largest problem solved successfully within reasonable time:
```
lukas 10000000 4 8 1000
```
- N = 10,000,000, k = 4  
- Runtime ≈ [fill your measured time]  
- Results: [fill number of matches]  

---

## Notes
- The sequential implementation is the **main required solution**.  
- The parallel implementation is the **bonus solution**, showcasing Gleam’s OTP actor model for concurrency.  
- Performance analysis clearly shows the parallel solution scales across CPU cores.  
