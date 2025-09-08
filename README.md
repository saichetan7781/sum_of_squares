# Lukas Assignment (Gleam)

## Team Members
Sai Chetan Nandikanti (UFID: 77447179, UF Mail:sa.nandikanti@ufl.edu)

Rishav Raju Chintalapati - (UFID:74264181 UF Mail:  r.chintalapati@ufl.edu)
 
## Github Repository


## Project Description

The application uses actors to achieve concurrency:
Main: initializes the boss, spawns workers, and parses command-line inputs.
Worker: computes sums of consecutive squares, reports matches, and handles allocated ranges of tasks.
Boss: assigns tasks to employees, collects data, and completes output.
 
The **Lukas problem** is resolved by this project:

> Determine all initial values `s ≤ N` such that the sum of `k` consecutive squares starting at `s` is a perfect square in and of itself.

There are two implementations offered:
**Sequential version** (`src/lukas.gleam`) is the main file of the task.
Actor-based boss/worker parallelism is used in the bonus implementation of the **Parallel version** (`src/lukas_bonus.gleam`).

---

To work with this project you’ll need Gleam (tested on v1.12.0), Erlang/OTP (required for escript execution), and for the parallel extension, the additional packages gleam_otp and gleam_erlang. You can install these extras using gleam add gleam_otp gleam_erlang. Once dependencies are ready, the project can be tested with gleam test.

For sequential execution, run the program as gleam run -- <N> <k> [limit_print] where N is the maximum starting number to consider, k is the length of the consecutive square sequence, and limit_print is optional to restrict how many matches are displayed. For example, gleam run -- 200 2 produces results like:

---- Results (sorted) ----  
N: 200  k: 2  matches: 3  
3  
20  
119

---
The parallel bonus version uses the format gleam run -- <N> <k> <workers> <chunk> where workers sets the number of concurrent actors and chunk specifies how many subproblems are sent to each worker per request. For instance, gleam run -- 200 2 4 10 outputs:

---- Results (parallel) ----  
N: 200  k: 2  workers: 4  chunk: 10  
Matches found: 3  
3  
20  
119  

---- Results (parallel) ----  
N: 200  k: 2  workers: 4  chunk: 10  
Matches found: 3  
3  
20  
119  

## Performance Evaluation Report

Optimal Chunk Size

During testing with multiple chunk sizes (10, 100, 1000, 5000), the best performance was achieved at:

Chunk size: 1000

Explanation:

Very small chunks (e.g., 10) caused excessive communication overhead.

Very large chunks (e.g., 5000) led to poor workload distribution across workers.

A chunk size of 1000 provided the right balance, reducing overhead while maintaining efficient parallel execution.

## Benchmark: lukas 1000000 4

Sequential Execution

Command: gleam run -- 1000000 4

---- Results ----
N: 1000000  k: 4  matches: 0

Performance (on test machine):

Real time: ~0.04s

CPU time: ~0.06s

CPU/Real ratio: ~1.03 (indicating single-threaded execution).

## Parallel Execution

Performance (on test machine):
workers: 8

Real time: ~0.30s

CPU time: ~2.28s

CPU/Real ratio: ~7.6s

Insights:

With 8 workers, CPU utilization approached full capacity (ratio close to 8).

Confirms that the parallel implementation scales efficiently with available cores.

## Maximum Problem Size Solved

Largest problem successfully solved was for:

N = 10,000,000 4

Real time: ~ 0.4s

CPU time: 3.32s

CPU/ Real Ratio: ~ 7.9s

Note: 
The bonus implementation has been performed in the lukas_bonus file.


