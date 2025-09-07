// src/parallel_lukas.gleam
// Parallel actor-based boss + workers (local). Bonus implementation.
// Usage: when active: gleam run -- <N> <k> [workers] [chunk]

import gleam/io
import argv
import gleam/int
import gleam/list

import gleam/otp/actor as actor
import gleam/erlang/process as process

// Math helpers (same as sequential)
fn sum_k_squares_from(s: Int, k: Int) -> Int {
  let c = {k - 1} * k * {2 * k - 1} / 6
  k * s * s + k * {k - 1} * s + c
}

fn isqrt(low: Int, high: Int, n: Int) -> Int {
  case low > high {
    True -> high
    False -> {
      let mid = {low + high} / 2
      let sq = mid * mid
      case sq < n {
        True -> isqrt(mid + 1, high, n)
        False ->
          case sq > n {
            True -> isqrt(low, mid - 1, n)
            False -> mid
          }
      }
    }
  }
}

fn integer_sqrt(n: Int) -> Int {
  case n <= 1 { True -> n False -> isqrt(0, n, n) }
}

fn is_perfect_square(n: Int) -> Bool {
  case n < 0 { True -> False False -> { let r = integer_sqrt(n) r * r == n } }
}

fn find_in_range(start: Int, end_: Int, k: Int) -> List(Int) {
  list.range(start, end_)
  |> list.filter(fn(s) { is_perfect_square(sum_k_squares_from(s, k)) })
}

// Simple list helpers
fn prepend_list(from: List(Int), to: List(Int)) -> List(Int) {
  case from {
    [] -> to
    [h, ..t] -> prepend_list(t, [h, ..to])
  }
}

fn dedupe_loop(prev: Int, seen_first: Bool, rest: List(Int), acc: List(Int)) -> List(Int) {
  case rest {
    [] -> list.reverse(acc)
    [h, ..t] -> {
      case seen_first {
        False -> dedupe_loop(h, True, t, [h, ..acc])
        True -> {
          case h == prev {
            True -> dedupe_loop(prev, True, t, acc)
            False -> dedupe_loop(h, True, t, [h, ..acc])
          }
        }
      }
    }
  }
}

fn dedupe_sorted(xs: List(Int)) -> List(Int) {
  dedupe_loop(0, False, xs, [])
}

// Messages / states
pub type BossMsg {
  RequestWork(reply_to: process.Subject(WorkerCmd))
  ReportResults(found: List(Int))
  WorkerDone
}

pub type WorkerCmd {
  Work(start: Int, end_: Int)
  NoWork
}

pub type BossState {
  BossState(next_start: Int, n: Int, k: Int, chunk: Int, finished: Int, total_workers: Int, finish_subject: process.Subject(String), results: List(Int))
}

pub type WorkerState {
  WorkerState(boss_subject: process.Subject(BossMsg), k: Int)
}

// Boss handler
fn boss_handle(state: BossState, message: BossMsg) -> actor.Next(BossState, BossMsg) {
  case message {
    RequestWork(reply_to) -> {
      let BossState(next_start, n, k, chunk, finished, total_workers, finish_subject, results) = state
      case next_start > n {
        True -> {
          process.send(reply_to, NoWork)
          actor.continue(state)
        }
        False -> {
          let end_ = case next_start + {chunk - 1} < n { True -> next_start + {chunk - 1} False -> n }
          process.send(reply_to, Work(next_start, end_))
          actor.continue(BossState(end_ + 1, n, k, chunk, finished, total_workers, finish_subject, results))
        }
      }
    }

    ReportResults(found) -> {
      let BossState(next_start, n, k, chunk, finished, total_workers, finish_subject, results) = state
      let new_results = prepend_list(found, results)
      actor.continue(BossState(next_start, n, k, chunk, finished, total_workers, finish_subject, new_results))
    }

    WorkerDone -> {
      let BossState(next_start, n, k, chunk, finished, total_workers, finish_subject, results) = state
      let finished2 = finished + 1
      case finished2 == total_workers {
        True -> {
          // finalize: sort & dedupe & print
          let sorted = list.sort(results, by: fn(a, b) { int.compare(a, b) })
          let unique = dedupe_sorted(sorted)
          io.println("---- Results (parallel) ----")
          io.println(
            "N: " <> int.to_string(n)
            <> "  k: " <> int.to_string(k)
            <> "  workers: " <> int.to_string(total_workers)
            <> "  chunk: " <> int.to_string(chunk)
          )
          io.println("Matches found: " <> int.to_string(list.length(unique)))
          list.each(unique, fn(x) { io.println(int.to_string(x)) })
          process.send(finish_subject, "done")
          actor.stop()
        }
        False -> actor.continue(BossState(next_start, n, k, chunk, finished2, total_workers, finish_subject, results))
      }
    }
  }
}

// Worker implementation
pub type WorkerMsg { Start }

fn worker_loop(state: WorkerState) -> Nil {
  let WorkerState(boss_subject, k) = state
  let reply_subj = process.new_subject()
  process.send(boss_subject, RequestWork(reply_subj))

  case process.receive(reply_subj, within: 60_000) {
    Ok(msg) -> {
      case msg {
        Work(start, end_) -> {
          let found = find_in_range(start, end_, k)
          process.send(boss_subject, ReportResults(found))
          worker_loop(state)
        }
        NoWork -> {
          process.send(boss_subject, WorkerDone)
          Nil
        }
      }
    }
    Error(_) -> {
      // timeout -> tell boss we're done
      process.send(boss_subject, WorkerDone)
      Nil
    }
  }
}

fn worker_handle(state: WorkerState, message: WorkerMsg) -> actor.Next(WorkerState, WorkerMsg) {
  case message {
    Start -> {
      worker_loop(state)
      actor.stop()
    }
  }
}

// spawn helper
fn spawn_workers(boss_subj: process.Subject(BossMsg), workers: Int, k: Int, i: Int) {
  case i > workers {
    True -> Nil
    False -> {
      let wstate = WorkerState(boss_subj, k)
      let assert Ok(worker_ref) = actor.new(wstate) |> actor.on_message(worker_handle) |> actor.start
      let worker_subj = worker_ref.data
      process.send(worker_subj, Start)
      spawn_workers(boss_subj, workers, k, i + 1)
    }
  }
}

// CLI & main
pub fn main() {
  let args = argv.load().arguments
  case args {
    [n_s, k_s] -> run_from_strings(n_s, k_s, "4", "1000")
    [n_s, k_s, workers_s] -> run_from_strings(n_s, k_s, workers_s, "1000")
    [n_s, k_s, workers_s, chunk_s] -> run_from_strings(n_s, k_s, workers_s, chunk_s)
    _ -> io.println("Usage: parallel_lukas <N> <k> [workers] [chunk]")
  }
}

fn parse_int_or_default(s: String, d: Int) -> Int {
  case int.parse(s) { Ok(i) -> i Error(_) -> d }
}

fn run_from_strings(n_s: String, k_s: String, workers_s: String, chunk_s: String) {
  let n = parse_int_or_default(n_s, 100)
  let k = parse_int_or_default(k_s, 2)
  let workers = parse_int_or_default(workers_s, 4)
  let chunk = parse_int_or_default(chunk_s, 1000)

  let finish_subj = process.new_subject()
  let boss_init = BossState(1, n, k, chunk, 0, workers, finish_subj, [])
  let assert Ok(boss_ref) = actor.new(boss_init) |> actor.on_message(boss_handle) |> actor.start
  let boss_subj = boss_ref.data

  spawn_workers(boss_subj, workers, k, 1)

  case process.receive(finish_subj, within: 3_600_000) {
    Ok(_) -> Nil
    Error(_) -> io.println("Timed out waiting for completion.")
  }
}
