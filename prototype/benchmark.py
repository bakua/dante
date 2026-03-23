#!/usr/bin/env python3
"""
DANTE TERMINAL - Quantitative Model Benchmark
Measures tokens/sec, peak RSS memory (MB), and time-to-first-token across models.
Each prompt is run independently (fresh context) for reproducible measurements.

Usage:
    python benchmark.py --models models/tinyllama-1.1b-chat-q4km.gguf models/phi3-mini-4k-q4.gguf
    python benchmark.py --models models/*.gguf --output benchmarks.json
"""

import argparse
import json
import os
import threading
import time
from pathlib import Path

import psutil
from llama_cpp import Llama

from dante_cli import SYSTEM_PROMPT

DEFAULT_PROMPTS_FILE = Path(__file__).parent / "benchmark_prompts.json"
DEFAULT_OUTPUT_FILE = Path(__file__).parent / "benchmarks.json"


# ─── Memory Tracking ────────────────────────────────────────────────────────


class MemoryTracker:
    """Polls process RSS in a background thread to capture peak memory usage."""

    def __init__(self, poll_interval: float = 0.05):
        self.process = psutil.Process(os.getpid())
        self.poll_interval = poll_interval
        self.peak_rss_bytes = 0
        self.baseline_rss_bytes = 0
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self):
        """Record baseline RSS and begin background polling."""
        self.baseline_rss_bytes = self.process.memory_info().rss
        self.peak_rss_bytes = self.baseline_rss_bytes
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._poll, daemon=True)
        self._thread.start()

    def _poll(self):
        while not self._stop_event.is_set():
            current = self.process.memory_info().rss
            if current > self.peak_rss_bytes:
                self.peak_rss_bytes = current
            self._stop_event.wait(self.poll_interval)

    def stop(self):
        """Stop polling and join the background thread."""
        self._stop_event.set()
        if self._thread:
            self._thread.join(timeout=2.0)

    @property
    def peak_rss_mb(self) -> float:
        return self.peak_rss_bytes / (1024 * 1024)

    @property
    def baseline_rss_mb(self) -> float:
        return self.baseline_rss_bytes / (1024 * 1024)


# ─── Prompt Loading ─────────────────────────────────────────────────────────


def load_prompts(prompts_file: Path) -> list[dict]:
    """Load benchmark prompts from JSON file."""
    with open(prompts_file) as f:
        return json.load(f)


# ─── Single Prompt Benchmark ────────────────────────────────────────────────


def benchmark_single_prompt(
    llm: Llama,
    prompt_text: str,
    max_tokens: int = 512,
    temperature: float = 0.8,
) -> dict:
    """Run a single prompt with streaming to measure TTFT, tokens/sec, response length.

    Each prompt is run with a fresh context (system prompt + user prompt) so
    measurements are independent and reproducible across runs.
    """
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": prompt_text},
    ]

    t_start = time.perf_counter()
    ttft: float | None = None
    total_content = ""
    chunk_token_count = 0

    # Use streaming API to capture time-to-first-token
    stream = llm.create_chat_completion(
        messages=messages,
        max_tokens=max_tokens,
        temperature=temperature,
        top_p=0.95,
        repeat_penalty=1.1,
        stream=True,
    )

    for chunk in stream:
        choices = chunk.get("choices", [])
        if not choices:
            continue
        delta = choices[0].get("delta", {})
        content = delta.get("content", "")
        if content:
            if ttft is None:
                ttft = time.perf_counter() - t_start
            total_content += content
            chunk_token_count += 1  # Each streaming chunk ≈ 1 token

    t_end = time.perf_counter()
    total_time = t_end - t_start

    # Use tokenizer for accurate token count when available
    token_count = chunk_token_count
    if total_content and hasattr(llm, "tokenize"):
        try:
            accurate_count = len(
                llm.tokenize(total_content.encode("utf-8"), add_bos=False)
            )
            if accurate_count > 0:
                token_count = accurate_count
        except TypeError:
            # Older llama-cpp-python versions may not support add_bos
            try:
                accurate_count = len(
                    llm.tokenize(total_content.encode("utf-8"))
                )
                if accurate_count > 0:
                    token_count = accurate_count
            except Exception:
                pass  # Fall back to chunk count

    tokens_per_sec = token_count / total_time if total_time > 0 else 0.0

    return {
        "ttft_seconds": round(ttft, 4) if ttft is not None else None,
        "total_time_seconds": round(total_time, 4),
        "completion_tokens": token_count,
        "tokens_per_sec": round(tokens_per_sec, 2),
        "response_length_chars": len(total_content),
    }


# ─── Full Model Benchmark ───────────────────────────────────────────────────


def benchmark_model(
    model_path: str,
    prompts: list[dict],
    n_ctx: int = 4096,
    gpu_layers: int = -1,
    max_tokens: int = 512,
) -> dict:
    """Benchmark a single model across all prompts, tracking peak RSS."""
    model_name = Path(model_path).stem
    print(f"\n{'=' * 60}")
    print(f"  Benchmarking: {model_name}")
    print(f"  Context: {n_ctx} | GPU layers: {gpu_layers}")
    print(f"  Prompts: {len(prompts)}")
    print(f"{'=' * 60}")

    # Start memory tracking before model load to capture full RSS impact
    mem_tracker = MemoryTracker()
    mem_tracker.start()

    # Load model
    t_load_start = time.perf_counter()
    try:
        llm = Llama(
            model_path=model_path,
            n_ctx=n_ctx,
            n_gpu_layers=gpu_layers,
            verbose=False,
        )
    except Exception as e:
        mem_tracker.stop()
        return {
            "model_name": model_name,
            "model_path": model_path,
            "error": f"Model load failed: {e}",
        }
    t_load = time.perf_counter() - t_load_start
    print(f"  ✓ Model loaded in {t_load:.2f}s")

    # Run each prompt independently
    prompt_results = []
    for i, prompt_data in enumerate(prompts):
        prompt_text = prompt_data["prompt"]
        prompt_id = prompt_data.get("id", i + 1)
        category = prompt_data.get("category", "unknown")

        print(f"  [{prompt_id}/{len(prompts)}] {category}: ", end="", flush=True)

        try:
            result = benchmark_single_prompt(
                llm, prompt_text, max_tokens=max_tokens
            )
            result["prompt_id"] = prompt_id
            result["category"] = category
            prompt_results.append(result)

            ttft_str = (
                f"{result['ttft_seconds']:.3f}s"
                if result["ttft_seconds"] is not None
                else "N/A"
            )
            print(
                f"{result['completion_tokens']} tok | "
                f"{result['total_time_seconds']:.1f}s | "
                f"{result['tokens_per_sec']:.1f} tok/s | "
                f"TTFT: {ttft_str}"
            )
        except Exception as e:
            print(f"ERROR: {e}")
            prompt_results.append(
                {
                    "prompt_id": prompt_id,
                    "category": category,
                    "error": str(e),
                }
            )

    mem_tracker.stop()

    # Compute aggregates from successful runs
    valid_results = [r for r in prompt_results if "error" not in r]

    if valid_results:
        all_tps = [r["tokens_per_sec"] for r in valid_results]
        all_ttft = [
            r["ttft_seconds"]
            for r in valid_results
            if r["ttft_seconds"] is not None
        ]
        all_lengths = [r["response_length_chars"] for r in valid_results]
        total_tokens = sum(r["completion_tokens"] for r in valid_results)

        avg_tokens_per_sec = sum(all_tps) / len(all_tps)
        min_tokens_per_sec = min(all_tps)
        max_tokens_per_sec = max(all_tps)
        avg_ttft = sum(all_ttft) / len(all_ttft) if all_ttft else 0.0
        min_ttft = min(all_ttft) if all_ttft else 0.0
        max_ttft = max(all_ttft) if all_ttft else 0.0
        avg_response_length = sum(all_lengths) / len(all_lengths)
    else:
        avg_tokens_per_sec = 0.0
        min_tokens_per_sec = 0.0
        max_tokens_per_sec = 0.0
        avg_ttft = 0.0
        min_ttft = 0.0
        max_ttft = 0.0
        avg_response_length = 0.0
        total_tokens = 0

    summary = {
        "model_name": model_name,
        "model_path": model_path,
        "n_ctx": n_ctx,
        "gpu_layers": gpu_layers,
        "model_load_time_seconds": round(t_load, 4),
        "peak_rss_mb": round(mem_tracker.peak_rss_mb, 2),
        "baseline_rss_mb": round(mem_tracker.baseline_rss_mb, 2),
        "model_rss_delta_mb": round(
            mem_tracker.peak_rss_mb - mem_tracker.baseline_rss_mb, 2
        ),
        "prompts_run": len(prompts),
        "prompts_succeeded": len(valid_results),
        "aggregate": {
            "avg_tokens_per_sec": round(avg_tokens_per_sec, 2),
            "min_tokens_per_sec": round(min_tokens_per_sec, 2),
            "max_tokens_per_sec": round(max_tokens_per_sec, 2),
            "avg_ttft_seconds": round(avg_ttft, 4),
            "min_ttft_seconds": round(min_ttft, 4),
            "max_ttft_seconds": round(max_ttft, 4),
            "avg_response_length_chars": round(avg_response_length, 1),
            "total_completion_tokens": total_tokens,
        },
        "per_prompt": prompt_results,
    }

    # Print summary
    print(f"\n  --- Summary ---")
    print(f"  Avg tokens/sec:    {avg_tokens_per_sec:.1f} (min: {min_tokens_per_sec:.1f}, max: {max_tokens_per_sec:.1f})")
    print(f"  Avg TTFT:          {avg_ttft:.3f}s (min: {min_ttft:.3f}s, max: {max_ttft:.3f}s)")
    print(f"  Peak RSS:          {mem_tracker.peak_rss_mb:.1f} MB")
    print(f"  RSS delta (model): {mem_tracker.peak_rss_mb - mem_tracker.baseline_rss_mb:.1f} MB")
    print(f"  Total tokens:      {total_tokens}")
    print(f"  Prompts OK:        {len(valid_results)}/{len(prompts)}")

    return summary


# ─── Main Entry Point ───────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(
        description="DANTE TERMINAL - Quantitative Model Benchmark"
    )
    parser.add_argument(
        "--models",
        nargs="+",
        required=True,
        help="One or more paths to GGUF model files",
    )
    parser.add_argument(
        "--prompts",
        type=str,
        default=str(DEFAULT_PROMPTS_FILE),
        help=f"Path to benchmark prompts JSON (default: {DEFAULT_PROMPTS_FILE})",
    )
    parser.add_argument(
        "--output",
        type=str,
        default=str(DEFAULT_OUTPUT_FILE),
        help=f"Output JSON file for results (default: {DEFAULT_OUTPUT_FILE})",
    )
    parser.add_argument(
        "--ctx", type=int, default=4096, help="Context window size (default: 4096)"
    )
    parser.add_argument(
        "--gpu-layers",
        type=int,
        default=-1,
        help="GPU layers (-1 = all, 0 = CPU only)",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=512,
        help="Max tokens per response (default: 512)",
    )
    args = parser.parse_args()

    # Load prompts
    prompts_path = Path(args.prompts)
    if not prompts_path.exists():
        print(f"ERROR: Prompts file not found: {prompts_path}")
        return 1
    prompts = load_prompts(prompts_path)
    print(f"Loaded {len(prompts)} benchmark prompts from {prompts_path}")

    # Validate model paths
    model_paths = []
    for mp in args.models:
        if not Path(mp).exists():
            print(f"WARNING: Model not found: {mp} — skipping")
        else:
            model_paths.append(mp)

    if not model_paths:
        print("ERROR: No valid model paths provided")
        return 1

    # Run benchmarks
    all_results = {
        "benchmark_version": "1.0",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "system_info": {
            "python_process_pid": os.getpid(),
            "cpu_count": psutil.cpu_count(),
            "total_ram_mb": round(psutil.virtual_memory().total / (1024 * 1024), 1),
        },
        "config": {
            "n_ctx": args.ctx,
            "gpu_layers": args.gpu_layers,
            "max_tokens": args.max_tokens,
            "num_prompts": len(prompts),
        },
        "models": [],
    }

    for model_path in model_paths:
        result = benchmark_model(
            model_path=model_path,
            prompts=prompts,
            n_ctx=args.ctx,
            gpu_layers=args.gpu_layers,
            max_tokens=args.max_tokens,
        )
        all_results["models"].append(result)

    # Write results
    output_path = Path(args.output)
    output_path.write_text(json.dumps(all_results, indent=2))
    print(f"\n✓ Results written to {output_path}")

    # Print comparison table
    print(f"\n{'=' * 70}")
    print(f"  MODEL COMPARISON")
    print(f"{'=' * 70}")
    print(f"  {'Model':<30} {'tok/s':>8} {'TTFT':>8} {'RSS MB':>8}")
    print(f"  {'-' * 30} {'-' * 8} {'-' * 8} {'-' * 8}")
    for m in all_results["models"]:
        if "error" in m:
            print(f"  {m['model_name']:<30} {'ERROR':>24}")
            continue
        agg = m["aggregate"]
        print(
            f"  {m['model_name']:<30} "
            f"{agg['avg_tokens_per_sec']:>8.1f} "
            f"{agg['avg_ttft_seconds']:>7.3f}s "
            f"{m['peak_rss_mb']:>7.1f}"
        )
    print(f"{'=' * 70}\n")

    return 0


if __name__ == "__main__":
    exit(main())
