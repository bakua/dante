#!/usr/bin/env python3
"""
DANTE TERMINAL - CLI Text Adventure Prototype
Loads a GGUF model via llama-cpp-python and runs an interactive fiction game loop.
Validates: model quality, prompt structure, and context window management.

Usage:
    python dante_cli.py --model /path/to/model.gguf [--ctx 4096] [--turns 20]
"""

import argparse
import time
from pathlib import Path
from llama_cpp import Llama

# ─── Game Master System Prompt ───────────────────────────────────────────────
# Legacy prompt preserved for before/after comparison (BL-043)

LEGACY_SYSTEM_PROMPT = """\
You are the Game Master of a classic text adventure game in the spirit of Zork \
and Colossal Cave Adventure. You narrate an immersive, atmospheric dungeon-crawl \
adventure with vivid but concise descriptions (2-4 sentences per scene).

Rules you MUST follow:
- Describe the environment, objects, and any characters present.
- React logically to the player's freeform commands. If a command is nonsensical, \
  gently redirect ("You can't do that here, but you notice...").
- Track game state implicitly: remember items the player picks up, doors opened, \
  enemies defeated, and rooms visited.
- After EVERY response, print exactly 3 suggested actions the player might take, \
  formatted as:
  > 1. [action]
  > 2. [action]
  > 3. [action]
- Keep a sense of mystery, danger, and discovery. Reward curiosity.
- Never break character. You ARE the dungeon — ancient, sardonic, and fair.\
"""

# Production prompt loaded from file — synthesizes BL-010, BL-013, BL-028, BL-036
_PROMPT_FILE = Path(__file__).parent / "game_master_prompt.txt"
SYSTEM_PROMPT = _PROMPT_FILE.read_text().strip() if _PROMPT_FILE.exists() else LEGACY_SYSTEM_PROMPT

# Repeat-instruction anchor placed near generation point (BL-036 §2.3)
STYLE_ANCHOR = "[Style: sardonic narrator, sensory detail, max 90 words. Exactly 3 suggestions.]"

OPENING_PROMPT = "Begin the adventure. Describe the opening scene where the player awakens."

# ─── Model Loader ────────────────────────────────────────────────────────────

def load_model(model_path: str, n_ctx: int, n_gpu_layers: int = -1) -> Llama:
    """Load a GGUF model with llama-cpp-python."""
    print(f"\n⏳ Loading model: {model_path}")
    print(f"   Context window: {n_ctx} tokens | GPU layers: {n_gpu_layers}")
    t0 = time.time()
    llm = Llama(
        model_path=model_path,
        n_ctx=n_ctx,
        n_gpu_layers=n_gpu_layers,
        verbose=False,
    )
    elapsed = time.time() - t0
    print(f"   ✓ Model loaded in {elapsed:.1f}s\n")
    return llm


# ─── Chat Engine ─────────────────────────────────────────────────────────────

class GameSession:
    """Manages the conversation with context window awareness."""

    def __init__(self, llm: Llama, max_ctx: int, system_prompt: str | None = None):
        self.llm = llm
        self.max_ctx = max_ctx
        self.system_prompt = system_prompt or SYSTEM_PROMPT
        self.messages: list[dict] = [{"role": "system", "content": self.system_prompt}]
        self.turn_count = 0
        # BL-036: use anchor note near generation point for persona maintenance
        self.use_anchor = (self.system_prompt != LEGACY_SYSTEM_PROMPT)

    def _trim_context(self):
        """Keep system prompt + last N turns to stay within context budget.
        Reserve ~800 tokens for the response and keep conversation manageable."""
        # Rough estimate: 4 chars ≈ 1 token
        max_chars = (self.max_ctx - 800) * 4
        while self._estimate_chars() > max_chars and len(self.messages) > 3:
            # Remove oldest user/assistant pair (keep system prompt at index 0)
            self.messages.pop(1)
            if len(self.messages) > 1 and self.messages[1]["role"] == "assistant":
                self.messages.pop(1)

    def _estimate_chars(self) -> int:
        return sum(len(m["content"]) for m in self.messages)

    def generate(self, user_input: str | None = None) -> dict:
        """Send user input (or opening prompt) and get GM response.
        Returns dict with 'text', 'prompt_tokens', 'completion_tokens',
        'elapsed', 'tok_per_sec' for structured scoring.
        """
        if user_input is not None:
            content = user_input
        else:
            content = OPENING_PROMPT

        # BL-036 §2.3: Inject anchor note before the player message
        # to exploit recency bias and maintain persona/format compliance
        if self.use_anchor and self.turn_count > 0:
            self.messages.append({"role": "system", "content": STYLE_ANCHOR})

        self.messages.append({"role": "user", "content": content})

        self._trim_context()
        self.turn_count += 1

        # BL-036 §4.4: max_tokens=200 caps response length (was 512)
        # Combined with few-shot calibration + anchor for triple redundancy
        max_tok = 200 if self.use_anchor else 512

        t0 = time.time()
        response = self.llm.create_chat_completion(
            messages=self.messages,
            max_tokens=max_tok,
            temperature=0.8,
            top_p=0.95,
            repeat_penalty=1.1,
        )
        elapsed = time.time() - t0

        reply = response["choices"][0]["message"]["content"].strip()
        tokens_used = response.get("usage", {})
        prompt_tokens = tokens_used.get("prompt_tokens", 0)
        completion_tokens = tokens_used.get("completion_tokens", 0)

        self.messages.append({"role": "assistant", "content": reply})

        # Print stats for benchmarking
        tps = completion_tokens / elapsed if elapsed > 0 else 0
        print(f"  [{self.turn_count}] {completion_tokens} tok | {elapsed:.1f}s | {tps:.1f} tok/s | ctx: {prompt_tokens}+{completion_tokens}")

        return {
            "text": reply,
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "elapsed": elapsed,
            "tok_per_sec": tps,
        }


# ─── Terminal UI ─────────────────────────────────────────────────────────────

GREEN = "\033[32m"
DIM = "\033[2m"
BOLD = "\033[1m"
RESET = "\033[0m"

def print_gm(text: str):
    """Print Game Master output in green."""
    print(f"\n{GREEN}{text}{RESET}\n")

def print_banner():
    print(f"""{GREEN}{BOLD}
╔══════════════════════════════════════════╗
║         D A N T E   T E R M I N A L     ║
║        ~ CLI Prototype v0.1 ~           ║
╚══════════════════════════════════════════╝{RESET}
{DIM}Type your commands in plain English. Type 'quit' to exit.{RESET}
""")


# ─── Main Loop ───────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="DANTE TERMINAL - CLI Text Adventure")
    parser.add_argument("--model", required=True, help="Path to GGUF model file")
    parser.add_argument("--ctx", type=int, default=4096, help="Context window size (default: 4096)")
    parser.add_argument("--turns", type=int, default=20, help="Max turns before auto-quit (default: 20)")
    parser.add_argument("--gpu-layers", type=int, default=-1, help="GPU layers (-1 = all, 0 = CPU only)")
    args = parser.parse_args()

    llm = load_model(args.model, args.ctx, args.gpu_layers)
    session = GameSession(llm, args.ctx)

    print_banner()
    print(f"{DIM}Generating opening scene...{RESET}")

    # Opening scene
    result = session.generate()
    print_gm(result["text"])

    # Game loop
    while session.turn_count < args.turns:
        try:
            user_input = input(f"{BOLD}> {RESET}").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n\nAdventure paused. Farewell, traveler.")
            break

        if not user_input:
            continue
        if user_input.lower() in ("quit", "exit", "q"):
            print("\nThe dungeon fades to black. Until next time...")
            break

        result = session.generate(user_input)
        print_gm(result["text"])

    print(f"\n{DIM}Session ended after {session.turn_count} turns.{RESET}")
    print(f"{DIM}Total messages in context: {len(session.messages)}{RESET}\n")


if __name__ == "__main__":
    main()
