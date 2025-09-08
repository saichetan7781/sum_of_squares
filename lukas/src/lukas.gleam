import argv
import gleam/int
import gleam/io
import gleam/list
import gleam/result
 
/// --------- CLI entry ---------
pub fn main() {
  let args = argv.load().arguments
 
  // Accept either: <program> N K   or   N K
  let parsed = case args {
    [_prog, n, k] -> parse_pair(n, k)
    [n, k] -> parse_pair(n, k)
    _ -> Error(Nil)
  }
 
  case parsed {
    Ok(#(limit, span)) -> run(limit, span)
    Error(_) -> io.println("usage: lukas N K")
  }
}
 
/// --------- Orchestration ---------
fn run(n: Int, k: Int) {
  let starts =
    build_range(1, n)
    // <<— only change here; no impact on parallel_lukas
    |> list.filter(fn(i) { is_square(window_sum(i, k)) })
 
  // Print each starting index on its own line
  list.each(starts, fn(i) { io.println(int.to_string(i)) })
}
 
/// --------- Parsing helpers ---------
fn parse_pair(a: String, b: String) -> Result(#(Int, Int), Nil) {
  result.try(int.parse(a), fn(x) { result.map(int.parse(b), fn(y) { #(x, y) }) })
}
 
/// --------- Math helpers ---------
// unwrap Result(Int, Nil) from int.divide; b is never 0 in our calls
 
fn div(a: Int, b: Int) -> Int {
  result.unwrap(int.divide(a, b), 0)
}
 
// Sum_{t=1..m} t^2  =  m(m+1)(2m+1)/6
fn sq_prefix(m: Int) -> Int {
  let a = m
  let b = m + 1
  let c = 2 * m + 1
  a * b * c |> div(6)
}
 
// Sum of k consecutive squares starting at i
fn window_sum(i: Int, k: Int) -> Int {
  let j = i + k - 1
  sq_prefix(j) - sq_prefix(i - 1)
}
 
// Perfect square test via integer binary search
fn is_square(x: Int) -> Bool {
  case x {
    n if n < 0 -> False
    n if n < 2 -> True
    _ -> root_exists(x, 1, div(x, 2) + 1)
  }
}
 
fn root_exists(x: Int, lo: Int, hi: Int) -> Bool {
  case lo > hi {
    True -> False
    False -> {
      let mid = lo + div(hi - lo, 2)
      let sq = mid * mid
      case compare(sq, x) {
        0 -> True
        ord if ord < 0 -> root_exists(x, mid + 1, hi)
        _ -> root_exists(x, lo, mid - 1)
      }
    }
  }
}
 
// Simple comparison to avoid importing another module
fn compare(a: Int, b: Int) -> Int {
  case a - b {
    d if d < 0 -> -1
    0 -> 0
    _ -> 1
  }
}
 
/// --------- Tiny list helper ---------
fn build_range(a: Int, b: Int) -> List(Int) {
  case a > b {
    True -> []
    False -> [a, ..build_range(a + 1, b)]
  }
}
 