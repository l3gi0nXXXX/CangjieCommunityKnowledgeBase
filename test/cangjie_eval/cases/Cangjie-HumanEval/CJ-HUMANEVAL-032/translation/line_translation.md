# Line Translation: CJ-HUMANEVAL-032

The official recorder expands the 100 deterministic coefficient inputs only. The Cangjie verifier preserves the official property oracle: each candidate result is accepted when the polynomial residual is strictly below `1e-4`. Plus inputs use canonical allclose only as a fallback when cross-language floating-point projection makes the Cangjie residual unstable; alternate roots that satisfy the residual remain accepted.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `METADATA = {}` | `` |
| 4 | `` | `` |
| 5 | `` | `` |
| 6 | `def check(candidate):` | `` |
| 7 | `    import math` | `` |
| 8 | `    import random` | `` |
| 9 | `    rng = random.Random(42)` | `` |
| 10 | `    import copy` | `` |
| 11 | `    for _ in range(100):` | `` |
| 12 | `        ncoeff = 2 * rng.randint(1, 4)` | `` |
| 13 | `        coeffs = []` | `` |
| 14 | `        for _ in range(ncoeff):` | `` |
| 15 | `            coeff = rng.randint(-10, 10)` | `` |
| 16 | `            if coeff == 0:` | `` |
| 17 | `                coeff = 1` | `` |
| 18 | `            coeffs.append(coeff)` | `` |
| 19 | `        solution = candidate(copy.deepcopy(coeffs))` | `CJ-HUMANEVAL-032_l19_c001, CJ-HUMANEVAL-032_l19_c002, CJ-HUMANEVAL-032_l19_c003, CJ-HUMANEVAL-032_l19_c004, CJ-HUMANEVAL-032_l19_c005, CJ-HUMANEVAL-032_l19_c006, CJ-HUMANEVAL-032_l19_c007, CJ-HUMANEVAL-032_l19_c008, CJ-HUMANEVAL-032_l19_c009, CJ-HUMANEVAL-032_l19_c010, CJ-HUMANEVAL-032_l19_c011, CJ-HUMANEVAL-032_l19_c012, CJ-HUMANEVAL-032_l19_c013, CJ-HUMANEVAL-032_l19_c014, CJ-HUMANEVAL-032_l19_c015, CJ-HUMANEVAL-032_l19_c016, CJ-HUMANEVAL-032_l19_c017, CJ-HUMANEVAL-032_l19_c018, CJ-HUMANEVAL-032_l19_c019, CJ-HUMANEVAL-032_l19_c020, CJ-HUMANEVAL-032_l19_c021, CJ-HUMANEVAL-032_l19_c022, CJ-HUMANEVAL-032_l19_c023, CJ-HUMANEVAL-032_l19_c024, CJ-HUMANEVAL-032_l19_c025, CJ-HUMANEVAL-032_l19_c026, CJ-HUMANEVAL-032_l19_c027, CJ-HUMANEVAL-032_l19_c028, CJ-HUMANEVAL-032_l19_c029, CJ-HUMANEVAL-032_l19_c030, CJ-HUMANEVAL-032_l19_c031, CJ-HUMANEVAL-032_l19_c032, CJ-HUMANEVAL-032_l19_c033, CJ-HUMANEVAL-032_l19_c034, CJ-HUMANEVAL-032_l19_c035, CJ-HUMANEVAL-032_l19_c036, CJ-HUMANEVAL-032_l19_c037, CJ-HUMANEVAL-032_l19_c038, CJ-HUMANEVAL-032_l19_c039, CJ-HUMANEVAL-032_l19_c040, CJ-HUMANEVAL-032_l19_c041, CJ-HUMANEVAL-032_l19_c042, CJ-HUMANEVAL-032_l19_c043, CJ-HUMANEVAL-032_l19_c044, CJ-HUMANEVAL-032_l19_c045, CJ-HUMANEVAL-032_l19_c046, CJ-HUMANEVAL-032_l19_c047, CJ-HUMANEVAL-032_l19_c048, CJ-HUMANEVAL-032_l19_c049, CJ-HUMANEVAL-032_l19_c050, CJ-HUMANEVAL-032_l19_c051, CJ-HUMANEVAL-032_l19_c052, CJ-HUMANEVAL-032_l19_c053, CJ-HUMANEVAL-032_l19_c054, CJ-HUMANEVAL-032_l19_c055, CJ-HUMANEVAL-032_l19_c056, CJ-HUMANEVAL-032_l19_c057, CJ-HUMANEVAL-032_l19_c058, CJ-HUMANEVAL-032_l19_c059, CJ-HUMANEVAL-032_l19_c060, CJ-HUMANEVAL-032_l19_c061, CJ-HUMANEVAL-032_l19_c062, CJ-HUMANEVAL-032_l19_c063, CJ-HUMANEVAL-032_l19_c064, CJ-HUMANEVAL-032_l19_c065, CJ-HUMANEVAL-032_l19_c066, CJ-HUMANEVAL-032_l19_c067, CJ-HUMANEVAL-032_l19_c068, CJ-HUMANEVAL-032_l19_c069, CJ-HUMANEVAL-032_l19_c070, CJ-HUMANEVAL-032_l19_c071, CJ-HUMANEVAL-032_l19_c072, CJ-HUMANEVAL-032_l19_c073, CJ-HUMANEVAL-032_l19_c074, CJ-HUMANEVAL-032_l19_c075, CJ-HUMANEVAL-032_l19_c076, CJ-HUMANEVAL-032_l19_c077, CJ-HUMANEVAL-032_l19_c078, CJ-HUMANEVAL-032_l19_c079, CJ-HUMANEVAL-032_l19_c080, CJ-HUMANEVAL-032_l19_c081, CJ-HUMANEVAL-032_l19_c082, CJ-HUMANEVAL-032_l19_c083, CJ-HUMANEVAL-032_l19_c084, CJ-HUMANEVAL-032_l19_c085, CJ-HUMANEVAL-032_l19_c086, CJ-HUMANEVAL-032_l19_c087, CJ-HUMANEVAL-032_l19_c088, CJ-HUMANEVAL-032_l19_c089, CJ-HUMANEVAL-032_l19_c090, CJ-HUMANEVAL-032_l19_c091, CJ-HUMANEVAL-032_l19_c092, CJ-HUMANEVAL-032_l19_c093, CJ-HUMANEVAL-032_l19_c094, CJ-HUMANEVAL-032_l19_c095, CJ-HUMANEVAL-032_l19_c096, CJ-HUMANEVAL-032_l19_c097, CJ-HUMANEVAL-032_l19_c098, CJ-HUMANEVAL-032_l19_c099, CJ-HUMANEVAL-032_l19_c100` |
| 20 | `        assert math.fabs(poly(coeffs, solution)) < 1e-4` | The same 100 labels from line 19; every label checks `abs(poly(originalCoefficients, candidateResult)) < 0.0001`. |
| 21 | `` | `` |
