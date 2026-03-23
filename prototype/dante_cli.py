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
from llama_cpp import Llama

# ─── Game Master System Prompt ───────────────────────────────────────────────

SYSTEM_PROMPT = """\
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

    def __init__(self, llm: Llama, max_ctx: int):
        self.llm = llm
        self.max_ctx = max_ctx
        self.messages: list[dict] = [{"role": "system", "content": SYSTEM_PROMPT}]
        self.turn_count = 0

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

    def generate(self, user_input: str | None = None) -> str:
        """Send user input (or opening prompt) and get GM response."""
        if user_input is not None:
            self.messages.append({"role": "user", "content": user_input})
        else:
            self.messages.append({"role": "user", "content": OPENING_PROMPT})

        self._trim_context()
        self.turn_count += 1

        t0 = time.time()
        response = self.llm.create_chat_completion(
            messages=self.messages,
            max_tokens=512,
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

        return reply


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
    opening = session.generate()
    print_gm(opening)

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

        reply = session.generate(user_input)
        print_gm(reply)

    print(f"\n{DIM}Session ended after {session.turn_count} turns.{RESET}")
    print(f"{DIM}Total messages in context: {len(session.messages)}{RESET}\n")


if __name__ == "__main__":
    main()
