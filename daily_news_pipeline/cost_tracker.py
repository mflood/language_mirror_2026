"""
Per-step cost recording for the daily news pipeline.

Each step writes its own report to work/<date>/costs/<step>.json. After the
run completes, `finalize_run` aggregates all step files into a single
timestamped cost ledger entry under cache/cost_history/YYYY/MM/.

Estimated cost rates are conservative ballparks — they're for *trend* visibility,
not invoice reconciliation.
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


# Approximate USD-per-token / per-char rates. Update as pricing changes.
LLM_PRICING = {
    # Anthropic — per million tokens (sonnet 4.5)
    "anthropic": {
        "claude-sonnet-4-5":   {"input_per_mtok": 3.00,  "output_per_mtok": 15.00},
        "claude-opus-4":       {"input_per_mtok": 15.00, "output_per_mtok": 75.00},
        "claude-haiku-4-5":    {"input_per_mtok": 0.80,  "output_per_mtok": 4.00},
    },
    # OpenAI — per million tokens (Nov 2025 published rates)
    "openai": {
        "gpt-4o":              {"input_per_mtok": 2.50,  "output_per_mtok": 10.00},
        "gpt-4o-mini":         {"input_per_mtok": 0.15,  "output_per_mtok": 0.60},
        "gpt-5":               {"input_per_mtok": 1.25,  "output_per_mtok": 10.00},
        "gpt-5.5":             {"input_per_mtok": 2.00,  "output_per_mtok": 10.00},  # placeholder; update with official rates
        "o1":                  {"input_per_mtok": 15.00, "output_per_mtok": 60.00},
    },
}

TTS_PRICING = {
    "elevenlabs": {
        # Approximate Creator-tier credit cost; Korean multi-byte chars cost
        # more credits per char than English, so apply a multiplier.
        "creator": {"per_char_usd": 0.00022, "ko_multiplier": 1.5},
    },
    "polly": {
        "neural":     {"per_char_usd": 4e-6},   # $4 / 1M chars
        "generative": {"per_char_usd": 16e-6},
        "standard":   {"per_char_usd": 4e-6},
    },
}


def estimate_llm_cost(provider: str, model: str, input_tokens: int, output_tokens: int) -> float:
    rates = LLM_PRICING.get(provider, {}).get(model)
    if not rates:
        return 0.0
    return (input_tokens * rates["input_per_mtok"] + output_tokens * rates["output_per_mtok"]) / 1_000_000


def estimate_tts_cost(provider: str, tier_or_engine: str, chars: int, lang: str = "en") -> float:
    rates = TTS_PRICING.get(provider, {}).get(tier_or_engine)
    if not rates:
        return 0.0
    cost = chars * rates["per_char_usd"]
    if provider == "elevenlabs" and lang == "ko":
        cost *= rates.get("ko_multiplier", 1.0)
    return cost


@dataclass
class StepCostRecorder:
    """
    Records cumulative cost stats for a single pipeline step. Writes a JSON
    report to work/<date>/costs/<step>.json on finalize().

    Usage:
        with StepCostRecorder("2_generate_script", work_dir) as rec:
            rec.add_llm_call(provider="anthropic", model="claude-sonnet-4-5",
                             input_tokens=1190, output_tokens=1198,
                             label="script:story_1")
            ...
    """

    step: str
    work_dir: Path
    started_at: str = field(default_factory=lambda: time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
    completed_at: str | None = None
    llm_calls: list[dict] = field(default_factory=list)
    tts_calls: list[dict] = field(default_factory=list)
    extra: dict[str, Any] = field(default_factory=dict)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        self.completed_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        self.write()
        return False

    def add_llm_call(self, *, provider: str, model: str, input_tokens: int, output_tokens: int,
                     label: str = "", response_chars: int | None = None) -> float:
        cost = estimate_llm_cost(provider, model, input_tokens, output_tokens)
        self.llm_calls.append({
            "label": label,
            "provider": provider,
            "model": model,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "response_chars": response_chars,
            "estimated_cost_usd": round(cost, 5),
            "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        })
        return cost

    def add_tts_call(self, *, provider: str, tier_or_engine: str, voice_id: str, voice_label: str,
                     model: str, lang: str, text: str, audio_key: str, cache_hit: bool = False,
                     duration_ms: int | None = None) -> float:
        chars = len(text)
        cost = 0.0 if cache_hit else estimate_tts_cost(provider, tier_or_engine, chars, lang)
        self.tts_calls.append({
            "provider": provider,
            "tier_or_engine": tier_or_engine,
            "voice_id": voice_id,
            "voice_label": voice_label,
            "model": model,
            "lang": lang,
            "chars": chars,
            "audio_key": audio_key,
            "cache_hit": cache_hit,
            "estimated_cost_usd": round(cost, 6),
            "duration_ms": duration_ms,
        })
        return cost

    def totals(self) -> dict:
        llm_total = sum(c["estimated_cost_usd"] for c in self.llm_calls)
        tts_total = sum(c["estimated_cost_usd"] for c in self.tts_calls)
        cache_hits = sum(1 for c in self.tts_calls if c["cache_hit"])
        cache_misses = sum(1 for c in self.tts_calls if not c["cache_hit"])
        return {
            "llm_calls": len(self.llm_calls),
            "llm_input_tokens": sum(c["input_tokens"] for c in self.llm_calls),
            "llm_output_tokens": sum(c["output_tokens"] for c in self.llm_calls),
            "llm_cost_usd": round(llm_total, 5),
            "tts_turns": len(self.tts_calls),
            "tts_cache_hits": cache_hits,
            "tts_cache_misses": cache_misses,
            "tts_chars_debited": sum(c["chars"] for c in self.tts_calls if not c["cache_hit"]),
            "tts_cost_usd": round(tts_total, 5),
            "total_cost_usd": round(llm_total + tts_total, 5),
        }

    def write(self) -> Path:
        if self.completed_at is None:
            self.completed_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        out_dir = self.work_dir / "costs"
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"{self.step}.json"
        payload = {
            "step": self.step,
            "started_at": self.started_at,
            "completed_at": self.completed_at,
            "totals": self.totals(),
            "llm_calls": self.llm_calls,
            "tts_calls": self.tts_calls,
            "extra": self.extra,
        }
        out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return out_path


def finalize_run(work_dir: Path, cache_root: Path, date: str) -> Path:
    """
    Aggregate all work/<date>/costs/*.json files into a single timestamped
    cost ledger entry at cache/cost_history/YYYY/MM/YYYY-MM-DD_HHMMSS.json.
    Returns the written path.
    """
    costs_dir = work_dir / "costs"
    step_files = sorted(costs_dir.glob("*.json")) if costs_dir.exists() else []
    steps_data = {}
    grand_total = 0.0
    llm_total = 0.0
    tts_total = 0.0
    provider_breakdown: dict[str, dict] = {}

    for sf in step_files:
        step = json.loads(sf.read_text(encoding="utf-8"))
        steps_data[step["step"]] = step
        totals = step.get("totals", {})
        grand_total += totals.get("total_cost_usd", 0.0)
        llm_total += totals.get("llm_cost_usd", 0.0)
        tts_total += totals.get("tts_cost_usd", 0.0)
        for c in step.get("llm_calls", []):
            key = f"{c['provider']}/{c['model']}"
            agg = provider_breakdown.setdefault(key, {"calls": 0, "input_tokens": 0, "output_tokens": 0, "cost_usd": 0.0})
            agg["calls"] += 1
            agg["input_tokens"] += c["input_tokens"]
            agg["output_tokens"] += c["output_tokens"]
            agg["cost_usd"] += c["estimated_cost_usd"]
        for c in step.get("tts_calls", []):
            key = f"{c['provider']}/{c['tier_or_engine']}"
            agg = provider_breakdown.setdefault(key, {"calls": 0, "cache_hits": 0, "cache_misses": 0, "chars_debited": 0, "cost_usd": 0.0})
            agg["calls"] = agg.get("calls", 0) + 1
            if c["cache_hit"]:
                agg["cache_hits"] = agg.get("cache_hits", 0) + 1
            else:
                agg["cache_misses"] = agg.get("cache_misses", 0) + 1
                agg["chars_debited"] = agg.get("chars_debited", 0) + c["chars"]
            agg["cost_usd"] = agg.get("cost_usd", 0.0) + c["estimated_cost_usd"]

    # Round provider totals
    for v in provider_breakdown.values():
        v["cost_usd"] = round(v["cost_usd"], 5)

    ts = time.strftime("%H%M%S", time.gmtime())
    out_dir = cache_root / "cost_history" / date[:4] / date[5:7]
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{date}_{ts}.json"

    payload = {
        "date": date,
        "finalized_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "totals": {
            "estimated_cost_usd": round(grand_total, 5),
            "llm_cost_usd": round(llm_total, 5),
            "tts_cost_usd": round(tts_total, 5),
        },
        "providers": provider_breakdown,
        "steps": {k: v.get("totals", {}) for k, v in steps_data.items()},
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return out_path
