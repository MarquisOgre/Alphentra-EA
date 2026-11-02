# Alphentra-EA

A collection repository for acquiring, rebranding, upgrading, and validating trading indicators and integrated algorithmic-trading products under the Alphentra brand.

**Brand:** Alphentra | **Product name:** ELITE APEX | **Tagline:** TRADE BEYOND LIMITS.

## Repository objective

Collect existing indicators and EA source projects, rebrand them consistently under Alphentra, upgrade their UI and functionality, and validate each release.

Where a strategy is converted for Algo Trading, the customer-facing deliverable is one integrated product combining analysis, chart visuals, signals, and optional automated execution. The Indicators and Expert-Advisors directories organize the collection and development sources; they do not imply separately marketed indicator and EA products.

## Structure

```
Alphentra-EA/
├── Indicators/
│   ├── APEX5/
│   ├── Elite APEX/
│   ├── Trend Indicators/
│   ├── Momentum Indicators/
│   ├── SMC Indicators/
│   └── Liquidity Indicators/
├── Expert-Advisors/
│   ├── APEX5 EA/
│   ├── Elite APEX EA/
│   ├── Trend EA/
│   ├── Momentum EA/
│   ├── SMC EA/
│   └── Liquidity EA/
├── Common/
│   ├── Risk Manager/
│   ├── Trade Manager/
│   ├── Signal Engine/
│   └── Notification Engine/
├── Branding/
└── Documentation/
```

## Standards

- Preserve original calculations, buffers, signal conditions, and behavior unless changes are explicitly approved.
- Apply a consistent Alphentra visual identity while retaining each strategy's analytical features.
- Separate strategy logic from reusable execution and risk-management components internally.
- Automated execution is configurable and disabled by default until enabled by the user.
- Validate with MetaEditor compilation, MT5 Strategy Tester, and demo forward testing.
- Record actual changes and test results; do not claim unperformed validation.

## Initial status

This commit defines the collection purpose, structure, and development standards. No source strategy has yet been changed or validated.
