import argv
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result
 
// ---------- Messages ----------
pub type BossMsg {
  ExpectChunks(Int)
  ChunkFinished(List(Int))
}
 
pub type WorkerMsg {
  // scan inclusive [start..stop] for window size k and report to boss
  Scan(start: Int, stop: Int, k: Int, boss: process.Subject(BossMsg))
}
 
// ---------- Boss state as a proper type ----------
type BossState {
  BossState(received: Int, expected: Int, notify: process.Subject(Nil))
}
 
// ---------- Config ----------
const default_workers = 4
 
const default_chunk = 50_000
 
// ---------- CLI / entry ----------
pub fn main() {
  let args = argv.load().arguments
 
  let parsed = case args {
    [_p, n, k, w, c] -> parse4(n, k, w, c)
    [_p, n, k] -> parse2(n, k)
    [n, k, w, c] -> parse4(n, k, w, c)
    [n, k] -> parse2(n, k)
    _ -> Error(Nil)
  }
 
  case parsed {
    Ok(#(n, k, w, c)) -> run(n, k, w, c)
    Error(_) -> io.println("usage: parallel_lukas N K [WORKERS CHUNK]")
  }
}
 
fn parse2(n: String, k: String) -> Result(#(Int, Int, Int, Int), Nil) {
  result.try(int.parse(n), fn(nn) {
    result.map(int.parse(k), fn(kk) {
      #(nn, kk, default_workers, default_chunk)
    })
  })
}
 
fn parse4(
  n: String,
  k: String,
  w: String,
  c: String,
) -> Result(#(Int, Int, Int, Int), Nil) {
  result.try(int.parse(n), fn(nn) {
    result.try(int.parse(k), fn(kk) {
      result.try(int.parse(w), fn(ww) {
        result.map(int.parse(c), fn(cc) { #(nn, kk, ww, cc) })
      })
    })
  })
}
 
// ---------- Orchestration ----------
fn run(n: Int, k: Int, workers: Int, chunk: Int) {
  let workers = max(1, workers)
  let chunk = max(1, chunk)
 
  // Subject to wake main when boss is done
  let done = process.new_subject()
 
  // Start boss with named state
  let assert Ok(b_started) =
    actor.new(BossState(received: 0, expected: 0, notify: done))
    |> actor.on_message(boss_loop)
    |> actor.start
  let boss = b_started.data
 
  // Start worker pool
  let pool =
    list.repeat(workers, 0)
    |> list.map(fn(_) {
      let assert Ok(w_started) =
        actor.new(Nil) |> actor.on_message(worker_loop) |> actor.start
      w_started.data
    })
 
  // Build jobs and tell boss how many are coming
  let jobs = chunkify(1, n, chunk)
  process.send(boss, ExpectChunks(list.length(jobs)))
 
  // Dispatch round-robin (no more index_map issues)
  dispatch_jobs(jobs, pool, k, boss)
 
  // Block main until boss says all chunks arrived
  let _ = process.receive_forever(done)
  Nil
}
 
// ---------- Dispatch helpers ----------
fn dispatch_jobs(
  jobs: List(#(Int, Int)),
  pool: List(process.Subject(WorkerMsg)),
  k: Int,
  boss: process.Subject(BossMsg),
) {
  let plen = list.length(pool)
  dispatch_loop(jobs, pool, plen, 0, k, boss)
}
 
fn dispatch_loop(
  jobs: List(#(Int, Int)),
  pool: List(process.Subject(WorkerMsg)),
  plen: Int,
  i: Int,
  k: Int,
  boss: process.Subject(BossMsg),
) {
  case jobs {
    [] -> Nil
    [job, ..rest] -> {
      let #(s, e) = job
      let idx = i % plen
      let worker = nth(pool, idx) |> unwrap_or(start_worker())
      process.send(worker, Scan(s, e, k, boss))
      dispatch_loop(rest, pool, plen, i + 1, k, boss)
    }
  }
}
 
// ---------- Boss logic ----------
fn boss_loop(state: BossState, msg: BossMsg) -> actor.Next(BossState, BossMsg) {
  let BossState(received: r0, expected: e0, notify: notify) = state
 
  case msg {
    ExpectChunks(total) ->
      actor.continue(BossState(received: r0, expected: total, notify: notify))
 
    ChunkFinished(indices) -> {
      list.each(indices, fn(i) { io.println(int.to_string(i)) })
      let r1 = r0 + 1
      case e0 > 0 && r1 == e0 {
        True -> {
          process.send(notify, Nil)
          actor.stop()
        }
        False ->
          actor.continue(BossState(received: r1, expected: e0, notify: notify))
      }
    }
  }
}
 
// ---------- Worker logic ----------
fn worker_loop(_s: Nil, msg: WorkerMsg) -> actor.Next(Nil, WorkerMsg) {
  case msg {
    Scan(start, stop, k, boss) -> {
      let found =
        range_inclusive(start, stop)
        |> list.filter(fn(i) { is_square(win_sum(i, k)) })
      process.send(boss, ChunkFinished(found))
      actor.continue(Nil)
    }
  }
}
 
// ---------- Helpers ----------
fn start_worker() -> process.Subject(WorkerMsg) {
  let assert Ok(w_started) =
    actor.new(Nil) |> actor.on_message(worker_loop) |> actor.start
  w_started.data
}
 
fn nth(xs: List(a), n: Int) -> Result(a, Nil) {
  case xs {
    [] -> Error(Nil)
    [x, ..rest] ->
      case n {
        m if m == 0 -> Ok(x)
        m -> nth(rest, m - 1)
      }
  }
}
 
fn unwrap_or(x: Result(a, Nil), default: a) -> a {
  case x {
    Ok(v) -> v
    Error(_) -> default
  }
}
 
fn max(a: Int, b: Int) -> Int {
  case a >= b {
    True -> a
    False -> b
  }
}
 
fn chunkify(start: Int, n: Int, size: Int) -> List(#(Int, Int)) {
  case start > n {
    True -> []
    False -> {
      let stop = int.min(n, start + size - 1)
      [#(start, stop), ..chunkify(stop + 1, n, size)]
    }
  }
}
 
fn range_inclusive(a: Int, b: Int) -> List(Int) {
  case a > b {
    True -> []
    False -> [a, ..range_inclusive(a + 1, b)]
  }
}
 
// ---------- Same math as sequential ----------
fn div(a: Int, b: Int) -> Int {
  result.unwrap(int.divide(a, b), 0)
}
 
fn sq_prefix(m: Int) -> Int {
  let a = m
  let b = m + 1
  let c = 2 * m + 1
  div(a * b * c, 6)
}
 
fn win_sum(i: Int, k: Int) -> Int {
  let j = i + k - 1
  sq_prefix(j) - sq_prefix(i - 1)
}
 
fn is_square(x: Int) -> Bool {
  case x {
    n if n < 0 -> False
    n if n < 2 -> True
    _ -> has_root(x, 1, div(x, 2) + 1)
  }
}
 
fn has_root(x: Int, lo: Int, hi: Int) -> Bool {
  case lo > hi {
    True -> False
    False -> {
      let mid = lo + div(hi - lo, 2)
      let sq = mid * mid
      case cmp(sq, x) {
        0 -> True
        d if d < 0 -> has_root(x, mid + 1, hi)
        _ -> has_root(x, lo, mid - 1)
      }
    }
  }
}
 
fn cmp(a: Int, b: Int) -> Int {
  case a - b {
    d if d < 0 -> -1
    0 -> 0
    _ -> 1
  }
}
 