# BL-210: Quality Rubric Application — Spectrum Evaluation of 10 Interactive Fiction Responses

> **BL-210** | Evaluated: 2026-03-26 | Rubric: BL-171 | Status: **COMPLETE**
>
> Purpose: Demonstrate subjective quality evaluation on a spectrum (not just binary pass/fail) by applying the BL-171 6-dimension rubric to 10 interactive fiction responses.

---

## Summary

Applied the BL-171 evaluation rubric to 10 interactive fiction responses (6 from MockInferenceBackend, 4 hand-crafted at varying quality levels) and scored each on all 6 dimensions (D1-D6) using the 1-5 integer scale with anchored descriptors. Composite scores ranged from 1.67 to 4.83, demonstrating full-spectrum evaluation capability. The evaluation identifies D5 (World State Tracking) and D6 (Response Length) as the weakest dimensions across the mock response set, while D1 (Narrative Coherence) and D4 (Tone Consistency) are consistently strongest.

---

## Key Findings

1. **Composite scores span the full quality range** (1.67 to 4.83), confirming the rubric can differentiate between poor, adequate, good, and excellent responses — not just pass/fail.

2. **MockInferenceBackend responses cluster in the 3.33-4.00 range** (adequate to good). This is encouraging for the product: the canned responses used in demo/mock mode meet the BL-171 "SHIP WITH CAVEATS" threshold individually.

3. **D5 (World State Tracking) is the weakest dimension** across all responses, averaging 2.80. Even the best mock responses score 3-4 here because canned responses are inherently stateless — they can't reference prior turns or inventory changes. This dimension will be the critical test when evaluating live Qwen2-1.5B inference.

4. **D6 (Response Length) is the second weakest** at 3.10 average. Five of the six mock responses fall in the 48-55 word range, consistently below the 60-90 word target. This is a tunable parameter — the system prompt or max_tokens setting can push responses longer.

5. **D4 (Tone Consistency) is the strongest dimension** at 3.70. The mock responses consistently maintain dark, atmospheric language without fourth-wall breaks. Response R04 ("voice like rustling pages", "nose that barely exists") achieved a perfect 5.

6. **The rubric successfully identifies catastrophic failures.** R07 (fourth-wall break) scored 1.67 composite with three dimension-1 scores and a critical failure flag. The rubric's "automatic NO-SHIP" rule for fourth-wall breaks correctly triggers here.

7. **The rubric differentiates between types of weakness.** R08 (stub response) and R07 (chatbot mode) both score poorly but for entirely different reasons — R08 fails on length and atmosphere, R07 fails on tone and state tracking. This dimensional granularity is what spectrum evaluation provides over binary pass/fail.

---

## Analysis: Dimension-by-Dimension

### Strongest Dimensions

| Dimension | Average | Assessment |
|---|---|---|
| **D1: Narrative Coherence** | 3.70 | The mock responses consistently build cause-and-effect chains. R03 (discovery scene) scored 5 for its trace→seam→wall pivots→alcove flow. Only intentionally degraded responses (R07, R08) scored below 3. |
| **D4: Tone Consistency** | 3.70 | Atmospheric language is reliable across the mock set. Sensory details (smell, sound, touch) appear in every mock response. The sardonic edge is occasionally missing but the baseline is solid. |

### Weakest Dimensions

| Dimension | Average | Assessment |
|---|---|---|
| **D5: World State Tracking** | 2.80 | Structural weakness: canned responses can't reference prior turns. The best score was 4 (R06, R09), achieved by referencing inventory items. Live inference must demonstrate D5 >= 3.0 on multi-turn scenarios. |
| **D6: Response Length** | 3.10 | Five of six mocks are 48-55 words (below 60 target). Individually each reads well, but the terminal UI was designed for 60-90 words. Prompt engineering or token budget adjustments could fix this. |

### Middle Dimensions

| Dimension | Average | Assessment |
|---|---|---|
| **D2: Command Parsing** | 3.50 | Mock responses are generic (not responding to specific commands), so scoring is conservative. Live inference should score higher here since it actually receives and processes player input. |
| **D3: Suggestion Relevance** | 3.60 | Consistently scene-specific suggestions in the mocks. R03 and R09 scored 5 with non-obvious, curiosity-rewarding options. The generic suggestions in R07/R08 pulled the average down. |

---

## Quality Distribution

```
5.0 |
4.5 | ██ R09 (4.83)
4.0 | ██ R03 (4.00)
3.5 | ██████████ R01(3.67) R04(3.67) R06(3.83) R02(3.50) R10(3.50)
3.0 | ████ R05 (3.33)
2.5 |
2.0 | ██ R08 (2.00)
1.5 | ██ R07 (1.67)
1.0 |
```

- **1 response >= 4.0** (R09: 4.83) — demonstrates the rubric can identify excellence
- **5 responses in 3.5-4.0** — the "SHIP" / "SHIP WITH CAVEATS" zone
- **2 responses in 3.0-3.5** — adequate quality
- **1 response at 2.0** — below average, identifiable weakness
- **1 response at 1.67** — critical failure, automatically detectable

---

## Recommendations

1. **Readiness criterion "Evaluate subjective output" is now demonstrably met.** This evaluation produced per-response dimensional scores on a 1-5 spectrum, composite ratings, quality distribution analysis, and actionable dimensional insights — not binary pass/fail.

2. **When live Qwen2-1.5B inference is available, prioritize re-running this evaluation** with the 10 BL-171 test scenarios. The mock response analysis establishes a baseline; live inference results will be directly comparable using the same scoring methodology.

3. **D5 (World State Tracking) is the highest-risk dimension for live inference.** The 1.5B parameter model may struggle to maintain multi-turn context. Prepare mitigation: (a) aggressive location context injection (already implemented in BL-162), (b) explicit state summaries in the system prompt, (c) shorter context windows to reduce confusion.

4. **D6 (Response Length) is the most tunable dimension.** If mock responses are representative of Qwen2-1.5B's natural output length, increase the "60-90 words" instruction emphasis in the system prompt or set a higher minimum in the GBNF grammar.

5. **The rubric and scoring methodology should be codified as a reusable evaluation pipeline** — the quality_scores.json format can serve as the schema for automated evaluation in CI, enabling regression detection on prompt changes.

---

## Sources

- BL-171: Prompt Quality Evaluation Rubric (6-dimension rubric, 10 test scenarios, thresholds)
- MockInferenceBackend: `dante_terminal/lib/services/mock_inference_backend.dart` (6 canned responses)
- 4 hand-crafted responses authored at intentionally varied quality levels for spectrum demonstration

---

*Evaluation conducted: 2026-03-26. Methodology: BL-171 rubric applied by AI evaluator to static response text. For production go/no-go decisions, re-evaluate with live Qwen2-1.5B inference on physical device per BL-171 Section 4.*
