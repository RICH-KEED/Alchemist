# Architecture Debate — Advocate & Judge Format

## Advocate brief (one per candidate)

```
## Advocate: [Candidate Name]

### Scores (1-5, evidence-linked)

| Criterion | Score | Evidence |
|---|---|---|
| [Criterion 1] | 4 | [link / data point / benchmark — version & date] |
| [Criterion 2] | 3 | [evidence] |
| ... | | |

### Strengths (top 3, with evidence)
1. **
2. **
3. **

### Weaknesses (real ones, not strawmen — be honest)
1. ** — Mitigation: **
2. **

### Attacks on alternatives (specific, evidence-backed)
- Against [Candidate B]: **
- Against [Candidate C]: **

### Ecosystem snapshot
- Version: [latest stable]
- Pub score: [score] | GitHub stars: [N] | Last commit: [date]
- Community: [Discord/StackOverflow activity, issue close rate]
- Production users: [known apps using it]

### Mitigation plan (for the weakest criterion)
- Risk: **
- Mitigation: **
- Cost to implement mitigation: [estimate]
```

---

## Judge decision matrix & recommendation

```
## Decision Matrix (judge-adjusted)

| Criterion (weight) | [Candidate A] | [Candidate B] | [Candidate C] |
|---|---|---|---|
| C1 (w=0.xx) | 4 | 3 | 2 |
| C2 (w=0.xx) | 3 | 5 | 3 |
| ... | | | |
| **Weighted Total** | X.XX | X.XX | X.XX |

### Cross-examination findings
- [Candidate A] advocate claimed [claim] — judge verdict: [upheld / weakened / overturned] because **
- [Candidate B] advocate claimed [claim] — judge verdict: **

### Recommendation
- **Winner:** [Candidate X] — weighted score: X.XX
- **Margin:** X.XX over runner-up [Candidate Y]
- **Top risk:** **
- **Mitigation:** **
- **Plan B (runner-up):** [Candidate Y] — what would make us switch:
  - Trigger 1: **
  - Trigger 2: **

### ADR-ready summary
- Context: [the decision question + constraints]
- Decision: [the winner + one-line why]
- Alternatives considered: [runner-up + why not]
- Consequences: [top risk + mitigation]
```
