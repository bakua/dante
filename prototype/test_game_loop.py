#!/usr/bin/env python3
"""
Automated test: runs the DANTE game loop for N turns with scripted player inputs.
Validates that the model can maintain coherent interactive fiction across turns.

Produces structured per-turn quality scores for before/after comparison (BL-043).

Usage:
    python test_game_loop.py --model /path/to/model.gguf [--ctx 4096] [--turns 7]
    python test_game_loop.py --model /path/to/model.gguf --legacy  # use old prompt
"""

import argparse
import json
import re
import time
from pathlib import Path

# Import from dante_cli
from dante_cli import load_model, GameSession, LEGACY_SYSTEM_PROMPT, SYSTEM_PROMPT

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


# ─── Per-Turn Scoring ────────────────────────────────────────────────────────

def score_turn(text: str, turn_num: int) -> dict:
    """Score a single GM response on multiple quality dimensions.
    Each dimension is scored 0-5. Returns dict with scores and rationale.
    """
    scores = {}

    # 1. Suggestion compliance: does it have exactly 3 suggestions?
    suggestion_count = _count_suggestions(text)
    if suggestion_count == 3:
        scores["suggestion_compliance"] = 5
    elif suggestion_count == 2:
        scores["suggestion_compliance"] = 3
    elif suggestion_count >= 1:
        scores["suggestion_compliance"] = 1
    else:
        scores["suggestion_compliance"] = 0

    # 2. Response length: target 60-90 words (BL-013)
    # Extract narrative portion (before suggestions)
    narrative = _extract_narrative(text)
    word_count = len(narrative.split())
    if 60 <= word_count <= 90:
        scores["length_compliance"] = 5
    elif 45 <= word_count <= 120:
        scores["length_compliance"] = 3
    elif 30 <= word_count <= 150:
        scores["length_compliance"] = 2
    else:
        scores["length_compliance"] = 0

    # 3. Sensory detail: check for sensory words
    sensory_words = [
        "smell", "scent", "odor", "stench", "aroma", "fragrant",
        "sound", "hear", "echo", "whisper", "creak", "hum", "rumble",
        "touch", "feel", "cold", "warm", "rough", "smooth", "damp", "wet",
        "taste", "bitter", "metallic", "sweet", "sour",
        "light", "dark", "shadow", "glow", "dim", "bright", "shimmer",
        "dust", "rust", "stone", "iron", "wood",
    ]
    text_lower = text.lower()
    sensory_hits = sum(1 for w in sensory_words if w in text_lower)
    if sensory_hits >= 4:
        scores["sensory_detail"] = 5
    elif sensory_hits >= 2:
        scores["sensory_detail"] = 3
    elif sensory_hits >= 1:
        scores["sensory_detail"] = 2
    else:
        scores["sensory_detail"] = 0

    # 4. Suggestion quality: are suggestions concise (3-7 words)?
    suggestions = _extract_suggestions(text)
    if suggestions:
        sug_word_counts = [len(s.split()) for s in suggestions]
        good_length = sum(1 for wc in sug_word_counts if 3 <= wc <= 10)
        scores["suggestion_quality"] = min(5, good_length * 2)  # 0,2,4 for 0,1,2+ good
    else:
        scores["suggestion_quality"] = 0

    # 5. Format quality: clean separation between narrative and suggestions
    has_clean_format = bool(re.search(r'\n\s*>\s*1\.', text))
    scores["format_quality"] = 5 if has_clean_format else (2 if suggestion_count > 0 else 0)

    # Composite score (average of all dimensions)
    scores["composite"] = round(sum(scores.values()) / len(scores), 1)
    scores["word_count"] = word_count
    scores["suggestion_count"] = suggestion_count

    return scores


def _count_suggestions(text: str) -> int:
    """Count numbered suggestions in the text."""
    lines = text.strip().split("\n")
    count = 0
    for line in lines:
        stripped = line.strip()
        if re.match(r'^>\s*\d+\.', stripped) or re.match(r'^\d+\.', stripped):
            count += 1
    return count


def _extract_narrative(text: str) -> str:
    """Extract the narrative portion (before suggestions)."""
    lines = text.strip().split("\n")
    narrative_lines = []
    for line in lines:
        stripped = line.strip()
        if re.match(r'^>\s*\d+\.', stripped) or re.match(r'^\d+\.\s', stripped):
            break
        if stripped:
            narrative_lines.append(stripped)
    return " ".join(narrative_lines)


def _extract_suggestions(text: str) -> list[str]:
    """Extract suggestion text from numbered lines."""
    suggestions = []
    for line in text.strip().split("\n"):
        m = re.match(r'^\s*>?\s*\d+\.\s*(.+)', line.strip())
        if m:
            suggestions.append(m.group(1).strip())
    return suggestions


def _has_suggestions(text: str) -> bool:
    """Check if the response contains numbered action suggestions."""
    return _count_suggestions(text) >= 2


# ─── Test Runner ─────────────────────────────────────────────────────────────

def run_test(model_path: str, n_ctx: int, num_turns: int, gpu_layers: int,
             use_legacy: bool = False) -> dict:
    """Run an automated game session and collect results with per-turn scores."""
    prompt_label = "legacy" if use_legacy else "production"
    system_prompt = LEGACY_SYSTEM_PROMPT if use_legacy else SYSTEM_PROMPT

    results = {
        "model_path": model_path,
        "model_name": Path(model_path).stem,
        "n_ctx": n_ctx,
        "prompt_variant": prompt_label,
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

    session = GameSession(llm, n_ctx, system_prompt=system_prompt)
    t_start = time.time()

    # Turn 0: opening scene
    try:
        result = session.generate()
        text = result["text"]
        turn_scores = score_turn(text, 0)
        results["turns"].append({
            "turn": 0,
            "input": "(opening)",
            "output": text,
            "output_length": len(text),
            "has_suggestions": _has_suggestions(text),
            "scores": turn_scores,
            "prompt_tokens": result["prompt_tokens"],
            "completion_tokens": result["completion_tokens"],
            "elapsed": round(result["elapsed"], 2),
            "tok_per_sec": round(result["tok_per_sec"], 1),
        })
        print(f"\n--- OPENING SCENE ---\n{text}\n")
    except Exception as e:
        results["errors"].append(f"Opening generation failed: {e}")
        results["total_time"] = time.time() - t_start
        return results

    # Turns 1..N
    for i in range(min(num_turns, len(TEST_ACTIONS))):
        action = TEST_ACTIONS[i]
        try:
            result = session.generate(action)
            text = result["text"]
            has_sug = _has_suggestions(text)
            turn_scores = score_turn(text, i + 1)
            results["turns"].append({
                "turn": i + 1,
                "input": action,
                "output": text,
                "output_length": len(text),
                "has_suggestions": has_sug,
                "scores": turn_scores,
                "prompt_tokens": result["prompt_tokens"],
                "completion_tokens": result["completion_tokens"],
                "elapsed": round(result["elapsed"], 2),
                "tok_per_sec": round(result["tok_per_sec"], 1),
            })
            print(f"\n--- TURN {i+1}: '{action}' ---\n{text}\n")

            # Basic coherence check: response should be >20 chars and not identical to previous
            if len(text) < 20:
                results["errors"].append(f"Turn {i+1}: Response too short ({len(text)} chars)")
            if i > 0 and text == results["turns"][-2]["output"]:
                results["errors"].append(f"Turn {i+1}: Identical to previous response")
                results["coherence_maintained"] = False

        except Exception as e:
            results["errors"].append(f"Turn {i+1} failed: {e}")
            break

    results["total_time"] = round(time.time() - t_start, 1)
    results["turns_completed"] = len(results["turns"])
    results["suggestion_rate"] = round(
        sum(1 for t in results["turns"] if t["has_suggestions"]) / len(results["turns"])
        if results["turns"] else 0, 2
    )

    # Aggregate scores across all turns
    if results["turns"]:
        all_scores = [t["scores"] for t in results["turns"]]
        dimensions = [k for k in all_scores[0] if k not in ("composite", "word_count", "suggestion_count")]
        results["aggregate_scores"] = {}
        for dim in dimensions:
            values = [s[dim] for s in all_scores]
            results["aggregate_scores"][dim] = round(sum(values) / len(values), 2)
        composites = [s["composite"] for s in all_scores]
        results["aggregate_scores"]["composite"] = round(sum(composites) / len(composites), 2)
        results["aggregate_scores"]["avg_word_count"] = round(
            sum(s["word_count"] for s in all_scores) / len(all_scores), 1
        )

    return results


def print_summary(results: dict):
    """Print a human-readable test summary with per-turn scores."""
    print("\n" + "=" * 70)
    print(f"MODEL: {results['model_name']}")
    print(f"PROMPT: {results.get('prompt_variant', 'unknown')}")
    print(f"CONTEXT: {results['n_ctx']} tokens")
    print(f"TURNS COMPLETED: {results.get('turns_completed', 0)}")
    print(f"TOTAL TIME: {results['total_time']}s")
    print(f"SUGGESTION RATE: {results.get('suggestion_rate', 0):.0%}")
    print(f"COHERENCE: {'OK' if results['coherence_maintained'] else 'LOST'}")

    # Per-turn score table
    if results["turns"]:
        print(f"\n{'Turn':<5} {'Words':<6} {'Sug#':<5} {'SugCompl':<9} {'Length':<7} {'Sensory':<8} {'SugQual':<8} {'Format':<7} {'Composite':<10}")
        print("-" * 70)
        for t in results["turns"]:
            s = t["scores"]
            print(f"{t['turn']:<5} {s['word_count']:<6} {s['suggestion_count']:<5} "
                  f"{s['suggestion_compliance']:<9} {s['length_compliance']:<7} "
                  f"{s['sensory_detail']:<8} {s['suggestion_quality']:<8} "
                  f"{s['format_quality']:<7} {s['composite']:<10}")

    # Aggregate
    if "aggregate_scores" in results:
        agg = results["aggregate_scores"]
        print(f"\nAGGREGATE SCORES:")
        for k, v in agg.items():
            print(f"  {k}: {v}")

    if results["errors"]:
        print(f"\nERRORS ({len(results['errors'])}):")
        for e in results["errors"]:
            print(f"  - {e}")
    else:
        print("\nERRORS: None")
    print("=" * 70)


def main():
    parser = argparse.ArgumentParser(description="DANTE TERMINAL - Automated Test")
    parser.add_argument("--model", required=True, help="Path to GGUF model file")
    parser.add_argument("--ctx", type=int, default=4096, help="Context window size")
    parser.add_argument("--turns", type=int, default=7, help="Number of player turns to simulate")
    parser.add_argument("--gpu-layers", type=int, default=-1, help="GPU layers (-1 = all)")
    parser.add_argument("--output", type=str, default=None, help="Save JSON results to file")
    parser.add_argument("--legacy", action="store_true",
                        help="Use legacy (pre-research) system prompt for comparison")
    args = parser.parse_args()

    results = run_test(args.model, args.ctx, args.turns, args.gpu_layers,
                       use_legacy=args.legacy)
    print_summary(results)

    if args.output:
        # Save full results including output text and scores
        Path(args.output).write_text(json.dumps(results, indent=2))
        print(f"\nResults saved to {args.output}")

    return 0 if not results["errors"] and results.get("turns_completed", 0) >= 5 else 1


if __name__ == "__main__":
    exit(main())
