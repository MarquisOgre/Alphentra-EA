# ELITE APEX — Algo V2.0
### Alphentra AI | TRADE BEYOND LIMITS.

ELITE APEX Algo V2.0 is an integrated MetaTrader 5 Expert Advisor (EA) combining APEX market-analysis tools, chart visuals and trade planning with automated execution.

> **Risk warning:** Trading involves substantial risk. These settings are defaults, not a profit guarantee or a guarantee that losses will remain within a specified percentage. Test on a demo account before live use.

## 1. Current default Algo configuration

The following values were checked against the repository's `main` branch source.

| Input | Default | Description |
|---|---:|---|
| `InpAlgoTradingEnabled` | `true` | Enables the EA's automated execution logic. |
| `InpAlgoMagicNumber` | `502026` | Identifies APEX-managed positions. |
| `InpAlgoUseRiskPercent` | `false` | Selects fixed-lot sizing when false. |
| `InpAlgoRiskPercent` | `0.10` | Risk-based sizing input; inactive in fixed-lot mode. |
| `InpAlgoFixedLot` | **`0.10`** | Fixed volume requested for each new trade. |
| `InpAlgoMaxPositionsPerSymbol` | `3` | Maximum APEX-managed positions on the current symbol. |
| `InpAlgoMaxTotalPositions` | `10` | Maximum APEX-managed positions across the account. |
| `InpAlgoMaxDailyLossPercent` | `2.00` | Daily equity-loss threshold used to stop new entries. |
| `InpAlgoMaxAggregateRiskPercent` | `2.00` | Maximum calculated combined open risk for APEX-managed positions, as a percentage of equity. |
| `InpAlgoMaxSignalAgeSec` | `120` | Maximum permitted signal age in seconds. |
| `InpAlgoDeviationPoints` | `20` | Maximum price deviation setting passed with trade requests. |
| `InpAlgoMoveToBEAtTP1` | `true` | Attempts to move the position's stop loss to breakeven at TP1. |
| `InpAlgoMoveSLToTP1AtTP2` | `true` | Attempts to move the stop loss to TP1 at TP2. |

### Fixed-lot mode

The current default is **fixed-lot mode**: `InpAlgoUseRiskPercent = false` and `InpAlgoFixedLot = 0.10`.

The EA requests **0.10 lots** for a new trade, subject to symbol volume rules, available margin, trade validation and risk/position safeguards. `InpAlgoRiskPercent = 0.10` does not control sizing while fixed-lot mode is selected. To use risk-based sizing, enable `InpAlgoUseRiskPercent` and configure `InpAlgoRiskPercent`.

## 2. Position limits and account requirements

The defaults allow up to **3 APEX-managed positions per symbol** and **10 APEX-managed positions across the account**. These limits apply to positions identified by the configured APEX magic number; they are not general limits on manual trades or unrelated EAs using different magic numbers.

### Hedging account required

Opening multiple independent positions on the same symbol requires an MT5 **hedging** account. The EA checks the account margin mode and blocks its multi-position execution on a netting account. Contact your broker if you are unsure which account mode you have.

### Aggregate open-risk protection

Before accepting another entry, the EA calculates open risk for APEX-managed positions using their stop-loss levels and checks the proposed trade against the configured aggregate risk ceiling. At the default `2.00%`, new entries can be blocked when calculated combined open risk reaches or would exceed the threshold.

If a managed position has no usable stop loss, or its risk cannot be calculated, the EA may block additional entries rather than assume the risk is safe. This is a safeguard, not a maximum-loss guarantee. Gaps, slippage, spreads and execution conditions can cause actual losses to exceed calculated risk.

### Daily loss protection

The `2.00%` daily loss setting is an entry-control safeguard based on the EA's daily equity tracking. It is not a guaranteed account-level stop-out and does not eliminate losses on positions that are already open.

## 3. TP1, TP2 and position management

The EA manages APEX positions individually:
- At TP1, if `InpAlgoMoveToBEAtTP1` is enabled, it attempts to move that position's stop loss to breakeven.
- At TP2, if `InpAlgoMoveSLToTP1AtTP2` is enabled, it attempts to move that position's stop loss to the TP1 level.

Each position has its own trade-plan state. Management depends on the position being identified and the broker accepting the stop-loss modification. Check MT5 Experts and Journal logs for errors.

## 4. Installation and activation in MetaTrader 5

1. Open MetaTrader 5 and launch MetaEditor.
2. Open `Elite Apex  - Algo V2.0.mq5`.
3. Compile the source in MetaEditor and resolve any errors.
4. In MT5, refresh the Navigator panel if necessary.
5. Attach ELITE APEX Algo V2.0 to the chart for the symbol you want it to trade.
6. In the EA **Inputs** tab, review the lot size, position limits and risk settings.
7. In the **Common** tab, allow algorithmic trading for the EA.
8. Enable the terminal's global **Algo Trading** control.
9. Confirm that the account permits EA trading and that the market is open.

For multiple symbols, attach the EA to the relevant symbol charts. Signals are not guaranteed to become trades: they must pass signal validation, freshness, position, risk, broker and execution checks.

## 5. Alerts and notifications

| Input | Default | Purpose |
|---|---:|---|
| `InpPopupAlert` | `true` | On-screen popup alerts when triggered. |
| `InpSoundAlert` | `true` | Sound alerts when triggered. |
| `InpSoundFile` | `alert2.wav` | Sound file used for alerts. |
| `InpPushAlert` | `false` | MetaTrader mobile push notifications; disabled by default. |

To enable push notifications:
1. Set `InpPushAlert` to `true` in the EA inputs.
2. In MT5 desktop, open **Tools → Options → Notifications**.
3. Enable push notifications and enter the MetaQuotes ID from your MT5 mobile app.
4. Use **Test** to verify delivery.

Push notifications are separate from Telegram channel updates.

## 6. Broker and symbol considerations

Before trading, verify the broker's requirements for each symbol:
- Minimum and maximum trade volume.
- Volume step (whether 0.10 lots is a valid increment).
- Contract size and tick value.
- Minimum stop distance and freeze level.
- Available margin and leverage.
- Trading sessions, spreads and execution conditions.

If 0.10 lots is not valid for a symbol, the broker may reject the order or EA volume validation may prevent it from being sent. A fixed lot is not a fixed percentage of account risk: monetary risk varies with the symbol, stop-loss distance and contract specifications.

## 7. Troubleshooting

If no trade opens, check:
1. Is the correct ELITE APEX Algo V2.0 EA attached?
2. Did the source compile successfully?
3. Is `InpAlgoTradingEnabled` set to `true`?
4. Is MT5 global Algo Trading enabled?
5. Is **Allow Algo Trading** enabled in the EA Common tab?
6. Does the account permit automated trading and use hedging mode?
7. Have the per-symbol or account-wide APEX position limits been reached?
8. Would the entry exceed the aggregate open-risk limit?
9. Has the signal exceeded `InpAlgoMaxSignalAgeSec`?
10. Are volume, margin, stop-distance and trading-session requirements satisfied?
11. Do MT5 **Experts** or **Journal** tabs show a rejection or validation message?

Do not increase risk limits simply to force a trade. Identify the reason for the block first.

## 8. Testing and release checklist

Before using the EA on a live account:
- Compile the exact release source in MetaEditor and resolve errors and warnings.
- Test on a demo account using the intended broker and symbols.
- Test fixed-lot execution, stop-loss placement, TP1/TP2 management, breakeven movement and stop movement to TP1.
- Test position limits, aggregate-risk blocking, daily-loss protection and behavior after terminal or EA restart.
- Verify behavior on the broker's actual hedging account and symbol specifications.
- Review Experts and Journal logs during testing.

**A source-code configuration review is not a substitute for MetaEditor compilation or platform testing.** Do not describe the EA as audited, guaranteed or production-verified unless those checks have actually been completed.

## 9. Project and branding

- **Product:** ELITE APEX — Algo V2.0
- **Brand:** Alphentra AI
- **Tagline:** TRADE BEYOND LIMITS.
- **Telegram:** https://t.me/alphentra
- **Repository:** https://github.com/MarquisOgre/Alphentra-EA

Always obtain the release source from the official repository and verify that you are compiling the intended version.
