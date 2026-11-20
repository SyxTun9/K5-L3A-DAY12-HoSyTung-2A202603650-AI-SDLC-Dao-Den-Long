# ADR-001: Lamp fuel and dawn victory

**Status:** Accepted for Phase 3 (Contract 1.2)

Each lantern stores `ever_lit`, `lit`, remaining fuel, and partial deposit progress. Fuel is integer subunits at 60 units per displayed fuel point so one fuel point per second and stacked shade drain stay deterministic at 60 Hz. An extinguished lantern keeps its history and needs five motes to relight; lighting it again counts toward the player's growing carry capacity.

Victory is checked only at dawn. The player must still have a flame and at least `ceil(0.6 × lantern_count)` lamps must be lit. This keeps the objective meaningful while fuel can run out before dawn. No-flame loss takes priority on the final tick. Dawn victory awards points for surviving fuel and remaining flames, without a time-left bonus.
