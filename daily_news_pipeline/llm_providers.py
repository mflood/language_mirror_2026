"""
LLM provider abstraction. Two implementations today: Anthropic Claude and OpenAI.

Each pipeline step selects its provider via `llm.yaml` (or environment overrides).
The cost tracker records per-call usage with provider+model attribution, so the
same step can use different models on different days and the ledger reflects it.

Adding a new provider: subclass `LLMProvider`, implement `chat`, register in
`make_provider()`.
"""

from __future__ import annotations

import os
from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class LLMResponse:
    text: str
    input_tokens: int
    output_tokens: int
    provider: str
    model: str


class LLMProvider(ABC):
    name: str
    model: str

    @abstractmethod
    def chat(self, prompt: str, max_tokens: int) -> LLMResponse:
        """Single-turn chat. Returns the response text + usage."""


# ─── Anthropic ────────────────────────────────────────────────────────────────


class AnthropicProvider(LLMProvider):
    name = "anthropic"

    def __init__(self, model: str) -> None:
        try:
            from anthropic import Anthropic
        except ImportError as e:
            raise SystemExit(f"anthropic package required: {e}")
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            raise SystemExit("ANTHROPIC_API_KEY is not set")
        self.model = model
        self._client = Anthropic(api_key=api_key)

    def chat(self, prompt: str, max_tokens: int) -> LLMResponse:
        msg = self._client.messages.create(
            model=self.model,
            max_tokens=max_tokens,
            messages=[{"role": "user", "content": prompt}],
        )
        parts = []
        for block in msg.content:
            if getattr(block, "type", None) == "text":
                parts.append(block.text)
        text = "".join(parts).strip()
        usage = getattr(msg, "usage", None)
        in_tok = getattr(usage, "input_tokens", 0) if usage else 0
        out_tok = getattr(usage, "output_tokens", 0) if usage else 0
        return LLMResponse(text=text, input_tokens=in_tok, output_tokens=out_tok,
                           provider=self.name, model=self.model)


# ─── OpenAI ───────────────────────────────────────────────────────────────────


class OpenAIProvider(LLMProvider):
    name = "openai"

    def __init__(self, model: str) -> None:
        try:
            from openai import OpenAI
        except ImportError as e:
            raise SystemExit(f"openai package required: {e}")
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise SystemExit("OPENAI_API_KEY is not set")
        self.model = model
        self._client = OpenAI(api_key=api_key)

    def chat(self, prompt: str, max_tokens: int) -> LLMResponse:
        # Reasoning models (o1, o3) require slightly different params, but
        # chat.completions accepts both. max_tokens semantics: for reasoning
        # models, it's a hard ceiling on visible output (reasoning tokens are
        # separate and billed but unobservable).
        kwargs = {
            "model": self.model,
            "messages": [{"role": "user", "content": prompt}],
        }
        # Newer models (o1/o3/o4 reasoning + gpt-5+) use max_completion_tokens;
        # older gpt-4* / gpt-4o use max_tokens.
        if self.model.startswith(("o1", "o3", "o4", "gpt-5")):
            kwargs["max_completion_tokens"] = max_tokens
        else:
            kwargs["max_tokens"] = max_tokens

        resp = self._client.chat.completions.create(**kwargs)
        text = (resp.choices[0].message.content or "").strip()
        usage = getattr(resp, "usage", None)
        in_tok = getattr(usage, "prompt_tokens", 0) if usage else 0
        out_tok = getattr(usage, "completion_tokens", 0) if usage else 0
        return LLMResponse(text=text, input_tokens=in_tok, output_tokens=out_tok,
                           provider=self.name, model=self.model)


# ─── Factory ──────────────────────────────────────────────────────────────────


PROVIDERS_BY_NAME: dict[str, type[LLMProvider]] = {
    "anthropic": AnthropicProvider,
    "openai": OpenAIProvider,
}


def make_provider(provider_name: str, model: str) -> LLMProvider:
    if provider_name not in PROVIDERS_BY_NAME:
        raise SystemExit(f"unknown LLM provider '{provider_name}'. options: {sorted(PROVIDERS_BY_NAME)}")
    return PROVIDERS_BY_NAME[provider_name](model=model)


def provider_for_step(step_name: str, llm_cfg: dict) -> LLMProvider:
    """Resolve the provider+model for a named pipeline step from llm.yaml."""
    steps_cfg = llm_cfg.get("steps", {})
    step_cfg = steps_cfg.get(step_name)
    if not step_cfg:
        raise SystemExit(f"llm.yaml has no `steps.{step_name}` configuration")
    provider_name = step_cfg.get("provider")
    model = step_cfg.get("model")
    if not provider_name or not model:
        raise SystemExit(f"llm.yaml steps.{step_name} must specify both `provider` and `model`")
    return make_provider(provider_name, model)


def max_tokens_for_step(step_name: str, llm_cfg: dict, default: int = 2048) -> int:
    step_cfg = llm_cfg.get("steps", {}).get(step_name, {})
    return int(step_cfg.get("max_tokens", default))
