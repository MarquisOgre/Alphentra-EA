//+------------------------------------------------------------------+
//|                                      APEX_DTC_Elite_v1.2.mq5     |
//|     APEX ELITE V5.1  +  DTC EMA STACK  •  FULL HYBRID            |
//|     Liquidity • Structure • Order Blocks • FVG • DOM             |
//|     Multi-Symbol Scanner • Session Ranges • Crystal Trade Plan   |
//|     Detailed Alerts • High-Visibility Color Schema               |
//|     BUILD 1.20  •  Complete Production Version                   |
//+------------------------------------------------------------------+
#property copyright   "APEX + DTC Elite Hybrid"
#property link        ""
#property version     "1.20"
#property description "Institutional SMC engine + DTC EMA Stack confluence"
#property description "Full Scanner, Session Boxes, OP/SL/TP1-3/BE Trade Plan"
#property description "Detailed Alerts with Entry, SL, TP1, TP2, TP3, BE"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

//--- EMA Ribbon (DTC)
#property indicator_label1  "EMA 30"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#property indicator_label2  "EMA 35"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLime
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "EMA 40"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLime
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "EMA 45"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrLime
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

#property indicator_label5  "EMA 50"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrLime
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6  "EMA 60"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrLime
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//==================================================================
// ENUMS
//==================================================================
enum ENUM_EA_MODE
{
   EA_OFF   = 0,   // Off (signal-only)
   EA_GV    = 1,   // GlobalVariables
   EA_FILE  = 2,   // JSON file
   EA_EVENT = 3,   // ChartEvent
   EA_ALL   = 4    // All channels
};

//==================================================================
// INPUT PARAMETERS
//==================================================================
input group "▄ CORE ENGINE ▀"
input ENUM_TIMEFRAMES InpSetupTF        = PERIOD_M5;     // Setup timeframe
input ENUM_TIMEFRAMES InpHTFTF          = PERIOD_H1;     // Higher timeframe bias
input int    InpBarsToAnalyze           = 400;           // Bars to analyze
input int    InpSwingStrength           = 3;             // Swing strength

input group "▄ DTC EMA RIBBON ▀"
input int    InpEMA1                    = 30;            // EMA 1
input int    InpEMA2                    = 35;            // EMA 2
input int    InpEMA3                    = 40;            // EMA 3
input int    InpEMA4                    = 45;            // EMA 4
input int    InpEMA5                    = 50;            // EMA 5
input int    InpEMA6                    = 60;            // EMA 6
input int    InpEMAConfluenceScore      = 12;            // Extra score when stack aligns

input group "▄ DTC MULTI-TIMEFRAME ▀"
input ENUM_TIMEFRAMES InpTF1            = PERIOD_M15;    // 15M
input ENUM_TIMEFRAMES InpTF2            = PERIOD_M30;    // 30M
input ENUM_TIMEFRAMES InpTF3            = PERIOD_H1;     // 1H
input ENUM_TIMEFRAMES InpTF4            = PERIOD_H4;     // 4H
input ENUM_TIMEFRAMES InpTF5            = PERIOD_D1;     // Daily
input int    InpMTFScoreWeight          = 8;             // Score per aligned TF

input group "▄ ORDER BOOK (DOM) ▀"
input bool   InpUseDOM                  = true;          // Enable DOM engine
input double InpDOMImbalanceThr         = 0.20;          // Imbalance threshold
input bool   InpRequireDOMAgree         = false;         // Block if DOM against
input int    InpDOMScoreWeight          = 10;            // DOM score weight

input group "▄ STRUCTURE ▀"
input bool   InpRequireBOS              = false;         // Require BOS
input bool   InpRequireMSS              = false;         // Require MSS
input int    InpBOSBufferPoints         = 10;            // Break buffer (points)

input group "▄ LIQUIDITY ▀"
input bool   InpUsePrevDay              = true;          // Previous day high/low
input bool   InpUsePrevWeek             = true;          // Previous week high/low
input bool   InpUseSwingLiq             = true;          // Swing liquidity
input bool   InpUseEqualLiq             = true;          // Equal highs/lows
input int    InpEqualTolPoints          = 50;            // Equal level tolerance
input int    InpSweepBufPoints          = 10;            // Sweep wick buffer
input int    InpReclaimPoints           = 5;             // Reclaim buffer
input int    InpSweepWindow             = 3;             // Sweep lookback bars

input group "▄ DISPLACEMENT ▀"
input bool   InpUseDisplacement         = true;
input double InpDispFactor              = 1.40;
input int    InpDispLookback            = 10;

input group "▄ ZONES (OB / FVG) ▀"
input bool   InpUseOrderBlocks          = true;
input bool   InpUseFVG                  = true;
input int    InpFVGMinPoints            = 30;

input group "▄ PREMIUM / DISCOUNT ▀"
input bool   InpUsePDZone               = true;
input double InpPDLevel                 = 0.40;
input int    InpRangeLookback           = 60;

input group "▄ HTF / TIME ▀"
input bool   InpUseHTFAlign             = true;
input bool   InpUseKillzones            = true;
input double InpKZ1Start                = 10.0;          // London start (server)
input double InpKZ1Hours                = 2.0;
input double InpKZ2Start                = 16.5;          // NY start (server)
input double InpKZ2Hours                = 3.0;
input bool   InpUseSessionFilter        = false;
input int    InpSessionStartHour        = 7;
input int    InpSessionEndHour          = 22;

input group "▄ SPREAD ▀"
input bool   InpUseSpreadFilter         = true;
input double InpMaxSpreadPoints         = 500;

input group "▄ SCORING ▀"
input int    InpMinimumScore            = 60;
input int    InpScoreMargin             = 10;
input int    InpAScore                  = 78;
input int    InpAPlusScore              = 90;

input group "▄ RISK GOVERNOR ▀"
input bool   InpAntiOvertrade           = true;
input int    InpCooldownMinutes         = 15;
input int    InpMaxSignalsDay           = 6;
input int    InpMaxSignalsSession       = 3;
input bool   InpOppositeLock            = true;
input bool   InpOnePerBar               = true;

input group "▄ TRADE LEVELS ▀"
input bool   InpShowPreview             = true;
input int    InpSLBufferPoints          = 30;
input double InpSLATRMult               = 0.35;
input double InpMaxSLATRMult            = 2.5;
input double InpFallbackSLATR           = 1.5;
input double InpTP1RR                   = 1.5;
input double InpTP2RR                   = 2.0;
input double InpTP3RR                   = 3.0;
input double InpBreakEvenRR             = 1.0;

input group "▄ EA EXECUTION HOOKS ▀"
input ENUM_EA_MODE InpEAMode            = EA_GV;
input string InpEANamespace             = "APEX5";
input bool   InpEAFileCommon            = true;
input int    InpEAEventID               = 777001;

input group "▄ MULTI-SYMBOL SCANNER ▀"
input bool   InpScannerOn               = true;
input string InpScanList                = "EURUSD,GBPUSD,USDJPY,XAUUSD,US30,NAS100,BTCUSD";
input int    InpScanIntervalSec         = 15;
input int    InpScanMaxRows             = 12;
input int    InpScanAlertScore          = 78;
input int    InpScanPanelX              = 370;
input int    InpScanPanelY              = 26;

input group "▄ SESSION RANGES ▀"
input bool   InpSessionsOn              = true;
input bool   InpSessExtendActive        = true;
input bool   InpSessShowMidline         = true;
input bool   InpSess1On                 = true;
input string InpSess1Name               = "ASIA";
input double InpSess1Start              = 1.0;
input double InpSess1Hours              = 8.0;
input bool   InpSess2On                 = true;
input string InpSess2Name               = "LONDON";
input double InpSess2Start              = 10.0;
input double InpSess2Hours              = 6.0;
input bool   InpSess3On                 = true;
input string InpSess3Name               = "NEWYORK";
input double InpSess3Start              = 16.5;
input double InpSess3Hours              = 6.0;

input group "▄ VISUAL ▀"
input bool   InpShowPanel               = true;
input ENUM_BASE_CORNER InpPanelCorner   = CORNER_LEFT_UPPER;
input int    InpPanelX                  = 12;
input int    InpPanelY                  = 22;
input int    InpPanelWidth              = 350;
input bool   InpShowLiqLines            = true;
input bool   InpShowZones               = true;
input bool   InpShowSweepMarks          = true;
input bool   InpShowTradePlan           = true;
input bool   InpShowArrow               = true;
input int    InpPlanBars                = 30;

input group "▄ ALERTS ▀"
input bool   InpPopupAlert              = true;
input bool   InpSoundAlert              = true;
input string InpSoundFile               = "alert2.wav";
input bool   InpPushAlert               = false;

//==================================================================
// HIGH-VISIBILITY COLOR SCHEMA (AI Optimized)
//==================================================================
color clrPanelBG      = C'11,15,23';       // Deep navy
color clrHeaderBG     = C'17,23,35';
color clrBorder       = C'42,52,72';
color clrTextMain     = C'228,233,243';
color clrTextDim      = C'115,125,145';
color clrAccent       = C'255,193,7';       // Amber gold
color clrBuy          = C'0,230,118';       // Neon emerald
color clrSell         = C'255,82,82';       // Neon coral
color clrOP           = C'255,255,255';
color clrSL           = C'255,82,82';
color clrTP           = C'0,230,118';
color clrBE           = C'255,213,0';
color clrRiskFill     = C'68,16,26';
color clrRewardFill   = C'8,52,38';
color clrLiqPD        = C'255,193,7';
color clrLiqPW        = C'135,145,170';
color clrLiqEQ        = C'255,135,45';
color clrOBBullFill   = C'5,46,38';
color clrOBBullLine   = C'0,195,135';
color clrOBBearFill   = C'52,12,18';
color clrOBBearLine   = C'235,65,65';
color clrFVGBullFill  = C'6,36,58';
color clrFVGBullLine  = C'0,145,215';
color clrFVGBearFill  = C'48,28,6';
color clrFVGBearLine  = C'235,155,45';
color clrSessAsia     = C'200,155,35';
color clrSessLondon   = C'45,165,215';
color clrSessNY       = C'215,85,155';
color clrScanSignal   = C'18,48,32';
color clrScanNormal   = C'16,20,30';

//==================================================================
// GLOBAL VARIABLES
//==================================================================
#define PFX      "APEXDTC_"
#define MAX_SW   24
#define MAX_ZN   4
#define MAX_CD   20
#define MAX_SCAN 24
#define MAX_SES  3

// EMA Buffers
double EMA1Buffer[], EMA2Buffer[], EMA3Buffer[], EMA4Buffer[], EMA5Buffer[], EMA6Buffer[];
int    handleEMA1, handleEMA2, handleEMA3, handleEMA4, handleEMA5, handleEMA6;

// DTC Multi-Timeframe
bool   g_mtfBull[5], g_mtfBear[5];
string g_mtfText[5];

// Core state
datetime g_lastBarT   = 0;
uint     g_lastUI     = 0;

// Risk governor
int      g_daily = 0, g_sess = 0, g_dayNum = -1;
datetime g_lastSignal = 0, g_lastSignalBar = 0;
int      g_lastDir = 0;

// Results
int      g_buyScore = 0, g_sellScore = 0;
string   g_signal = "INIT", g_block = "", g_quality = "—";
string   g_htf = "—", g_trend = "—", g_event = "—", g_regime = "—";
string   g_pdZone = "—", g_kz = "—", g_sweepTxt = "—";
bool     g_kzActive = false;
double   g_pdPct = 0.5;
bool     g_htfBull = false, g_htfBear = false;
bool     g_bullBreak = false, g_bearBreak = false;
bool     g_bullMSS = false, g_bearMSS = false;
bool     g_emaBull = false, g_emaBear = false;

// Liquidity
double   g_pdh = 0, g_pdl = 0, g_pwh = 0, g_pwl = 0;
double   g_eqh = 0, g_eql = 0;
int      g_eqhN = 0, g_eqlN = 0;
double   g_nearAbove = 0, g_nearBelow = 0;
string   g_aboveTag = "-", g_belowTag = "-";
double   g_candAP[MAX_CD]; string g_candAT[MAX_CD]; int g_candAN = 0;
double   g_candBP[MAX_CD]; string g_candBT[MAX_CD]; int g_candBN = 0;

// Swings
double   g_swH[MAX_SW]; datetime g_swHT[MAX_SW]; int g_swHN = 0;
double   g_swL[MAX_SW]; datetime g_swLT[MAX_SW]; int g_swLN = 0;

// Zones
double   g_bobTop[MAX_ZN], g_bobBot[MAX_ZN]; datetime g_bobTime[MAX_ZN]; int g_bobN = 0;
double   g_sobTop[MAX_ZN], g_sobBot[MAX_ZN]; datetime g_sobTime[MAX_ZN]; int g_sobN = 0;
double   g_bfvTop[MAX_ZN], g_bfvBot[MAX_ZN]; datetime g_bfvTime[MAX_ZN]; int g_bfvN = 0;
double   g_sfvTop[MAX_ZN], g_sfvBot[MAX_ZN]; datetime g_sfvTime[MAX_ZN]; int g_sfvN = 0;
bool     g_inBullOB = false, g_inBearOB = false;
bool     g_inBullFVG = false, g_inBearFVG = false;
double   g_bobSL = 0, g_sobSL = 0;

// Sweep
bool     g_sweepFound = false, g_sweepIsLow = false;
double   g_sweepPx = 0;
datetime g_sweepT = 0;

// DOM
bool     g_domBook = false, g_domHas = false;
double   g_domBidV = 0, g_domAskV = 0, g_domImb = 0;
double   g_domBidWP = 0, g_domBidWV = 0, g_domAskWP = 0, g_domAskWV = 0;
int      g_domLv = 0;
long     g_tickDelta = 0;
double   g_lastBid = 0;

// Trade Plan
double   g_op = 0, g_sl = 0, g_tp1 = 0, g_tp2 = 0, g_tp3 = 0, g_be = 0;
int      g_riskPts = 0;
string   g_targetTag = "-";
bool     g_planBuy = true, g_confirmed = false;
datetime g_signalTime = 0;

// EA
long     g_eaSeq = 0;

// Scanner
string   g_scanSyms[];
int      g_scanN = 0;
int      g_scanOrder[];
double   g_scanBuy[], g_scanSell[];
int      g_scanDir[], g_scanGrade[];
double   g_scanSpread[];
datetime g_scanBar[], g_scanAlerted[];
string   g_scanTrend[], g_scanHTF[], g_scanState[];
uint     g_scanLastRun = 0;

// Sessions
string   g_sesName[MAX_SES];
bool     g_sesOn[MAX_SES];
double   g_sesStart[MAX_SES], g_sesHours[MAX_SES];
color    g_sesFill[MAX_SES], g_sesLine[MAX_SES];
double   g_sesHi[MAX_SES], g_sesLo[MAX_SES];
datetime g_sesT1[MAX_SES], g_sesT2[MAX_SES];
bool     g_sesActive[MAX_SES];
int      g_sesSweep[MAX_SES];
int      g_sesTick = 0;

//==================================================================
// INITIALIZATION
//==================================================================
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "APEX+DTC Elite v1.2");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   DeleteByPrefix(PFX);

   // EMA Buffers
   SetIndexBuffer(0, EMA1Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, EMA2Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, EMA3Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, EMA4Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, EMA5Buffer, INDICATOR_DATA);
   SetIndexBuffer(5, EMA6Buffer, INDICATOR_DATA);

   ArraySetAsSeries(EMA1Buffer, true);
   ArraySetAsSeries(EMA2Buffer, true);
   ArraySetAsSeries(EMA3Buffer, true);
   ArraySetAsSeries(EMA4Buffer, true);
   ArraySetAsSeries(EMA5Buffer, true);
   ArraySetAsSeries(EMA6Buffer, true);

   handleEMA1 = iMA(_Symbol, PERIOD_CURRENT, InpEMA1, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA2 = iMA(_Symbol, PERIOD_CURRENT, InpEMA2, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA3 = iMA(_Symbol, PERIOD_CURRENT, InpEMA3, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA4 = iMA(_Symbol, PERIOD_CURRENT, InpEMA4, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA5 = iMA(_Symbol, PERIOD_CURRENT, InpEMA5, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA6 = iMA(_Symbol, PERIOD_CURRENT, InpEMA6, 0, MODE_EMA, PRICE_CLOSE);

   if(handleEMA1 == INVALID_HANDLE || handleEMA2 == INVALID_HANDLE ||
      handleEMA3 == INVALID_HANDLE || handleEMA4 == INVALID_HANDLE ||
      handleEMA5 == INVALID_HANDLE || handleEMA6 == INVALID_HANDLE)
   {
      Print("APEX+DTC: Failed to create EMA handles");
      return(INIT_FAILED);
   }

   if(InpUseDOM)
      g_domBook = MarketBookAdd(_Symbol);

   SessionsInit();
   if(InpScannerOn) ScannerInit();
   if(InpSessionsOn) RefreshSessions();

   if(InpScannerOn || InpSessionsOn || InpEAMode == EA_GV || InpEAMode == EA_ALL)
      EventSetTimer(1);

   ResetDailyCounter();
   Print("APEX+DTC Elite v1.2 initialized successfully");
   return(INIT_SUCCEEDED);
}

//==================================================================
// DEINITIALIZATION
//==================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_domBook) MarketBookRelease(_Symbol);
   DeleteByPrefix(PFX);
   ChartRedraw(0);
}

//==================================================================
// DOM EVENT
//==================================================================
void OnBookEvent(const string &symbol)
{
   if(symbol != _Symbol) return;
   UpdateDOM();
   UIDraw();
}

void UpdateDOM()
{
   MqlBookInfo book[];
   if(!MarketBookGet(_Symbol, book))
   {
      g_domHas = false;
      return;
   }
   int n = ArraySize(book);
   if(n <= 0)
   {
      g_domHas = false;
      return;
   }

   double bv = 0, av = 0;
   double bwV = 0, bwP = 0, awV = 0, awP = 0;

   for(int i = 0; i < n; i++)
   {
      bool isBuy = (book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET);
      double v = (double)book[i].volume;

      if(isBuy)
      {
         bv += v;
         if(v > bwV) { bwV = v; bwP = book[i].price; }
      }
      else
      {
         av += v;
         if(v > awV) { awV = v; awP = book[i].price; }
      }
   }

   g_domBidV = bv;
   g_domAskV = av;
   g_domLv   = n;
   g_domBidWP = bwP;
   g_domBidWV = bwV;
   g_domAskWP = awP;
   g_domAskWV = awV;
   g_domImb   = (bv + av) > 0 ? (bv - av) / (bv + av) : 0.0;
   g_domHas   = true;
}

//==================================================================
// MAIN CALCULATION
//==================================================================
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 150) return(0);

   // Copy EMA buffers
   if(CopyBuffer(handleEMA1, 0, 0, rates_total, EMA1Buffer) <= 0) return(0);
   if(CopyBuffer(handleEMA2, 0, 0, rates_total, EMA2Buffer) <= 0) return(0);
   if(CopyBuffer(handleEMA3, 0, 0, rates_total, EMA3Buffer) <= 0) return(0);
   if(CopyBuffer(handleEMA4, 0, 0, rates_total, EMA4Buffer) <= 0) return(0);
   if(CopyBuffer(handleEMA5, 0, 0, rates_total, EMA5Buffer) <= 0) return(0);
   if(CopyBuffer(handleEMA6, 0, 0, rates_total, EMA6Buffer) <= 0) return(0);

   // EMA Stack detection
   g_emaBull = (EMA1Buffer[0] > EMA2Buffer[0] &&
                EMA2Buffer[0] > EMA3Buffer[0] &&
                EMA3Buffer[0] > EMA4Buffer[0] &&
                EMA4Buffer[0] > EMA5Buffer[0] &&
                EMA5Buffer[0] > EMA6Buffer[0]);

   g_emaBear = (EMA1Buffer[0] < EMA2Buffer[0] &&
                EMA2Buffer[0] < EMA3Buffer[0] &&
                EMA3Buffer[0] < EMA4Buffer[0] &&
                EMA4Buffer[0] < EMA5Buffer[0] &&
                EMA5Buffer[0] < EMA6Buffer[0]);

   // Dynamic ribbon color
   color emaCol = g_emaBull ? clrBuy : (g_emaBear ? clrSell : clrGray);
   for(int p = 0; p < 6; p++)
      PlotIndexSetInteger(p, PLOT_LINE_COLOR, emaCol);

   // Tick delta
   MqlTick tk;
   if(SymbolInfoTick(_Symbol, tk))
   {
      if(g_lastBid > 0)
      {
         if(tk.bid > g_lastBid)      g_tickDelta++;
         else if(tk.bid < g_lastBid) g_tickDelta--;
      }
      g_lastBid = tk.bid;
   }

   // New bar analysis
   datetime bt = iTime(_Symbol, InpSetupTF, 0);
   if(bt > 0 && bt != g_lastBarT)
   {
      if(Analyze())
      {
         g_lastBarT = bt;
         g_tickDelta = 0;
         if(InpSessionsOn) RefreshSessions();
      }
   }

   UIDraw();
   return(rates_total);
}

//==================================================================
// TIMER
//==================================================================
void OnTimer()
{
   EA_Heartbeat();

   if(InpScannerOn && g_scanN > 0)
   {
      uint now = GetTickCount();
      if(now - g_scanLastRun >= (uint)(MathMax(5, InpScanIntervalSec) * 1000))
      {
         g_scanLastRun = now;
         RunScanner();
      }
   }

   g_sesTick++;
   if(InpSessionsOn && g_sesTick >= 5)
   {
      g_sesTick = 0;
      RefreshSessions();
   }
}

//==================================================================
// CHART EVENT (Scanner row click)
//==================================================================
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(!InpScannerOn || g_scanN <= 0) return;

   string base = PFX + "P_SC_r";
   if(StringFind(sparam, base) != 0) return;

   int us = StringFind(sparam, "_sym");
   if(us < 0) return;

   int len = us - StringLen(base);
   if(len <= 0) return;

   int idx = (int)StringToInteger(StringSubstr(sparam, StringLen(base), len));
   if(idx < 0 || idx >= g_scanN) return;

   ChartSetSymbolPeriod(0, g_scanSyms[idx], PERIOD_CURRENT);
}

//==================================================================
// DATA HELPERS
//==================================================================
bool LoadRates(const ENUM_TIMEFRAMES tf, const int count, MqlRates &r[])
{
   ArraySetAsSeries(r, true);
   int copied = CopyRates(_Symbol, tf, 0, count, r);
   return(copied >= 60);
}

double AvgRange(const MqlRates &r[], const int total, const int period)
{
   if(total < period + 2) return(0);
   double s = 0;
   for(int i = 1; i <= period; i++)
      s += MathMax(r[i].high, r[i+1].close) - MathMin(r[i].low, r[i+1].close);
   return(s / period);
}

double EMAOn(const MqlRates &r[], const int total, const int period, const int endShift)
{
   if(total < period + endShift + 2) return(0);
   double k = 2.0 / (period + 1.0);
   double e = r[total - 1].close;
   for(int i = total - 2; i >= endShift; i--)
      e = r[i].close * k + e * (1.0 - k);
   return(e);
}

string VolFmt(double v)
{
   if(v >= 1000000.0) return DoubleToString(v / 1000000.0, 1) + "M";
   if(v >= 1000.0)    return DoubleToString(v / 1000.0, 1) + "K";
   return DoubleToString(v, 0);
}

string TFStr(ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);
   StringReplace(s, "PERIOD_", "");
   return(s);
}

string SymKey(string s)
{
   StringReplace(s, ".", "-");
   StringReplace(s, " ", "");
   return(s);
}

//==================================================================
// DTC MULTI-TIMEFRAME BIAS
//==================================================================
void UpdateMTFBias()
{
   ENUM_TIMEFRAMES tfs[5] = {InpTF1, InpTF2, InpTF3, InpTF4, InpTF5};

   for(int i = 0; i < 5; i++)
   {
      double emaFast[], emaSlow[];
      ArraySetAsSeries(emaFast, true);
      ArraySetAsSeries(emaSlow, true);

      int hFast = iMA(_Symbol, tfs[i], 20, 0, MODE_EMA, PRICE_CLOSE);
      int hSlow = iMA(_Symbol, tfs[i], 50, 0, MODE_EMA, PRICE_CLOSE);

      if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE)
      {
         g_mtfBull[i] = false;
         g_mtfBear[i] = false;
         g_mtfText[i] = "N/A";
         continue;
      }

      if(CopyBuffer(hFast, 0, 0, 5, emaFast) <= 0 ||
         CopyBuffer(hSlow, 0, 0, 5, emaSlow) <= 0)
      {
         g_mtfBull[i] = false;
         g_mtfBear[i] = false;
         g_mtfText[i] = "N/A";
         IndicatorRelease(hFast);
         IndicatorRelease(hSlow);
         continue;
      }

      g_mtfBull[i] = (emaFast[0] > emaSlow[0]);
      g_mtfBear[i] = (emaFast[0] < emaSlow[0]);
      g_mtfText[i] = g_mtfBull[i] ? "Bullish" : "Bearish";

      IndicatorRelease(hFast);
      IndicatorRelease(hSlow);
   }
}

//==================================================================
// SWING DETECTION
//==================================================================
bool IsSwingHighAt(const MqlRates &r[], const int i, const int st)
{
   if(i - st < 1 || i + st >= ArraySize(r)) return(false);
   for(int j = 1; j <= st; j++)
   {
      if(r[i].high <= r[i - j].high) return(false);
      if(r[i].high <= r[i + j].high) return(false);
   }
   return(true);
}

bool IsSwingLowAt(const MqlRates &r[], const int i, const int st)
{
   if(i - st < 1 || i + st >= ArraySize(r)) return(false);
   for(int j = 1; j <= st; j++)
   {
      if(r[i].low >= r[i - j].low) return(false);
      if(r[i].low >= r[i + j].low) return(false);
   }
   return(true);
}

void ScanSwings(const MqlRates &r[], const int total)
{
   g_swHN = 0;
   g_swLN = 0;
   int st = InpSwingStrength;
   int maxIdx = MathMin(total - st - 1, InpBarsToAnalyze);

   for(int i = st + 1; i < maxIdx; i++)
   {
      if(g_swHN < MAX_SW && IsSwingHighAt(r, i, st))
      {
         g_swH[g_swHN]  = r[i].high;
         g_swHT[g_swHN] = r[i].time;
         g_swHN++;
      }
      if(g_swLN < MAX_SW && IsSwingLowAt(r, i, st))
      {
         g_swL[g_swLN]  = r[i].low;
         g_swLT[g_swLN] = r[i].time;
         g_swLN++;
      }
      if(g_swHN >= MAX_SW && g_swLN >= MAX_SW) break;
   }
}

string TrendFromSwings()
{
   if(g_swHN < 2 || g_swLN < 2) return("N/A");
   bool hh = g_swH[0] > g_swH[1];
   bool hl = g_swL[0] > g_swL[1];
   bool lh = g_swH[0] < g_swH[1];
   bool ll = g_swL[0] < g_swL[1];

   if((hh && ll) || (lh && hl)) return("RANGING ↔");
   if(hh || hl) return("BULLISH ▲");
   if(lh || ll) return("BEARISH ▼");
   return("RANGING ↔");
}

//==================================================================
// LIQUIDITY MAP
//==================================================================
void AddC(const bool above, const double p, const string tag)
{
   if(p <= 0) return;
   if(above)
   {
      if(g_candAN >= MAX_CD) return;
      g_candAP[g_candAN] = p;
      g_candAT[g_candAN] = tag;
      g_candAN++;
   }
   else
   {
      if(g_candBN >= MAX_CD) return;
      g_candBP[g_candBN] = p;
      g_candBT[g_candBN] = tag;
      g_candBN++;
   }
}

void Cluster(const double &a[], const int n, const double tol, const double refP,
             const bool wantAbove, double &lvl, int &cnt)
{
   lvl = 0;
   cnt = 0;
   int best = 0;
   double bl = 0, bd = DBL_MAX;

   for(int i = 0; i < n; i++)
   {
      if(wantAbove  && a[i] <= refP) continue;
      if(!wantAbove && a[i] >= refP) continue;

      int c = 1;
      double sum = a[i];
      for(int j = 0; j < n; j++)
      {
         if(j == i) continue;
         if(MathAbs(a[j] - a[i]) <= tol)
         {
            c++;
            sum += a[j];
         }
      }
      if(c < 2) continue;

      double L = sum / c;
      double d = MathAbs(L - refP);
      if(c > best || (c == best && d < bd))
      {
         best = c;
         bl = L;
         bd = d;
      }
   }
   if(best >= 2)
   {
      lvl = bl;
      cnt = best;
   }
}

void LiquidityMap(const MqlRates &r[], const int total)
{
   double c1 = r[1].close;
   g_candAN = 0;
   g_candBN = 0;
   g_pdh = 0; g_pdl = 0; g_pwh = 0; g_pwl = 0;
   g_eqh = 0; g_eql = 0; g_eqhN = 0; g_eqlN = 0;

   double atr = AvgRange(r, total, 14);
   double tol = InpEqualTolPoints * _Point;
   if(atr > 0) tol = MathMax(tol, atr * 0.10);

   if(InpUsePrevDay)
   {
      MqlRates d[];
      ArraySetAsSeries(d, true);
      if(CopyRates(_Symbol, PERIOD_D1, 1, 1, d) == 1)
      {
         g_pdh = d[0].high;
         g_pdl = d[0].low;
      }
   }

   if(InpUsePrevWeek)
   {
      MqlRates w[];
      ArraySetAsSeries(w, true);
      if(CopyRates(_Symbol, PERIOD_W1, 1, 1, w) == 1)
      {
         g_pwh = w[0].high;
         g_pwl = w[0].low;
      }
   }

   if(InpUseEqualLiq)
   {
      if(g_swHN >= 2) Cluster(g_swH, g_swHN, tol, c1, true,  g_eqh, g_eqhN);
      if(g_swLN >= 2) Cluster(g_swL, g_swLN, tol, c1, false, g_eql, g_eqlN);
   }

   if(InpUsePrevDay)
   {
      if(g_pdh > 0) AddC(true,  g_pdh, "PDH");
      if(g_pdl > 0) AddC(false, g_pdl, "PDL");
   }
   if(InpUsePrevWeek)
   {
      if(g_pwh > 0) AddC(true,  g_pwh, "PWH");
      if(g_pwl > 0) AddC(false, g_pwl, "PWL");
   }
   if(g_eqh > 0 && g_eqhN >= 2) AddC(true,  g_eqh, "EQH x" + IntegerToString(g_eqhN));
   if(g_eql > 0 && g_eqlN >= 2) AddC(false, g_eql, "EQL x" + IntegerToString(g_eqlN));

   if(InpUseSwingLiq)
   {
      if(g_swHN > 0) AddC(true,  g_swH[0], "SWH");
      if(g_swLN > 0) AddC(false, g_swL[0], "SWL");
   }

   // Nearest above / below
   g_nearAbove = 0; g_aboveTag = "-";
   double bd = DBL_MAX;
   for(int i = 0; i < g_candAN; i++)
   {
      if(g_candAP[i] > c1 && g_candAP[i] - c1 < bd)
      {
         bd = g_candAP[i] - c1;
         g_nearAbove = g_candAP[i];
         g_aboveTag  = g_candAT[i];
      }
   }

   g_nearBelow = 0; g_belowTag = "-";
   bd = DBL_MAX;
   for(int i = 0; i < g_candBN; i++)
   {
      if(g_candBP[i] < c1 && c1 - g_candBP[i] < bd)
      {
         bd = c1 - g_candBP[i];
         g_nearBelow = g_candBP[i];
         g_belowTag  = g_candBT[i];
      }
   }

   if(g_domHas)
   {
      if(g_domAskWP > 0) AddC(true,  g_domAskWP, "ASK WALL");
      if(g_domBidWP > 0) AddC(false, g_domBidWP, "BID WALL");
   }
}

//==================================================================
// SWEEP + RECLAIM
//==================================================================
bool DetectSweep(const MqlRates &r[], const int total, const bool buy)
{
   double level = buy ? g_nearBelow : g_nearAbove;
   if(level <= 0) return(false);

   double sb = InpSweepBufPoints * _Point;
   double rc = InpReclaimPoints * _Point;
   int maxS = MathMin(InpSweepWindow, total - 2);

   for(int s = 1; s <= maxS; s++)
   {
      if(buy)
      {
         if(r[s].low < level - sb)
         {
            for(int c = s; c >= 1; c--)
            {
               if(r[c].close > level + rc)
               {
                  g_sweepFound = true;
                  g_sweepIsLow = true;
                  g_sweepPx    = r[s].low;
                  g_sweepT     = r[s].time;
                  return(true);
               }
            }
         }
      }
      else
      {
         if(r[s].high > level + sb)
         {
            for(int c = s; c >= 1; c--)
            {
               if(r[c].close < level - rc)
               {
                  g_sweepFound = true;
                  g_sweepIsLow = false;
                  g_sweepPx    = r[s].high;
                  g_sweepT     = r[s].time;
                  return(true);
               }
            }
         }
      }
   }
   return(false);
}

//==================================================================
// DISPLACEMENT
//==================================================================
bool Disp(const MqlRates &r[], const int total, const bool bull)
{
   if(!InpUseDisplacement) return(true);
   int cnt = MathMin(InpDispLookback, total - 3);
   if(cnt < 5) return(false);

   double avg = 0;
   for(int i = 2; i < cnt + 2; i++)
      avg += MathAbs(r[i].close - r[i].open);
   avg /= cnt;

   double body = MathAbs(r[1].close - r[1].open);
   if(bull) return(r[1].close > r[1].open && body >= avg * InpDispFactor);
   return(r[1].close < r[1].open && body >= avg * InpDispFactor);
}

//==================================================================
// ORDER BLOCKS
//==================================================================
bool Violated(const MqlRates &r[], const int obIdx, const double line, const bool bull)
{
   for(int k = obIdx - 1; k >= 1; k--)
   {
      if(bull  && r[k].close < line) return(true);
      if(!bull && r[k].close > line) return(true);
   }
   return(false);
}

void ScanOrderBlocks(const MqlRates &r[], const int total, const double atr)
{
   g_bobN = 0; g_sobN = 0;
   g_inBullOB = false; g_inBearOB = false;
   g_bobSL = 0; g_sobSL = 0;
   if(!InpUseOrderBlocks) return;

   double c1 = r[1].close;
   int maxScan = MathMin(60, total - 6);

   for(int i = 1; i < maxScan; i++)
   {
      double body = MathAbs(r[i].close - r[i].open);
      bool bullDisp = (r[i].close > r[i].open && body >= atr * InpDispFactor * 0.9);
      bool bearDisp = (r[i].close < r[i].open && body >= atr * InpDispFactor * 0.9);

      if(bullDisp && g_bobN < MAX_ZN)
      {
         for(int j = i + 1; j < i + 8 && j < total - 1; j++)
         {
            if(r[j].close < r[j].open)
            {
               double top = r[j].high;
               double bot = r[j].low;
               if(!Violated(r, j, bot, true) && c1 >= bot)
               {
                  g_bobTop[g_bobN]  = top;
                  g_bobBot[g_bobN]  = bot;
                  g_bobTime[g_bobN] = r[j].time;
                  g_bobN++;
                  if(c1 <= top) g_inBullOB = true;
                  if(top <= c1 && bot > g_bobSL) g_bobSL = bot;
               }
               break;
            }
         }
      }

      if(bearDisp && g_sobN < MAX_ZN)
      {
         for(int j = i + 1; j < i + 8 && j < total - 1; j++)
         {
            if(r[j].close > r[j].open)
            {
               double top = r[j].high;
               double bot = r[j].low;
               if(!Violated(r, j, top, false) && c1 <= top)
               {
                  g_sobTop[g_sobN]  = top;
                  g_sobBot[g_sobN]  = bot;
                  g_sobTime[g_sobN] = r[j].time;
                  g_sobN++;
                  if(c1 >= bot) g_inBearOB = true;
                  if(bot >= c1 && (g_sobSL == 0 || top < g_sobSL)) g_sobSL = top;
               }
               break;
            }
         }
      }
   }
}

//==================================================================
// FAIR VALUE GAPS
//==================================================================
void ScanFVGs(const MqlRates &r[], const int total, const double atr)
{
   g_bfvN = 0; g_sfvN = 0;
   g_inBullFVG = false; g_inBearFVG = false;
   if(!InpUseFVG) return;

   double c1 = r[1].close;
   int maxScan = MathMin(50, total - 3);
   double minGap = InpFVGMinPoints * _Point;
   if(atr > 0) minGap = MathMax(minGap, atr * 0.12);

   for(int i = 1; i < maxScan; i++)
   {
      // Bullish FVG
      if(r[i].low - r[i+2].high >= minGap)
      {
         double top = r[i].low;
         double bot = r[i+2].high;
         bool mitigated = false;
         for(int k = i - 1; k >= 1; k--)
         {
            if(r[k].close < bot) { mitigated = true; break; }
         }
         if(!mitigated && c1 >= bot && g_bfvN < MAX_ZN)
         {
            g_bfvTop[g_bfvN]  = top;
            g_bfvBot[g_bfvN]  = bot;
            g_bfvTime[g_bfvN] = r[i+1].time;
            g_bfvN++;
            if(c1 <= top && c1 >= bot) g_inBullFVG = true;
         }
      }

      // Bearish FVG
      if(r[i+2].low - r[i].high >= minGap)
      {
         double top = r[i+2].low;
         double bot = r[i].high;
         bool mitigated = false;
         for(int k = i - 1; k >= 1; k--)
         {
            if(r[k].close > top) { mitigated = true; break; }
         }
         if(!mitigated && c1 <= top && g_sfvN < MAX_ZN)
         {
            g_sfvTop[g_sfvN]  = top;
            g_sfvBot[g_sfvN]  = bot;
            g_sfvTime[g_sfvN] = r[i+1].time;
            g_sfvN++;
            if(c1 >= bot && c1 <= top) g_inBearFVG = true;
         }
      }
   }
}

//==================================================================
// REGIME / PD / HTF / KILLZONE
//==================================================================
string Regime(const MqlRates &r[], const int total)
{
   int lb = 30;
   if(total < lb + 5) return("UNKNOWN");
   double move = MathAbs(r[1].close - r[lb].close);
   double path = 0;
   for(int i = 1; i < lb; i++)
      path += MathAbs(r[i].close - r[i+1].close);
   if(path <= 0) return("CHOPPY");
   double eff = move / path;
   if(eff >= 0.60) return(r[1].close > r[lb].close ? "TREND UP ▲" : "TREND DOWN ▼");
   if(eff <= 0.25) return("CHOPPY");
   return("RANGE ↔");
}

void PDZone(const MqlRates &r[], const int total)
{
   g_pdZone = "—";
   g_pdPct  = 0.5;
   int lb = MathMin(InpRangeLookback, total - 2);
   double hh = r[1].high, ll = r[1].low;
   for(int i = 1; i <= lb; i++)
   {
      if(r[i].high > hh) hh = r[i].high;
      if(r[i].low  < ll) ll = r[i].low;
   }
   double rng = hh - ll;
   if(rng <= 0) return;
   g_pdPct = (r[1].close - ll) / rng;
   if(!InpUsePDZone) { g_pdZone = "OFF"; return; }
   if(g_pdPct <= InpPDLevel)          g_pdZone = "DISCOUNT";
   else if(g_pdPct >= 1.0 - InpPDLevel) g_pdZone = "PREMIUM";
   else                               g_pdZone = "EQUILIBRIUM";
}

string HTFBias()
{
   g_htfBull = false;
   g_htfBear = false;
   MqlRates h[];
   if(!LoadRates(InpHTFTF, 300, h)) return("N/A");
   int n = ArraySize(h);
   if(n < 120) return("N/A");

   double e1 = EMAOn(h, n, 50, 1);
   double e2 = EMAOn(h, n, 50, 11);
   double c  = h[1].close;
   if(e1 <= 0 || e2 <= 0) return("N/A");

   if(c > e1 && e1 >= e2) { g_htfBull = true; return("BULLISH ▲"); }
   if(c < e1 && e1 <= e2) { g_htfBear = true; return("BEARISH ▼"); }
   return("MIXED ↔");
}

bool Killzone(string &name)
{
   name = "—";
   if(!InpUseKillzones) return(false);
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   double t = dt.hour + dt.min / 60.0;

   if(t >= InpKZ1Start && t < InpKZ1Start + InpKZ1Hours)
   {
      name = "LONDON";
      return(true);
   }
   if(t >= InpKZ2Start && t < InpKZ2Start + InpKZ2Hours)
   {
      name = "NEW YORK";
      return(true);
   }
   return(false);
}

bool InSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   if(InpSessionStartHour <= InpSessionEndHour)
      return(h >= InpSessionStartHour && h < InpSessionEndHour);
   return(h >= InpSessionStartHour || h < InpSessionEndHour);
}

//==================================================================
// SCORING (Hybrid APEX + DTC)
//==================================================================
int Score(const bool buy, const bool sweep, const bool disp, const bool kz)
{
   int s = 0;

   if(sweep) s += 25;

   bool brk = buy ? g_bullBreak : g_bearBreak;
   bool mss = buy ? g_bullMSS   : g_bearMSS;
   if(brk) s += (mss ? 18 : 14);

   if(disp) s += 10;

   if(buy  && g_inBullOB)  s += 12;
   if(!buy && g_inBearOB)  s += 12;
   if(buy  && g_inBullFVG) s += 6;
   if(!buy && g_inBearFVG) s += 6;

   if(buy  && g_pdPct <= InpPDLevel)        s += 8;
   if(!buy && g_pdPct >= 1.0 - InpPDLevel)  s += 8;

   // DOM
   if(g_domHas)
   {
      if(buy  && g_domImb >=  InpDOMImbalanceThr) s += InpDOMScoreWeight;
      if(!buy && g_domImb <= -InpDOMImbalanceThr) s += InpDOMScoreWeight;
   }
   else
   {
      if(buy  && g_tickDelta > 0) s += InpDOMScoreWeight / 2;
      if(!buy && g_tickDelta < 0) s += InpDOMScoreWeight / 2;
   }

   // HTF
   if(InpUseHTFAlign)
   {
      if(buy  && g_htfBull) s += 10;
      if(!buy && g_htfBear) s += 10;
   }

   if(kz) s += 6;

   // === DTC EMA STACK ===
   if(buy  && g_emaBull) s += InpEMAConfluenceScore;
   if(!buy && g_emaBear) s += InpEMAConfluenceScore;

   // === DTC MULTI-TIMEFRAME ===
   int mtfAligned = 0;
   for(int i = 0; i < 5; i++)
   {
      if(buy  && g_mtfBull[i]) mtfAligned++;
      if(!buy && g_mtfBear[i]) mtfAligned++;
   }
   s += mtfAligned * InpMTFScoreWeight;

   if(s > 100) s = 100;
   return(s);
}

string QualityOf(const int s)
{
   if(s >= InpAPlusScore)   return("A+");
   if(s >= InpAScore)       return("A");
   if(s >= InpMinimumScore) return("B");
   return("—");
}

//==================================================================
// TRADE PLAN (ATR Adaptive)
//==================================================================
bool BuildTradePlan(const bool buy, const MqlRates &r[], const int total)
{
   double entry = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0) return(false);

   double atr = AvgRange(r, total, 14);
   if(atr <= 0) atr = 100 * _Point;

   g_planBuy = buy;

   if(buy)
   {
      double base = 0;
      bool has = false;

      if(g_sweepFound && g_sweepIsLow && g_sweepPx < entry)
      {
         base = g_sweepPx;
         has = true;
      }
      if(g_bobSL > 0 && g_bobSL < entry)
      {
         base = has ? MathMin(base, g_bobSL) : g_bobSL;
         has = true;
      }
      if(g_swLN > 0 && g_swL[0] < entry)
      {
         base = has ? MathMin(base, g_swL[0]) : g_swL[0];
         has = true;
      }

      double buf = MathMax(InpSLBufferPoints * _Point, atr * InpSLATRMult);
      g_sl = has ? base - buf : entry - atr * InpFallbackSLATR;

      double risk = entry - g_sl;
      if(risk > atr * InpMaxSLATRMult)
      {
         risk = atr * InpMaxSLATRMult;
         g_sl = entry - risk;
      }
      if(risk < atr * 0.4)
      {
         risk = atr * 0.4;
         g_sl = entry - risk;
      }

      g_op  = entry;
      g_tp1 = entry + risk * InpTP1RR;
      g_tp2 = entry + risk * InpTP2RR;
      g_tp3 = entry + risk * InpTP3RR;
      g_be  = entry + risk * InpBreakEvenRR;
      g_riskPts = (int)MathRound(risk / _Point);
   }
   else
   {
      double base = 0;
      bool has = false;

      if(g_sweepFound && !g_sweepIsLow && g_sweepPx > entry)
      {
         base = g_sweepPx;
         has = true;
      }
      if(g_sobSL > 0 && g_sobSL > entry)
      {
         base = has ? MathMax(base, g_sobSL) : g_sobSL;
         has = true;
      }
      if(g_swHN > 0 && g_swH[0] > entry)
      {
         base = has ? MathMax(base, g_swH[0]) : g_swH[0];
         has = true;
      }

      double buf = MathMax(InpSLBufferPoints * _Point, atr * InpSLATRMult);
      g_sl = has ? base + buf : entry + atr * InpFallbackSLATR;

      double risk = g_sl - entry;
      if(risk > atr * InpMaxSLATRMult)
      {
         risk = atr * InpMaxSLATRMult;
         g_sl = entry + risk;
      }
      if(risk < atr * 0.4)
      {
         risk = atr * 0.4;
         g_sl = entry + risk;
      }

      g_op  = entry;
      g_tp1 = entry - risk * InpTP1RR;
      g_tp2 = entry - risk * InpTP2RR;
      g_tp3 = entry - risk * InpTP3RR;
      g_be  = entry - risk * InpBreakEvenRR;
      g_riskPts = (int)MathRound(risk / _Point);
   }

   g_op  = NormalizeDouble(g_op,  _Digits);
   g_sl  = NormalizeDouble(g_sl,  _Digits);
   g_tp1 = NormalizeDouble(g_tp1, _Digits);
   g_tp2 = NormalizeDouble(g_tp2, _Digits);
   g_tp3 = NormalizeDouble(g_tp3, _Digits);
   g_be  = NormalizeDouble(g_be,  _Digits);

   // Target tag
   g_targetTag = "-";
   double bestP = 0;
   string bestTag = "";
   if(buy)
   {
      for(int i = 0; i < g_candAN; i++)
      {
         if(g_candAP[i] > g_op && (bestP == 0 || g_candAP[i] < bestP))
         {
            bestP = g_candAP[i];
            bestTag = g_candAT[i];
         }
      }
   }
   else
   {
      for(int i = 0; i < g_candBN; i++)
      {
         if(g_candBP[i] < g_op && (bestP == 0 || g_candBP[i] > bestP))
         {
            bestP = g_candBP[i];
            bestTag = g_candBT[i];
         }
      }
   }
   if(bestP > 0)
      g_targetTag = bestTag + " " + DoubleToString(bestP, _Digits);

   return(true);
}

//==================================================================
// DETAILED ALERT
//==================================================================
void SendDetailedAlert(const bool buy)
{
   int sc = buy ? g_buyScore : g_sellScore;

   string msg = StringFormat(
      "════════════════════════════════════════════\n"
      "   APEX + DTC ELITE  •  %s SIGNAL\n"
      "════════════════════════════════════════════\n"
      "Symbol      : %s\n"
      "Direction   : %s\n"
      "Score       : %d   (%s)\n"
      "EMA Stack   : %s\n"
      "────────────────────────────────────────────\n"
      "ENTRY (OP)  : %s\n"
      "STOP LOSS   : %s   (%d points)\n"
      "TAKE PROFIT1: %s   (%.1fR)\n"
      "TAKE PROFIT2: %s   (%.1fR)\n"
      "TAKE PROFIT3: %s   (%.1fR)\n"
      "BREAK EVEN  : %s\n"
      "Target      : %s\n"
      "════════════════════════════════════════════",
      buy ? "BUY" : "SELL",
      _Symbol,
      buy ? "LONG ▲" : "SHORT ▼",
      sc, QualityOf(sc),
      g_emaBull ? "BULLISH STACK" : (g_emaBear ? "BEARISH STACK" : "MIXED"),
      DoubleToString(g_op,  _Digits),
      DoubleToString(g_sl,  _Digits), g_riskPts,
      DoubleToString(g_tp1, _Digits), InpTP1RR,
      DoubleToString(g_tp2, _Digits), InpTP2RR,
      DoubleToString(g_tp3, _Digits), InpTP3RR,
      DoubleToString(g_be,  _Digits),
      g_targetTag
   );

   if(InpPopupAlert) Alert(msg);
   if(InpSoundAlert) PlaySound(InpSoundFile);
   if(InpPushAlert)  SendNotification(msg);
   Print(msg);
}

//==================================================================
// RISK GOVERNOR
//==================================================================
bool AntiOK(const bool buy)
{
   g_block = "";
   if(!InpAntiOvertrade) return(true);

   if(g_daily >= InpMaxSignalsDay)
   {
      g_block = "DAY LIMIT";
      return(false);
   }
   if(g_sess >= InpMaxSignalsSession)
   {
      g_block = "SESSION LIMIT";
      return(false);
   }

   if(g_lastSignal > 0)
   {
      long elapsed = (long)(TimeCurrent() - g_lastSignal);
      if(elapsed < InpCooldownMinutes * 60)
      {
         g_block = "COOLDOWN";
         return(false);
      }
   }

   if(InpOnePerBar && g_lastSignalBar == g_lastBarT)
   {
      g_block = "1 PER BAR";
      return(false);
   }

   if(InpOppositeLock)
   {
      if(buy  && g_lastDir == -1) { g_block = "OPPOSITE LOCK"; return(false); }
      if(!buy && g_lastDir ==  1) { g_block = "OPPOSITE LOCK"; return(false); }
   }
   return(true);
}

void RegisterSignal(const bool buy)
{
   g_lastSignal    = TimeCurrent();
   g_lastSignalBar = g_lastBarT;
   g_lastDir       = buy ? 1 : -1;
   g_daily++;
   g_sess++;
   SendDetailedAlert(buy);
   EA_PushSignal(buy);
}

//==================================================================
// EA HOOKS
//==================================================================
int TGTCode(const string tag)
{
   if(StringFind(tag, "PDH") == 0) return(1);
   if(StringFind(tag, "PDL") == 0) return(2);
   if(StringFind(tag, "PWH") == 0) return(3);
   if(StringFind(tag, "PWL") == 0) return(4);
   if(StringFind(tag, "EQH") == 0) return(5);
   if(StringFind(tag, "EQL") == 0) return(6);
   if(StringFind(tag, "SWH") == 0) return(7);
   if(StringFind(tag, "SWL") == 0) return(8);
   if(StringFind(tag, "ASK") == 0) return(9);
   if(StringFind(tag, "BID") == 0) return(10);
   return(0);
}

void EA_PushSignal(const bool buy)
{
   if(InpEAMode == EA_OFF) return;

   g_eaSeq++;
   string ns  = InpEANamespace;
   string sk  = SymKey(_Symbol);
   double cmd = buy ? 1 : 2;
   double dir = buy ? 1 : -1;
   string dirS = buy ? "BUY" : "SELL";
   int    sc  = buy ? g_buyScore : g_sellScore;

   string json = StringFormat(
      "{\"ns\":\"%s\",\"symbol\":\"%s\",\"cmd\":%.0f,\"dir\":\"%s\",\"seq\":%I64d,"
      "\"score\":%d,\"grade\":\"%s\",\"op\":%s,\"sl\":%s,\"tp1\":%s,\"tp2\":%s,"
      "\"tp3\":%s,\"be\":%s,\"risk_pts\":%d,\"tgt_code\":%d,\"target\":\"%s\","
      "\"tf\":\"%s\",\"time\":\"%s\",\"ema\":\"%s\"}",
      ns, _Symbol, cmd, dirS, g_eaSeq, sc, QualityOf(sc),
      DoubleToString(g_op,  _Digits),
      DoubleToString(g_sl,  _Digits),
      DoubleToString(g_tp1, _Digits),
      DoubleToString(g_tp2, _Digits),
      DoubleToString(g_tp3, _Digits),
      DoubleToString(g_be,  _Digits),
      g_riskPts, TGTCode(g_targetTag), g_targetTag,
      TFStr(InpSetupTF),
      TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
      g_emaBull ? "BULL" : (g_emaBear ? "BEAR" : "MIXED")
   );

   bool doGV   = (InpEAMode == EA_GV   || InpEAMode == EA_ALL);
   bool doFile = (InpEAMode == EA_FILE || InpEAMode == EA_ALL);
   bool doEvt  = (InpEAMode == EA_EVENT|| InpEAMode == EA_ALL);

   if(doGV)
   {
      GlobalVariableSet(ns + "_" + sk + "_CMD",   cmd);
      GlobalVariableSet(ns + "_" + sk + "_SEQ",   (double)g_eaSeq);
      GlobalVariableSet(ns + "_" + sk + "_DIR",   dir);
      GlobalVariableSet(ns + "_" + sk + "_SCORE", (double)sc);
      GlobalVariableSet(ns + "_" + sk + "_OP",    g_op);
      GlobalVariableSet(ns + "_" + sk + "_SL",    g_sl);
      GlobalVariableSet(ns + "_" + sk + "_TP1",   g_tp1);
      GlobalVariableSet(ns + "_" + sk + "_TP2",   g_tp2);
      GlobalVariableSet(ns + "_" + sk + "_TP3",   g_tp3);
      GlobalVariableSet(ns + "_" + sk + "_BE",    g_be);
      GlobalVariableSet(ns + "_" + sk + "_RISK",  (double)g_riskPts);
      GlobalVariableSet(ns + "_" + sk + "_TIME",  (double)(long)TimeCurrent());
   }

   if(doFile)
   {
      string fn = ns + "_" + _Symbol + "_SIGNAL.json";
      int flags = FILE_WRITE | FILE_TXT | FILE_ANSI | (InpEAFileCommon ? FILE_COMMON : 0);
      int h = FileOpen(fn, flags);
      if(h != INVALID_HANDLE)
      {
         FileWriteString(h, json);
         FileClose(h);
      }
   }

   if(doEvt)
      EventChartCustom(0, (ushort)InpEAEventID, (long)cmd, g_op, json);

   PrintFormat("APEX+DTC EA-HOOK seq %I64d → %s", g_eaSeq, dirS);
}

void EA_Heartbeat()
{
   if(!(InpEAMode == EA_GV || InpEAMode == EA_ALL)) return;
   GlobalVariableSet(InpEANamespace + "_" + SymKey(_Symbol) + "_HB",
                     (double)(long)TimeCurrent());
}

//==================================================================
// MULTI-SYMBOL SCANNER (Full Quality)
//==================================================================
void ScannerInit()
{
   g_scanN = 0;
   ArrayResize(g_scanSyms, 0);

   string parts[];
   ushort sep = StringGetCharacter(",", 0);
   int n = StringSplit(InpScanList, sep, parts);
   int cap = MathMin(InpScanMaxRows, MAX_SCAN);

   for(int i = 0; i < n && g_scanN < cap; i++)
   {
      string s = parts[i];
      StringTrimLeft(s);
      StringTrimRight(s);
      if(s == "") continue;
      if(!SymbolSelect(s, true)) continue;

      int sz = ArraySize(g_scanSyms);
      ArrayResize(g_scanSyms, sz + 1);
      g_scanSyms[sz] = s;
   }
   g_scanN = ArraySize(g_scanSyms);

   ArrayResize(g_scanBuy,     g_scanN);
   ArrayResize(g_scanSell,    g_scanN);
   ArrayResize(g_scanDir,     g_scanN);
   ArrayResize(g_scanGrade,   g_scanN);
   ArrayResize(g_scanSpread,  g_scanN);
   ArrayResize(g_scanBar,     g_scanN);
   ArrayResize(g_scanAlerted, g_scanN);
   ArrayResize(g_scanOrder,   g_scanN);
   ArrayResize(g_scanTrend,   g_scanN);
   ArrayResize(g_scanHTF,     g_scanN);
   ArrayResize(g_scanState,   g_scanN);

   for(int i = 0; i < g_scanN; i++)
   {
      g_scanBuy[i] = 0; g_scanSell[i] = 0;
      g_scanDir[i] = 0; g_scanGrade[i] = 0;
      g_scanSpread[i] = 0;
      g_scanBar[i] = 0; g_scanAlerted[i] = 0;
      g_scanTrend[i] = "…";
      g_scanHTF[i]   = "…";
      g_scanState[i] = "…";
   }
}

bool ScannerAnalyzeLite(const int idx)
{
   string sym = g_scanSyms[idx];

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(sym, InpSetupTF, 0, InpBarsToAnalyze, r) < 60)
   {
      g_scanState[idx] = "…";
      return(false);
   }
   int total = ArraySize(r);
   g_scanBar[idx] = r[0].time;

   // Local swings
   double swH[MAX_SW], swL[MAX_SW];
   int nH = 0, nL = 0;
   int st = InpSwingStrength;
   int maxIdx = MathMin(total - st - 1, InpBarsToAnalyze);

   for(int i = st + 1; i < maxIdx; i++)
   {
      if(nH < MAX_SW && IsSwingHighAt(r, i, st)) swH[nH++] = r[i].high;
      if(nL < MAX_SW && IsSwingLowAt(r, i, st))  swL[nL++] = r[i].low;
      if(nH >= MAX_SW && nL >= MAX_SW) break;
   }

   // Trend
   string trend = "RANGE ↔";
   if(nH >= 2 && nL >= 2)
   {
      bool hh = swH[0] > swH[1], hl = swL[0] > swL[1];
      bool lh = swH[0] < swH[1], ll = swL[0] < swL[1];
      if((hh && ll) || (lh && hl)) trend = "RANGE ↔";
      else if(hh || hl) trend = "BULL ▲";
      else if(lh || ll) trend = "BEAR ▼";
   }
   g_scanTrend[idx] = trend;

   // BOS / MSS
   double buf = InpBOSBufferPoints * _Point;
   double c1 = r[1].close;
   bool bullBreak = (nH > 0 && c1 > swH[0] + buf);
   bool bearBreak = (nL > 0 && c1 < swL[0] - buf);
   bool bullMSS = bullBreak && nH > 1 && nL > 1 && (swH[0] < swL[1]);
   bool bearMSS = bearBreak && nH > 1 && nL > 1 && (swL[0] > swH[1]);

   // Nearest liquidity
   double atr = AvgRange(r, total, 14);
   if(atr <= 0) atr = 100 * _Point;
   double tol = InpEqualTolPoints * _Point;
   if(atr > 0) tol = MathMax(tol, atr * 0.10);

   double nearA = 0, nearB = 0;
   MqlRates d[];
   ArraySetAsSeries(d, true);
   if(CopyRates(sym, PERIOD_D1, 1, 1, d) == 1)
   {
      if(d[0].high > c1) nearA = d[0].high;
      if(d[0].low  < c1) nearB = d[0].low;
   }
   if(nH > 0 && swH[0] > c1 && (nearA == 0 || swH[0] < nearA)) nearA = swH[0];
   if(nL > 0 && swL[0] < c1 && (nearB == 0 || swL[0] > nearB)) nearB = swL[0];

   // Sweeps
   bool swLow = false, swHigh = false;
   double sb = InpSweepBufPoints * _Point;
   double rc = InpReclaimPoints * _Point;
   int maxS = MathMin(InpSweepWindow, total - 2);

   if(nearB > 0)
   {
      for(int s = 1; s <= maxS && !swLow; s++)
      {
         if(r[s].low < nearB - sb)
         {
            for(int c2 = s; c2 >= 1; c2--)
            {
               if(r[c2].close > nearB + rc) { swLow = true; break; }
            }
         }
      }
   }
   if(nearA > 0)
   {
      for(int s = 1; s <= maxS && !swHigh; s++)
      {
         if(r[s].high > nearA + sb)
         {
            for(int c2 = s; c2 >= 1; c2--)
            {
               if(r[c2].close < nearA - rc) { swHigh = true; break; }
            }
         }
      }
   }

   // Displacement
   bool bullDisp = true, bearDisp = true;
   if(InpUseDisplacement)
   {
      int cnt = MathMin(InpDispLookback, total - 3);
      double avg = 0;
      for(int i = 2; i < cnt + 2; i++)
         avg += MathAbs(r[i].close - r[i].open);
      avg /= cnt;
      double body = MathAbs(c1 - r[1].open);
      bullDisp = (c1 > r[1].open && body >= avg * InpDispFactor);
      bearDisp = (c1 < r[1].open && body >= avg * InpDispFactor);
   }

   // Premium / Discount
   double pdPct = 0.5;
   {
      int lb = MathMin(InpRangeLookback, total - 2);
      double hh = r[1].high, ll = r[1].low;
      for(int i = 1; i <= lb; i++)
      {
         if(r[i].high > hh) hh = r[i].high;
         if(r[i].low  < ll) ll = r[i].low;
      }
      double rng = hh - ll;
      if(rng > 0) pdPct = (c1 - ll) / rng;
   }

   // HTF bias
   string htf = "N/A";
   bool hBull = false, hBear = false;
   {
      MqlRates h[];
      ArraySetAsSeries(h, true);
      if(CopyRates(sym, InpHTFTF, 0, 300, h) >= 120)
      {
         int hn = ArraySize(h);
         double e1 = EMAOn(h, hn, 50, 1);
         double e2 = EMAOn(h, hn, 50, 11);
         if(e1 > 0 && e2 > 0)
         {
            if(h[1].close > e1 && e1 >= e2) { htf = "BULL ▲"; hBull = true; }
            else if(h[1].close < e1 && e1 <= e2) { htf = "BEAR ▼"; hBear = true; }
            else htf = "MIXED ↔";
         }
      }
   }
   g_scanHTF[idx] = htf;

   string kzN;
   bool kz = Killzone(kzN);

   // Score
   int scB = 0, scS = 0;
   if(swLow || swHigh) { scB += 25; scS += 25; }
   if(bullBreak) scB += (bullMSS ? 18 : 14);
   if(bearBreak) scS += (bearMSS ? 18 : 14);
   if(bullDisp) scB += 10;
   if(bearDisp) scS += 10;
   if(pdPct <= InpPDLevel)       scB += 8;
   if(pdPct >= 1.0 - InpPDLevel) scS += 8;
   if(InpUseHTFAlign)
   {
      if(hBull) scB += 10;
      if(hBear) scS += 10;
   }
   if(kz) { scB += 6; scS += 6; }
   if(scB > 100) scB = 100;
   if(scS > 100) scS = 100;

   g_scanBuy[idx]  = scB;
   g_scanSell[idx] = scS;

   double spr = (double)SymbolInfoInteger(sym, SYMBOL_SPREAD);
   g_scanSpread[idx] = spr;

   int top = MathMax(scB, scS);
   int margin = MathAbs(scB - scS);
   g_scanGrade[idx] = top;
   g_scanDir[idx] = 0;

   string state = "—";
   if(top >= InpMinimumScore && margin >= InpScoreMargin)
   {
      int dir = (scB >= scS) ? 1 : -1;
      g_scanDir[idx] = dir;
      bool gateOK = true;
      if(InpRequireBOS && !((dir == 1) ? bullBreak : bearBreak)) gateOK = false;
      if(gateOK && InpRequireMSS && !((dir == 1) ? bullMSS : bearMSS)) gateOK = false;
      if(gateOK && InpUseSpreadFilter && spr > InpMaxSpreadPoints) gateOK = false;
      state = gateOK ? "SIGNAL" : "GATED";
   }
   else if(top >= InpMinimumScore) state = "WATCH";

   g_scanState[idx] = state;
   return(true);
}

void ScannerAlerts()
{
   for(int i = 0; i < g_scanN; i++)
   {
      if(g_scanState[i] != "SIGNAL") continue;
      int top = g_scanGrade[i];
      if(top < InpScanAlertScore) continue;
      if(g_scanAlerted[i] == g_scanBar[i]) continue;

      g_scanAlerted[i] = g_scanBar[i];
      bool buy = (g_scanDir[i] == 1);
      string msg = StringFormat("APEX+DTC SCAN | %s | %s | SCORE %d %s | SPRD %.0f",
         g_scanSyms[i], buy ? "BUY" : "SELL", top, QualityOf(top), g_scanSpread[i]);

      if(InpPopupAlert) Alert(msg);
      if(InpSoundAlert) PlaySound(InpSoundFile);
      if(InpPushAlert)  SendNotification(msg);
   }
}

void RunScanner()
{
   if(!InpScannerOn || g_scanN <= 0) return;

   for(int i = 0; i < g_scanN; i++)
      ScannerAnalyzeLite(i);

   // Rank by top score
   int order[];
   ArrayResize(order, g_scanN);
   for(int i = 0; i < g_scanN; i++) order[i] = i;

   for(int i = 1; i < g_scanN; i++)
   {
      int key = order[i];
      double kv = MathMax(g_scanBuy[key], g_scanSell[key]);
      int j = i - 1;
      while(j >= 0 && MathMax(g_scanBuy[order[j]], g_scanSell[order[j]]) < kv)
      {
         order[j + 1] = order[j];
         j--;
      }
      order[j + 1] = key;
   }
   for(int i = 0; i < g_scanN; i++) g_scanOrder[i] = order[i];

   ScannerAlerts();
   DrawScannerPanel();
}

void DrawScannerPanel()
{
   int x = InpScanPanelX;
   int y = InpScanPanelY;
   int W = 335;
   int rows = g_scanN;
   int H = 50 + rows * 18;

   UIRect("SC_bg",  x, y, W, H, clrPanelBG, clrBorder);
   UIRect("SC_hdr", x, y, W, 24, clrHeaderBG, clrBorder);
   UILabel("SC_ttl", x + 10, y + 5, "APEX SCANNER", clrAccent, 9);
   UILabel("SC_clk", x + W - 95, y + 6, "click = switch", clrTextDim, 7);

   int hy = y + 28;
   UILabel("SC_h0", x + 8,   hy, "SYMBOL", clrTextDim, 8);
   UILabel("SC_h1", x + 80,  hy, "TREND",  clrTextDim, 8);
   UILabel("SC_h2", x + 135, hy, "BIAS",   clrTextDim, 8);
   UILabel("SC_h3", x + 185, hy, "B/S",    clrTextDim, 8);
   UILabel("SC_h4", x + 235, hy, "GR",     clrTextDim, 8);
   UILabel("SC_h5", x + 265, hy, "STATE",  clrTextDim, 8);

   for(int rr = 0; rr < rows; rr++)
   {
      int i  = g_scanOrder[rr];
      int ry = y + 48 + rr * 18;
      bool sig = (g_scanState[i] == "SIGNAL");
      color rowbg = sig ? clrScanSignal : clrScanNormal;

      UIRect("SC_r" + IntegerToString(i) + "_bg", x + 4, ry - 2, W - 8, 16, rowbg, rowbg);

      UILabel("SC_r" + IntegerToString(i) + "_sym", x + 8, ry,
              g_scanSyms[i], clrTextMain, 8, "Consolas");

      color tc = clrTextDim;
      if(StringFind(g_scanTrend[i], "BULL") >= 0) tc = clrBuy;
      else if(StringFind(g_scanTrend[i], "BEAR") >= 0) tc = clrSell;
      UILabel("SC_r" + IntegerToString(i) + "_tr", x + 80, ry, g_scanTrend[i], tc, 8);

      color hc = clrTextDim;
      if(StringFind(g_scanHTF[i], "BULL") >= 0) hc = clrBuy;
      else if(StringFind(g_scanHTF[i], "BEAR") >= 0) hc = clrSell;
      UILabel("SC_r" + IntegerToString(i) + "_ht", x + 135, ry, g_scanHTF[i], hc, 8);

      UILabel("SC_r" + IntegerToString(i) + "_bs", x + 185, ry,
              StringFormat("%d/%d", (int)g_scanBuy[i], (int)g_scanSell[i]),
              g_scanBuy[i] >= g_scanSell[i] ? clrBuy : clrSell, 8, "Consolas");

      int tS = (int)MathMax(g_scanBuy[i], g_scanSell[i]);
      color gc = clrTextDim;
      if(tS >= InpAPlusScore)      gc = clrBuy;
      else if(tS >= InpAScore)     gc = clrAccent;
      else if(tS >= InpMinimumScore) gc = clrTextMain;
      UILabel("SC_r" + IntegerToString(i) + "_gr", x + 235, ry, QualityOf(tS), gc, 8, "Consolas");

      UILabel("SC_r" + IntegerToString(i) + "_st", x + 265, ry, g_scanState[i],
              sig ? clrAccent : (g_scanState[i] == "WATCH" ? clrTextMain : clrTextDim), 8);
   }
}

//==================================================================
// SESSION RANGES (Full Quality)
//==================================================================
void SessionsInit()
{
   g_sesName[0]  = InpSess1Name;  g_sesOn[0] = InpSess1On;
   g_sesStart[0] = InpSess1Start; g_sesHours[0] = InpSess1Hours;
   g_sesFill[0]  = C'38,28,10';   g_sesLine[0] = clrSessAsia;

   g_sesName[1]  = InpSess2Name;  g_sesOn[1] = InpSess2On;
   g_sesStart[1] = InpSess2Start; g_sesHours[1] = InpSess2Hours;
   g_sesFill[1]  = C'8,30,45';    g_sesLine[1] = clrSessLondon;

   g_sesName[2]  = InpSess3Name;  g_sesOn[2] = InpSess3On;
   g_sesStart[2] = InpSess3Start; g_sesHours[2] = InpSess3Hours;
   g_sesFill[2]  = C'40,12,28';   g_sesLine[2] = clrSessNY;

   for(int i = 0; i < MAX_SES; i++)
   {
      g_sesHi[i] = 0; g_sesLo[i] = 0;
      g_sesT1[i] = 0; g_sesT2[i] = 0;
      g_sesActive[i] = false;
      g_sesSweep[i] = 0;
   }
}

void RefreshSessions()
{
   if(!InpSessionsOn) return;
   datetime now = TimeCurrent();

   for(int sIdx = 0; sIdx < MAX_SES; sIdx++)
   {
      g_sesHi[sIdx] = 0;
      g_sesLo[sIdx] = 0;
      g_sesActive[sIdx] = false;
      g_sesSweep[sIdx] = 0;
      if(!g_sesOn[sIdx]) continue;

      MqlDateTime dt;
      TimeToStruct(now, dt);
      dt.hour = (int)MathFloor(g_sesStart[sIdx]);
      dt.min  = (int)MathRound((g_sesStart[sIdx] - dt.hour) * 60.0);
      dt.sec  = 0;
      datetime t1 = StructToTime(dt);

      long dur = (long)MathRound(g_sesHours[sIdx] * 3600.0);
      datetime tEnd = (datetime)((long)t1 + dur);

      bool active = (now >= t1 && now < tEnd);
      datetime t2 = (active && InpSessExtendActive) ? now : tEnd;
      if(t2 <= t1) t2 = (datetime)((long)t1 + PeriodSeconds(InpSetupTF));

      g_sesT1[sIdx] = t1;
      g_sesT2[sIdx] = t2;
      g_sesActive[sIdx] = active;

      MqlRates sr[];
      ArraySetAsSeries(sr, true);
      datetime stop = (datetime)((long)t2 - 1);
      int copied = CopyRates(_Symbol, InpSetupTF, t1, stop, sr);
      if(copied <= 0) continue;

      double hi = sr[0].high, lo = sr[0].low;
      for(int i = 0; i < copied; i++)
      {
         if(sr[i].high > hi) hi = sr[i].high;
         if(sr[i].low  < lo) lo = sr[i].low;
      }
      g_sesHi[sIdx] = hi;
      g_sesLo[sIdx] = lo;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid > hi)      g_sesSweep[sIdx] =  1;
      else if(bid < lo) g_sesSweep[sIdx] = -1;
   }
   DrawSessionBoxes();
}

void DrawSessionBoxes()
{
   DeleteByPrefix(PFX + "SES_");
   if(!InpSessionsOn) return;

   for(int sIdx = 0; sIdx < MAX_SES; sIdx++)
   {
      if(!g_sesOn[sIdx] || g_sesHi[sIdx] <= 0 || g_sesLo[sIdx] <= 0) continue;

      string id = "SES_" + IntegerToString(sIdx);
      ZoneRect(id, g_sesT1[sIdx], g_sesLo[sIdx], g_sesT2[sIdx], g_sesHi[sIdx],
               g_sesFill[sIdx], g_sesLine[sIdx]);

      if(InpSessShowMidline)
      {
         double mid = (g_sesHi[sIdx] + g_sesLo[sIdx]) * 0.5;
         TrendSeg(id + "_mid", g_sesT1[sIdx], mid, g_sesT2[sIdx], mid,
                  g_sesLine[sIdx], STYLE_DOT, 1);
      }

      string tag = g_sesName[sIdx];
      color  lc  = g_sesLine[sIdx];
      if(g_sesSweep[sIdx] > 0)
      {
         tag += " ▲SWEPT";
         lc = clrSell;
      }
      else if(g_sesSweep[sIdx] < 0)
      {
         tag += " ▼SWEPT";
         lc = clrBuy;
      }

      tag += StringFormat("  H %s  L %s  R %.0fp",
         DoubleToString(g_sesHi[sIdx], _Digits),
         DoubleToString(g_sesLo[sIdx], _Digits),
         (g_sesHi[sIdx] - g_sesLo[sIdx]) / _Point);

      ChartText(id + "_lb", g_sesT2[sIdx], g_sesHi[sIdx], tag, lc, 8);
   }
}

//==================================================================
// MAIN ANALYSIS PIPELINE
//==================================================================
bool Analyze()
{
   MqlRates r[];
   if(!LoadRates(InpSetupTF, InpBarsToAnalyze, r))
   {
      g_signal = "LOADING…";
      return(false);
   }
   int total = ArraySize(r);
   if(total < 60)
   {
      g_signal = "LOADING…";
      return(false);
   }

   g_confirmed = false;
   g_sweepFound = false;
   g_sweepPx = 0;
   g_sweepT = 0;

   UpdateMTFBias();
   ScanSwings(r, total);
   g_trend = TrendFromSwings();

   double buf = InpBOSBufferPoints * _Point;
   g_bullBreak = (g_swHN > 0 && r[1].close > g_swH[0] + buf);
   g_bearBreak = (g_swLN > 0 && r[1].close < g_swL[0] - buf);
   g_bullMSS = g_bullBreak && g_swHN > 1 && g_swLN > 1 && (g_swH[0] < g_swL[1]);
   g_bearMSS = g_bearBreak && g_swHN > 1 && g_swLN > 1 && (g_swL[0] > g_swH[1]);

   g_event = "—";
   if(g_bullBreak)      g_event = g_bullMSS ? "MSS ▲" : "BOS ▲";
   else if(g_bearBreak) g_event = g_bearMSS ? "MSS ▼" : "BOS ▼";

   LiquidityMap(r, total);

   double atr = AvgRange(r, total, 14);
   if(atr <= 0) atr = 100 * _Point;

   bool bullDisp = Disp(r, total, true);
   bool bearDisp = Disp(r, total, false);

   ScanOrderBlocks(r, total, atr);
   ScanFVGs(r, total, atr);

   PDZone(r, total);
   g_htf = HTFBias();
   g_regime = Regime(r, total);
   g_kzActive = Killzone(g_kz);
   bool kz = g_kzActive;

   bool swLow  = DetectSweep(r, total, true);
   bool swHigh = DetectSweep(r, total, false);
   if(swLow)       g_sweepTxt = "LOW ✓";
   else if(swHigh) g_sweepTxt = "HIGH ✓";
   else            g_sweepTxt = "—";

   g_buyScore  = Score(true,  swLow || swHigh, bullDisp, kz);
   g_sellScore = Score(false, swLow || swHigh, bearDisp, kz);

   bool dirBuy = (g_buyScore >= g_sellScore);
   int  top    = dirBuy ? g_buyScore : g_sellScore;
   int  margin = MathAbs(g_buyScore - g_sellScore);
   g_quality = QualityOf(top);

   if(top < InpMinimumScore)
   {
      g_signal = "STANDBY";
      g_block  = "SCORE < " + IntegerToString(InpMinimumScore);
   }
   else if(margin < InpScoreMargin)
   {
      g_signal = "STANDBY";
      g_block  = "NO DOMINANCE";
   }
   else
   {
      bool ok = true;
      if(InpRequireBOS && !(dirBuy ? g_bullBreak : g_bearBreak))
      {
         ok = false;
         g_block = "NO BOS";
      }
      if(ok && InpRequireMSS && !(dirBuy ? g_bullMSS : g_bearMSS))
      {
         ok = false;
         g_block = "NO MSS";
      }
      if(ok && InpRequireDOMAgree && g_domHas)
      {
         if(dirBuy  && g_domImb <= -InpDOMImbalanceThr) { ok = false; g_block = "DOM AGAINST"; }
         if(!dirBuy && g_domImb >=  InpDOMImbalanceThr) { ok = false; g_block = "DOM AGAINST"; }
      }
      if(ok && InpUseSessionFilter && !InSession())
      {
         ok = false;
         g_block = "OUT OF SESSION";
      }
      if(ok && InpUseSpreadFilter)
      {
         double spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         if(spr > InpMaxSpreadPoints)
         {
            ok = false;
            g_block = "SPREAD WIDE";
         }
      }
      if(ok && !AntiOK(dirBuy)) ok = false;

      if(ok && BuildTradePlan(dirBuy, r, total))
      {
         g_signalTime = r[1].time;
         g_signal = StringFormat("%s CONFIRMED", dirBuy ? "BUY" : "SELL");
         g_confirmed = true;
         RegisterSignal(dirBuy);
         DrawTradePlan(dirBuy, r);
      }
      else if(!ok)
         g_signal = StringFormat("%s BLOCKED", dirBuy ? "BUY" : "SELL");
   }

   if(!g_confirmed)
   {
      bool pb = (g_buyScore >= g_sellScore);
      if(BuildTradePlan(pb, r, total))
      {
         if(InpShowPreview && top >= InpMinimumScore && g_signal == "STANDBY")
            g_signal = StringFormat("PREVIEW %s %d", pb ? "BUY" : "SELL", top);
      }
   }

   DrawSweepMark(r, atr);
   DrawZones();
   DrawLiquidity();
   return(true);
}

//==================================================================
// DAILY RESET
//==================================================================
void ResetDailyCounter()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(g_dayNum < 0)
   {
      g_dayNum = dt.day_of_year;
      return;
   }
   if(dt.day_of_year != g_dayNum)
   {
      g_dayNum = dt.day_of_year;
      g_daily = 0;
      g_sess  = 0;
      g_lastDir = 0;
      g_lastSignal = 0;
      g_lastSignalBar = 0;
   }
}

//==================================================================
// OBJECT UTILITIES
//==================================================================
void DeleteByPrefix(const string pfx)
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, 0, -1);
      if(StringFind(nm, pfx) == 0)
         ObjectDelete(0, nm);
   }
}

void HLineL(const string id, const double p, const color c,
            const ENUM_LINE_STYLE st, const int w, const string tag)
{
   if(p <= 0) return;
   string nm = PFX + id;
   if(ObjectFind(0, nm) < 0)
   {
      ObjectCreate(0, nm, OBJ_HLINE, 0, 0, p);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_BACK, false);
      ObjectSetInteger(0, nm, OBJPROP_ZORDER, 2);
   }
   ObjectSetDouble(0, nm, OBJPROP_PRICE, p);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, st);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, w);
   ObjectSetString(0, nm, OBJPROP_TEXT, tag);
}

void ChartText(const string id, const datetime t, const double p,
               const string txt, const color c, const int fs = 9)
{
   string nm = PFX + id;
   if(ObjectFind(0, nm) < 0)
   {
      ObjectCreate(0, nm, OBJ_TEXT, 0, t, p);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   ObjectSetInteger(0, nm, OBJPROP_TIME, t);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, p);
   ObjectSetString(0, nm, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, fs);
   ObjectSetString(0, nm, OBJPROP_FONT, "Segoe UI");
}

void TrendSeg(const string id, const datetime t1, const double p1,
              const datetime t2, const double p2,
              const color c, const ENUM_LINE_STYLE st, const int w)
{
   string nm = PFX + id;
   if(ObjectFind(0, nm) < 0)
   {
      ObjectCreate(0, nm, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_BACK, false);
      ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
   }
   ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, nm, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, st);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, w);
}

void ZoneRect(const string id, const datetime t1, const double p1,
              const datetime t2, const double p2,
              const color fill, const color line)
{
   string nm = PFX + id;
   if(ObjectFind(0, nm) < 0)
   {
      ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_BACK, true);
      ObjectSetInteger(0, nm, OBJPROP_FILL, true);
   }
   ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, nm, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, fill);

   string bd = nm + "_bd";
   if(ObjectFind(0, bd) < 0)
   {
      ObjectCreate(0, bd, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, bd, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bd, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, bd, OBJPROP_BACK, false);
      ObjectSetInteger(0, bd, OBJPROP_FILL, false);
   }
   ObjectSetInteger(0, bd, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, bd, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, bd, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, bd, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, bd, OBJPROP_COLOR, line);
}

//==================================================================
// CHART DRAWING
//==================================================================
void DrawLiquidity()
{
   DeleteByPrefix(PFX + "L_");
   if(!InpShowLiqLines) return;

   datetime t = TimeCurrent() + PeriodSeconds(InpSetupTF) * 8;

   if(g_pdh > 0)
   {
      HLineL("L_pdh", g_pdh, clrLiqPD, STYLE_SOLID, 1, "PDH");
      ChartText("L_pdhT", t, g_pdh, "PDH", clrLiqPD, 8);
   }
   if(g_pdl > 0)
   {
      HLineL("L_pdl", g_pdl, clrLiqPD, STYLE_SOLID, 1, "PDL");
      ChartText("L_pdlT", t, g_pdl, "PDL", clrLiqPD, 8);
   }
   if(g_pwh > 0) HLineL("L_pwh", g_pwh, clrLiqPW, STYLE_DOT, 1, "PWH");
   if(g_pwl > 0) HLineL("L_pwl", g_pwl, clrLiqPW, STYLE_DOT, 1, "PWL");
   if(g_eqh > 0)
   {
      HLineL("L_eqh", g_eqh, clrLiqEQ, STYLE_DASH, 1, "EQH");
      ChartText("L_eqhT", t, g_eqh, "EQH x" + IntegerToString(g_eqhN), clrLiqEQ, 8);
   }
   if(g_eql > 0)
   {
      HLineL("L_eql", g_eql, clrLiqEQ, STYLE_DASH, 1, "EQL");
      ChartText("L_eqlT", t, g_eql, "EQL x" + IntegerToString(g_eqlN), clrLiqEQ, 8);
   }
}

void DrawZones()
{
   DeleteByPrefix(PFX + "Z_");
   if(!InpShowZones) return;

   datetime t2 = TimeCurrent() + PeriodSeconds(InpSetupTF) * 12;

   for(int i = 0; i < g_bobN; i++)
      ZoneRect("Z_OBb" + IntegerToString(i), g_bobTime[i], g_bobBot[i], t2, g_bobTop[i],
               clrOBBullFill, clrOBBullLine);

   for(int i = 0; i < g_sobN; i++)
      ZoneRect("Z_OBs" + IntegerToString(i), g_sobTime[i], g_sobBot[i], t2, g_sobTop[i],
               clrOBBearFill, clrOBBearLine);

   for(int i = 0; i < g_bfvN; i++)
      ZoneRect("Z_FVb" + IntegerToString(i), g_bfvTime[i], g_bfvBot[i], t2, g_bfvTop[i],
               clrFVGBullFill, clrFVGBullLine);

   for(int i = 0; i < g_sfvN; i++)
      ZoneRect("Z_FVs" + IntegerToString(i), g_sfvTime[i], g_sfvBot[i], t2, g_sfvTop[i],
               clrFVGBearFill, clrFVGBearLine);
}

void DrawSweepMark(const MqlRates &r[], const double atr)
{
   DeleteByPrefix(PFX + "S_");
   if(!InpShowSweepMarks || !g_sweepFound) return;

   double p = g_sweepIsLow ? g_sweepPx - atr * 0.3 : g_sweepPx + atr * 0.3;
   ChartText("S_mrk", g_sweepT, p, "✕ SWEEP",
             g_sweepIsLow ? clrBuy : clrSell, 9);
}

void DrawTradePlan(const bool buy, const MqlRates &r[])
{
   DeleteByPrefix(PFX + "T_");
   if(!InpShowTradePlan) return;

   double atr = AvgRange(r, ArraySize(r), 14);
   if(atr <= 0) atr = 100 * _Point;

   datetime t1 = g_signalTime;
   datetime t2 = t1 + PeriodSeconds(InpSetupTF) * InpPlanBars;
   int sc = buy ? g_buyScore : g_sellScore;
   color dir = buy ? clrBuy : clrSell;

   // Risk / Reward zones
   ZoneRect("T_RISK", t1, g_op, t2, g_sl,  clrRiskFill,   clrRiskFill);
   ZoneRect("T_RWD",  t1, g_op, t2, g_tp3, clrRewardFill, clrRewardFill);

   // Horizontal lines
   HLineL("T_OP",  g_op,  clrOP, STYLE_SOLID, 2, "OP");
   HLineL("T_SL",  g_sl,  clrSL, STYLE_DASH,  2, "SL");
   HLineL("T_TP1", g_tp1, clrTP, STYLE_SOLID, 2, "TP1");
   HLineL("T_TP2", g_tp2, clrTP, STYLE_DASH,  2, "TP2");
   HLineL("T_TP3", g_tp3, clrTP, STYLE_DOT,   2, "TP3");
   HLineL("T_BE",  g_be,  clrBE, STYLE_DOT,   1, "BE");

   // Price labels
   ChartText("T_OPT", t2, g_op,  " OP  " + DoubleToString(g_op,  _Digits), clrOP, 9);
   ChartText("T_SLT", t2, g_sl,  " SL  " + DoubleToString(g_sl,  _Digits), clrSL, 9);
   ChartText("T_T1T", t2, g_tp1, " TP1 " + DoubleToString(g_tp1, _Digits), clrTP, 9);
   ChartText("T_T2T", t2, g_tp2, " TP2 " + DoubleToString(g_tp2, _Digits), clrTP, 9);
   ChartText("T_T3T", t2, g_tp3, " TP3 " + DoubleToString(g_tp3, _Digits), clrTP, 9);
   ChartText("T_BET", t2, g_be,  " BE", clrBE, 8);

   ChartText("T_SIG", t1, buy ? g_sl - atr * 0.4 : g_sl + atr * 0.4,
             StringFormat("APEX %s %d • %s", buy ? "BUY" : "SELL", sc, QualityOf(sc)),
             dir, 9);

   if(InpShowArrow)
   {
      string nm = PFX + "T_ARW";
      if(ObjectCreate(0, nm, OBJ_ARROW, 0, t1,
                      buy ? r[1].low - atr * 0.45 : r[1].high + atr * 0.45))
      {
         ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, buy ? 233 : 234);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, dir);
         ObjectSetInteger(0, nm, OBJPROP_WIDTH, 3);
         ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      }
   }
   ChartRedraw(0);
}

//==================================================================
// DASHBOARD UI
//==================================================================
void UIRect(const string id, const int x, const int y, const int w, const int h,
            const color bg, const color border)
{
   string nm = PFX + "P_" + id;
   if(ObjectFind(0, nm) < 0)
   {
      ObjectCreate(0, nm, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, nm, OBJPROP_CORNER, InpPanelCorner);
      ObjectSetInteger(0, nm, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_BACK, false);
      ObjectSetInteger(0, nm, OBJPROP_ZORDER, 10);
   }
   ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, nm, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, nm, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, border);
}

void UILabel(const string id, const int x, const int y, const string txt,
             const color c, const int fs, const string font = "Segoe UI")
{
   string nm = PFX + "P_" + id;
   if(ObjectFind(0, nm) < 0)
   {
      ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, nm, OBJPROP_CORNER, InpPanelCorner);
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_BACK, false);
      ObjectSetInteger(0, nm, OBJPROP_ZORDER, 11);
   }
   ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, nm, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, fs);
   ObjectSetString(0, nm, OBJPROP_FONT, font);
}

void RowLbl(const string id, const string label, const string val,
            const color vc, const int x, const int y)
{
   UILabel(id + "_l", x + 12, y, label, clrTextDim, 9);
   UILabel(id + "_v", x + 125, y, val, vc, 9, "Consolas");
}

void UIDraw()
{
   if(!InpShowPanel) return;

   uint now = GetTickCount();
   if(now - g_lastUI < 200) return;
   g_lastUI = now;

   ResetDailyCounter();

   int x  = InpPanelX;
   int y0 = InpPanelY;
   int W  = InpPanelWidth;

   // Background
   UIRect("bg",  x, y0, W, 740, clrPanelBG, clrBorder);
   UIRect("hdr", x, y0, W, 32,  clrHeaderBG, clrBorder);

   UILabel("ttl",  x + 12, y0 + 7, "APEX + DTC", clrTextMain, 12);
   UILabel("ttl2", x + 118, y0 + 7, "ELITE v1.2", clrAccent, 11);

   // Quality chip
   int top = MathMax(g_buyScore, g_sellScore);
   color chipBG = clrBorder;
   if(top >= InpAPlusScore)        chipBG = C'5,70,45';
   else if(top >= InpAScore)       chipBG = C'6,52,70';
   else if(top >= InpMinimumScore) chipBG = C'75,55,6';

   UIRect("chip", x + W - 60, y0 + 6, 48, 20, chipBG, chipBG);
   UILabel("chipT", x + W - 50, y0 + 9, g_quality, clrTextMain, 9, "Consolas");

   // Sub header
   UILabel("sub", x + 12, y0 + 36,
           _Symbol + " • " + TFStr(InpSetupTF) + " • EMA: " +
           (g_emaBull ? "BULL STACK" : (g_emaBear ? "BEAR STACK" : "MIXED")),
           clrTextDim, 8);

   // Banner
   color bbg = C'32,38,52';
   color btx = clrTextMain;
   if(g_confirmed)
   {
      bbg = g_planBuy ? C'5,58,38' : C'68,18,24';
      btx = g_planBuy ? clrBuy : clrSell;
   }
   else if(StringFind(g_signal, "BLOCKED") >= 0)
   {
      bbg = C'72,54,8';
      btx = C'255,185,55';
   }
   UIRect("ban", x + 8, y0 + 54, W - 16, 32, bbg, bbg);
   UILabel("banT", x + 18, y0 + 62, g_signal, btx, 12);

   // Score bars
   int sy = y0 + 96;
   int trkW = W - 145;
   UIRect("btrk", x + 58, sy, trkW, 13, C'28,34,46', C'28,34,46');
   UIRect("bfil", x + 58, sy, (int)(trkW * g_buyScore / 100.0), 13, C'6,75,48', C'6,75,48');
   UILabel("blb",  x + 12, sy - 1, "BUY", clrTextDim, 9);
   UILabel("bnum", x + 58 + trkW + 8, sy - 1, StringFormat("%3d", g_buyScore), clrBuy, 9, "Consolas");

   sy += 19;
   UIRect("strk", x + 58, sy, trkW, 13, C'28,34,46', C'28,34,46');
   UIRect("sfil", x + 58, sy, (int)(trkW * g_sellScore / 100.0), 13, C'90,24,30', C'90,24,30');
   UILabel("slb",  x + 12, sy - 1, "SELL", clrTextDim, 9);
   UILabel("snum", x + 58 + trkW + 8, sy - 1, StringFormat("%3d", g_sellScore), clrSell, 9, "Consolas");

   // Market Context
   int ry = y0 + 145;
   UIRect("acM", x + 8, ry, 3, 12, clrAccent, clrAccent);
   UILabel("hM", x + 16, ry - 2, "MARKET CONTEXT", clrAccent, 9);
   ry += 18;

   RowLbl("rHTF", "HTF BIAS", g_htf,
          g_htfBull ? clrBuy : (g_htfBear ? clrSell : clrTextMain), x, ry); ry += 16;
   RowLbl("rSTR", "STRUCTURE", g_trend,
          StringFind(g_trend, "BULL") >= 0 ? clrBuy :
          (StringFind(g_trend, "BEAR") >= 0 ? clrSell : clrTextDim), x, ry); ry += 16;
   RowLbl("rEMA", "EMA STACK",
          g_emaBull ? "BULLISH" : (g_emaBear ? "BEARISH" : "MIXED"),
          g_emaBull ? clrBuy : (g_emaBear ? clrSell : clrTextDim), x, ry); ry += 16;
   RowLbl("rEVT", "LAST EVENT", g_event, clrTextMain, x, ry); ry += 16;
   RowLbl("rREG", "REGIME", g_regime, clrTextMain, x, ry); ry += 16;
   RowLbl("rPD",  "PD ZONE", g_pdZone + " (" + DoubleToString(g_pdPct * 100, 0) + "%)",
          g_pdZone == "DISCOUNT" ? clrBuy :
          (g_pdZone == "PREMIUM" ? clrSell : clrTextMain), x, ry); ry += 16;
   RowLbl("rKZ",  "KILLZONE", g_kz, g_kzActive ? clrAccent : clrTextDim, x, ry); ry += 18;

   // DTC Multi-TF
   UIRect("acMTF", x + 8, ry, 3, 12, clrAccent, clrAccent);
   UILabel("hMTF", x + 16, ry - 2, "DTC MULTI-TF BIAS", clrAccent, 9);
   ry += 18;

   string tfs[5] = {"15M", "30M", "1H", "4H", "D1"};
   for(int i = 0; i < 5; i++)
   {
      color tc = g_mtfBull[i] ? clrBuy : (g_mtfBear[i] ? clrSell : clrTextDim);
      RowLbl("rMTF" + IntegerToString(i), tfs[i], g_mtfText[i], tc, x, ry);
      ry += 15;
   }
   ry += 6;

   // Liquidity
   UIRect("acL", x + 8, ry, 3, 12, clrAccent, clrAccent);
   UILabel("hL", x + 16, ry - 2, "LIQUIDITY MAP", clrAccent, 9);
   ry += 18;
   RowLbl("rSWP", "SWEEP", g_sweepTxt, g_sweepFound ? clrAccent : clrTextDim, x, ry); ry += 16;
   RowLbl("rABV", "ABOVE", g_nearAbove > 0 ? g_aboveTag + " " + DoubleToString(g_nearAbove, _Digits) : "—",
          clrSell, x, ry); ry += 16;
   RowLbl("rBLW", "BELOW", g_nearBelow > 0 ? g_belowTag + " " + DoubleToString(g_nearBelow, _Digits) : "—",
          clrBuy, x, ry); ry += 18;

   // Trade Plan
   UIRect("acT", x + 8, ry, 3, 12, clrAccent, clrAccent);
   UILabel("hT", x + 16, ry - 2, "TRADE PLAN" + (g_confirmed ? "" : "  (PREVIEW)"), clrAccent, 9);
   ry += 18;
   RowLbl("rOP",  "OP",  DoubleToString(g_op,  _Digits), clrOP, x, ry); ry += 15;
   RowLbl("rSL",  "SL",  DoubleToString(g_sl,  _Digits) + "  •  " + IntegerToString(g_riskPts) + "p", clrSL, x, ry); ry += 15;
   RowLbl("rT1",  "TP1", DoubleToString(g_tp1, _Digits) + "  •  " + DoubleToString(InpTP1RR, 1) + "R", clrTP, x, ry); ry += 15;
   RowLbl("rT2",  "TP2", DoubleToString(g_tp2, _Digits) + "  •  " + DoubleToString(InpTP2RR, 1) + "R", clrTP, x, ry); ry += 15;
   RowLbl("rT3",  "TP3", DoubleToString(g_tp3, _Digits) + "  •  " + DoubleToString(InpTP3RR, 1) + "R", clrTP, x, ry); ry += 15;
   RowLbl("rBE",  "BE",  DoubleToString(g_be,  _Digits), clrBE, x, ry); ry += 15;
   RowLbl("rTG",  "TARGET", g_targetTag, clrAccent, x, ry); ry += 18;

   // Footer
   double spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   UILabel("f1", x + 12, ry,
           StringFormat("SPRD %.0f   DAY %d/%d   SES %d/%d",
                        spr, g_daily, InpMaxSignalsDay, g_sess, InpMaxSignalsSession),
           clrTextDim, 8, "Consolas");
   ry += 16;

   string st2 = "STATUS: ARMED • SCANNING";
   color  st2c = clrTextDim;
   if(g_confirmed)
   {
      st2 = "STATUS: SIGNAL FIRED → EA HOOK";
      st2c = clrAccent;
   }
   else if(g_block != "" && StringFind(g_signal, "BLOCKED") >= 0)
   {
      long cd = 0;
      if(g_lastSignal > 0)
         cd = InpCooldownMinutes * 60 - (long)(TimeCurrent() - g_lastSignal);
      if(cd < 0) cd = 0;
      st2 = StringFormat("STATUS: %s • CD %02I64d:%02I64d", g_block, cd / 60, cd % 60);
      st2c = C'255,185,55';
   }
   UILabel("f2", x + 12, ry, st2, st2c, 8, "Consolas");

   ChartRedraw(0);
}
//+------------------------------------------------------------------+