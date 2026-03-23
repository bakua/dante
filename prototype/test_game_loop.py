#!/usr/bin/env python3
"""
Automated test: runs the DANTE game loop for N turns with scripted player inputs.
Validates that the model can maintain coherent interactive fiction across turns.

Usage:
    python test_game_loop.py --model /path/to/model.gguf [--ctx 4096] [--turns 7]
"""

import argparse
import json
import time
from pathlib import Path

# Import from dante_cli
from dante_cli import load_model, GameSession

# Scripted player actions for automated testing
TEST_ACTIONS = [
    "Look around the room carefully",
    "Pick up anything that looks useful",
    "Go through the northern door",
    "Examine the walls for hidden passages",
    "Use the torch to light up the dark corridor",
    "Talk to the strange figure in the shadows",
    "Check my inventory",
    "Open the chest carefully",
    "Climb the stone staircase",
    "Read the inscription on the wall",
]


def run_test(model_path: str, n_ctx: int, num_turns: int, gpu_layers: int) -> dict:
    """Run an automated game session and collect results."""
    results = {
        "model_path": model_path,
        "model_name": Path(model_path).stem,
        "n_ctx": n_ctx,
        "turns": [],
        "total_time": 0,
        "errors": [],
        "coherence_maintained": True,
    }

    try:
        llm = load_model(model_path, n_ctx, gpu_layers)
    except Exception as e:
        results["errors"].append(f"Model load failed: {e}")
        return results

    session = GameSession(llm, n_ctx)
    t_start = time.time()

    # Turn 0: opening scene
    try:
        opening = session.generate()
        results["turns"].append({
            "turn": 0,
            "input": "(opening)",
            "output": opening,
            "output_length": len(opening),
            "has_suggestions": _has_suggestions(opening),
        })
        print(f"\n--- OPENING SCENE ---\n{opening}\n")
    except Exception as e:
        results["errors"].append(f"Opening generation failed: {e}")
        results["total_time"] = time.time() - t_start
        return results

    # Turns 1..N
    for i in range(min(num_turns, len(TEST_ACTIONS))):
        action = TEST_ACTIONS[i]
        try:
            reply = session.generate(action)
            has_sug = _has_suggestions(reply)
            results["turns"].append({
                "turn": i + 1,
                "input": action,
                "output": reply,
                "output_length": len(reply),
                "has_suggestions": has_sug,
            })
            print(f"\n--- TURN {i+1}: '{action}' ---\n{reply}\n")

            # Basic coherence check: response should be >20 chars and not identical to previous
            if len(reply) < 20:
                results["errors"].append(f"Turn {i+1}: Response too short ({len(reply)} chars)")
            if i > 0 and reply == results["turns"][-2]["output"]:
                results["errors"].append(f"Turn {i+1}: Identical to previous response")
                results["coherence_maintained"] = False

        except Exception as e:
            results["errors"].append(f"Turn {i+1} failed: {e}")
            break

    results["total_time"] = time.time() - t_start
    results["turns_completed"] = len(results["turns"])
    results["suggestion_rate"] = sum(1 for t in results["turns"] if t["has_suggestions"]) / len(results["turns"]) if results["turns"] else 0

    return results


def _has_suggestions(text: str) -> bool:
    """Check if the response contains numbered action suggestions."""
    lines = text.strip().split("\n")
    numbered = sum(1 for l in lines if l.strip().startswith(("1.", "2.", "3.", "> 1.", "> 2.", "> 3.")))
    return numbered >= 2  # At least 2 of 3 suggestions present


def print_summary(results: dict):
    """Print a human-readable test summary."""
    print("\n" + "=" * 60)
    print(f"MODEL: {results['model_name']}")
    print(f"CONTEXT: {results['n_ctx']} tokens")
    print(f"TURNS COMPLETED: {results.get('turns_completed', 0)}")
    print(f"TOTAL TIME: {results['total_time']:.1f}s")
    print(f"SUGGESTION RATE: {results.get('suggestion_rate', 0):.0%}")
    print(f"COHERENCE: {'✓ Maintained' if results['coherence_maintained'] else '✗ Lost'}")
    if results["errors"]:
        print(f"ERRORS ({len(results['errors'])}):")
        for e in results["errors"]:
            print(f"  - {e}")
    else:
        print("ERRORS: None")
    print("=" * 60)


def main():
    parser = argparse.ArgumentParser(description="DANTE TERMINAL - Automated Test")
    parser.add_argument("--model", required=True, help="Path to GGUF model file")
    parser.add_argument("--ctx", type=int, default=4096, help="Context window size")
    parser.add_argument("--turns", type=int, default=7, help="Number of player turns to simulate")
    parser.add_argument("--gpu-layers", type=int, default=-1, help="GPU layers (-1 = all)")
    parser.add_argument("--output", type=str, default=None, help="Save JSON results to file")
    args = parser.parse_args()

    results = run_test(args.model, args.ctx, args.turns, args.gpu_layers)
    print_summary(results)

    if args.output:
        # Save without the full output text to keep file small
        save_results = {**results}
        save_results["turns"] = [
            {k: v for k, v in t.items() if k != "output"}
            for t in results["turns"]
        ]
        Path(args.output).write_text(json.dumps(save_results, indent=2))
        print(f"\nResults saved to {args.output}")

    return 0 if not results["errors"] and results.get("turns_completed", 0) >= 5 else 1


if __name__ == "__main__":
    exit(main())
