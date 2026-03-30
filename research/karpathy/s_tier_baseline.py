#!/usr/bin/env python3
"""
S-Tier Colony Baseline & Rank Modifier System
===============================================
Karpathy Incremental Research - Smoke & Honey

This module defines what an S-tier colony looks like -- the absolute upper
end of real-world beekeeping performance -- and provides multipliers to
derive B through F rank performance from that S-tier baseline.

All validation targets across phases 1-8 should reference these constants.
The philosophy:
  - S-tier = elite colony: exceptional queen, ideal conditions, top 5% real-world
  - A-tier = excellent colony: strong queen, good management, top 20%
  - B-tier = average managed colony: typical hobbyist result
  - C-tier = declining colony: aging queen, some stress
  - D-tier = struggling colony: failing queen, disease pressure
  - F-tier = dead/queenless colony: no viable reproduction

Real-world science backing S-tier numbers:
  - Winston (1987): peak laying 2,000+ eggs/day for superior queens
  - Seeley (1995): feral colony peaks at 40-60k; managed can hit 80k
  - USDA/NCA: top-performing colonies produce 200+ lbs harvestable honey
  - Farrar (1943): well-managed colonies winter with 20-30k bees
  - Laidlaw & Page (1997): queen quality directly correlates to all outputs

Game calendar: 8 months x 28 days = 224 days/year. 5 years = 1120 days.
"""


# ===========================================================================
# QUEEN GRADE SYSTEM
# ===========================================================================
# Grade multipliers applied to S-tier baseline to derive each rank
GRADE_MULTIPLIERS = {
    "S": 1.00,   # S-tier IS the baseline (1.25x of old A-tier base)
    "A": 0.85,   # Excellent but not exceptional
    "B": 0.70,   # Average managed colony
    "C": 0.55,   # Declining
    "D": 0.35,   # Struggling
    "F": 0.00,   # Dead/queenless
}

# Grade multipliers on queen laying rate specifically
# (slightly different curve -- laying drops faster than other metrics)
LAYING_GRADE_MULTIPLIERS = {
    "S": 1.00,
    "A": 0.85,
    "B": 0.70,
    "C": 0.55,
    "D": 0.35,
    "F": 0.00,
}


# ===========================================================================
# S-TIER QUEEN CONSTANTS
# ===========================================================================
# An S-tier queen at peak (year 2, midsummer, no stress):
S_QUEEN_PEAK_LAYING = 2000       # eggs/day at peak season (Wide-Clover/High-Sun)
S_QUEEN_LAYING_RANGE = (1800, 2000)  # daily range during peak season

# Queen laying rate ranges by grade (eggs/day at peak season)
GRADE_LAYING_RANGES = {
    "S": (1800, 2000),    # Elite: consistent high output
    "A": (1500, 1700),    # Excellent
    "B": (1200, 1400),    # Average
    "C": (800, 1100),     # Declining
    "D": (300, 700),      # Struggling
    "F": (0, 0),          # Queenless
}


# ===========================================================================
# S-TIER POPULATION TARGETS (per year, 224-day cycle)
# ===========================================================================
# These are what the simulation should hit for an S-tier colony:
S_SUMMER_PEAK_ADULTS = (55000, 70000)    # summer peak adult population
S_WINTER_MIN_ADULTS = (20000, 30000)     # winter cluster minimum
S_FORAGER_PEAK = (20000, 28000)          # peak forager count midsummer
S_DRONE_PEAK = (300, 600)               # peak drone count

# Derived targets for other grades:
def grade_population_targets(grade: str) -> dict:
    """Return population targets for a given grade."""
    m = GRADE_MULTIPLIERS[grade]
    return {
        "summer_peak": (int(S_SUMMER_PEAK_ADULTS[0] * m), int(S_SUMMER_PEAK_ADULTS[1] * m)),
        "winter_min": (int(S_WINTER_MIN_ADULTS[0] * m), int(S_WINTER_MIN_ADULTS[1] * m)),
        "forager_peak": (int(S_FORAGER_PEAK[0] * m), int(S_FORAGER_PEAK[1] * m)),
    }


# ===========================================================================
# S-TIER HONEY PRODUCTION TARGETS (per 224-day year)
# ===========================================================================
S_ANNUAL_PRODUCTION = (300, 500)       # lbs gross honey produced per year
S_HARVESTABLE_HONEY = (100, 160)       # lbs harvestable after leaving winter stores
S_WINTER_CONSUMPTION = (25, 45)        # lbs consumed over winter (56 days)
S_PEAK_HONEY_STORES = (80, 150)        # lbs peak stores before harvest

def grade_honey_targets(grade: str) -> dict:
    """Return honey production targets for a given grade."""
    m = GRADE_MULTIPLIERS[grade]
    return {
        "annual_production": (int(S_ANNUAL_PRODUCTION[0] * m), int(S_ANNUAL_PRODUCTION[1] * m)),
        "harvestable": (int(S_HARVESTABLE_HONEY[0] * m), int(S_HARVESTABLE_HONEY[1] * m)),
        "winter_consumption": (int(S_WINTER_CONSUMPTION[0] * m), int(S_WINTER_CONSUMPTION[1] * m)),
    }


# ===========================================================================
# S-TIER BROOD TARGETS
# ===========================================================================
S_PEAK_BROOD = (25000, 30000)          # peak total brood cells (midsummer)
S_DAILY_EMERGENCE = (1500, 2000)       # daily bee emergence at peak
S_BROOD_NEST_COVERAGE = 0.85           # fraction of brood zone utilized

def grade_brood_targets(grade: str) -> dict:
    """Return brood targets for a given grade."""
    m = GRADE_MULTIPLIERS[grade]
    return {
        "peak_brood": (int(S_PEAK_BROOD[0] * m), int(S_PEAK_BROOD[1] * m)),
        "daily_emergence": (int(S_DAILY_EMERGENCE[0] * m), int(S_DAILY_EMERGENCE[1] * m)),
    }


# ===========================================================================
# S-TIER DISEASE RESISTANCE
# ===========================================================================
# An S-tier colony has natural varroa resistance traits:
S_VARROA_TOLERANCE = 0.85              # 85% of mites removed by grooming (VSH trait)
S_VARROA_DOUBLING_DAYS = (50, 80)      # slower varroa growth due to hygiene
S_DISEASE_RESISTANCE = 0.90            # 90% chance of self-curing minor infections

# Lower grades have progressively worse disease management:
VARROA_GRADE_DOUBLING = {
    "S": (50, 80),      # VSH/hygienic behavior slows mite growth
    "A": (45, 70),      # Good hygiene
    "B": (40, 60),      # Average
    "C": (35, 55),      # Below average
    "D": (30, 50),      # Poor hygiene
    "F": (25, 40),      # No resistance
}


# ===========================================================================
# S-TIER ENVIRONMENT RESPONSE
# ===========================================================================
# S-tier colonies respond better to environmental conditions:
S_FORAGE_EFFICIENCY = (1.05, 1.25)     # above-average nectar collection
S_THERMOREGULATION = 0.95              # 95% efficient cluster heating

FORAGE_EFFICIENCY_BY_GRADE = {
    "S": (1.05, 1.25),
    "A": (0.95, 1.15),
    "B": (0.85, 1.05),
    "C": (0.70, 0.90),
    "D": (0.55, 0.75),
    "F": (0.00, 0.00),
}


# ===========================================================================
# S-TIER 5-YEAR MILESTONES
# ===========================================================================
# What an S-tier colony should achieve each year of a 5-year run:
# (assuming queen is replaced when she degrades naturally)
S_5YEAR_MILESTONES = {
    1: {"peak_adults": 60000, "honey_produced": 350, "harvestable": 120},
    2: {"peak_adults": 65000, "honey_produced": 400, "harvestable": 140},  # queen peaks yr 2
    3: {"peak_adults": 60000, "honey_produced": 350, "harvestable": 120},  # slight decline
    4: {"peak_adults": 55000, "honey_produced": 300, "harvestable": 100},  # queen aging
    5: {"peak_adults": 50000, "honey_produced": 280, "harvestable": 90},   # needs requeening
}


# ===========================================================================
# COLONY SIM DEFAULT STARTING CONDITIONS (S-Tier)
# ===========================================================================
S_STARTING_CONDITIONS = {
    "honey_stores": 25.0,          # lbs (well-provisioned)
    "pollen_stores": 5.0,          # lbs
    "initial_brood_daily": 1200,   # brood cohort per day in pipeline at start
    "nurse_count": 12000,
    "house_count": 14000,
    "forager_count": 10000,
    "drone_count": 400,
    "queen_grade": "S",
    "queen_age_days": 0,
    "queen_base_rate": 2000,
}

# Starting conditions for B-tier (the default "average" colony)
B_STARTING_CONDITIONS = {
    "honey_stores": 15.0,
    "pollen_stores": 3.0,
    "initial_brood_daily": 800,
    "nurse_count": 8000,
    "house_count": 10000,
    "forager_count": 6000,
    "drone_count": 300,
    "queen_grade": "B",
    "queen_age_days": 0,
    "queen_base_rate": 1350,
}


# ===========================================================================
# CALENDAR CONSTANTS (shared across all phases)
# ===========================================================================
YEAR_LENGTH = 224
MONTH_LENGTH = 28
MONTHS_PER_YEAR = 8
SEASON_FACTORS = [0.55, 0.80, 1.00, 1.00, 0.65, 0.35, 0.08, 0.05]
MONTH_NAMES = [
    "Quickening", "Greening", "Wide-Clover", "High-Sun",
    "Full-Earth", "Reaping", "Deepcold", "Kindlemonth",
]


# ===========================================================================
# HELPER FUNCTIONS
# ===========================================================================
def get_grade_mult(grade: str) -> float:
    """Get the overall grade multiplier."""
    return GRADE_MULTIPLIERS.get(grade, 0.70)  # default to B if unknown


def apply_grade(s_tier_value, grade: str):
    """Apply grade multiplier to an S-tier value (int or float)."""
    m = GRADE_MULTIPLIERS[grade]
    if isinstance(s_tier_value, int):
        return int(s_tier_value * m)
    return s_tier_value * m


def apply_grade_range(s_tier_range: tuple, grade: str) -> tuple:
    """Apply grade multiplier to an S-tier (min, max) range."""
    m = GRADE_MULTIPLIERS[grade]
    return (int(s_tier_range[0] * m), int(s_tier_range[1] * m))


def describe_grade(grade: str) -> str:
    """Human-readable description of a grade."""
    descriptions = {
        "S": "Elite (top 5% real-world)",
        "A": "Excellent (top 20%)",
        "B": "Average managed colony",
        "C": "Declining colony",
        "D": "Struggling colony",
        "F": "Dead/queenless",
    }
    return descriptions.get(grade, "Unknown")


# ===========================================================================
# VALIDATION TARGET BUILDER
# ===========================================================================
def build_validation_targets(grade: str = "S") -> dict:
    """
    Build complete validation target set for a given grade.
    Used by all phase test scripts to know what numbers to hit.
    """
    m = GRADE_MULTIPLIERS[grade]
    return {
        "grade": grade,
        "grade_mult": m,
        "description": describe_grade(grade),

        # Queen
        "queen_peak_laying": apply_grade_range(S_QUEEN_LAYING_RANGE, grade),
        "queen_base_rate": int(S_QUEEN_PEAK_LAYING * m),

        # Population
        "summer_peak_adults": apply_grade_range(S_SUMMER_PEAK_ADULTS, grade),
        "winter_min_adults": apply_grade_range(S_WINTER_MIN_ADULTS, grade),
        "forager_peak": apply_grade_range(S_FORAGER_PEAK, grade),

        # Honey
        "annual_production": apply_grade_range(S_ANNUAL_PRODUCTION, grade),
        "harvestable_honey": apply_grade_range(S_HARVESTABLE_HONEY, grade),
        "winter_consumption": apply_grade_range(S_WINTER_CONSUMPTION, grade),
        "peak_honey_stores": apply_grade_range(S_PEAK_HONEY_STORES, grade),

        # Brood
        "peak_brood": apply_grade_range(S_PEAK_BROOD, grade),
        "daily_emergence": apply_grade_range(S_DAILY_EMERGENCE, grade),

        # Disease
        "varroa_doubling_days": VARROA_GRADE_DOUBLING.get(grade, (40, 60)),

        # Efficiency
        "forage_efficiency": FORAGE_EFFICIENCY_BY_GRADE.get(grade, (0.85, 1.05)),

        # Starting conditions
        "starting": S_STARTING_CONDITIONS if grade == "S" else B_STARTING_CONDITIONS,
    }


# ===========================================================================
# Print summary when run directly
# ===========================================================================
if __name__ == "__main__":
    print("=" * 70)
    print("S-TIER COLONY BASELINE & RANK MODIFIER SYSTEM")
    print("Smoke & Honey - Karpathy Research Machine")
    print("=" * 70)

    for grade in ["S", "A", "B", "C", "D", "F"]:
        targets = build_validation_targets(grade)
        print(f"\n--- Grade {grade}: {targets['description']} (mult={targets['grade_mult']:.2f}) ---")
        print(f"  Queen peak laying:    {targets['queen_peak_laying']}")
        print(f"  Summer peak adults:   {targets['summer_peak_adults']}")
        print(f"  Winter min adults:    {targets['winter_min_adults']}")
        print(f"  Annual honey prod:    {targets['annual_production']} lbs")
        print(f"  Harvestable honey:    {targets['harvestable_honey']} lbs")
        print(f"  Winter consumption:   {targets['winter_consumption']} lbs")
        print(f"  Peak brood cells:     {targets['peak_brood']}")
        print(f"  Varroa doubling:      {targets['varroa_doubling_days']} days")
        print(f"  Forage efficiency:    {targets['forage_efficiency']}")
